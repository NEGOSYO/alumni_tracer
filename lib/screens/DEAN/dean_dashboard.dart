import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../services/filter_options_service.dart';
import '../../state/user_store.dart';
import 'dean_analytics_data.dart';

class DeanDashboard extends StatefulWidget {
  final Map<String, dynamic> user;

  const DeanDashboard({super.key, required this.user});

  @override
  State<DeanDashboard> createState() => _DeanDashboardState();
}

class _DeanDashboardState extends State<DeanDashboard> {
  static const Color primaryMaroon = Color(0xFF4A152C);
  static const Color lightBackground = Color(0xFFF7F8FA);
  static const Color accentGold = Color(0xFFC5A046);
  static const Color cardBorder = Color(0xFFE5E7EB);
  static const Color softRose = Color(0xFFF8F1F4);

  static const List<Color> chartColors = [
    Color(0xFF4A152C),
    Color(0xFFC5A046),
    Color(0xFF2F80ED),
    Color(0xFF27AE60),
    Color(0xFFF2994A),
    Color(0xFF9B51E0),
  ];

  late final String? _assignedProgram;
  String _selectedProgram = 'All';
  bool _isLoading = true;
  List<String> _programOptions = const ['All'];

  Map<String, dynamic> _summary = {
    'total_alumni': 0,
    'employment_rate': 0,
    'unemployment_rate': 0,
    'submissions': 0,
  };
  List<Map<String, dynamic>> _batchData = [];
  List<Map<String, dynamic>> _industryData = [];
  List<Map<String, dynamic>> _topEmployers = [];
  Map<String, dynamic> _jobRelevance = {'related': 0, 'other': 0};

  @override
  void initState() {
    super.initState();
    _assignedProgram = _normalizeProgram(
      widget.user['program'] ?? UserStore.value?['program'],
    );
    _selectedProgram = _assignedProgram ?? 'All';
    _programOptions = _assignedProgram == null
        ? const ['All']
        : [_assignedProgram];
    _loadFilterOptions();
    _fetchDashboardData();
  }

  String? _normalizeProgram(dynamic value) {
    final normalized = value?.toString().trim().toUpperCase() ?? '';
    if (normalized == 'BSIT' || normalized == 'BSSW') {
      return normalized;
    }
    return null;
  }

  String get _programLabel => _assignedProgram ?? 'All Programs';

  String get _roleLabel => _assignedProgram == null
      ? 'Department Dean'
      : '$_assignedProgram Department Head';

  Future<void> _loadFilterOptions() async {
    if (_assignedProgram != null) return;

    try {
      final options = await FilterOptionsService.fetch();
      if (!mounted) return;
      setState(() {
        _programOptions = ['All', ...options.programs];
        if (!_programOptions.contains(_selectedProgram)) {
          _selectedProgram = _programOptions.first;
        }
      });
    } catch (_) {
      // Preserve the fallback list when backend options are unavailable.
    }
  }

  Future<void> _fetchDashboardData() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final analytics = await DeanAnalyticsService.fetch(
        program: _selectedProgram,
      );

      if (!mounted) return;

      setState(() {
        _summary = analytics.summary;
        _batchData = analytics.batchData;
        _industryData = analytics.industryData;
        _topEmployers = analytics.topEmployers;
        _jobRelevance = analytics.jobRelevance;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load dean dashboard: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBackground,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 1100;
                final isNarrow = constraints.maxWidth < 860;

                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFF7F8FA), Color(0xFFF4F1F2)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(
                      constraints.maxWidth < 600 ? 16 : 32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroHeader(isNarrow),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 20,
                          runSpacing: 20,
                          children: [
                            _buildStatCard(
                              "Total Submissions",
                              "${_summary['total_alumni'] ?? 0}",
                              Icons.people_alt_outlined,
                              Colors.blue,
                              constraints.maxWidth,
                            ),
                            _buildStatCard(
                              "Employment Rate",
                              "${_summary['employment_rate'] ?? 0}%",
                              Icons.trending_up,
                              Colors.green,
                              constraints.maxWidth,
                            ),
                            _buildStatCard(
                              "Unemployment",
                              "${_summary['unemployment_rate'] ?? 0}%",
                              Icons.trending_down,
                              Colors.redAccent,
                              constraints.maxWidth,
                            ),
                            _buildStatCard(
                              "Tracer Submissions",
                              "${_summary['submissions'] ?? 0}",
                              Icons.assignment_turned_in_outlined,
                              accentGold,
                              constraints.maxWidth,
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        _buildDashboardSection(
                          title: "Employment Rate Per Batch",
                          child: SizedBox(
                            height: 300,
                            child: _batchData.isEmpty
                                ? _buildEmptyState("No batch data yet.")
                                : _buildBarChart(),
                          ),
                        ),
                        const SizedBox(height: 32),
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildDashboardSection(
                                  title: "Industry Distribution",
                                  child: SizedBox(
                                    height: 300,
                                    child: _industryData.isEmpty
                                        ? _buildEmptyState(
                                            "No industry data found in tracer submissions.",
                                          )
                                        : _buildPieChart(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: _buildDashboardSection(
                                  title: "Top Employers",
                                  child: _topEmployers.isEmpty
                                      ? _buildEmptyState(
                                          "No employer records available yet.",
                                        )
                                      : Column(
                                          children: _topEmployers
                                              .asMap()
                                              .entries
                                              .map(
                                                (entry) => _buildEmployerItem(
                                                  entry.value['name']
                                                          ?.toString() ??
                                                      'Unknown Employer',
                                                  "${entry.value['count'] ?? 0} Alumni",
                                                  chartColors[entry.key %
                                                      chartColors.length],
                                                ),
                                              )
                                              .toList(),
                                        ),
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _buildDashboardSection(
                                title: "Industry Distribution",
                                child: SizedBox(
                                  height: 300,
                                  child: _industryData.isEmpty
                                      ? _buildEmptyState(
                                          "No industry data found in tracer submissions.",
                                        )
                                      : _buildPieChart(),
                                ),
                              ),
                              const SizedBox(height: 24),
                              _buildDashboardSection(
                                title: "Top Employers",
                                child: _topEmployers.isEmpty
                                    ? _buildEmptyState(
                                        "No employer records available yet.",
                                      )
                                    : Column(
                                        children: _topEmployers
                                            .asMap()
                                            .entries
                                            .map(
                                              (entry) => _buildEmployerItem(
                                                entry.value['name']
                                                        ?.toString() ??
                                                    'Unknown Employer',
                                                "${entry.value['count'] ?? 0} Alumni",
                                                chartColors[entry.key %
                                                    chartColors.length],
                                              ),
                                            )
                                            .toList(),
                                      ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 32),
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildDashboardSection(
                                  title: "Job Relevance",
                                  child: _buildJobRelevanceCard(),
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: _buildDashboardSection(
                                  title: "Data Notes",
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: softRose,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: cardBorder),
                                    ),
                                    child: const Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "This dashboard now reads live tracer submissions.",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(height: 12),
                                        Text(
                                          "Industry data is grouped from the tracer form's sector field.",
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          "Batch employment is grouped from year_graduated.",
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _buildDashboardSection(
                                title: "Job Relevance",
                                child: _buildJobRelevanceCard(),
                              ),
                              const SizedBox(height: 24),
                              _buildDashboardSection(
                                title: "Data Notes",
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: softRose,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: cardBorder),
                                  ),
                                  child: const Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "This dashboard now reads live tracer submissions.",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        "Industry data is grouped from the tracer form's sector field.",
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        "Batch employment is grouped from year_graduated.",
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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

  Widget _buildHeroHeader(bool isNarrow) {
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
      child: Wrap(
        spacing: 18,
        runSpacing: 18,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              Icons.query_stats_outlined,
              color: accentGold,
              size: 34,
            ),
          ),
          SizedBox(
            width: isNarrow ? double.infinity : 460,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome, ${widget.user['name'] ?? _roleLabel}!",
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _assignedProgram == null
                      ? "Review live tracer analytics, industry trends, and graduate outcomes across the academic programs."
                      : "Review live tracer analytics, industry trends, and graduate outcomes for $_assignedProgram.",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: _assignedProgram == null
                    ? DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          dropdownColor: primaryMaroon,
                          value: _selectedProgram,
                          style: const TextStyle(color: Colors.white),
                          iconEnabledColor: Colors.white,
                          items: _programOptions
                              .map(
                                (program) => DropdownMenuItem(
                                  value: program,
                                  child: Text(
                                    program == 'All' ? 'All Programs' : program,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _selectedProgram = value);
                            _fetchDashboardData();
                          },
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline, color: accentGold, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            _assignedProgram,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
              OutlinedButton.icon(
                onPressed: _fetchDashboardData,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.30)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text('Refresh $_programLabel'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Text(
        message,
        style: const TextStyle(color: Colors.grey, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildJobRelevanceCard() {
    final related = (_jobRelevance['related'] ?? 0) as int;
    final other = (_jobRelevance['other'] ?? 0) as int;
    final total = related + other;
    final relatedRate = total > 0 ? ((related / total) * 100).round() : 0;
    final otherRate = total > 0 ? ((other / total) * 100).round() : 0;
    final isNarrow = MediaQuery.of(context).size.width < 640;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: softRose,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        children: [
          if (isNarrow)
            Column(
              children: [
                _buildMiniMetric("Related", "$relatedRate%", Colors.green),
                const SizedBox(height: 16),
                _buildMiniMetric("Other/Partial", "$otherRate%", accentGold),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildMiniMetric(
                    "Related",
                    "$relatedRate%",
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMiniMetric(
                    "Other/Partial",
                    "$otherRate%",
                    accentGold,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: total > 0 ? related / total : 0,
            minHeight: 12,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: Colors.grey.shade300,
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          Text(
            "$related related responses and $other other or partial responses",
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    final total = _industryData.fold<double>(
      0,
      (sum, item) => sum + ((item['value'] ?? 0) as num).toDouble(),
    );

    return PieChart(
      PieChartData(
        sectionsSpace: 4,
        centerSpaceRadius: 42,
        sections: _industryData.asMap().entries.map((entry) {
          final item = entry.value;
          final value = ((item['value'] ?? 0) as num).toDouble();
          final percentage = total > 0 ? (value / total) * 100 : 0;
          final title = percentage >= 10
              ? "${percentage.toStringAsFixed(0)}%"
              : '';

          return PieChartSectionData(
            value: value,
            color: chartColors[entry.key % chartColors.length],
            title: title,
            radius: 58,
            titleStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmployerItem(String name, String count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 35,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          Text(
            count,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    double totalWidth,
  ) {
    double cardWidth = (totalWidth - (20 * 3)) / 4;
    if (totalWidth < 1100) cardWidth = (totalWidth - 20) / 2;
    if (totalWidth < 600) cardWidth = totalWidth;

    return Container(
      width: cardWidth,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 20),
          Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 100,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= _batchData.length) {
                  return const SizedBox();
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _batchData[index]['year']?.toString() ?? '',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, m) => Text(
                "${v.toInt()}%",
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: Colors.grey.shade100, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: _batchData.asMap().entries.map((entry) {
          final rate = ((entry.value['rate'] ?? 0) as num).toDouble();
          return _makeGroupData(entry.key, rate);
        }).toList(),
      ),
    );
  }

  BarChartGroupData _makeGroupData(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: primaryMaroon,
          width: 40,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 100,
            color: lightBackground,
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardSection({
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}
