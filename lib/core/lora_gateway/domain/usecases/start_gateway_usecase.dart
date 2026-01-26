import 'package:bb_mobile/core/lora_gateway/domain/repositories/lora_gateway_repository.dart';

/// Use case for starting the LoRa Gateway.
class StartGatewayUsecase {
  StartGatewayUsecase({
    required LoraGatewayRepository repository,
  }) : _repository = repository;

  final LoraGatewayRepository _repository;

  /// Starts the gateway to begin listening for and processing transactions.
  ///
  /// The gateway must be connected to a Meshtastic device first.
  void execute() {
    _repository.startGateway();
  }
}
