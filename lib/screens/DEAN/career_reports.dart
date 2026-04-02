import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/api_service.dart';
import '../../services/csv_export_service.dart';
import '../../services/filter_options_service.dart';
import '../../services/signed_tracer_filter.dart';
import '../../state/user_store.dart';

class CareerReportsPage extends StatefulWidget {
  const CareerReportsPage({super.key});

  @override
  State<CareerReportsPage> createState() => _CareerReportsPageState();
}

class _CareerReportsPageState extends State<CareerReportsPage> {
  final Color primaryMaroon = const Color(0xFF4A152C);
  final Color accentGold = const Color(0xFFC5A046);
  final Color bgLight = const Color(0xFFF7F8FA);
  final Color borderColor = const Color(0xFFE5E7EB);

  late final String? _assignedProgram;
  String selectedProgram = 'BSIT';
  String selectedBatch = 'All Batches';
  String selectedStatus = 'All Status';
  bool _isLoading = true;
  List<String> _programOptions = const ['BSIT', 'BSSW'];
  List<String> _batchOptions = const ['All Batches'];
  List<String> _statusOptions = const ['All Status'];

  List<Map<String, dynamic>> _allRows = [];
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic> _report = {};

  @override
  void initState() {
    super.initState();
    _assignedProgram = _normalizeProgram(UserStore.value?['program']);
    selectedProgram = _assignedProgram ?? 'BSIT';
    _programOptions = _assignedProgram == null
        ? const ['BSIT', 'BSSW']
        : [_assignedProgram];
    _loadFilterOptions();
    _fetchReports();
  }

  String? _normalizeProgram(dynamic value) {
    final normalized = value?.toString().trim().toUpperCase() ?? '';
    if (normalized == 'BSIT' || normalized == 'BSSW') {
      return normalized;
    }
    return null;
  }

  Future<void> _loadFilterOptions() async {
    try {
      final options = await FilterOptionsService.fetch(program: selectedProgram);
      if (!mounted) return;
      setState(() {
        _programOptions = _assignedProgram == null
            ? (options.programs.isEmpty ? const ['BSIT', 'BSSW'] : options.programs)
            : [_assignedProgram];
        _batchOptions = ['All Batches', ...options.years];
        _statusOptions = ['All Status', ...options.statuses];
        if (!_programOptions.contains(selectedProgram)) {
          selectedProgram = _programOptions.first;
        }
        if (!_batchOptions.contains(selectedBatch)) {
          selectedBatch = _batchOptions.first;
        }
        if (!_statusOptions.contains(selectedStatus)) {
          selectedStatus = _statusOptions.first;
        }
      });
    } catch (_) {
      // Preserve local fallback values when filter metadata is unavailable.
    }
  }

  Future<void> _fetchReports() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final tracerResponse = await http.get(
        ApiService.uri(
          'get_tracer_submissions.php',
          queryParameters: {'program': selectedProgram},
        ),
        headers: ApiService.authHeaders(),
      );
      final reportResponse = await http.get(
        ApiService.uri(
          'get_reports.php',
          queryParameters: {'program': selectedProgram},
        ),
        headers: ApiService.authHeaders(),
      );

      if (tracerResponse.statusCode != 200 ||
          reportResponse.statusCode != 200) {
        throw Exception('Failed to load report data');
      }

      final tracerDecoded = jsonDecode(tracerResponse.body);
      final reportDecoded = jsonDecode(reportResponse.body);
      final rawRows = tracerDecoded is Map ? tracerDecoded['alumni'] ?? [] : [];
      final signedRecords = tracerDecoded is Map
          ? ((tracerDecoded['signed_records'] ?? []) as List)
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : const <Map<String, dynamic>>[];
      final rows = SignedTracerFilter.keepSignedOnly(
        (rawRows as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(),
        signedRecords: signedRecords,
      );

      if (!mounted) return;
      setState(() {
        _allRows = rows;
        _report = reportDecoded is Map
            ? Map<String, dynamic>.from(reportDecoded['report'] ?? const {})
            : <String, dynamic>{};
        final dynamicBatches = _allRows
            .map((row) => (row['year_graduated'] ?? '').toString())
            .where((value) => value.isNotEmpty && value != 'null')
            .toSet()
            .toList()
          ..sort();
        _batchOptions = ['All Batches', ...dynamicBatches];
        if (!_batchOptions.contains(selectedBatch)) {
          selectedBatch = _batchOptions.first;
        }
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load career reports: $e')),
      );
    }
  }

  void _applyFilters() {
    _rows = _allRows.where((row) {
      final batch = (row['year_graduated'] ?? '').toString();
      final status = (row['employment_status'] ?? '').toString();

      final matchesBatch =
          selectedBatch == 'All Batches' || batch == selectedBatch;
      final matchesStatus =
          selectedStatus == 'All Status' || status == selectedStatus;

      return matchesBatch && matchesStatus;
    }).toList();
  }

  Map<String, int> _countBy(String key) {
    final counts = <String, int>{};
    for (final row in _rows) {
      final label = (row[key] ?? 'Unspecified').toString().trim();
      final normalized = label.isEmpty || label == 'null'
          ? 'Unspecified'
          : label;
      counts[normalized] = (counts[normalized] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 900;
    final isCompact = width < 640;
    final total = _rows.length;
    final employed = _rows.where((row) {
      final status = (row['employment_status'] ?? '').toString().toLowerCase();
      return status == 'employed' ||
          status == 'self-employed' ||
          status == 'employer';
    }).length;
    final unemployed = _rows
        .where(
          (row) => (row['employment_status'] ?? '').toString() == 'Unemployed',
        )
        .length;
    final rate = total == 0 ? 0 : ((employed / total) * 100).round();

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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'Dean Reports',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Live Career Reports',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _assignedProgram == null
                                  ? 'Filter live tracer records by program, batch, and employment status to review department-level insights.'
                                  : 'Filter live tracer records for $_assignedProgram by batch and employment status to review department-level insights.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildFilterSection(),
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
                                'Graduates',
                                '$total',
                                Icons.people,
                                Colors.blue,
                                cardWidth,
                              ),
                              _buildSummaryCard(
                                'Employed',
                                '$employed',
                                Icons.work,
                                Colors.green,
                                cardWidth,
                              ),
                              _buildSummaryCard(
                                'Unemployed',
                                '$unemployed',
                                Icons.person_off,
                                Colors.red,
                                cardWidth,
                              ),
                              _buildSummaryCard(
                                'Rate',
                                '$rate%',
                                Icons.trending_up,
                                accentGold,
                                cardWidth,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildChartContainer(
                        title: 'Employment Status Distribution',
                        child: _buildBarChart(_countBy('employment_status')),
                        height: 340,
                      ),
                      const SizedBox(height: 24),
                      if (isNarrow)
                        Column(
                          children: [
                            _buildChartContainer(
                              title: 'Industry Distribution',
                              child: _buildPieChart(_countBy('sector')),
                              height: 340,
                            ),
                            const SizedBox(height: 24),
                            _buildChartContainer(
                              title: 'Salary Distribution (PHP)',
                              child: _buildBarChart(_countBy('monthly_income')),
                              height: 340,
                            ),
                          ],
                        )
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildChartContainer(
                                title: 'Industry Distribution',
                                child: _buildPieChart(_countBy('sector')),
                                height: 340,
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _buildChartContainer(
                                title: 'Salary Distribution (PHP)',
                                child: _buildBarChart(
                                  _countBy('monthly_income'),
                                ),
                                height: 340,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 24),
                      if (isNarrow)
                        Column(
                          children: [
                            _buildChartContainer(
                              title: 'Job Relevance',
                              child: _buildPieChart(_countBy('related_job')),
                              height: 340,
                            ),
                            const SizedBox(height: 24),
                            _buildChartContainer(
                              title: 'Report Highlights',
                              child: _buildHighlights(),
                              height: 340,
                            ),
                          ],
                        )
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildChartContainer(
                                title: 'Job Relevance',
                                child: _buildPieChart(_countBy('related_job')),
                                height: 340,
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _buildChartContainer(
                                title: 'Report Highlights',
                                child: _buildHighlights(),
                                height: 340,
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

  Widget _buildFilterSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.filter_alt_outlined, color: accentGold),
          ),
          if (_assignedProgram == null)
            _buildDropdown('Program', selectedProgram, _programOptions, (v) {
              if (v == null) return;
              setState(() {
                selectedProgram = v;
                selectedBatch = 'All Batches';
                selectedStatus = 'All Status';
              });
              _loadFilterOptions();
              _fetchReports();
            })
          else
            _buildLockedProgramBadge(),
          _buildDropdown('Batch', selectedBatch, _batchOptions, (v) {
            if (v == null) return;
            setState(() {
              selectedBatch = v;
              _applyFilters();
            });
          }),
          _buildDropdown(
            'Status',
            selectedStatus,
            _statusOptions,
            (v) {
              if (v == null) return;
              setState(() {
                selectedStatus = v;
                _applyFilters();
              });
            },
          ),
          FilledButton.icon(
            onPressed: _rows.isEmpty ? null : _exportCsv,
            icon: const Icon(Icons.table_view_outlined),
            label: const Text('Export CSV'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: primaryMaroon,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedProgramBadge() {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Program',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline, color: accentGold, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _assignedProgram ?? selectedProgram,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              isExpanded: true,
              isDense: true,
              underline: const SizedBox(),
              items: items
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String label,
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
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartContainer({
    required String title,
    required Widget child,
    required double height,
  }) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
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
          const SizedBox(height: 20),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildBarChart(Map<String, int> counts) {
    final entries = counts.entries.toList();
    if (entries.isEmpty) {
      return const Center(child: Text('No chart data available.'));
    }

    return BarChart(
      BarChartData(
        backgroundColor: Colors.transparent,
        alignment: BarChartAlignment.spaceAround,
        barGroups: [
          for (var i = 0; i < entries.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entries[i].value.toDouble(),
                  color: i.isEven ? primaryMaroon : accentGold,
                  width: 20,
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 32),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= entries.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _shortLabel(entries[index].key),
                    style: const TextStyle(fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _buildPieChart(Map<String, int> counts) {
    final entries = counts.entries.toList();
    if (entries.isEmpty) {
      return const Center(child: Text('No chart data available.'));
    }

    final colors = [
      primaryMaroon,
      accentGold,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.grey,
    ];

    return PieChart(
      PieChartData(
        sections: [
          for (var i = 0; i < entries.length; i++)
            PieChartSectionData(
              value: entries[i].value.toDouble(),
              color: colors[i % colors.length],
              title: entries[i].key.length > 12
                  ? '${entries[i].key.substring(0, 12)}...'
                  : entries[i].key,
              radius: 50,
              titleStyle: const TextStyle(color: Colors.white, fontSize: 10),
            ),
        ],
      ),
    );
  }

  Widget _buildHighlights() {
    final findings = ((_report['findings'] ?? []) as List)
        .map((item) => item.toString())
        .take(4)
        .toList();

    if (findings.isEmpty) {
      return const Center(child: Text('No report highlights available.'));
    }

    return ListView.separated(
      itemCount: findings.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(findings[index], style: const TextStyle(height: 1.45)),
      ),
    );
  }

  String _shortLabel(String value) {
    final trimmed = value.trim();
    if (trimmed.length <= 14) return trimmed;
    return '${trimmed.substring(0, 14)}...';
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  List<List<String>> _buildCareerReportExportRows() {
    final kpis = _report['kpis'] is Map
        ? Map<String, dynamic>.from(_report['kpis'] as Map)
        : <String, dynamic>{};
    final summaryRows = [
      ['Generated On', DateTime.now().toIso8601String(), '', '', '', '', ''],
      ['Program Filter', selectedProgram, '', '', '', '', ''],
      ['Batch Filter', selectedBatch, '', '', '', '', ''],
      ['Status Filter', selectedStatus, '', '', '', '', ''],
      [
        'Employment Rate',
        '${_toDouble(kpis['employment_rate']).toStringAsFixed(1)}%',
        '',
        '',
        '',
        '',
        '',
      ],
      [
        'Job Relevance',
        '${_toDouble(kpis['job_relevance_rate']).toStringAsFixed(1)}%',
        '',
        '',
        '',
        '',
        '',
      ],
      [
        'Filtered Rows',
        _rows.length.toString(),
        '',
        '',
        '',
        '',
        '',
      ],
      ['', '', '', '', '', '', ''],
    ];

    final dataRows = _rows
        .map(
          (row) => [
            (row['name'] ?? row['full_name'] ?? 'N/A').toString(),
            (row['program'] ?? selectedProgram).toString(),
            (row['year_graduated'] ?? 'N/A').toString(),
            (row['employment_status'] ?? 'N/A').toString(),
            (row['sector'] ?? 'N/A').toString(),
            (row['monthly_income'] ?? 'N/A').toString(),
            (row['related_job'] ?? row['job_related'] ?? 'N/A').toString(),
          ],
        )
        .toList();

    return [...summaryRows, ...dataRows];
  }

  Future<void> _exportCsv() async {
    try {
      final path = await CsvExportService.exportRows(
        filename:
            'career_reports_${DateTime.now().millisecondsSinceEpoch}.csv',
        headers: const [
          'Name',
          'Program',
          'Year Graduated',
          'Employment Status',
          'Sector',
          'Monthly Income',
          'Related Job',
        ],
        rows: _buildCareerReportExportRows(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV exported: $path'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to export CSV.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
