import 'package:bb_mobile/core/lora_gateway/domain/entities/usb_device_info.dart';
import 'package:bb_mobile/core/lora_gateway/domain/repositories/lora_gateway_repository.dart';

/// Use case for scanning available USB serial devices.
class ScanUsbDevicesUsecase {
  ScanUsbDevicesUsecase({
    required LoraGatewayRepository repository,
  }) : _repository = repository;

  final LoraGatewayRepository _repository;

  /// Scans for USB serial devices that could be Meshtastic devices.
  ///
  /// Returns a list of [UsbDeviceInfo] representing available devices.
  Future<List<UsbDeviceInfo>> execute() async {
    return _repository.scanDevices();
  }
}
