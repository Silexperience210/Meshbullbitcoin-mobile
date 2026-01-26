/// Represents the connection state of the LoRa Gateway.
enum GatewayConnectionState {
  /// Not connected to any Meshtastic device.
  disconnected,

  /// Attempting to connect to a Meshtastic device.
  connecting,

  /// Successfully connected to a Meshtastic device.
  connected,

  /// Connection failed or was lost.
  error,
}

/// Represents the overall status of the LoRa Gateway.
class GatewayStatus {
  const GatewayStatus({
    this.connectionState = GatewayConnectionState.disconnected,
    this.deviceName,
    this.devicePort,
    this.isGatewayActive = false,
    this.txReceived = 0,
    this.txBroadcasted = 0,
    this.txFailed = 0,
    this.lastError,
    this.isTestnet = false,
  });

  final GatewayConnectionState connectionState;
  final String? deviceName;
  final String? devicePort;
  final bool isGatewayActive;
  final int txReceived;
  final int txBroadcasted;
  final int txFailed;
  final String? lastError;
  final bool isTestnet;

  bool get isConnected => connectionState == GatewayConnectionState.connected;
  bool get hasError => connectionState == GatewayConnectionState.error;

  GatewayStatus copyWith({
    GatewayConnectionState? connectionState,
    String? deviceName,
    String? devicePort,
    bool? isGatewayActive,
    int? txReceived,
    int? txBroadcasted,
    int? txFailed,
    String? lastError,
    bool? isTestnet,
  }) {
    return GatewayStatus(
      connectionState: connectionState ?? this.connectionState,
      deviceName: deviceName ?? this.deviceName,
      devicePort: devicePort ?? this.devicePort,
      isGatewayActive: isGatewayActive ?? this.isGatewayActive,
      txReceived: txReceived ?? this.txReceived,
      txBroadcasted: txBroadcasted ?? this.txBroadcasted,
      txFailed: txFailed ?? this.txFailed,
      lastError: lastError ?? this.lastError,
      isTestnet: isTestnet ?? this.isTestnet,
    );
  }

  @override
  String toString() => 'GatewayStatus('
      'connectionState: $connectionState, '
      'deviceName: $deviceName, '
      'isGatewayActive: $isGatewayActive, '
      'txReceived: $txReceived, '
      'txBroadcasted: $txBroadcasted)';
}
