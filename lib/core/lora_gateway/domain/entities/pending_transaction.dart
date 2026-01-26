/// Represents a Bitcoin transaction being received via LoRa in chunks.
///
/// The BTX protocol splits large transactions into 180-byte chunks.
/// This class manages the reassembly of those chunks into a complete transaction.
class PendingTransaction {
  PendingTransaction({
    required this.txId,
    required this.totalSize,
    required this.sender,
    DateTime? startTime,
  })  : _chunks = {},
        _startTime = startTime ?? DateTime.now(),
        expectedChunks = (totalSize + _chunkSize - 1) ~/ _chunkSize;

  static const int _chunkSize = 180;
  static const int timeoutSeconds = 30;

  final int txId;
  final int totalSize;
  final String sender;
  final int expectedChunks;
  final DateTime _startTime;
  final Map<int, List<int>> _chunks;

  DateTime get startTime => _startTime;
  int get receivedChunks => _chunks.length;

  /// Returns true if all chunks have been received.
  bool get isComplete => _chunks.length == expectedChunks;

  /// Returns true if the transaction has exceeded the timeout period.
  bool get isExpired =>
      DateTime.now().difference(_startTime).inSeconds > timeoutSeconds;

  /// Adds a chunk to the pending transaction.
  void addChunk(int index, List<int> data) {
    if (index >= 0 && index < expectedChunks) {
      _chunks[index] = data;
    }
  }

  /// Returns true if a specific chunk has been received.
  bool hasChunk(int index) => _chunks.containsKey(index);

  /// Reassembles all chunks into the complete transaction bytes.
  ///
  /// Returns null if the transaction is not complete.
  List<int>? reassemble() {
    if (!isComplete) return null;

    final result = <int>[];
    for (var i = 0; i < expectedChunks; i++) {
      final chunk = _chunks[i];
      if (chunk == null) return null;
      result.addAll(chunk);
    }

    // Trim to exact size (remove padding from last chunk)
    if (result.length > totalSize) {
      return result.sublist(0, totalSize);
    }
    return result;
  }

  /// Returns the progress as a percentage (0.0 to 1.0).
  double get progress => expectedChunks > 0 ? _chunks.length / expectedChunks : 0.0;

  @override
  String toString() =>
      'PendingTransaction(txId: $txId, $receivedChunks/$expectedChunks chunks, '
      '${isComplete ? "complete" : "pending"}, sender: $sender)';
}
