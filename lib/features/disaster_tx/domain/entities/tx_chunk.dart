/// Represents a chunk of a Bitcoin transaction for LoRa transmission.
class TxChunk {
  const TxChunk({
    required this.chunkNumber,
    required this.totalChunks,
    required this.hexData,
  });

  final int chunkNumber;
  final int totalChunks;
  final String hexData;

  /// Format as BTX protocol message: "BTX:<chunk>/<total>:<hex_data>"
  String get formattedMessage => 'BTX:$chunkNumber/$totalChunks:$hexData';

  /// Get progress percentage (0.0 to 1.0)
  double get progress => chunkNumber / totalChunks;

  @override
  String toString() => 'TxChunk($chunkNumber/$totalChunks, ${hexData.length} bytes)';
}
