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

    // Map each unique node ID to its EARLIEST hit time
    Map<int, int> nodeEarliestHits = {};
    for (int i = 0; i < parts.length; i += 2) {
      int nodeId = int.parse(parts[i].trim());
      int timePassed = int.parse(parts[i + 1].trim());

      if (!nodeEarliestHits.containsKey(nodeId) || timePassed < nodeEarliestHits[nodeId]!) {
        nodeEarliestHits[nodeId] = timePassed;
      }
    }

    if (nodeEarliestHits.length != 5) {
      throw FormatException('Invalid run: expected timings for 5 unique nodes, but got ${nodeEarliestHits.length}');
    }

    // Sort by time to ensure normalization is correct
    var sortedTimes = nodeEarliestHits.values.toList()..sort();

    int baseTime = sortedTimes.first;
    return sortedTimes.map((t) => t - baseTime).toList();
  }
}
