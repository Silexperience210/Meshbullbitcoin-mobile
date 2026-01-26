import 'package:bb_mobile/core/lora_gateway/domain/repositories/lora_gateway_repository.dart';

/// Use case for stopping the LoRa Gateway.
class StopGatewayUsecase {
  StopGatewayUsecase({
    required LoraGatewayRepository repository,
  }) : _repository = repository;

  final LoraGatewayRepository _repository;

  /// Stops the gateway from processing transactions.
  void execute() {
    _repository.stopGateway();
  }
}
