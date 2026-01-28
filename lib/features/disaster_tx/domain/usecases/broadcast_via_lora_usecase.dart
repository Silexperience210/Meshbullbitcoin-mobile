import 'package:bb_mobile/features/disaster_tx/data/datasources/meshtastic_ble_datasource.dart';
import 'package:bb_mobile/features/disaster_tx/domain/entities/meshtastic_device.dart';
import 'package:bb_mobile/features/disaster_tx/domain/entities/tx_chunk.dart';
import 'package:bb_mobile/features/disaster_tx/domain/usecases/chunk_transaction_usecase.dart';

/// Use case to broadcast a Bitcoin transaction via LoRa mesh network.
class BroadcastViaLoraUsecase {
  BroadcastViaLoraUsecase({
    required MeshtasticBleDatasource bleDatasource,
    required ChunkTransactionUsecase chunkTransactionUsecase,
  })  : _bleDatasource = bleDatasource,
        _chunkTransactionUsecase = chunkTransactionUsecase;

  final MeshtasticBleDatasource _bleDatasource;
  final ChunkTransactionUsecase _chunkTransactionUsecase;

  /// Broadcasts a transaction to the LoRa mesh network.
  ///
  /// [txHex] - The raw transaction in hexadecimal format.
  /// [device] - The Meshtastic device to send through.
  /// [onProgress] - Callback for progress updates (0.0 to 1.0).
  ///
  /// Returns when all chunks have been sent successfully.
  Future<void> execute({
    required String txHex,
    required MeshtasticDevice device,
    void Function(double progress, TxChunk chunk)? onProgress,
  }) async {
    // 1. Connect to device if not already connected
    if (!_bleDatasource.isConnected) {
      await _bleDatasource.connect(device);
    }

    // 2. Chunk the transaction based on device MTU
    final chunks = _chunkTransactionUsecase.execute(
      txHex: txHex,
      chunkSize: device.effectiveChunkSize,
    );

    // 3. Send each chunk via BLE
    for (final chunk in chunks) {
      await _bleDatasource.sendChunk(chunk);

      // Report progress
      onProgress?.call(chunk.progress, chunk);
    }

    // All chunks sent successfully
  }

  /// Disconnect from the current device.
  Future<void> disconnect() async {
    await _bleDatasource.disconnect();
  }
}
