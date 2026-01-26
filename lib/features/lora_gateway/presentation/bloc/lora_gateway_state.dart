part of 'lora_gateway_cubit.dart';

/// State for the LoRa Gateway feature.
@freezed
sealed class LoraGatewayState with _$LoraGatewayState {
  const factory LoraGatewayState({
    /// List of available USB devices.
    @Default([]) List<UsbDeviceInfo> availableDevices,

    /// Currently selected device.
    UsbDeviceInfo? selectedDevice,

    /// Current connection state.
    @Default(GatewayConnectionState.disconnected)
    GatewayConnectionState connectionState,

    /// Whether the gateway is actively processing transactions.
    @Default(false) bool isGatewayActive,

    /// Whether scanning for devices.
    @Default(false) bool isScanning,

    /// Transaction log entries (in-memory only).
    @Default([]) List<TransactionLogEntry> transactionLog,

    /// Number of transactions received.
    @Default(0) int txReceived,

    /// Number of transactions successfully broadcasted.
    @Default(0) int txBroadcasted,

    /// Number of failed transactions.
    @Default(0) int txFailed,

    /// Whether using testnet.
    @Default(false) bool isTestnet,

    /// Error message if any.
    String? error,

    /// Connected device name.
    String? connectedDeviceName,
  }) = _LoraGatewayState;

  const LoraGatewayState._();

  /// Whether connected to a Meshtastic device.
  bool get isConnected => connectionState == GatewayConnectionState.connected;

  /// Whether connecting to a device.
  bool get isConnecting => connectionState == GatewayConnectionState.connecting;

  /// Whether there's an error.
  bool get hasError => connectionState == GatewayConnectionState.error;

  /// Status text for display.
  String get statusText {
    switch (connectionState) {
      case GatewayConnectionState.disconnected:
        return 'Disconnected';
      case GatewayConnectionState.connecting:
        return 'Connecting...';
      case GatewayConnectionState.connected:
        return isGatewayActive ? 'Gateway Active' : 'Connected';
      case GatewayConnectionState.error:
        return 'Error';
    }
  }
}
