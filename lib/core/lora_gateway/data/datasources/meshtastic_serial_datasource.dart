import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:bb_mobile/core/lora_gateway/domain/entities/lora_message.dart';
import 'package:bb_mobile/core/lora_gateway/domain/entities/usb_device_info.dart';
import 'package:convert/convert.dart';
import 'package:usb_serial/usb_serial.dart';

/// BTX Protocol constants.
class BtxProtocol {
  static const int txStart = 0x01;
  static const int txChunk = 0x02;
  static const int txEnd = 0x03;
  static const int txAck = 0x04;
  static const int txError = 0x05;

  static const int chunkSize = 180;
  static const int maxTxSize = 2048;
  static const int privateAppPort = 256;

  // Error codes
  static const int errTooLarge = 1;
  static const int errTimeout = 2;
  static const int errInvalid = 3;
  static const int errBroadcastFailed = 4;
}

/// Datasource for communicating with Meshtastic devices via USB serial.
///
/// Handles:
/// - Scanning for USB serial devices
/// - Connecting/disconnecting from Meshtastic
/// - Parsing incoming BTX protocol messages
/// - Sending ACK/ERROR responses
class MeshtasticSerialDatasource {
  MeshtasticSerialDatasource();

  UsbPort? _port;
  StreamSubscription<Uint8List>? _inputSubscription;
  final _messageController = StreamController<LoraMessage>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final List<int> _inputBuffer = [];

  /// Stream of parsed LoRa messages.
  Stream<LoraMessage> get messageStream => _messageController.stream;

  /// Stream of connection state changes.
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Whether currently connected to a device.
  bool get isConnected => _port != null;

  /// Scans for available USB serial devices.
  Future<List<UsbDeviceInfo>> scanDevices() async {
    if (!Platform.isAndroid) {
      return [];
    }

    try {
      final devices = await UsbSerial.listDevices();
      return devices
          .where((device) => device.deviceId != null)
          .map((device) => UsbDeviceInfo(
        deviceId: device.deviceId!,
        port: device.deviceId.toString(),
        productName: device.productName,
        manufacturerName: device.manufacturerName,
        vendorId: device.vid,
        productId: device.pid,
      )).toList();
    } catch (e) {
      return [];
    }
  }

  /// Connects to a USB serial device.
  Future<void> connect(UsbDeviceInfo deviceInfo) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('USB serial is only supported on Android');
    }

    await disconnect();

    try {
      final devices = await UsbSerial.listDevices();
      final device = devices.firstWhere(
        (d) => d.deviceId == deviceInfo.deviceId,
        orElse: () => throw Exception('Device not found'),
      );

      _port = await device.create();
      if (_port == null) {
        throw Exception('Failed to create USB port');
      }

      final openResult = await _port!.open();
      if (!openResult) {
        _port = null;
        throw Exception('Failed to open USB port');
      }

      // Configure serial port for Meshtastic
      await _port!.setDTR(true);
      await _port!.setRTS(true);
      await _port!.setPortParameters(
        115200,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      // Listen for incoming data
      _inputSubscription = _port!.inputStream?.listen(
        _onDataReceived,
        onError: (error) {
          _connectionController.add(false);
        },
        onDone: () {
          _connectionController.add(false);
        },
      );

      _connectionController.add(true);
    } catch (e) {
      await disconnect();
      rethrow;
    }
  }

  /// Disconnects from the current device.
  Future<void> disconnect() async {
    try {
      await _inputSubscription?.cancel();
      _inputSubscription = null;

      await _port?.close();
      _port = null;

      _inputBuffer.clear();
      _connectionController.add(false);
    } catch (e) {
      // Ignore disconnection errors
    }
  }

  /// Processes incoming serial data.
  void _onDataReceived(Uint8List data) {
    _inputBuffer.addAll(data);
    _processBuffer();
  }

  /// Processes the input buffer to extract complete messages.
  void _processBuffer() {
    // Try to parse Meshtastic serial protocol
    // Meshtastic uses a simple framing: 0x94 0xC3 <len_high> <len_low> <payload>
    while (_inputBuffer.length >= 4) {
      // Look for Meshtastic magic bytes
      final magicIndex = _findMeshtasticFrame();
      if (magicIndex < 0) {
        // No magic found, check for text-based BTX messages
        _tryParseTextMessage();
        break;
      }

      // Skip bytes before magic
      if (magicIndex > 0) {
        _inputBuffer.removeRange(0, magicIndex);
      }

      if (_inputBuffer.length < 4) break;

      // Parse frame length
      final lenHigh = _inputBuffer[2];
      final lenLow = _inputBuffer[3];
      final payloadLen = (lenHigh << 8) | lenLow;

      if (payloadLen > 2048) {
        // Invalid length, skip this frame
        _inputBuffer.removeAt(0);
        continue;
      }

      final totalLen = 4 + payloadLen;
      if (_inputBuffer.length < totalLen) {
        // Wait for more data
        break;
      }

      // Extract payload
      final payload = _inputBuffer.sublist(4, totalLen);
      _inputBuffer.removeRange(0, totalLen);

      // Parse the Meshtastic payload
      _parseMeshtasticPayload(Uint8List.fromList(payload));
    }

    // Limit buffer size to prevent memory issues
    if (_inputBuffer.length > 8192) {
      _inputBuffer.removeRange(0, _inputBuffer.length - 4096);
    }
  }

  /// Finds the start of a Meshtastic frame in the buffer.
  int _findMeshtasticFrame() {
    for (var i = 0; i < _inputBuffer.length - 1; i++) {
      if (_inputBuffer[i] == 0x94 && _inputBuffer[i + 1] == 0xC3) {
        return i;
      }
    }
    return -1;
  }

  /// Attempts to parse a text-based BTX message from the buffer.
  void _tryParseTextMessage() {
    // Convert buffer to string and look for newlines
    final text = String.fromCharCodes(_inputBuffer);
    final newlineIndex = text.indexOf('\n');

    if (newlineIndex >= 0) {
      final line = text.substring(0, newlineIndex).trim();
      _inputBuffer.removeRange(0, newlineIndex + 1);

      if (line.isNotEmpty) {
        _parseTextLine(line);
      }
    }
  }

  /// Parses a text line for BTX format or raw hex.
  void _parseTextLine(String line) {
    final now = DateTime.now();

    // Check for BTX:n/total:data format
    if (line.startsWith('BTX:')) {
      final parts = line.split(':');
      if (parts.length >= 3) {
        final chunkInfo = parts[1].split('/');
        if (chunkInfo.length == 2) {
          final chunkNum = int.tryParse(chunkInfo[0]);
          final totalChunks = int.tryParse(chunkInfo[1]);
          final hexData = parts.sublist(2).join(':');

          if (chunkNum != null && totalChunks != null) {
            _messageController.add(LoraBtxTextMessage(
              sender: 'text',
              timestamp: now,
              chunkNumber: chunkNum,
              totalChunks: totalChunks,
              hexData: hexData,
            ));
            return;
          }
        }
      }
    }

    // Check for raw hex transaction
    final cleanHex = line.replaceAll(' ', '').replaceAll('0x', '');
    if (_isValidHex(cleanHex) && cleanHex.length >= 60) {
      _messageController.add(LoraTextMessage(
        sender: 'text',
        timestamp: now,
        text: cleanHex,
      ));
    }
  }

  /// Parses a Meshtastic protobuf payload.
  void _parseMeshtasticPayload(Uint8List payload) {
    // Simplified parsing - look for BTX binary messages in the payload
    // The actual Meshtastic protobuf is complex, but BTX messages have a simple format

    for (var i = 0; i < payload.length; i++) {
      final byte = payload[i];

      // Look for BTX message type bytes
      if (byte == BtxProtocol.txStart ||
          byte == BtxProtocol.txChunk ||
          byte == BtxProtocol.txEnd) {
        final remaining = payload.sublist(i);
        final message = _parseBtxMessage(remaining);
        if (message != null) {
          _messageController.add(message);
          return;
        }
      }
    }

    // Try to extract text from payload
    try {
      final text = String.fromCharCodes(payload);
      if (text.contains('BTX:') || _isValidHex(text.trim())) {
        _parseTextLine(text.trim());
      }
    } catch (_) {
      // Not valid text
    }
  }

  /// Parses a BTX binary message.
  LoraMessage? _parseBtxMessage(Uint8List data) {
    if (data.isEmpty) return null;

    final now = DateTime.now();
    final msgType = data[0];

    switch (msgType) {
      case BtxProtocol.txStart:
        if (data.length >= 4) {
          final txId = data[1];
          final totalSize = (data[2] << 8) | data[3];
          return LoraTxStartMessage(
            sender: 'mesh',
            timestamp: now,
            txId: txId,
            totalSize: totalSize,
          );
        }

      case BtxProtocol.txChunk:
        if (data.length >= 3) {
          final txId = data[1];
          final chunkIndex = data[2];
          final chunkData = data.sublist(3);
          return LoraTxChunkMessage(
            sender: 'mesh',
            timestamp: now,
            txId: txId,
            chunkIndex: chunkIndex,
            data: chunkData.toList(),
          );
        }

      case BtxProtocol.txEnd:
        if (data.length >= 2) {
          final txId = data[1];
          return LoraTxEndMessage(
            sender: 'mesh',
            timestamp: now,
            txId: txId,
          );
        }
    }

    return null;
  }

  /// Sends an ACK message with TXID back to the sender.
  Future<void> sendAckWithTxid(int btxTxId, String txid) async {
    if (_port == null) return;

    try {
      final txidBytes = hex.decode(txid);
      final message = <int>[
        BtxProtocol.txAck,
        btxTxId,
        ...txidBytes.take(32), // TXID is 32 bytes
      ];

      final frame = _buildMeshtasticFrame(Uint8List.fromList(message));
      await _port!.write(frame);
    } catch (e) {
      // Log error but don't throw
    }
  }

  /// Sends an error message back to the sender.
  Future<void> sendError(int btxTxId, int errorCode) async {
    if (_port == null) return;

    try {
      final message = Uint8List.fromList([
        BtxProtocol.txError,
        btxTxId,
        errorCode,
      ]);

      final frame = _buildMeshtasticFrame(message);
      await _port!.write(frame);
    } catch (e) {
      // Log error but don't throw
    }
  }

  /// Builds a Meshtastic serial frame.
  Uint8List _buildMeshtasticFrame(Uint8List payload) {
    final len = payload.length;
    return Uint8List.fromList([
      0x94, 0xC3,           // Magic bytes
      (len >> 8) & 0xFF,    // Length high byte
      len & 0xFF,           // Length low byte
      ...payload,
    ]);
  }

  /// Checks if a string contains only valid hex characters.
  bool _isValidHex(String s) {
    final hexRegex = RegExp(r'^[0-9a-fA-F]+$');
    return hexRegex.hasMatch(s) && s.length % 2 == 0;
  }

  /// Disposes of resources.
  Future<void> dispose() async {
    await disconnect();
    await _messageController.close();
    await _connectionController.close();
  }
}
