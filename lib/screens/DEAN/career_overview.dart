import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../services/filter_options_service.dart';
import '../../state/user_store.dart';
import 'dean_analytics_data.dart';

class CareerOverviewPage extends StatefulWidget {
  const CareerOverviewPage({super.key});

  @override
  State<CareerOverviewPage> createState() => _CareerOverviewPageState();
}

class _CareerOverviewPageState extends State<CareerOverviewPage> {
  final Color primaryMaroon = const Color(0xFF4A152C);
  final Color accentGold = const Color(0xFFC5A046);
  final Color bgLight = const Color(0xFFF7F8FA);
  final Color borderColor = const Color(0xFFE5E7EB);

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
    _assignedProgram = _normalizeProgram(UserStore.value?['program']);
    _selectedProgram = _assignedProgram ?? 'All';
    _programOptions = _assignedProgram == null
        ? const ['All']
        : [_assignedProgram];
    _loadFilterOptions();
    _fetchOverview();
  }

  String? _normalizeProgram(dynamic value) {
    final normalized = value?.toString().trim().toUpperCase() ?? '';
    if (normalized == 'BSIT' || normalized == 'BSSW') {
      return normalized;
    }
    return null;
  }

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

  Future<void> _fetchOverview() async {
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
        SnackBar(content: Text('Failed to load career overview: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 960;
    final isCompact = width < 600;
    final isHeroStacked = width < 820;

    return Scaffold(
      backgroundColor: bgLight,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isCompact ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.all(isCompact ? 20 : 28),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [primaryMaroon, const Color(0xFF6C1F3D)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primaryMaroon.withValues(alpha: 0.16),
                              blurRadius: 24,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: isHeroStacked
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.14,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      'Dean Overview',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Live Career Overview',
                                    style: TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _assignedProgram == null
                                        ? 'Real-time summary based on tracer submissions across all academic programs.'
                                        : 'Real-time summary based on tracer submissions for $_assignedProgram.',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.82,
                                      ),
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _assignedProgram == null
                                      ? _buildProgramDropdown()
                                      : _buildLockedProgramBadge(
                                          expanded: true,
                                        ),
                                  const SizedBox(height: 12),
                                  _buildRefreshButton(expanded: true),
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.14,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: const Text(
                                            'Dean Overview',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'Live Career Overview',
                                          style: TextStyle(
                                            fontSize: 30,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _assignedProgram == null
                                              ? 'Real-time summary based on tracer submissions across all academic programs.'
                                              : 'Real-time summary based on tracer submissions for $_assignedProgram.',
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.82,
                                            ),
                                            fontSize: 14,
                                            height: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  SizedBox(
                                    width: 260,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: _assignedProgram == null
                                              ? _buildProgramDropdown()
                                              : _buildLockedProgramBadge(),
                                        ),
                                        const SizedBox(width: 12),
                                        _buildRefreshButton(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 24),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final cardWidth = constraints.maxWidth >= 1180
                              ? (constraints.maxWidth - 48) / 4
                              : constraints.maxWidth >= 760
                              ? (constraints.maxWidth - 16) / 2
                              : constraints.maxWidth;
                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              _buildSummaryCard(
                                'Total Submissions',
                                '${_summary['total_alumni'] ?? 0}',
                                Icons.groups,
                                Colors.blue,
                                cardWidth,
                              ),
                              _buildSummaryCard(
                                'Employment Rate',
                                '${_summary['employment_rate'] ?? 0}%',
                                Icons.work,
                                Colors.green,
                                cardWidth,
                              ),
                              _buildSummaryCard(
                                'Unemployment Rate',
                                '${_summary['unemployment_rate'] ?? 0}%',
                                Icons.person_off,
                                Colors.red,
                                cardWidth,
                              ),
                              _buildSummaryCard(
                                'Tracer Submissions',
                                '${_summary['submissions'] ?? 0}',
                                Icons.assignment_turned_in_outlined,
                                accentGold,
                                cardWidth,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      if (isNarrow)
                        Column(
                          children: [
                            _buildSectionCard(
                              'Employment Trend (Yearly %)',
                              SizedBox(
                                height: 240,
                                child: _batchData.isEmpty
                                    ? _buildEmptyState('No batch data yet.')
                                    : _buildLineChart(),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildSectionCard(
                              'Industry Distribution',
                              _industryData.isEmpty
                                  ? _buildEmptyState(
                                      'No industry distribution found.',
                                    )
                                  : _buildIndustryDistribution(),
                            ),
                            const SizedBox(height: 20),
                            _buildTopEmployersCard(),
                            const SizedBox(height: 20),
                            _buildJobRelevancePanel(),
                          ],
                        )
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  _buildSectionCard(
                                    'Employment Trend (Yearly %)',
                                    SizedBox(
                                      height: 240,
                                      child: _batchData.isEmpty
                                          ? _buildEmptyState(
                                              'No batch data yet.',
                                            )
                                          : _buildLineChart(),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _buildSectionCard(
                                    'Industry Distribution',
                                    _industryData.isEmpty
                                        ? _buildEmptyState(
                                            'No industry distribution found.',
                                          )
                                        : _buildIndustryDistribution(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                children: [
                                  _buildTopEmployersCard(),
                                  const SizedBox(height: 20),
                                  _buildJobRelevancePanel(),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.grey, fontSize: 13),
      ),
    );
  }

  Widget _buildProgramDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedProgram,
          isExpanded: true,
          items: _programOptions
              .map(
                (program) => DropdownMenuItem(
                  value: program,
                  child: Text(program == 'All' ? 'All Programs' : program),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _selectedProgram = value);
            _fetchOverview();
          },
        ),
      ),
    );
  }

  Widget _buildLockedProgramBadge({bool expanded = false}) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, color: accentGold, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Department: ${_assignedProgram ?? 'All Programs'}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    return expanded ? SizedBox(width: double.infinity, child: badge) : badge;
  }

  Widget _buildRefreshButton({bool expanded = false}) {
    final button = OutlinedButton.icon(
      onPressed: _fetchOverview,
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('Refresh'),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: primaryMaroon,
        minimumSize: const Size(0, 52),
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }

  Widget _buildSectionCard(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 14,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
    double cardWidth,
  ) {
    return SizedBox(
      width: cardWidth,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 14,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              radius: 20,
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndustryDistribution() {
    final total = _industryData.fold<int>(
      0,
      (sum, item) => sum + (((item['value'] as num?)?.toInt()) ?? 0),
    );

    return Column(
      children: _industryData.map((item) {
        final label = item['industry']?.toString() ?? 'Unspecified';
        final count = (item['value'] as num?)?.toInt() ?? 0;
        final ratio = total == 0 ? 0.0 : count / total;
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text('${(ratio * 100).round()}%'),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 10,
                  backgroundColor: bgLight,
                  color: primaryMaroon,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTopEmployersCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Employers',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (_topEmployers.isEmpty)
            const Text(
              'No employer records available yet.',
              style: TextStyle(color: Colors.grey),
            )
          else
            ..._topEmployers.map(
              (entry) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.business_outlined, color: accentGold),
                title: Text(
                  entry['name']?.toString() ?? 'Unknown Employer',
                  style: const TextStyle(fontSize: 14),
                ),
                trailing: Text(
                  '${entry['count'] ?? 0}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                dense: true,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLineChart() {
    final spots = <FlSpot>[];
    for (var i = 0; i < _batchData.length; i++) {
      spots.add(
        FlSpot(i.toDouble(), ((_batchData[i]['rate'] as num?) ?? 0).toDouble()),
      );
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 30),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= _batchData.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _batchData[index]['year']?.toString() ?? '',
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: primaryMaroon,
            barWidth: 4,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: primaryMaroon.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobRelevancePanel() {
    final related = (_jobRelevance['related'] as num?)?.toInt() ?? 0;
    final other = (_jobRelevance['other'] as num?)?.toInt() ?? 0;
    final total = related + other;
    final relatedRate = total == 0 ? 0 : ((related / total) * 100).round();
    final otherRate = total == 0 ? 0 : ((other / total) * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: primaryMaroon,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: accentGold, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Job Relevance',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Related jobs: $relatedRate%',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            'Other or partial: $otherRate%',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            'Based on $total tracer responses with job relevance data.',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
