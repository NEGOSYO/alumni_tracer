// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

String _escapeCell(String value) {
  final normalized = value.replaceAll('"', '""');
  if (normalized.contains(',') ||
      normalized.contains('"') ||
      normalized.contains('\n') ||
      normalized.contains('\r')) {
    return '"$normalized"';
  }
  return normalized;
}

String _buildCsv(List<String> headers, List<List<String>> rows) {
  final buffer = StringBuffer();
  buffer.writeln(headers.map(_escapeCell).join(','));
  for (final row in rows) {
    buffer.writeln(row.map(_escapeCell).join(','));
  }
  return buffer.toString();
}

Future<String> exportRows({
  required String filename,
  required List<String> headers,
  required List<List<String>> rows,
}) async {
  final csv = _buildCsv(headers, rows);
  final sanitized = filename.toLowerCase().endsWith('.csv')
      ? filename
      : '$filename.csv';
  final blob = html.Blob([csv], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = sanitized
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return sanitized;
}
