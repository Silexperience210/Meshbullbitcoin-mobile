import 'package:bb_mobile/core/lora_gateway/domain/repositories/lora_gateway_repository.dart';

/// Use case for disconnecting from a Meshtastic device.
class DisconnectMeshtasticUsecase {
  DisconnectMeshtasticUsecase({
    required LoraGatewayRepository repository,
  }) : _repository = repository;

  final LoraGatewayRepository _repository;

  /// Disconnects from the currently connected Meshtastic device.
  Future<void> execute() async {
    await _repository.disconnect();
  }
}
