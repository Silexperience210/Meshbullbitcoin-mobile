import 'package:bb_mobile/features/disaster_tx/data/datasources/meshtastic_ble_datasource.dart';
import 'package:bb_mobile/features/disaster_tx/data/services/broadcast_notification_service.dart';
import 'package:bb_mobile/features/disaster_tx/domain/usecases/broadcast_via_lora_usecase.dart';
import 'package:bb_mobile/features/disaster_tx/domain/usecases/chunk_transaction_usecase.dart';
import 'package:bb_mobile/features/disaster_tx/presentation/cubit/disaster_tx_cubit.dart';
import 'package:get_it/get_it.dart';

void setupDisasterTxLocator(GetIt locator) {
  // Initialize notification service
  BroadcastNotificationService.initialize();
  // Data sources
  locator.registerLazySingleton<MeshtasticBleDatasource>(
    () => MeshtasticBleDatasource(),
  );

  // Use cases
  locator.registerLazySingleton<ChunkTransactionUsecase>(
    () => ChunkTransactionUsecase(),
  );

  locator.registerLazySingleton<BroadcastViaLoraUsecase>(
    () => BroadcastViaLoraUsecase(
      bleDatasource: locator(),
      chunkTransactionUsecase: locator(),
    ),
  );

  // Cubit
  locator.registerFactory<DisasterTxCubit>(
    () => DisasterTxCubit(
      bleDatasource: locator(),
      broadcastViaLoraUsecase: locator(),
    ),
  );
}
