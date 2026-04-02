import 'csv_export_service_stub.dart'
    if (dart.library.io) 'csv_export_service_io.dart'
    if (dart.library.html) 'csv_export_service_web.dart' as exporter;

class CsvExportService {
  static Future<String> exportRows({
    required String filename,
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return exporter.exportRows(
      filename: filename,
      headers: headers,
      rows: rows,
    );
  }

  static String escapeCell(String value) {
    final normalized = value.replaceAll('"', '""');
    if (normalized.contains(',') ||
        normalized.contains('"') ||
        normalized.contains('\n') ||
        normalized.contains('\r')) {
      return '"$normalized"';
    }
    return normalized;
  }
}
