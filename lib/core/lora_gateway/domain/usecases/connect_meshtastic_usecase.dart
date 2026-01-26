import 'package:bb_mobile/core/lora_gateway/domain/entities/usb_device_info.dart';
import 'package:bb_mobile/core/lora_gateway/domain/repositories/lora_gateway_repository.dart';

/// Use case for connecting to a Meshtastic device.
class ConnectMeshtasticUsecase {
  ConnectMeshtasticUsecase({
    required LoraGatewayRepository repository,
  }) : _repository = repository;

  final LoraGatewayRepository _repository;

  /// Connects to the specified Meshtastic device.
  ///
  /// Throws an exception if the connection fails.
  Future<void> execute(UsbDeviceInfo device) async {
    await _repository.connect(device);
  }
}
