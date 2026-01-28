import 'dart:async';
import 'dart:typed_data';
import 'package:bb_mobile/features/disaster_tx/domain/entities/meshtastic_device.dart';
import 'package:bb_mobile/features/disaster_tx/domain/entities/tx_chunk.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Data source for communicating with Meshtastic devices via BLE.
class MeshtasticBleDatasource {
  MeshtasticBleDatasource();

  // Meshtastic BLE UUIDs
  static final _serviceUuid = Guid('6ba1b218-15a8-461f-9fa8-5dcae273eafd');
  static final _toRadioUuid = Guid('f75c76d2-129e-4dad-a1dd-7866124401e7');

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _toRadioCharacteristic;
  int _currentMtu = 23; // Default BLE MTU

  /// Scan for nearby Meshtastic devices.
  Stream<MeshtasticDevice> scanDevices({Duration timeout = const Duration(seconds: 15)}) async* {
    // Start scanning
    await FlutterBluePlus.startScan(
      timeout: timeout,
      androidUsesFineLocation: true,
    );

    // Listen to scan results
    await for (final result in FlutterBluePlus.scanResults) {
      for (final r in result) {
        final name = r.device.platformName;
        if (name.toLowerCase().contains('meshtastic')) {
          yield MeshtasticDevice(
            name: name,
            address: r.device.remoteId.str,
            rssi: r.rssi,
          );
        }
      }
    }

    // Stop scanning when done
    await FlutterBluePlus.stopScan();
  }

  /// Connect to a Meshtastic device.
  Future<void> connect(MeshtasticDevice device) async {
    final bleDevice = BluetoothDevice.fromId(device.address);

    // Connect to device
    await bleDevice.connect(timeout: const Duration(seconds: 15));
    _connectedDevice = bleDevice;

    // Request MTU negotiation
    try {
      final mtu = await bleDevice.requestMtu(512);
      _currentMtu = mtu;
    } catch (e) {
      _currentMtu = 23; // Fallback to default
    }

    // Discover services
    final services = await bleDevice.discoverServices();

    // Find Meshtastic service and ToRadio characteristic
    for (final service in services) {
      if (service.uuid == _serviceUuid) {
        for (final characteristic in service.characteristics) {
          if (characteristic.uuid == _toRadioUuid) {
            _toRadioCharacteristic = characteristic;
            return;
          }
        }
      }
    }

    throw Exception('Meshtastic service or ToRadio characteristic not found');
  }

  /// Disconnect from the current device.
  Future<void> disconnect() async {
    await _connectedDevice?.disconnect();
    _connectedDevice = null;
    _toRadioCharacteristic = null;
    _currentMtu = 23;
  }

  /// Send a transaction chunk via BLE with retry logic.
  Future<void> sendChunk(TxChunk chunk) async {
    if (_toRadioCharacteristic == null) {
      throw Exception('Not connected to any device');
    }

    const maxRetries = 1;
    int retries = 0;

    while (retries <= maxRetries) {
      try {
        // Build Meshtastic protobuf packet
        final packet = _buildMeshtasticPacket(chunk.formattedMessage);

        // Send via BLE with confirmation
        await _toRadioCharacteristic!.write(
          packet,
          withoutResponse: false, // Wait for BLE confirmation
          timeout: 5, // 5 second timeout per chunk
        );

        // Success - wait between chunks for mesh stability
        await Future.delayed(const Duration(seconds: 2));
        return;
      } catch (e) {
        retries++;
        if (retries > maxRetries) {
          throw Exception('Failed to send chunk after $maxRetries retries: $e');
        }

        // Wait before retry
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  /// Get current MTU value.
  int get currentMtu => _currentMtu;

  /// Check if currently connected.
  bool get isConnected => _connectedDevice != null && _toRadioCharacteristic != null;

  /// Build a Meshtastic ToRadio protobuf packet with BLE framing.
  ///
  /// Packet structure (from BtcMesh MainActivity.kt):
  /// ```
  /// [0x94][0xC3][len_low][len_high]  ← BLE framing header
  ///     ↓
  /// ToRadio {
  ///   packet: MeshPacket {
  ///     to: 0xFFFFFFFF (broadcast)
  ///     decoded: Data {
  ///       portnum: 1 (TEXT_MESSAGE_APP)
  ///       payload: "BTX:1/3:..."
  ///     }
  ///     id: <random>
  ///     hop_limit: 6
  ///     want_ack: true
  ///   }
  /// }
  /// ```
  Uint8List _buildMeshtasticPacket(String message) {
    final payload = Uint8List.fromList(message.codeUnits);

    // Build Data message (inner payload)
    final dataMsg = <int>[];
    // portnum = 1 (TEXT_MESSAGE_APP) - field 1, varint
    dataMsg.add(0x08); // field 1, wire type 0
    dataMsg.add(0x01); // value = 1
    // payload - field 2, length-delimited
    dataMsg.add(0x12); // field 2, wire type 2
    _writeVarint(dataMsg, payload.length);
    dataMsg.addAll(payload);

    // Build MeshPacket
    final meshPacket = <int>[];

    // to = 0xFFFFFFFF (broadcast) - field 2, fixed32
    meshPacket.add(0x15); // field 2, wire type 5 (fixed32)
    meshPacket.addAll([0xFF, 0xFF, 0xFF, 0xFF]); // broadcast address

    // decoded = Data - field 4, length-delimited
    meshPacket.add(0x22); // field 4, wire type 2
    _writeVarint(meshPacket, dataMsg.length);
    meshPacket.addAll(dataMsg);

    // id = random packet ID - field 6, fixed32
    final packetId = DateTime.now().millisecondsSinceEpoch & 0xFFFFFFFF;
    meshPacket.add(0x35); // field 6, wire type 5 (fixed32)
    meshPacket.add(packetId & 0xFF);
    meshPacket.add((packetId >> 8) & 0xFF);
    meshPacket.add((packetId >> 16) & 0xFF);
    meshPacket.add((packetId >> 24) & 0xFF);

    // hop_limit = 6 - field 9, varint
    meshPacket.add(0x48); // field 9, wire type 0
    meshPacket.add(0x06); // value = 6

    // want_ack = true - field 10, varint
    meshPacket.add(0x50); // field 10, wire type 0
    meshPacket.add(0x01); // true

    // Build ToRadio wrapper
    final toRadio = <int>[];
    // packet - field 1, length-delimited
    toRadio.add(0x0A); // field 1, wire type 2
    _writeVarint(toRadio, meshPacket.length);
    toRadio.addAll(meshPacket);

    // Add Meshtastic BLE framing header
    // Format: [0x94][0xC3][len_low][len_high][protobuf...]
    final framedPacket = <int>[];
    framedPacket.add(0x94); // Magic byte 1
    framedPacket.add(0xC3); // Magic byte 2
    framedPacket.add(toRadio.length & 0xFF); // Length low byte
    framedPacket.add((toRadio.length >> 8) & 0xFF); // Length high byte
    framedPacket.addAll(toRadio);

    return Uint8List.fromList(framedPacket);
  }

  /// Write a varint to the buffer (protobuf encoding).
  void _writeVarint(List<int> buffer, int value) {
    var v = value;
    while ((v & ~0x7F) != 0) {
      buffer.add((v & 0x7F) | 0x80);
      v = v >> 7;
    }
    buffer.add(v & 0x7F);
  }
}
