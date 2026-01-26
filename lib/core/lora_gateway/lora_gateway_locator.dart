import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/lora_gateway/data/datasources/meshtastic_serial_datasource.dart';
import 'package:bb_mobile/core/lora_gateway/data/repositories/lora_gateway_repository_impl.dart';
import 'package:bb_mobile/core/lora_gateway/domain/repositories/lora_gateway_repository.dart';
import 'package:bb_mobile/core/lora_gateway/domain/usecases/broadcast_received_tx_usecase.dart';
import 'package:bb_mobile/core/lora_gateway/domain/usecases/connect_meshtastic_usecase.dart';
import 'package:bb_mobile/core/lora_gateway/domain/usecases/disconnect_meshtastic_usecase.dart';
import 'package:bb_mobile/core/lora_gateway/domain/usecases/scan_usb_devices_usecase.dart';
import 'package:bb_mobile/core/lora_gateway/domain/usecases/start_gateway_usecase.dart';
import 'package:bb_mobile/core/lora_gateway/domain/usecases/stop_gateway_usecase.dart';
import 'package:get_it/get_it.dart';

/// Dependency injection locator for the LoRa Gateway core module.
class LoraGatewayCoreLocator {
  /// Registers all datasources for the LoRa Gateway module.
  static void registerDatasources(GetIt locator) {
    locator.registerLazySingleton<MeshtasticSerialDatasource>(
      MeshtasticSerialDatasource.new,
    );
  }

  /// Registers all repositories for the LoRa Gateway module.
  static void registerRepositories(GetIt locator) {
    locator.registerLazySingleton<LoraGatewayRepository>(
      () => LoraGatewayRepositoryImpl(
        meshtasticDatasource: locator<MeshtasticSerialDatasource>(),
      ),
    );
  }

  /// Registers all use cases for the LoRa Gateway module.
  static void registerUsecases(GetIt locator) {
    locator.registerLazySingleton<ScanUsbDevicesUsecase>(
      () => ScanUsbDevicesUsecase(
        repository: locator<LoraGatewayRepository>(),
      ),
    );

    locator.registerLazySingleton<ConnectMeshtasticUsecase>(
      () => ConnectMeshtasticUsecase(
        repository: locator<LoraGatewayRepository>(),
      ),
    );

    locator.registerLazySingleton<DisconnectMeshtasticUsecase>(
      () => DisconnectMeshtasticUsecase(
        repository: locator<LoraGatewayRepository>(),
      ),
    );

    locator.registerLazySingleton<StartGatewayUsecase>(
      () => StartGatewayUsecase(
        repository: locator<LoraGatewayRepository>(),
      ),
    );

    locator.registerLazySingleton<StopGatewayUsecase>(
      () => StopGatewayUsecase(
        repository: locator<LoraGatewayRepository>(),
      ),
    );

    locator.registerLazySingleton<BroadcastReceivedTxUsecase>(
      () => BroadcastReceivedTxUsecase(
        broadcastUsecase: locator<BroadcastBitcoinTransactionUsecase>(),
        repository: locator<LoraGatewayRepository>(),
      ),
    );
  }
}
