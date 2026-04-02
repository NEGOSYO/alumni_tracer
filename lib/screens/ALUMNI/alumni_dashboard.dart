import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../services/api_service.dart';
import '../../services/content_service.dart';
import '../../state/user_store.dart';

class AlumniDashboard extends StatefulWidget {
  final Map<String, dynamic> user;
  final ValueChanged<int>? onModuleSelected;

  const AlumniDashboard({super.key, required this.user, this.onModuleSelected});

  @override
  State<AlumniDashboard> createState() => _AlumniDashboardState();
}

class _AlumniDashboardState extends State<AlumniDashboard> {
  static const Color primaryMaroon = Color(0xFF4A152C);
  static const Color accentGold = Color(0xFFC5A046);
  static const Color lightBackground = Color(0xFFF7F8FA);
  static const Color cardBorder = Color(0xFFE5E7EB);
  static const Color softRose = Color(0xFFF8F1F4);

  bool isLoading = true;
  List<Map<String, dynamic>> announcements = [];
  Map<String, dynamic>? tracerInfo;
  List<Map<String, dynamic>> recentActivities = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final rawUserId =
          widget.user['id'] ??
          widget.user['user_id'] ??
          widget.user['alumni_id'];
      final userId = int.tryParse('$rawUserId') ?? 0;

      // Fetch announcements
      final annData = await ContentService.fetchAnnouncements();

      // Fetch recent dashboard activity
      List<Map<String, dynamic>> activityData = const [];
      final activityRes = await http.get(
        ApiService.uri(
          'get_full_activity.php',
          queryParameters: {'role': 'alumni'},
        ),
      );

      if (activityRes.statusCode == 200) {
        final decoded = jsonDecode(activityRes.body);
        if (decoded is List) {
          activityData = decoded
              .whereType<Map>()
              .map((item) => item.map((key, value) => MapEntry('$key', value)))
              .toList();
        }
      }

      // Fetch tracer submission status
      Map<String, dynamic> tracerData = const {"submitted": false};

      if (userId > 0) {
        final tracerRes = await http.get(
          ApiService.uri(
            'check_tracer.php',
            queryParameters: {'alumni_id': '$userId'},
          ),
        );

        if (tracerRes.statusCode != 200) {
          throw Exception(
            'Tracer status request failed (${tracerRes.statusCode})',
          );
        }

        final tracerBody = tracerRes.body.trim();
        debugPrint('TRACER STATUS: ${tracerRes.statusCode}');
        debugPrint('TRACER BODY: $tracerBody');

        if (tracerBody.isEmpty) {
          throw Exception('Tracer API returned an empty response');
        }

        if (tracerBody.startsWith('<')) {
          throw Exception(
            'Tracer API returned HTML instead of JSON: $tracerBody',
          );
        }

        final decoded = jsonDecode(tracerBody);
        if (decoded is Map<String, dynamic>) {
          tracerData = decoded;
        }
      }

      if (!mounted) return;

      setState(() {
        announcements = annData
            .map((e) => e.map((key, value) => MapEntry(key.toString(), value)))
            .toList();
        recentActivities = activityData;

        final submitted = tracerData['submitted'] == true;
        final draftSaved = tracerData['draft_saved'] == true;
        tracerInfo = {
          'submitted': submitted ? 'Yes' : 'No',
          'draft_saved': draftSaved ? 'Yes' : 'No',
        };
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error fetching data: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBackground,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final contentWidth = constraints.maxWidth;
                final isNarrow = contentWidth < 900;
                final quickAccessWidth = _cardWidth(
                  contentWidth,
                  minWidth: 220,
                  spacing: 16,
                  maxColumns: 4,
                );

                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFF7F8FA), Color(0xFFF4F1F2)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(contentWidth < 600 ? 16 : 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroHeader(contentWidth < 760),
                        const SizedBox(height: 24),
                        if (isNarrow)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _profileCard(),
                              const SizedBox(height: 24),
                              _tracerCard(context),
                            ],
                          )
                        else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _profileCard()),
                              const SizedBox(width: 24),
                              Expanded(child: _tracerCard(context)),
                            ],
                          ),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: cardBorder),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Quick Access",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: primaryMaroon,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Move through your most important alumni tools with a cleaner, faster dashboard layout.",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                children: [
                                  _quickAccess(
                                    Icons.person_outline,
                                    "Profile",
                                    _openProfileModule,
                                    width: quickAccessWidth,
                                  ),
                                  _quickAccess(
                                    Icons.campaign_outlined,
                                    "Announcements",
                                    _openAnnouncementsModule,
                                    width: quickAccessWidth,
                                  ),
                                  _quickAccess(
                                    Icons.work_outline,
                                    "Jobs",
                                    _openJobsModule,
                                    width: quickAccessWidth,
                                  ),
                                  _quickAccess(
                                    Icons.settings_outlined,
                                    "Settings",
                                    _openSettingsModule,
                                    width: quickAccessWidth,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        if (isNarrow)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _announcementsCard(),
                              const SizedBox(height: 24),
                              _recentUpdatesCard(),
                            ],
                          )
                        else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: _announcementsCard()),
                              const SizedBox(width: 24),
                              Expanded(flex: 1, child: _recentUpdatesCard()),
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

  double _cardWidth(
    double availableWidth, {
    required double minWidth,
    required double spacing,
    required int maxColumns,
  }) {
    for (int columns = maxColumns; columns >= 1; columns--) {
      final width = (availableWidth - (spacing * (columns - 1))) / columns;
      if (width >= minWidth) {
        return width;
      }
    }
    return availableWidth;
  }

  Widget _buildHeroHeader(bool isStacked) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryMaroon, primaryMaroon.withValues(alpha: 0.88)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: primaryMaroon.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Flex(
        direction: isStacked ? Axis.vertical : Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              Icons.dashboard_customize_outlined,
              color: accentGold,
              size: 34,
            ),
          ),
          SizedBox(width: isStacked ? 0 : 18, height: isStacked ? 18 : 0),
          if (isStacked)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder<Map<String, dynamic>?>(
                  valueListenable: UserStore.currentUser,
                  builder: (context, liveUser, _) {
                    final name =
                        (liveUser?['name'] ?? widget.user['name'] ?? 'Alumni')
                            .toString()
                            .trim();

                    return Text(
                      "Welcome back, ${name.isEmpty ? 'Alumni' : name}!",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  "Review your profile, tracer participation, and recent alumni updates in one presentable, streamlined home screen.",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.5,
                    fontSize: 13,
                  ),
                ),
              ],
            )
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ValueListenableBuilder<Map<String, dynamic>?>(
                    valueListenable: UserStore.currentUser,
                    builder: (context, liveUser, _) {
                      final name =
                          (liveUser?['name'] ?? widget.user['name'] ?? 'Alumni')
                              .toString()
                              .trim();

                      return Text(
                        "Welcome back, ${name.isEmpty ? 'Alumni' : name}!",
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Review your profile, tracer participation, and recent alumni updates in one presentable, streamlined home screen.",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      height: 1.5,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _quickAccess(
    IconData icon,
    String label,
    VoidCallback onTap, {
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          decoration: BoxDecoration(
            color: softRose,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryMaroon,
                      primaryMaroon.withValues(alpha: 0.82),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accentGold, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: primaryMaroon,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: primaryMaroon),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tracerCard(BuildContext context) {
    final isSubmitted = tracerInfo != null && tracerInfo!['submitted'] == "Yes";
    final hasDraft = tracerInfo != null && tracerInfo!['draft_saved'] == "Yes";
    final submissionStatus = isSubmitted
        ? "Submitted"
        : (hasDraft ? "Draft Saved" : "Not Submitted");

    final statusColor = isSubmitted
        ? Colors.green
        : (hasDraft ? Colors.orange : Colors.red);

    return _cardBase(
      "Tracer Form Status",
      Icons.assignment_turned_in_outlined,
      Column(
        children: [
          _infoRow("Submission", submissionStatus, statusColor),
          const SizedBox(height: 16),
          if (submissionStatus != "Submitted")
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasDraft ? Colors.orange.shade50 : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: hasDraft
                      ? Colors.orange.shade200
                      : Colors.amber.shade200,
                ),
              ),
              child: Text(
                hasDraft
                    ? "You have a saved tracer draft. Open the form anytime to continue and submit it."
                    : "Please complete your tracer form to help us track alumni career outcomes.",
                style: TextStyle(
                  fontSize: 12,
                  color: hasDraft ? Colors.orange[900] : Colors.amber[900],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _openTracerModule,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryMaroon,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                submissionStatus == "Submitted"
                    ? "View Tracer Form"
                    : (hasDraft ? "Continue Draft" : "Complete Tracer Form"),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _announcementsCard() {
    if (announcements.isEmpty) {
      return _cardBase(
        "Latest Announcements",
        Icons.campaign_outlined,
        const Text(
          "No announcements available.",
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }

    return _cardBase(
      "Latest Announcements",
      Icons.campaign_outlined,
      Column(
        children: announcements
            .map(
              (a) => Column(
                children: [
                  _announcement(
                    (a['title'] ?? '').toString(),
                    (a['description'] ?? '').toString(),
                    (a['created_at'] ?? '').toString(),
                  ),
                  const Divider(),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _announcement(String title, String content, String date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            date,
            style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
          ),
        ],
      ),
    );
  }

  Widget _recentUpdatesCard() {
    if (recentActivities.isEmpty) {
      return _cardBase(
        "Recent Updates",
        Icons.access_time,
        const Text(
          "No recent updates available.",
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }

    return _cardBase(
      "Recent Updates",
      Icons.access_time,
      Column(
        children: recentActivities
            .take(4)
            .map(
              (activity) => _update(
                (activity['title'] ?? 'Update').toString(),
                (activity['time'] ?? 'Just now').toString(),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _update(String text, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: const TextStyle(fontSize: 13)),
                Text(
                  time,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileCard() {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: UserStore.currentUser,
      builder: (context, liveUser, _) {
        final user = liveUser ?? widget.user;
        final alumniNumber = _readUserValue(user, [
          'alumniNumber',
          'alumni_number',
          'studentNumber',
          'student_number',
        ]);
        final gradYear = _readUserValue(user, [
          'gradYear',
          'year_graduated',
          'graduation_year',
        ]);
        final degree = _readUserValue(user, ['degree', 'program', 'major']);
        final civilStatus = _readUserValue(user, [
          'civilStatus',
          'civil_status',
        ]);

        final requiredFields = [
          _readUserValue(user, ['firstName', 'first_name', 'name']),
          _readUserValue(user, ['email']),
          _readUserValue(user, ['phone']),
          _readUserValue(user, ['address']),
          alumniNumber,
          gradYear,
          degree,
          civilStatus,
        ];

        final profileComplete = requiredFields.every(
          (field) => field.isNotEmpty,
        );
        final cardWidth = MediaQuery.of(context).size.width;
        final tileWidth = cardWidth < 700 ? double.infinity : 150.0;

        return _cardBase(
          "Profile Status",
          Icons.person_search_outlined,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (profileComplete ? Colors.green : Colors.orange)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: (profileComplete ? Colors.green : Colors.orange)
                        .withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      profileComplete
                          ? Icons.verified_outlined
                          : Icons.pending_actions_outlined,
                      color: profileComplete ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Completion",
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profileComplete ? "Complete" : "Incomplete",
                            style: TextStyle(
                              color: profileComplete
                                  ? Colors.green
                                  : Colors.orange,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _profileInfoTile(
                    "Alumni Number",
                    alumniNumber.isEmpty ? "N/A" : alumniNumber,
                    tileWidth,
                  ),
                  _profileInfoTile(
                    "Graduation Year",
                    gradYear.isEmpty ? "N/A" : gradYear,
                    tileWidth,
                  ),
                  _profileInfoTile(
                    "Degree",
                    degree.isEmpty ? "N/A" : degree,
                    tileWidth,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _openProfileModule,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryMaroon,
                    side: BorderSide(
                      color: primaryMaroon.withValues(alpha: 0.18),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "View Full Profile",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _profileInfoTile(String label, String value, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: softRose,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  String _readUserValue(Map<String, dynamic> user, List<String> keys) {
    for (final key in keys) {
      final value = user[key];
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  Widget _cardBase(String title, IconData icon, Widget child) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryMaroon, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, [Color? status]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          status != null
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: status.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      color: status,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                )
              : Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  void _openProfileModule() => widget.onModuleSelected?.call(1);

  void _openAnnouncementsModule() => widget.onModuleSelected?.call(2);

  void _openJobsModule() => widget.onModuleSelected?.call(3);

  void _openSettingsModule() => widget.onModuleSelected?.call(4);

  String _normalizeProgram(dynamic rawProgram) {
    final value = rawProgram?.toString().trim() ?? '';
    final upper = value.toUpperCase();
    if (upper.contains('BSIT') || upper.contains('INFORMATION TECHNOLOGY')) {
      return 'BSIT';
    }
    if (upper.contains('BSSW') || upper.contains('SOCIAL WORK')) {
      return 'BSSW';
    }
    return upper;
  }

  void _openTracerModule() {
    final currentUser = UserStore.currentUser.value;
    final program = _normalizeProgram(
      currentUser?['program'] ??
          currentUser?['degree'] ??
          widget.user['program'] ??
          widget.user['degree'],
    );
    final tracerIndex = switch (program) {
      "BSSW" => 5,
      "BSIT" => 6,
      _ => -1,
    };

    if (tracerIndex != -1) {
      widget.onModuleSelected?.call(tracerIndex);
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Program not recognized")));
  }
}
