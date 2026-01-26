/// Represents the status of a transaction in the gateway log.
enum TransactionLogStatus {
  /// Transaction is being received (chunks incoming).
  receiving,

  /// Transaction fully received, pending broadcast.
  received,

  /// Transaction is being broadcasted to Bitcoin network.
  broadcasting,

  /// Transaction successfully broadcasted.
  broadcasted,

  /// Transaction broadcast failed.
  failed,
}

/// A log entry for a transaction processed by the LoRa Gateway.
class TransactionLogEntry {
  const TransactionLogEntry({
    required this.id,
    required this.sender,
    required this.timestamp,
    required this.status,
    this.txid,
    this.size,
    this.errorMessage,
    this.chunksReceived = 0,
    this.chunksTotal = 0,
  });

  /// Unique identifier for this log entry.
  final String id;

  /// The LoRa sender ID.
  final String sender;

  /// When the transaction was first received.
  final DateTime timestamp;

  /// Current status of the transaction.
  final TransactionLogStatus status;

  /// Bitcoin TXID (if broadcasted successfully).
  final String? txid;

  /// Transaction size in bytes.
  final int? size;

  /// Error message (if failed).
  final String? errorMessage;

  /// Number of chunks received.
  final int chunksReceived;

  /// Total expected chunks.
  final int chunksTotal;

  bool get isComplete => status == TransactionLogStatus.broadcasted;
  bool get isFailed => status == TransactionLogStatus.failed;
  bool get isInProgress =>
      status == TransactionLogStatus.receiving ||
      status == TransactionLogStatus.broadcasting;

  TransactionLogEntry copyWith({
    String? id,
    String? sender,
    DateTime? timestamp,
    TransactionLogStatus? status,
    String? txid,
    int? size,
    String? errorMessage,
    int? chunksReceived,
    int? chunksTotal,
  }) {
    return TransactionLogEntry(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      txid: txid ?? this.txid,
      size: size ?? this.size,
      errorMessage: errorMessage ?? this.errorMessage,
      chunksReceived: chunksReceived ?? this.chunksReceived,
      chunksTotal: chunksTotal ?? this.chunksTotal,
    );
  }

  @override
  String toString() => 'TransactionLogEntry('
      'id: $id, '
      'status: $status, '
      'txid: ${txid ?? "pending"})';
}
