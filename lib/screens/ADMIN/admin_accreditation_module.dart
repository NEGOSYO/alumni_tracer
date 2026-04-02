import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class AdminAccreditationModule extends StatelessWidget {
  const AdminAccreditationModule({
    super.key,
    required this.reportData,
    required this.onGenerateReport,
    required this.totalResponses,
    required this.employedCount,
    required this.selfEmployedCount,
    required this.unemployedCount,
  });

  final Map<String, dynamic>? reportData;
  final VoidCallback onGenerateReport;
  final int totalResponses;
  final int employedCount;
  final int selfEmployedCount;
  final int unemployedCount;

  @override
  Widget build(BuildContext context) {
    final report = _AccreditationReport.from(reportData);
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 700;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4A152C), Color(0xFF6D2944)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: isNarrow ? double.infinity : 660,
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Tracer Governance & Accreditation",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "A single admin page for tracer submissions, data governance checks, accreditation evidence, and official report generation.",
                      style: TextStyle(color: Colors.white70, height: 1.5),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: onGenerateReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC5A046),
                  foregroundColor: Colors.black87,
                ),
                icon: const Icon(Icons.description_outlined),
                label: const Text("Download PDF"),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final summaryCardWidth = _cardWidth(
              constraints.maxWidth,
              minWidth: 250,
              spacing: 16,
              maxColumns: 4,
            );
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _summaryCard(
                  context,
                  "Total Responses",
                  totalResponses.toString(),
                  Icons.people_outline,
                  Colors.blue,
                  summaryCardWidth,
                ),
                _summaryCard(
                  context,
                  "Employed",
                  employedCount.toString(),
                  Icons.work_outline,
                  Colors.green,
                  summaryCardWidth,
                ),
                _summaryCard(
                  context,
                  "Self-Employed",
                  selfEmployedCount.toString(),
                  Icons.storefront_outlined,
                  const Color(0xFF7B2E4B),
                  summaryCardWidth,
                ),
                _summaryCard(
                  context,
                  "Unemployed",
                  unemployedCount.toString(),
                  Icons.person_off_outlined,
                  Colors.red,
                  summaryCardWidth,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final kpiCardWidth = _cardWidth(
              constraints.maxWidth,
              minWidth: 220,
              spacing: 16,
              maxColumns: 5,
            );
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _kpi(
                  context,
                  "Employment",
                  "${report.employmentRate.toStringAsFixed(1)}%",
                  kpiCardWidth,
                ),
                _kpi(
                  context,
                  "First Job",
                  report.topTimeToFirstJob,
                  kpiCardWidth,
                ),
                _kpi(
                  context,
                  "Job Relevance",
                  "${report.jobRelevanceRate.toStringAsFixed(1)}%",
                  kpiCardWidth,
                ),
                _kpi(
                  context,
                  "Skills Utilization",
                  "${report.skillsUtilization.toStringAsFixed(1)}/5",
                  kpiCardWidth,
                ),
                _kpi(
                  context,
                  "PEO Attainment",
                  "${report.peoAverage.toStringAsFixed(1)}/5",
                  kpiCardWidth,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final chartCardWidth = _cardWidth(
              constraints.maxWidth,
              minWidth: 360,
              spacing: 20,
              maxColumns: 3,
            );
            return Wrap(
              spacing: 20,
              runSpacing: 20,
              children: [
                _chartCard(
                  context,
                  "Employment Rate",
                  _barChart(report.employmentBars, 100, percent: true),
                  chartCardWidth,
                ),
                _chartCard(
                  context,
                  "Time to First Job",
                  _barChart(report.firstJobBars, report.firstJobMax),
                  chartCardWidth,
                ),
                _chartCard(
                  context,
                  "Job Relevance",
                  _barChart(report.relevanceBars, 100, percent: true),
                  chartCardWidth,
                ),
                _chartCard(
                  context,
                  "Salary Distribution",
                  _barChart(report.salaryBars, report.salaryMax),
                  chartCardWidth,
                ),
                _chartCard(
                  context,
                  "Top Skills Used",
                  _barChart(report.skillBars, report.skillMax, rotate: true),
                  chartCardWidth,
                ),
                _chartCard(
                  context,
                  "BSIT vs BSSW",
                  _comparison(report),
                  chartCardWidth,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final textCardWidth = _cardWidth(
              constraints.maxWidth,
              minWidth: 360,
              spacing: 20,
              maxColumns: 2,
            );
            return Wrap(
              spacing: 20,
              runSpacing: 20,
              children: [
                _textCard(
                  context,
                  "Key Findings",
                  report.findings,
                  const Icon(
                    Icons.analytics_outlined,
                    color: Color(0xFFC5A046),
                  ),
                  textCardWidth,
                ),
                _textCard(
                  context,
                  "Improvement Actions",
                  report.actions,
                  const Icon(
                    Icons.fact_check_outlined,
                    color: Color(0xFFC5A046),
                  ),
                  textCardWidth,
                ),
              ],
            );
          },
        ),
      ],
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

  Widget _kpi(
    BuildContext context,
    String title,
    String value,
    double cardWidth,
  ) {
    return Container(
      width: cardWidth,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _summaryCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
    double cardWidth,
  ) {
    return Container(
      width: cardWidth,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chartCard(
    BuildContext context,
    String title,
    Widget child,
    double cardWidth,
  ) {
    final width = MediaQuery.of(context).size.width;
    return Container(
      width: cardWidth,
      height: width < 760 ? 320 : 290,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _textCard(
    BuildContext context,
    String title,
    List<String> items,
    Widget icon,
    double cardWidth,
  ) {
    return Container(
      width: cardWidth,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              icon,
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text("- $item", style: const TextStyle(height: 1.45)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _comparison(_AccreditationReport report) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _comparisonRow("Metric", const ["BSIT", "BSSW"], header: true),
          _comparisonRow("Employment", [
            report.bsitEmployment,
            report.bsswEmployment,
          ]),
          _comparisonRow("Relevance", [
            report.bsitRelevance,
            report.bsswRelevance,
          ]),
          _comparisonRow("Skills", [report.bsitSkills, report.bsswSkills]),
          _comparisonRow("PEO", [report.bsitPeo, report.bsswPeo]),
          _comparisonRow("Growth", [report.bsitGrowth, report.bsswGrowth]),
        ],
      ),
    );
  }

  Widget _comparisonRow(
    String label,
    List<String> values, {
    bool header = false,
  }) {
    final style = TextStyle(
      fontWeight: header ? FontWeight.w700 : FontWeight.w500,
      color: header ? const Color(0xFF4A152C) : Colors.black87,
      fontSize: 12,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: style,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              values[0],
              style: style,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              values[1],
              style: style,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _barChart(
    List<_BarPoint> bars,
    double maxY, {
    bool percent = false,
    bool rotate = false,
  }) {
    if (bars.isEmpty) {
      return const Center(child: Text("Not enough data yet."));
    }

    return BarChart(
      BarChartData(
        maxY: maxY <= 0 ? 1 : maxY,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) => Text(
                percent ? "${value.toInt()}%" : value.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < 0 || value.toInt() >= bars.length) {
                  return const SizedBox.shrink();
                }
                return Transform.rotate(
                  angle: rotate ? -0.35 : 0,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      bars[value.toInt()].label,
                      style: const TextStyle(fontSize: 10),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < bars.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: bars[i].value,
                  color: const Color(0xFF4A152C),
                  width: 22,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _AccreditationReport {
  _AccreditationReport._();

  late double employmentRate;
  late double jobRelevanceRate;
  late double skillsUtilization;
  late double peoAverage;
  late String topTimeToFirstJob;
  late List<_BarPoint> employmentBars;
  late List<_BarPoint> firstJobBars;
  late List<_BarPoint> relevanceBars;
  late List<_BarPoint> salaryBars;
  late List<_BarPoint> skillBars;
  late List<String> findings;
  late List<String> actions;
  late String bsitEmployment;
  late String bsswEmployment;
  late String bsitRelevance;
  late String bsswRelevance;
  late String bsitSkills;
  late String bsswSkills;
  late String bsitPeo;
  late String bsswPeo;
  late String bsitGrowth;
  late String bsswGrowth;

  double get firstJobMax => _max(firstJobBars);
  double get salaryMax => _max(salaryBars);
  double get skillMax => _max(skillBars);

  static _AccreditationReport from(Map<String, dynamic>? source) {
    final report = _AccreditationReport._();
    final kpis = _map(source?['kpis']);
    final charts = _map(source?['charts']);
    final comparison = _map(source?['comparison']);
    final bsit = _map(comparison['bsit']);
    final bssw = _map(comparison['bssw']);

    report.employmentRate = _double(kpis['employment_rate']);
    report.jobRelevanceRate = _double(kpis['job_relevance_rate']);
    report.skillsUtilization = _double(kpis['skills_utilization']);
    report.peoAverage = _double(kpis['peo_average']);
    report.topTimeToFirstJob = _string(
      kpis['top_time_to_first_job'],
      fallback: 'No data',
    );
    report.employmentBars = _bars(charts['employment_bars']);
    report.firstJobBars = _bars(charts['first_job_bars']);
    report.relevanceBars = _bars(charts['relevance_bars']);
    report.salaryBars = _bars(charts['salary_bars']);
    report.skillBars = _bars(charts['skill_bars']);
    report.findings = _strings(source?['findings']);
    report.actions = _strings(source?['actions']);
    report.bsitEmployment = _string(bsit['employment']);
    report.bsswEmployment = _string(bssw['employment']);
    report.bsitRelevance = _string(bsit['relevance']);
    report.bsswRelevance = _string(bssw['relevance']);
    report.bsitSkills = _string(bsit['skills']);
    report.bsswSkills = _string(bssw['skills']);
    report.bsitPeo = _string(bsit['peo']);
    report.bsswPeo = _string(bssw['peo']);
    report.bsitGrowth = _string(bsit['growth']);
    report.bsswGrowth = _string(bssw['growth']);
    return report;
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return <String, dynamic>{};
  }

  static double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _string(dynamic value, {String fallback = 'No data'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static List<String> _strings(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return const [];
  }

  static List<_BarPoint> _bars(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) {
          final map = _map(item);
          return _BarPoint(
            _string(map['label'], fallback: ''),
            _double(map['value']),
          );
        })
        .where((item) => item.label.isNotEmpty)
        .toList();
  }

  static double _max(List<_BarPoint> items) {
    if (items.isEmpty) return 1;
    return items.map((item) => item.value).reduce((a, b) => a > b ? a : b) + 1;
  }
}

class _BarPoint {
  const _BarPoint(this.label, this.value);

  final String label;
  final double value;
}
