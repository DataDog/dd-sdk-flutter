BigInt? extractDatadogTraceId(Map<String, List<String>> headers) {
  final traceIdHeader = headers['x-datadog-trace-id']?.first;
  if (traceIdHeader == null) {
    return null;
  }

  final lowPart = BigInt.tryParse(traceIdHeader);
  if (lowPart == null) {
    return null;
  }

  final tagsHeader = headers['x-datadog-tags']?.first;
  if (tagsHeader == null) {
    return lowPart;
  }

  final tags = tagsHeader.split(',');
  Map<String, String> tagMap = {};
  for (var tag in tags) {
    final parts = tag.split('=');
    tagMap[parts[0]] = parts[1];
  }

  final highPartString = tagMap['_dd.p.tid'];
  if (highPartString == null) {
    return lowPart;
  }
  final highPart = BigInt.tryParse(highPartString, radix: 16);
  if (highPart == null) {
    return lowPart;
  }

  return (highPart << 64) + lowPart;
}
