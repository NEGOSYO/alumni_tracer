Future<String> exportRows({
  required String filename,
  required List<String> headers,
  required List<List<String>> rows,
}) async {
  throw UnsupportedError('CSV export is not supported on this platform.');
}
