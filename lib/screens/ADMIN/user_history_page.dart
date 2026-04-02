import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/api_service.dart';
import '../../services/signed_tracer_filter.dart';

class AdminUserHistoryDialog extends StatefulWidget {
  const AdminUserHistoryDialog({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<AdminUserHistoryDialog> createState() => _AdminUserHistoryDialogState();
}

class _AdminUserHistoryDialogState extends State<AdminUserHistoryDialog> {
  static const Color _maroon = Color(0xFF4A152C);
  static const Color _gold = Color(0xFFC5A046);
  static const Color _light = Color(0xFFF8F9FA);
  static const Color _border = Color(0xFFE0E0E0);

  bool _isLoading = true;
  List<_HistoryEvent> _timeline = const [];
  List<Map<String, dynamic>> _tracerSubmissions = const [];
  List<Map<String, dynamic>> _signedSubmissions = const [];
  List<Map<String, dynamic>> _activityEvents = const [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final responses = await Future.wait([
        http.get(ApiService.uri('get_full_activity.php')),
        http.get(ApiService.uri('get_tracer_submissions.php')),
      ]);

      final rawActivities = _decodeList(responses[0].body);
      final tracerPayload = _decodeDynamic(responses[1].body);
      final tracerList = tracerPayload is List
          ? tracerPayload.whereType<Map>().toList()
          : (tracerPayload is Map
                ? (tracerPayload['alumni'] as List? ?? const [])
                      .whereType<Map>()
                      .toList()
                : const <Map>[]);
      final signedList = tracerPayload is Map
          ? ((tracerPayload['signed_records'] as List?) ?? const [])
                .whereType<Map>()
                .toList()
          : const <Map>[];
      final signedRecordMaps = signedList
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      final activityEvents = rawActivities
          .map((item) => Map<String, dynamic>.from(item))
          .where(_matchesUser)
          .toList();
      final tracerEvents = SignedTracerFilter.keepSignedOnly(
        tracerList
            .map((item) => Map<String, dynamic>.from(item))
            .where(_matchesUser)
            .toList(),
        signedRecords: signedRecordMaps,
      );
      final signedEvents = signedRecordMaps.where(_matchesUser).toList();

      final timeline = <_HistoryEvent>[
        _buildRegistrationEvent(),
        _buildCurrentProfileEvent(),
        ...activityEvents.map(_mapActivityEvent),
        ...tracerEvents.map(_mapTracerEvent),
        ...signedEvents.map(_mapSignedEvent),
      ]..removeWhere((event) => event.title.trim().isEmpty);

      timeline.sort((a, b) {
        final aTime = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      if (!mounted) return;
      setState(() {
        _activityEvents = activityEvents;
        _tracerSubmissions = tracerEvents;
        _signedSubmissions = signedEvents;
        _timeline = timeline;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  bool _matchesUser(Map<dynamic, dynamic> rawItem) {
    final item = rawItem.map((key, value) => MapEntry('$key', value));
    final selectedId = _readSelectedUserId(widget.user);
    final itemId = _readRecordUserId(item);
    if (selectedId != null && itemId != null) {
      return selectedId == itemId;
    }

    final selectedEmail = _normalized(widget.user['email']);
    final itemEmail = _normalized(
      item['email'] ?? item['user_email'] ?? item['contact_email'],
    );
    if (selectedEmail.isNotEmpty && itemEmail.isNotEmpty) {
      return selectedEmail == itemEmail;
    }

    // For a user-specific history view, avoid loose name/title matching.
    // Those broad matches can pull unrelated events into another user's
    // timeline when names overlap or activity titles mention other users.
    final metadata = item['metadata'];
    if (metadata is Map) {
      final normalizedMetadata = metadata.map(
        (key, value) => MapEntry('$key', value),
      );
      final metadataUserId = _readRecordUserId(normalizedMetadata);
      if (selectedId != null && metadataUserId != null) {
        return selectedId == metadataUserId;
      }

      final metadataEmail = _normalized(
        normalizedMetadata['email'] ?? normalizedMetadata['user_email'],
      );
      if (selectedEmail.isNotEmpty && metadataEmail.isNotEmpty) {
        return selectedEmail == metadataEmail;
      }
    }

    if (selectedId == null && selectedEmail.isEmpty) {
      return true;
    }

    return false;
  }

  _HistoryEvent _buildRegistrationEvent() {
    final program =
        widget.user['program'] ??
        widget.user['course'] ??
        widget.user['degree'];
    final year =
        widget.user['year'] ??
        widget.user['year_graduated'] ??
        widget.user['graduation_year'];
    final registeredAt =
        widget.user['created_at'] ??
        widget.user['registered_at'] ??
        widget.user['date_registered'];

    return _HistoryEvent(
      title: 'Registration details recorded',
      subtitle:
          'Program: ${_display(program)} | Year: ${_display(year)} | Email: ${_display(widget.user['email'])}',
      timeLabel: registeredAt?.toString().trim().isNotEmpty == true
          ? _formatDateLabel(registeredAt.toString())
          : 'Registration date not available',
      timestamp: _parseDate(registeredAt),
      type: 'Registration',
      icon: Icons.how_to_reg_outlined,
      color: Colors.blue,
    );
  }

  _HistoryEvent _buildCurrentProfileEvent() {
    final status = widget.user['status'] ?? widget.user['account_status'];
    return _HistoryEvent(
      title: 'Current account snapshot',
      subtitle:
          'Name: ${_display(widget.user['name'])} | Status: ${_display(status)}',
      timeLabel: 'Current record',
      timestamp: null,
      type: 'Profile',
      icon: Icons.person_outline,
      color: _maroon,
    );
  }

  _HistoryEvent _mapActivityEvent(Map<String, dynamic> item) {
    return _HistoryEvent(
      title: _display(item['title'], fallback: 'System activity'),
      subtitle: _display(
        item['description'] ?? item['details'] ?? item['type'],
        fallback: _display(item['type'], fallback: 'System activity'),
      ),
      timeLabel: _display(item['time'], fallback: 'Recent'),
      timestamp: _parseDate(
        item['occurred_at'] ??
            item['created_at'] ??
            item['timestamp'] ??
            item['time'],
      ),
      type: _display(item['type'], fallback: 'Activity'),
      icon: _iconForType(item['type']?.toString()),
      color: _colorForType(item['type']?.toString()),
    );
  }

  _HistoryEvent _mapTracerEvent(Map<String, dynamic> item) {
    final submittedAt = item['submitted_at'] ?? item['date_submitted'];
    return _HistoryEvent(
      title: 'Tracer submission recorded',
      subtitle:
          'Employment: ${_display(item['employment_status'])} | Related job: ${_display(item['job_related'] ?? item['related_job'])}',
      timeLabel: _formatDateLabel(
        _display(submittedAt, fallback: 'Submission date unavailable'),
      ),
      timestamp: _parseDate(submittedAt),
      type: 'Tracer',
      icon: Icons.assignment_outlined,
      color: Colors.green,
    );
  }

  _HistoryEvent _mapSignedEvent(Map<String, dynamic> item) {
    final signedAt = item['submission_timestamp'] ?? item['signed_at'];
    return _HistoryEvent(
      title: 'Signed tracer submission archived',
      subtitle:
          'Reference: ${_display(item['reference_id'])} | Agreement: ${_display(item['agreement_version'])}',
      timeLabel: _formatDateLabel(
        _display(signedAt, fallback: 'Signed date unavailable'),
      ),
      timestamp: _parseDate(signedAt),
      type: 'Signed Record',
      icon: Icons.fact_check_outlined,
      color: _gold,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dialogWidth = size.width < 960 ? size.width - 32 : 920.0;
    final isCompact = dialogWidth < 760;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: size.height - 48),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _light,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isCompact, dialogWidth),
            const SizedBox(height: 20),
            _buildSummaryCards(dialogWidth),
            const SizedBox(height: 20),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _timeline.isEmpty
                  ? _buildEmptyState()
                  : _buildTimeline(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isCompact, double dialogWidth) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: isCompact ? double.infinity : dialogWidth - 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _display(widget.user['name'], fallback: 'User History'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: _maroon,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Unified history of important account actions, tracer records, and signed submissions.',
                style: TextStyle(color: Colors.grey.shade700, height: 1.4),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _infoChip(
                    Icons.email_outlined,
                    _display(widget.user['email']),
                  ),
                  _infoChip(
                    Icons.school_outlined,
                    _display(
                      widget.user['program'] ??
                          widget.user['course'] ??
                          widget.user['degree'],
                    ),
                  ),
                  _infoChip(
                    Icons.verified_user_outlined,
                    _display(widget.user['status'], fallback: 'Unknown status'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _maroon,
                side: const BorderSide(color: _border),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCards(double dialogWidth) {
    final cards = [
      ('Timeline Events', _timeline.length.toString(), Icons.timeline, _maroon),
      (
        'Activity Logs',
        _activityEvents.length.toString(),
        Icons.notifications_active_outlined,
        Colors.blue,
      ),
      (
        'Tracer Records',
        _tracerSubmissions.length.toString(),
        Icons.assignment_outlined,
        Colors.green,
      ),
      (
        'Signed Records',
        _signedSubmissions.length.toString(),
        Icons.fact_check_outlined,
        _gold,
      ),
    ];

    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: cards
          .map(
            (card) => Container(
              width: dialogWidth < 560
                  ? double.infinity
                  : dialogWidth < 860
                  ? (dialogWidth - 62) / 2
                  : (dialogWidth - 90) / 4,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: card.$4.withValues(alpha: 0.12),
                    child: Icon(card.$3, color: card.$4),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.$2,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        card.$1,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildTimeline() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(18),
        itemCount: _timeline.length,
        separatorBuilder: (_, _) => Divider(color: Colors.grey.shade200),
        itemBuilder: (context, index) {
          final event = _timeline[index];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: event.color.withValues(alpha: 0.12),
              child: Icon(event.icon, color: event.color),
            ),
            title: Text(
              event.title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.subtitle),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _miniTag(event.type, event.color),
                      _miniTag(event.timeLabel, Colors.grey.shade700),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: _maroon.withValues(alpha: 0.10),
              child: const Icon(
                Icons.history_outlined,
                color: _maroon,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No user history found yet.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Stored records for this user will appear here as tracer submissions and activity logs become available.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _maroon),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _miniTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _decodeList(String body) {
    final decoded = _decodeDynamic(body);
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return const [];
  }

  dynamic _decodeDynamic(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  int? _readSelectedUserId(Map<String, dynamic> item) {
    final candidates = [item['id'], item['user_id'], item['alumni_id']];
    for (final value in candidates) {
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  int? _readRecordUserId(Map<String, dynamic> item) {
    final candidates = [item['user_id'], item['alumni_id'], item['userId']];
    for (final value in candidates) {
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  String _normalized(dynamic value) =>
      value?.toString().trim().toLowerCase() ?? '';

  String _display(dynamic value, {String fallback = 'N/A'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  DateTime? _parseDate(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  String _formatDateLabel(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    return '${_month(local.month)} ${local.day}, ${local.year} ${_toTwelveHour(local)}';
  }

  String _month(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  String _toTwelveHour(DateTime dateTime) {
    final hour = dateTime.hour == 0
        ? 12
        : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final suffix = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  IconData _iconForType(String? type) {
    switch ((type ?? '').toLowerCase()) {
      case 'authentication':
        return Icons.login_outlined;
      case 'registration':
        return Icons.how_to_reg_outlined;
      case 'verification':
        return Icons.verified_user_outlined;
      case 'profile':
        return Icons.person_outline;
      case 'jobs':
        return Icons.work_outline;
      case 'tracer':
        return Icons.assignment_outlined;
      default:
        return Icons.history_outlined;
    }
  }

  Color _colorForType(String? type) {
    switch ((type ?? '').toLowerCase()) {
      case 'authentication':
        return Colors.indigo;
      case 'registration':
        return Colors.blue;
      case 'verification':
        return Colors.orange;
      case 'profile':
        return _maroon;
      case 'jobs':
        return Colors.teal;
      case 'tracer':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

class _HistoryEvent {
  const _HistoryEvent({
    required this.title,
    required this.subtitle,
    required this.timeLabel,
    required this.type,
    required this.icon,
    required this.color,
    this.timestamp,
  });

  final String title;
  final String subtitle;
  final String timeLabel;
  final String type;
  final IconData icon;
  final Color color;
  final DateTime? timestamp;
}
