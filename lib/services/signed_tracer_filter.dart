class SignedTracerFilter {
  SignedTracerFilter._();

  static List<Map<String, dynamic>> keepSignedOnly(
    List<Map<String, dynamic>> submissions, {
    List<Map<String, dynamic>> signedRecords = const [],
  }) {
    final signedKeys = signedRecords
        .map(_recordKey)
        .where((key) => key.isNotEmpty)
        .toSet();

    return submissions.where((submission) {
      if (_hasEmbeddedSignature(submission)) {
        return true;
      }

      final key = _recordKey(submission);
      if (key.isNotEmpty && signedKeys.contains(key)) {
        return true;
      }

      return false;
    }).toList();
  }

  static bool _hasEmbeddedSignature(Map<String, dynamic> item) {
    final signature = _clean(
      item['signature'] ?? item['signature_base64'] ?? item['digital_signature'],
    );
    final agreed = _clean(item['is_agreed']);
    final agreementVersion = _clean(item['agreement_version']);

    return signature.isNotEmpty &&
        (agreed == 'yes' || agreed == 'true' || agreed == '1') &&
        agreementVersion.isNotEmpty;
  }

  static String _recordKey(Map<String, dynamic> item) {
    final userId = _clean(item['user_id'] ?? item['id'] ?? item['alumni_id']);
    final referenceId = _clean(item['reference_id']);
    final submittedAt = _clean(
      item['submission_timestamp'] ??
          item['submitted_at'] ??
          item['date_submitted'] ??
          item['signed_at'],
    );

    if (referenceId.isNotEmpty) return 'ref:$referenceId';
    if (userId.isNotEmpty && submittedAt.isNotEmpty) {
      return 'user:$userId|time:$submittedAt';
    }
    return '';
  }

  static String _clean(dynamic value) => value?.toString().trim().toLowerCase() ?? '';
}
