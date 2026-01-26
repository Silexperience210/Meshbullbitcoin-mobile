import 'package:bb_mobile/core/lora_gateway/domain/repositories/lora_gateway_repository.dart';
import 'package:bb_mobile/core/lora_gateway/domain/usecases/broadcast_received_tx_usecase.dart';
import 'package:bb_mobile/core/lora_gateway/domain/usecases/connect_meshtastic_usecase.dart';
import 'package:bb_mobile/core/lora_gateway/domain/usecases/disconnect_meshtastic_usecase.dart';
import 'package:bb_mobile/core/lora_gateway/domain/usecases/scan_usb_devices_usecase.dart';
import 'package:bb_mobile/core/lora_gateway/domain/usecases/start_gateway_usecase.dart';
import 'package:bb_mobile/core/lora_gateway/domain/usecases/stop_gateway_usecase.dart';
import 'package:bb_mobile/features/lora_gateway/presentation/bloc/lora_gateway_cubit.dart';
import 'package:get_it/get_it.dart';

/// Dependency injection locator for the LoRa Gateway feature.
class LoraGatewayFeatureLocator {
  /// Registers all dependencies for the LoRa Gateway feature.
  static void register(GetIt locator) {
    locator.registerFactory<LoraGatewayCubit>(
      () => LoraGatewayCubit(
        repository: locator<LoraGatewayRepository>(),
        scanDevicesUsecase: locator<ScanUsbDevicesUsecase>(),
        connectUsecase: locator<ConnectMeshtasticUsecase>(),
        disconnectUsecase: locator<DisconnectMeshtasticUsecase>(),
        startGatewayUsecase: locator<StartGatewayUsecase>(),
        stopGatewayUsecase: locator<StopGatewayUsecase>(),
        broadcastTxUsecase: locator<BroadcastReceivedTxUsecase>(),
      ),
    );
  }
}
