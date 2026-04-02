import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../services/api_service.dart';
import '../../state/user_store.dart';

class AdminDashboard extends StatefulWidget {
  final Function(int) onActionSelected;
  final VoidCallback onOpenRecentActivity;
  final VoidCallback onOpenLatestUsers;
  final Map<String, dynamic> user;

  const AdminDashboard({
    super.key,
    required this.onActionSelected,
    required this.onOpenRecentActivity,
    required this.onOpenLatestUsers,
    required this.user,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int touchedIndex = -1;

  final Color primaryMaroon = const Color(0xFF4A152C);
  final Color accentGold = const Color(0xFFC5A046);
  final Color bgLight = const Color(0xFFF8F9FA);
  final Color borderColor = const Color(0xFFE0E0E0);

  String _currentDate = "";
  late Timer _clockTimer;
  Timer? _dashboardRefreshTimer;

  Map<String, dynamic> liveStats = {
    "total_alumni": 0,
    "pending_users": 0,
    "tracer_submissions": 0,
    "employment_rate": 0,
  };

  List industries = [];
  List chartData = [];
  List activities = [];
  List latestUsers = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    _updateTime();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (Timer t) => _updateTime(),
    );

    fetchDashboardData();
    _dashboardRefreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => fetchDashboardData(showLoader: false),
    );
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _dashboardRefreshTimer?.cancel();
    super.dispose();
  }

  void _updateTime() {
    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(now);

    if (mounted) {
      setState(() {
        _currentDate = formattedDate;
      });
    }
  }

  // ✅ UPDATED FETCH (WITH SAFE LOADING)
  Future<void> fetchDashboardData({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => isLoading = true);
    }

    try {
      final response = await http.get(
        ApiService.uri('get_admin_stats.php'),
        headers: ApiService.authHeaders(),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          liveStats = data['summary'] ?? {};
          chartData = data['chart_data'] ?? [];
          activities = data['recent_activity'] ?? [];
          latestUsers = data['latest_users'] ?? [];
          industries = data['industries'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4A152C)),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth;
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  contentWidth < 600 ? 16 : 32,
                  24,
                  contentWidth < 600 ? 16 : 32,
                  32,
                ),
                child: _buildDashboardContent(contentWidth),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDashboardContent(double contentWidth) {
    final isNarrow = contentWidth < 900;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ✅ UPDATED HEADER WITH REFRESH BUTTON & DYNAMIC NAME
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: isNarrow ? double.infinity : 520,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ValueListenableBuilder<Map<String, dynamic>?>(
                    valueListenable: UserStore.currentUser,
                    builder: (context, liveUser, _) {
                      final name =
                          (liveUser?['name'] ?? widget.user['name'] ?? 'Admin')
                              .toString()
                              .trim();
                      return Text(
                        "Welcome back, ${name.isEmpty ? 'Admin' : name}!",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: primaryMaroon,
                        ),
                      );
                    },
                  ),
                  Text(
                    "Here's what's happening with the alumni portal today.",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            ),

            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _currentDate,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),

                // 🔥 REFRESH BUTTON
                IconButton(
                  onPressed: () {
                    fetchDashboardData();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  color: primaryMaroon,
                  tooltip: "Refresh Dashboard",
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    shadowColor: Colors.black.withValues(alpha: 0.1),
                    elevation: 2,
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 32),

        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildStatCard(
              "Total Alumni",
              liveStats['total_alumni'].toString(),
              Icons.people_outline,
              Colors.blue,
              contentWidth,
            ),
            _buildStatCard(
              "Pending Verification",
              liveStats['pending_users'].toString(),
              Icons.hourglass_top,
              Colors.red,
              contentWidth,
            ),
            _buildStatCard(
              "Tracer Submissions",
              liveStats['tracer_submissions'].toString(),
              Icons.assignment_outlined,
              Colors.green,
              contentWidth,
            ),
            _buildStatCard(
              "Employment Rate",
              "${liveStats['employment_rate']}%",
              Icons.trending_up,
              accentGold,
              contentWidth,
            ),
          ],
        ),

        const SizedBox(height: 32),

        const Text(
          "Quick Actions",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _actionButton("View Pending Users", Icons.verified_user, 3),
            _actionButton("Tracer Governance", Icons.analytics, 2),
            _actionButton("Manage Announcements", Icons.campaign, 4),
            _actionButton("Generate Reports", Icons.picture_as_pdf, 2),
          ],
        ),

        const SizedBox(height: 32),

        if (isNarrow)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildChartContainer(
                "Employment Rate per Batch",
                child: _barChart(),
              ),
              const SizedBox(height: 24),
              _buildChartContainer("Industry Distribution", child: _pieChart()),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildChartContainer(
                  "Employment Rate per Batch",
                  child: _barChart(),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 1,
                child: _buildChartContainer(
                  "Industry Distribution",
                  child: _pieChart(),
                ),
              ),
            ],
          ),

        const SizedBox(height: 32),

        if (isNarrow)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDataContainer(
                "Recent Activity",
                onViewAll: () {
                  widget.onOpenRecentActivity();
                },
                child: Column(
                  children: activities.isEmpty
                      ? [
                          const Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Text("No recent activity"),
                          ),
                        ]
                      : activities.take(5).map((act) {
                          return _activityItem(
                            act['title'] ?? "Unknown",
                            act['time'] ?? "",
                            act['type'] ?? "Tracer",
                            () {
                              widget.onOpenRecentActivity();
                            },
                          );
                        }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              _buildDataContainer(
                "Latest Registrations",
                onViewAll: () {
                  widget.onOpenLatestUsers();
                },
                child: Column(
                  children: latestUsers.isEmpty
                      ? [
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text("No new registrations"),
                          ),
                        ]
                      : latestUsers
                            .take(3)
                            .map(
                              (user) => _regItem(
                                user['name'] ?? 'Unknown',
                                user['course'] ?? 'N/A',
                                user['status'] ?? 'Pending',
                                user['email'] ?? 'No Email',
                                user['year'] ?? 'N/A',
                              ),
                            )
                            .toList(),
                ),
              ),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildDataContainer(
                  "Recent Activity",
                  onViewAll: () {
                    widget.onOpenRecentActivity();
                  },
                  child: Column(
                    children: activities.isEmpty
                        ? [
                            const Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Text("No recent activity"),
                            ),
                          ]
                        : activities.take(5).map((act) {
                            return _activityItem(
                              act['title'] ?? "Unknown",
                              act['time'] ?? "",
                              act['type'] ?? "Tracer",
                              () {
                                widget.onOpenRecentActivity();
                              },
                            );
                          }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildDataContainer(
                  "Latest Registrations",
                  onViewAll: () {
                    widget.onOpenLatestUsers();
                  },
                  child: Column(
                    children: latestUsers.isEmpty
                        ? [
                            const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text("No new registrations"),
                            ),
                          ]
                        : latestUsers
                              .take(3)
                              .map(
                                (user) => _regItem(
                                  user['name'] ?? 'Unknown',
                                  user['course'] ?? 'N/A',
                                  user['status'] ?? 'Pending',
                                  user['email'] ?? 'No Email',
                                  user['year'] ?? 'N/A',
                                ),
                              )
                              .toList(),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  // 🔽 KEEP ALL YOUR EXISTING WIDGETS BELOW (UNCHANGED)

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    double contentWidth,
  ) {
    return SizedBox(
      width: contentWidth < 700
          ? double.infinity
          : contentWidth >= 1180
          ? (contentWidth - 48) / 4
          : contentWidth >= 760
          ? (contentWidth - 16) / 2
          : double.infinity,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border(top: BorderSide(color: color, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 110;
                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: color),
                      const SizedBox(height: 8),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(icon, color: color),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(String title, IconData icon, int targetIndex) {
    return ElevatedButton.icon(
      onPressed: () {
        widget.onActionSelected.call(targetIndex);
      },
      icon: Icon(icon, size: 18, color: Colors.white),
      label: Text(title, style: const TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryMaroon,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      ),
    );
  }

  Widget _buildChartContainer(String title, {required Widget child}) {
    return Container(
      height: MediaQuery.of(context).size.width < 700 ? 340 : 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildDataContainer(
    String title, {
    required Widget child,
    VoidCallback? onViewAll,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (onViewAll != null)
                TextButton(
                  onPressed: onViewAll,
                  style: TextButton.styleFrom(
                    foregroundColor: accentGold,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    "View All",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _activityItem(
    String name,
    String time,
    String type,
    VoidCallback onTap,
  ) {
    const Color primaryMaroon = Color(0xFF4A152C);

    // Logic to pick icon based on the 'type' string from PHP
    IconData icon = Icons.edit_note;
    if (type == 'Tracer') {
      icon = Icons.description_outlined;
    } else if (type == 'Announcement') {
      icon = Icons.campaign;
    } else if (type == 'Verification') {
      icon = Icons.verified_user;
    }

    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        // ✅ FIXED: Changed .withOpacity to .withValues
        backgroundColor: primaryMaroon.withValues(alpha: 0.1),
        child: Icon(icon, color: primaryMaroon, size: 18),
      ),
      title: Text(
        name,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      ),
      subtitle: Text("$time • $type", style: const TextStyle(fontSize: 11)),
      trailing: Icon(
        Icons.chevron_right,
        size: 14,
        color: Colors.grey.shade400,
      ),
    );
  }

  Widget _regItem(
    String name,
    String course,
    String status,
    String email,
    String year,
  ) {
    // Use a clean, professional grey for the secondary text
    final Color statusColor =
        status.toLowerCase() == "approved" || status == "verified"
        ? Colors.green
        : Colors.orange;

    final Color primaryMaroon = const Color(0xFF4A152C);
    final isCompact = MediaQuery.of(context).size.width < 560;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        vertical: 4,
      ), // Added slight padding for the multi-line subtitle
      title: Text(
        name,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: primaryMaroon, // Applying your theme color to the name
        ),
      ),
      // ✅ Changed to Column to show multiple fields
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          // Combines Course and Year
          Text(
            "$course • Class of $year",
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          // Displays Email
          Text(
            email,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
          if (isCompact) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status.toLowerCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      trailing: isCompact
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status.toLowerCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }

  Widget _barChart() {
    return BarChart(
      BarChartData(
        maxY: 100,
        // --- ADDED: Tooltip when touching/hovering ---
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => primaryMaroon,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toInt()}%',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        // --- ADDED: Fixed Axis Labels ---
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                // value is the Year (x). We turn it into a string without "K"
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}%',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: borderColor, strokeWidth: 1, dashArray: [5, 5]),
        ),
        borderData: FlBorderData(show: false),
        barGroups: chartData.map((e) {
          return BarChartGroupData(
            x: int.parse(e['year'].toString()),
            barRods: [
              BarChartRodData(
                toY: (e['rate'] as num).toDouble(),
                color: primaryMaroon,
                width: 20,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _pieChart() {
    if (isLoading || industries.isEmpty) {
      return const Center(child: Text("No Industry Data"));
    }

    // Consistent color mapping
    Color getSectorColor(String name) {
      final cleanName = name.trim().toLowerCase();
      switch (cleanName) {
        case 'government':
          return primaryMaroon;
        case 'private':
          return accentGold;
        case 'ngo':
          return Colors.blue.shade700;
        case 'academic': // Matches your singular "Academic" in DB
          return Colors.teal.shade600;
        case 'overseas':
          return Colors.deepOrange.shade400;
        default:
          return Colors.grey.shade400;
      }
    }

    double totalSubmissions = (liveStats['tracer_submissions'] ?? 1).toDouble();

    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 40,

            // ✅ Hover / Tap interactions
            pieTouchData: PieTouchData(
              touchCallback: (event, response) {
                setState(() {
                  if (!event.isInterestedForInteractions ||
                      response == null ||
                      response.touchedSection == null) {
                    touchedIndex = -1;
                  } else {
                    touchedIndex = response.touchedSection!.touchedSectionIndex;
                  }
                });
              },
            ),

            sections: industries.asMap().entries.map((entry) {
              int index = entry.key;
              var data = entry.value;

              final isTouched = index == touchedIndex;

              // Determine sector name
              String sectorName =
                  data['industry'] ?? data['label'] ?? 'Unknown';

              return PieChartSectionData(
                value: (data['value'] ?? 0).toDouble(),
                title: "", // Clean look
                radius: isTouched ? 60 : 50, // Zoom on hover/tap
                color: getSectorColor(sectorName), // Use helper function
              );
            }).toList(),
          ),
        ),

        // 🔥 Floating Tooltip
        if (touchedIndex != -1 && touchedIndex < industries.length)
          Positioned(
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Builder(
                builder: (_) {
                  var data = industries[touchedIndex];
                  String sectorName =
                      data['industry'] ?? data['label'] ?? 'Unknown';
                  double percentage =
                      ((data['value'] ?? 0) / totalSubmissions) * 100;

                  return Text(
                    "$sectorName • ${percentage.toStringAsFixed(0)}%",
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class RecentActivityPage extends StatefulWidget {
  final List<dynamic> activities;
  final bool isLoading;
  final VoidCallback onBack;
  final Future<void> Function() onRefresh;

  const RecentActivityPage({
    super.key,
    required this.activities,
    required this.isLoading,
    required this.onBack,
    required this.onRefresh,
  });

  @override
  State<RecentActivityPage> createState() => _RecentActivityPageState();
}

class _RecentActivityPageState extends State<RecentActivityPage> {
  final Color primaryMaroon = const Color(0xFF4A152C);
  final Color bgLight = const Color(0xFFF8F9FA);

  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _filteredActivities = [];

  @override
  void initState() {
    super.initState();
    _filteredActivities = widget.activities;
    _searchController.addListener(_filterActivities);
  }

  void _filterActivities() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredActivities = widget.activities.where((act) {
        final title = (act['title'] ?? "").toString().toLowerCase();
        final type = (act['type'] ?? "").toString().toLowerCase();
        return title.contains(query) || type.contains(query);
      }).toList();
    });
  }

  @override
  void didUpdateWidget(RecentActivityPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activities != widget.activities) {
      _filterActivities();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 700;

    return Container(
      color: bgLight,
      padding: EdgeInsets.all(isNarrow ? 16.0 : 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isNarrow)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  onPressed: widget.onBack,
                  color: primaryMaroon,
                ),
                Text(
                  "Full Activity Log",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: primaryMaroon,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: widget.onRefresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text("Refresh Log"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryMaroon,
                      minimumSize: const Size(0, 48),
                      side: BorderSide(
                        color: primaryMaroon.withValues(alpha: 0.18),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  onPressed: widget.onBack,
                  color: primaryMaroon,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Full Activity Log",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: primaryMaroon,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: widget.onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text("Refresh Log"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryMaroon,
                    minimumSize: const Size(0, 48),
                    side: BorderSide(
                      color: primaryMaroon.withValues(alpha: 0.18),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Text(
            "Viewing all recent system updates and alumni interactions.",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search by alumni name or activity type...",
                prefixIcon: Icon(Icons.search, color: primaryMaroon),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: RefreshIndicator(
              onRefresh: widget.onRefresh,
              color: primaryMaroon,
              child: widget.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredActivities.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 100),
                        Center(
                          child: Text(
                            _searchController.text.isEmpty
                                ? "No activity history found."
                                : "No results matching \"${_searchController.text}\"",
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _filteredActivities.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final act = _filteredActivities[index];

                        IconData icon = Icons.edit_note;
                        if (act['type'] == 'Tracer') {
                          icon = Icons.description_outlined;
                        } else if (act['type'] == 'Announcement') {
                          icon = Icons.campaign;
                        } else if (act['type'] == 'Verification') {
                          icon = Icons.verified_user;
                        }

                        return ListTile(
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: isNarrow ? 0 : 4,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: primaryMaroon.withValues(
                              alpha: 0.1,
                            ),
                            child: Icon(icon, color: primaryMaroon, size: 20),
                          ),
                          title: Text(
                            act['title'] ?? "Activity",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Text(
                            "${act['time']} - ${act['type']}",
                            style: const TextStyle(fontSize: 13),
                          ),
                          trailing: isNarrow
                              ? null
                              : Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey.shade400,
                                  size: 18,
                                ),
                          onTap: () {},
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
