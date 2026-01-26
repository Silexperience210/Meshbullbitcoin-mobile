/// Information about a USB serial device.
class UsbDeviceInfo {
  const UsbDeviceInfo({
    required this.deviceId,
    required this.port,
    this.productName,
    this.manufacturerName,
    this.vendorId,
    this.productId,
  });

  /// Unique device identifier.
  final int deviceId;

  /// Serial port path (e.g., "/dev/ttyUSB0" or COM port).
  final String port;

  /// Product name from USB descriptor.
  final String? productName;

  /// Manufacturer name from USB descriptor.
  final String? manufacturerName;

  /// USB Vendor ID.
  final int? vendorId;

  /// USB Product ID.
  final int? productId;

  /// Returns a display name for the device.
  String get displayName {
    if (productName != null && productName!.isNotEmpty) {
      return productName!;
    }
    if (manufacturerName != null && manufacturerName!.isNotEmpty) {
      return '$manufacturerName ($port)';
    }
    return port;
  }

  /// Returns true if this is likely a Meshtastic device based on known chip IDs.
  bool get isMeshtasticCompatible {
    // Silicon Labs CP210x
    if (vendorId == 0x10C4 && productId == 0xEA60) return true;
    // CH340
    if (vendorId == 0x1A86 && productId == 0x7523) return true;
    // FTDI
    if (vendorId == 0x0403) return true;
    return false;
  }

  @override
  String toString() => 'UsbDeviceInfo('
      'deviceId: $deviceId, '
      'port: $port, '
      'product: $productName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UsbDeviceInfo &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId &&
          port == other.port;

  @override
  int get hashCode => deviceId.hashCode ^ port.hashCode;
}
