/// Represents a Meshtastic device discovered via BLE scan.
class MeshtasticDevice {
  const MeshtasticDevice({
    required this.name,
    required this.address,
    required this.rssi,
    this.mtu = 23, // Default BLE MTU
  });

  final String name;
  final String address;
  final int rssi; // Signal strength
  final int mtu;

  /// Calculate effective chunk size based on MTU.
  /// MTU - 3 (ATT header) - 50 (protobuf overhead)
  int get effectiveChunkSize => (mtu - 3 - 50).clamp(50, 400);

  /// Get signal quality indicator.
  SignalQuality get signalQuality {
    if (rssi >= -60) return SignalQuality.excellent;
    if (rssi >= -70) return SignalQuality.good;
    if (rssi >= -80) return SignalQuality.fair;
    return SignalQuality.poor;
  }

  MeshtasticDevice copyWith({
    String? name,
    String? address,
    int? rssi,
    int? mtu,
  }) {
    return MeshtasticDevice(
      name: name ?? this.name,
      address: address ?? this.address,
      rssi: rssi ?? this.rssi,
      mtu: mtu ?? this.mtu,
    );
  }
}

enum SignalQuality {
  excellent,
  good,
  fair,
  poor,
}
