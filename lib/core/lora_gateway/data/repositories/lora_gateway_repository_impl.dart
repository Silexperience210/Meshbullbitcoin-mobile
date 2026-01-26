import 'dart:async';

import 'package:bb_mobile/core/lora_gateway/data/datasources/meshtastic_serial_datasource.dart';
import 'package:bb_mobile/core/lora_gateway/domain/entities/gateway_status.dart';
import 'package:bb_mobile/core/lora_gateway/domain/entities/lora_message.dart';
import 'package:bb_mobile/core/lora_gateway/domain/entities/pending_transaction.dart';
import 'package:bb_mobile/core/lora_gateway/domain/entities/transaction_log_entry.dart';
import 'package:bb_mobile/core/lora_gateway/domain/entities/usb_device_info.dart';
import 'package:bb_mobile/core/lora_gateway/domain/repositories/lora_gateway_repository.dart';
import 'package:convert/convert.dart';

/// Implementation of [LoraGatewayRepository].
class LoraGatewayRepositoryImpl implements LoraGatewayRepository {
  LoraGatewayRepositoryImpl({
    required MeshtasticSerialDatasource meshtasticDatasource,
  }) : _datasource = meshtasticDatasource;

  final MeshtasticSerialDatasource _datasource;

  // State
  GatewayStatus _status = const GatewayStatus();
  final Map<int, PendingTransaction> _pendingTxs = {};
  final Map<String, _TextTxBuffer> _textBuffers = {};
  final List<TransactionLogEntry> _transactionLog = [];
  int _logEntryCounter = 0;

  // Subscriptions
  StreamSubscription<LoraMessage>? _messageSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  Timer? _cleanupTimer;

  // Stream controllers
  final _statusController = StreamController<GatewayStatus>.broadcast();
  final _logController = StreamController<TransactionLogEntry>.broadcast();
  final _completeTxController =
      StreamController<(String, String, String)>.broadcast();

  @override
  Stream<GatewayStatus> get statusStream => _statusController.stream;

  @override
  Stream<TransactionLogEntry> get transactionLogStream => _logController.stream;

  @override
  Stream<(String, String, String)> get completeTxStream =>
      _completeTxController.stream;

  @override
  GatewayStatus get currentStatus => _status;

  @override
  Future<List<UsbDeviceInfo>> scanDevices() {
    return _datasource.scanDevices();
  }

  @override
  Future<void> connect(UsbDeviceInfo device) async {
    _updateStatus(_status.copyWith(
      connectionState: GatewayConnectionState.connecting,
      lastError: null,
    ));

    try {
      await _datasource.connect(device);

      // Listen for connection changes
      _connectionSubscription = _datasource.connectionStream.listen((connected) {
        if (!connected && _status.isConnected) {
          _updateStatus(_status.copyWith(
            connectionState: GatewayConnectionState.disconnected,
            isGatewayActive: false,
          ));
        }
      });

      _updateStatus(_status.copyWith(
        connectionState: GatewayConnectionState.connected,
        deviceName: device.displayName,
        devicePort: device.port,
      ));
    } catch (e) {
      _updateStatus(_status.copyWith(
        connectionState: GatewayConnectionState.error,
        lastError: e.toString(),
      ));
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    stopGateway();
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    await _datasource.disconnect();

    _updateStatus(_status.copyWith(
      connectionState: GatewayConnectionState.disconnected,
      deviceName: null,
      devicePort: null,
      isGatewayActive: false,
    ));
  }

  @override
  void startGateway() {
    if (!_status.isConnected) return;

    // Start listening for messages
    _messageSubscription = _datasource.messageStream.listen(_handleMessage);

    // Start cleanup timer for expired transactions
    _cleanupTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _cleanupExpiredTransactions(),
    );

    _updateStatus(_status.copyWith(isGatewayActive: true));
  }

  @override
  void stopGateway() {
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _pendingTxs.clear();
    _textBuffers.clear();

    if (_status.isGatewayActive) {
      _updateStatus(_status.copyWith(isGatewayActive: false));
    }
  }

  @override
  Future<void> reportBroadcastSuccess(String logEntryId, String txid) async {
    // Update log entry
    final index = _transactionLog.indexWhere((e) => e.id == logEntryId);
    if (index >= 0) {
      final entry = _transactionLog[index].copyWith(
        status: TransactionLogStatus.broadcasted,
        txid: txid,
      );
      _transactionLog[index] = entry;
      _logController.add(entry);

      // Find the btxTxId from the entry id
      final btxTxId = int.tryParse(logEntryId.split('_').last) ?? 0;

      // Send ACK with TXID via LoRa
      await _datasource.sendAckWithTxid(btxTxId, txid);
    }

    _updateStatus(_status.copyWith(
      txBroadcasted: _status.txBroadcasted + 1,
    ));
  }

  @override
  void reportBroadcastFailure(String logEntryId, String errorMessage) {
    final index = _transactionLog.indexWhere((e) => e.id == logEntryId);
    if (index >= 0) {
      final entry = _transactionLog[index].copyWith(
        status: TransactionLogStatus.failed,
        errorMessage: errorMessage,
      );
      _transactionLog[index] = entry;
      _logController.add(entry);

      // Send error via LoRa
      final btxTxId = int.tryParse(logEntryId.split('_').last) ?? 0;
      _datasource.sendError(btxTxId, BtxProtocol.errBroadcastFailed);
    }

    _updateStatus(_status.copyWith(
      txFailed: _status.txFailed + 1,
    ));
  }

  @override
  void setTestnet(bool isTestnet) {
    _updateStatus(_status.copyWith(isTestnet: isTestnet));
  }

  @override
  List<TransactionLogEntry> getTransactionLog() {
    return List.unmodifiable(_transactionLog);
  }

  @override
  void clearTransactionLog() {
    _transactionLog.clear();
  }

  @override
  Future<void> dispose() async {
    stopGateway();
    await disconnect();
    await _statusController.close();
    await _logController.close();
    await _completeTxController.close();
    await _datasource.dispose();
  }

  void _updateStatus(GatewayStatus newStatus) {
    _status = newStatus;
    _statusController.add(_status);
  }

  void _handleMessage(LoraMessage message) {
    switch (message) {
      case LoraTxStartMessage():
        _handleTxStart(message);
      case LoraTxChunkMessage():
        _handleTxChunk(message);
      case LoraTxEndMessage():
        _handleTxEnd(message);
      case LoraBtxTextMessage():
        _handleBtxTextMessage(message);
      case LoraTextMessage():
        _handleTextMessage(message);
    }
  }

  void _handleTxStart(LoraTxStartMessage message) {
    if (message.totalSize > BtxProtocol.maxTxSize) {
      _datasource.sendError(message.txId, BtxProtocol.errTooLarge);
      return;
    }

    final pending = PendingTransaction(
      txId: message.txId,
      totalSize: message.totalSize,
      sender: message.sender,
    );

    _pendingTxs[message.txId] = pending;

    // Create log entry
    final logEntry = _createLogEntry(
      sender: message.sender,
      status: TransactionLogStatus.receiving,
      size: message.totalSize,
      chunksTotal: pending.expectedChunks,
      txId: message.txId,
    );
    _addLogEntry(logEntry);
  }

  void _handleTxChunk(LoraTxChunkMessage message) {
    final pending = _pendingTxs[message.txId];
    if (pending == null) return;

    pending.addChunk(message.chunkIndex, message.data);

    // Update log entry
    _updateLogEntryProgress(message.txId, pending.receivedChunks);
  }

  void _handleTxEnd(LoraTxEndMessage message) {
    final pending = _pendingTxs.remove(message.txId);
    if (pending == null) return;

    if (!pending.isComplete) {
      _datasource.sendError(message.txId, BtxProtocol.errInvalid);
      _updateLogEntryStatus(
        message.txId,
        TransactionLogStatus.failed,
        errorMessage: 'Incomplete transaction: ${pending.receivedChunks}/${pending.expectedChunks} chunks',
      );
      return;
    }

    final txBytes = pending.reassemble();
    if (txBytes == null) {
      _datasource.sendError(message.txId, BtxProtocol.errInvalid);
      _updateLogEntryStatus(
        message.txId,
        TransactionLogStatus.failed,
        errorMessage: 'Failed to reassemble transaction',
      );
      return;
    }

    final txHex = hex.encode(txBytes);
    final logEntryId = 'tx_${message.txId}';

    _updateLogEntryStatus(message.txId, TransactionLogStatus.broadcasting);
    _updateStatus(_status.copyWith(txReceived: _status.txReceived + 1));

    // Emit complete transaction for broadcast
    _completeTxController.add((txHex, pending.sender, logEntryId));
  }

  void _handleBtxTextMessage(LoraBtxTextMessage message) {
    final key = 'btx_${message.sender}';
    var buffer = _textBuffers[key];

    if (buffer == null || buffer.totalChunks != message.totalChunks) {
      buffer = _TextTxBuffer(
        sender: message.sender,
        totalChunks: message.totalChunks,
      );
      _textBuffers[key] = buffer;

      // Create log entry
      final logEntry = _createLogEntry(
        sender: message.sender,
        status: TransactionLogStatus.receiving,
        chunksTotal: message.totalChunks,
        txId: key.hashCode,
      );
      _addLogEntry(logEntry);
    }

    buffer.addChunk(message.chunkNumber, message.hexData);
    buffer.lastUpdate = DateTime.now();

    if (buffer.isComplete) {
      _textBuffers.remove(key);
      final txHex = buffer.reassemble();

      if (txHex != null && _isValidTransaction(txHex)) {
        final logEntryId = 'tx_${key.hashCode}';
        _updateLogEntryStatus(key.hashCode, TransactionLogStatus.broadcasting);
        _updateStatus(_status.copyWith(txReceived: _status.txReceived + 1));
        _completeTxController.add((txHex, message.sender, logEntryId));
      } else {
        _updateLogEntryStatus(
          key.hashCode,
          TransactionLogStatus.failed,
          errorMessage: 'Invalid transaction data',
        );
      }
    }
  }

  void _handleTextMessage(LoraTextMessage message) {
    final cleanHex = message.text.replaceAll(' ', '').replaceAll('0x', '');

    if (_isValidTransaction(cleanHex)) {
      final logEntryId = 'tx_text_${_logEntryCounter}';
      final logEntry = _createLogEntry(
        sender: message.sender,
        status: TransactionLogStatus.broadcasting,
        size: cleanHex.length ~/ 2,
        txId: _logEntryCounter,
      );
      _addLogEntry(logEntry);

      _updateStatus(_status.copyWith(txReceived: _status.txReceived + 1));
      _completeTxController.add((cleanHex, message.sender, logEntryId));
    }
  }

  bool _isValidTransaction(String txHex) {
    if (txHex.length < 120) return false; // Minimum ~60 bytes
    if (txHex.length > BtxProtocol.maxTxSize * 2) return false;

    // Check for valid hex
    final hexRegex = RegExp(r'^[0-9a-fA-F]+$');
    if (!hexRegex.hasMatch(txHex)) return false;

    try {
      final bytes = hex.decode(txHex);

      // Check version (first 4 bytes, little-endian)
      if (bytes.length < 10) return false;
      final version = bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24);
      if (version != 1 && version != 2) return false;

      return true;
    } catch (_) {
      return false;
    }
  }

  TransactionLogEntry _createLogEntry({
    required String sender,
    required TransactionLogStatus status,
    int? size,
    int chunksTotal = 0,
    int? txId,
  }) {
    _logEntryCounter++;
    return TransactionLogEntry(
      id: 'tx_${txId ?? _logEntryCounter}',
      sender: sender,
      timestamp: DateTime.now(),
      status: status,
      size: size,
      chunksTotal: chunksTotal,
    );
  }

  void _addLogEntry(TransactionLogEntry entry) {
    _transactionLog.insert(0, entry);
    _logController.add(entry);

    // Keep log size limited
    if (_transactionLog.length > 100) {
      _transactionLog.removeLast();
    }
  }

  void _updateLogEntryProgress(int txId, int chunksReceived) {
    final id = 'tx_$txId';
    final index = _transactionLog.indexWhere((e) => e.id == id);
    if (index >= 0) {
      final entry = _transactionLog[index].copyWith(
        chunksReceived: chunksReceived,
      );
      _transactionLog[index] = entry;
      _logController.add(entry);
    }
  }

  void _updateLogEntryStatus(
    int txId,
    TransactionLogStatus status, {
    String? errorMessage,
  }) {
    final id = 'tx_$txId';
    final index = _transactionLog.indexWhere((e) => e.id == id);
    if (index >= 0) {
      final entry = _transactionLog[index].copyWith(
        status: status,
        errorMessage: errorMessage,
      );
      _transactionLog[index] = entry;
      _logController.add(entry);
    }
  }

  void _cleanupExpiredTransactions() {
    final expiredIds = <int>[];

    for (final entry in _pendingTxs.entries) {
      if (entry.value.isExpired) {
        expiredIds.add(entry.key);
        _datasource.sendError(entry.key, BtxProtocol.errTimeout);
        _updateLogEntryStatus(
          entry.key,
          TransactionLogStatus.failed,
          errorMessage: 'Timeout waiting for chunks',
        );
      }
    }

    for (final id in expiredIds) {
      _pendingTxs.remove(id);
    }

    // Cleanup text buffers
    final expiredTextKeys = <String>[];
    for (final entry in _textBuffers.entries) {
      if (entry.value.isExpired) {
        expiredTextKeys.add(entry.key);
      }
    }

    for (final key in expiredTextKeys) {
      _textBuffers.remove(key);
    }
  }
}

/// Buffer for text-based BTX messages.
class _TextTxBuffer {
  _TextTxBuffer({
    required this.sender,
    required this.totalChunks,
  }) : chunks = {},
       lastUpdate = DateTime.now();

  final String sender;
  final int totalChunks;
  final Map<int, String> chunks;
  DateTime lastUpdate;

  bool get isComplete => chunks.length == totalChunks;
  bool get isExpired =>
      DateTime.now().difference(lastUpdate).inSeconds > 60;

  void addChunk(int number, String data) {
    chunks[number] = data;
  }

  String? reassemble() {
    if (!isComplete) return null;

    final buffer = StringBuffer();
    for (var i = 1; i <= totalChunks; i++) {
      final chunk = chunks[i];
      if (chunk == null) return null;
      buffer.write(chunk);
    }
    return buffer.toString();
  }
}

/// BTX Protocol constants (duplicated for convenience).
class BtxProtocol {
  static const int errTooLarge = 1;
  static const int errTimeout = 2;
  static const int errInvalid = 3;
  static const int errBroadcastFailed = 4;
  static const int maxTxSize = 2048;
}
