/// BTX Protocol message types for Bitcoin transaction transmission over LoRa.
enum BtxMessageType {
  /// TX_START (0x01): Initiates a new transaction transmission.
  /// Format: [0x01, tx_id, size_high, size_low]
  txStart(0x01),

  /// TX_CHUNK (0x02): Contains a chunk of transaction data.
  /// Format: [0x02, tx_id, chunk_idx, ...data]
  txChunk(0x02),

  /// TX_END (0x03): Marks the end of transaction transmission.
  /// Format: [0x03, tx_id]
  txEnd(0x03),

  /// TX_ACK (0x04): Acknowledgment of successful broadcast.
  /// Format: [0x04, tx_id, ...txid_bytes]
  txAck(0x04),

  /// TX_ERROR (0x05): Error during processing.
  /// Format: [0x05, tx_id, error_code]
  txError(0x05);

  const BtxMessageType(this.code);
  final int code;

  static BtxMessageType? fromCode(int code) {
    for (final type in values) {
      if (type.code == code) return type;
    }
    return null;
  }
}

/// BTX Protocol error codes.
enum BtxErrorCode {
  /// Transaction too large (> 2048 bytes).
  tooLarge(1),

  /// Timeout waiting for chunks.
  timeout(2),

  /// Invalid or incomplete transaction data.
  invalid(3),

  /// Failed to broadcast to Bitcoin network.
  broadcastFailed(4);

  const BtxErrorCode(this.code);
  final int code;

  static BtxErrorCode? fromCode(int code) {
    for (final error in values) {
      if (error.code == code) return error;
    }
    return null;
  }
}

/// Represents a parsed BTX protocol message received via LoRa.
sealed class LoraMessage {
  const LoraMessage({
    required this.sender,
    required this.timestamp,
  });

  final String sender;
  final DateTime timestamp;
}

/// TX_START message: Initiates a new transaction.
class LoraTxStartMessage extends LoraMessage {
  const LoraTxStartMessage({
    required super.sender,
    required super.timestamp,
    required this.txId,
    required this.totalSize,
  });

  final int txId;
  final int totalSize;

  @override
  String toString() =>
      'LoraTxStartMessage(txId: $txId, size: $totalSize, from: $sender)';
}

/// TX_CHUNK message: Contains transaction data chunk.
class LoraTxChunkMessage extends LoraMessage {
  const LoraTxChunkMessage({
    required super.sender,
    required super.timestamp,
    required this.txId,
    required this.chunkIndex,
    required this.data,
  });

  final int txId;
  final int chunkIndex;
  final List<int> data;

  @override
  String toString() =>
      'LoraTxChunkMessage(txId: $txId, chunk: $chunkIndex, ${data.length} bytes)';
}

/// TX_END message: Marks transmission complete.
class LoraTxEndMessage extends LoraMessage {
  const LoraTxEndMessage({
    required super.sender,
    required super.timestamp,
    required this.txId,
  });

  final int txId;

  @override
  String toString() => 'LoraTxEndMessage(txId: $txId, from: $sender)';
}

/// Text-based BTX message (BTX:chunk/total:hex_data format).
class LoraBtxTextMessage extends LoraMessage {
  const LoraBtxTextMessage({
    required super.sender,
    required super.timestamp,
    required this.chunkNumber,
    required this.totalChunks,
    required this.hexData,
  });

  final int chunkNumber;
  final int totalChunks;
  final String hexData;

  @override
  String toString() =>
      'LoraBtxTextMessage($chunkNumber/$totalChunks, ${hexData.length} chars)';
}

/// Raw text message (possible direct hex transaction).
class LoraTextMessage extends LoraMessage {
  const LoraTextMessage({
    required super.sender,
    required super.timestamp,
    required this.text,
  });

  final String text;

  @override
  String toString() => 'LoraTextMessage(${text.length} chars, from: $sender)';
}
