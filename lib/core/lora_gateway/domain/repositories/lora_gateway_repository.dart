import 'package:bb_mobile/core/lora_gateway/domain/entities/gateway_status.dart';
import 'package:bb_mobile/core/lora_gateway/domain/entities/transaction_log_entry.dart';
import 'package:bb_mobile/core/lora_gateway/domain/entities/usb_device_info.dart';

/// Repository interface for the LoRa Gateway functionality.
abstract class LoraGatewayRepository {
  /// Stream of gateway status updates.
  Stream<GatewayStatus> get statusStream;

  /// Stream of transaction log entries.
  Stream<TransactionLogEntry> get transactionLogStream;

  /// Stream of complete transactions ready to broadcast (as hex strings).
  Stream<(String txHex, String sender, String logEntryId)> get completeTxStream;

  /// Gets the current gateway status.
  GatewayStatus get currentStatus;

  /// Scans for available USB serial devices.
  Future<List<UsbDeviceInfo>> scanDevices();

  /// Connects to a Meshtastic device.
  Future<void> connect(UsbDeviceInfo device);

  /// Disconnects from the current device.
  Future<void> disconnect();

  /// Starts the gateway (begins listening for and processing transactions).
  void startGateway();

  /// Stops the gateway.
  void stopGateway();

  /// Reports a successful broadcast, triggering ACK to sender.
  Future<void> reportBroadcastSuccess(String logEntryId, String txid);

  /// Reports a failed broadcast.
  void reportBroadcastFailure(String logEntryId, String errorMessage);

  /// Sets whether to use testnet.
  void setTestnet(bool isTestnet);

  /// Gets the recent transaction log entries.
  List<TransactionLogEntry> getTransactionLog();

  /// Clears the transaction log.
  void clearTransactionLog();

  /// Disposes of resources.
  Future<void> dispose();
}
