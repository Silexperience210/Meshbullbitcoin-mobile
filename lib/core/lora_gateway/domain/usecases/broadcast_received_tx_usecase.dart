import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/lora_gateway/domain/repositories/lora_gateway_repository.dart';

/// Use case for broadcasting a transaction received via LoRa to the Bitcoin network.
class BroadcastReceivedTxUsecase {
  BroadcastReceivedTxUsecase({
    required BroadcastBitcoinTransactionUsecase broadcastUsecase,
    required LoraGatewayRepository repository,
  })  : _broadcastUsecase = broadcastUsecase,
        _repository = repository;

  final BroadcastBitcoinTransactionUsecase _broadcastUsecase;
  final LoraGatewayRepository _repository;

  /// Broadcasts a transaction and reports the result.
  ///
  /// [txHex] - The raw transaction in hexadecimal format.
  /// [logEntryId] - The log entry ID for tracking.
  ///
  /// Returns the TXID if successful.
  Future<String> execute({
    required String txHex,
    required String logEntryId,
  }) async {
    try {
      // Broadcast to Bitcoin network using existing infrastructure
      final txid = await _broadcastUsecase.execute(txHex, isPsbt: false);

      // Report success - this will send ACK via LoRa
      await _repository.reportBroadcastSuccess(logEntryId, txid);

      return txid;
    } catch (e) {
      // Report failure
      _repository.reportBroadcastFailure(logEntryId, e.toString());
      rethrow;
    }
  }
}
