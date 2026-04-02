import 'dart:convert';
import 'dart:io';

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

Directory _targetDirectory() {
  final userProfile = Platform.environment['USERPROFILE'];
  final home = Platform.environment['HOME'];
  final downloadsCandidates = [
    if (userProfile != null && userProfile.isNotEmpty)
      Directory('$userProfile\\Downloads'),
    if (home != null && home.isNotEmpty) Directory('$home/Downloads'),
  ];

  for (final directory in downloadsCandidates) {
    if (directory.existsSync()) {
      return directory;
    }
  }

  return Directory.systemTemp;
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
  final file = File('${_targetDirectory().path}${Platform.pathSeparator}$sanitized');
  await file.writeAsString(csv, encoding: utf8);
  return file.path;
}
