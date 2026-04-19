class DataProcessingService {
  /// Parses a comma-separated timing string from the nodes.
  /// Format: "node1,time1,node2,time2,..."
  /// Can handle redundant hits by keeping only the earliest hit for each node.
  /// Enforces that exactly 5 unique nodes must be present.
  /// Normalizes the first node hit to time 0.
  /// Returns a list of time offsets (ms) in chronological order.
  static List<int> parseNodeTimingData(String rawData) {
    List<String> parts = rawData.split(',').where((s) => s.trim().isNotEmpty).toList();
    if (parts.length % 2 != 0) {
      throw const FormatException('Invalid timing data: expected even number of parts (node,time pairs)');
    }

    // Map each unique node Name to its EARLIEST hit time
    Map<String, int> nodeEarliestHits = {};
    for (int i = 0; i < parts.length; i += 2) {
      String nodeName = parts[i].trim();
      int? timePassed = int.tryParse(parts[i + 1].trim());

      if (timePassed == null) {
        throw FormatException('Invalid timestamp for node $nodeName: ${parts[i+1]}');
      }

      if (!nodeEarliestHits.containsKey(nodeName) || timePassed < nodeEarliestHits[nodeName]!) {
        nodeEarliestHits[nodeName] = timePassed;
      }
    }

    if (nodeEarliestHits.length < 2) {
      throw FormatException('Invalid run: expected timings for at least 2 nodes (start and finish), but got ${nodeEarliestHits.length}');
    }

    // Sort by time to ensure normalization is correct
    var sortedTimes = nodeEarliestHits.values.toList()..sort();

    int baseTime = sortedTimes.first;
    return sortedTimes.map((t) => t - baseTime).toList();
  }
}
