import 'package:bb_mobile/features/disaster_tx/domain/entities/tx_chunk.dart';

/// Use case to split a Bitcoin transaction hex into chunks for LoRa transmission.
class ChunkTransactionUsecase {
  /// Splits a transaction hex string into chunks.
  ///
  /// [txHex] - The raw transaction in hexadecimal format.
  /// [chunkSize] - Maximum size of each chunk in bytes (default: 200).
  ///
  /// Returns a list of [TxChunk] objects ready for transmission.
  List<TxChunk> execute({
    required String txHex,
    int chunkSize = 200,
  }) {
    if (txHex.isEmpty) {
      throw ArgumentError('Transaction hex cannot be empty');
    }

    // Ensure chunk size is reasonable
    if (chunkSize < 50 || chunkSize > 400) {
      throw ArgumentError('Chunk size must be between 50 and 400 bytes');
    }

    final chunks = <TxChunk>[];
    final totalChunks = (txHex.length / chunkSize).ceil();

    for (int i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize > txHex.length)
          ? txHex.length
          : start + chunkSize;

      chunks.add(
        TxChunk(
          chunkNumber: i + 1,
          totalChunks: totalChunks,
          hexData: txHex.substring(start, end),
        ),
      );
    }

    return chunks;
  }
}
