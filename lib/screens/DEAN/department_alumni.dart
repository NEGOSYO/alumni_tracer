import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../services/api_service.dart';
import '../../services/csv_export_service.dart';
import '../../services/filter_options_service.dart';
import '../../state/user_store.dart';

class DepartmentAlumniPage extends StatefulWidget {
  const DepartmentAlumniPage({super.key});

  @override
  State<DepartmentAlumniPage> createState() => _DepartmentAlumniPageState();
}

class _DepartmentAlumniPageState extends State<DepartmentAlumniPage> {
  final Color primaryMaroon = const Color(0xFF4A152C);
  final Color bgLight = const Color(0xFFF7F8FA);
  final Color accentGold = const Color(0xFFC5A046);
  final Color borderColor = const Color(0xFFE5E7EB);

  String selectedProgram = "BSIT";
  String selectedBatch = "All Batches";
  String selectedStatus = "All Status";
  String? _assignedProgram;
  List<String> _programOptions = const ['BSIT', 'BSSW'];
  List<String> _batchOptions = const ['All Batches'];
  List<String> _statusOptions = const ['All Status'];

  List<dynamic> _filteredAlumni = [];
  Map<String, dynamic> _summary = {
    "total_graduates": 0,
    "employed": 0,
    "employment_rate": "0%",
    "job_alignment": "0%",
  };
  bool _isLoading = true;
  bool _isExportingReport = false;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _assignedProgram = _normalizeProgram(UserStore.value?['program']);
    selectedProgram = _assignedProgram ?? selectedProgram;
    _programOptions = _assignedProgram == null
        ? const ['BSIT', 'BSSW']
        : [_assignedProgram!];
    _loadFilterOptions();
    _fetchAlumniData();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _fetchAlumniData(showLoader: false),
    );
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
            : [_assignedProgram!];
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
      // Preserve the current fallback values if backend options are unavailable.
    }
  }

  Future<void> _fetchAlumniData({bool showLoader = true}) async {
    if (showLoader) setState(() => _isLoading = true);
    try {
      final response = await http.get(
        ApiService.uri(
          'get_department_alumni.php',
          queryParameters: {
            'program': selectedProgram,
            'batch': selectedBatch == 'All Batches' ? '' : selectedBatch,
            'status': selectedStatus,
          },
        ),
        headers: ApiService.authHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (!mounted) return;
        setState(() {
          _filteredAlumni = data['alumni'];
          _summary = data['summary'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to connect to server")),
      );
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  List<List<String>> _buildDepartmentExportRows() {
    final summaryRows = [
      ['Generated On', _formatReportDate(DateTime.now()), '', '', ''],
      ['Program Filter', selectedProgram, '', '', ''],
      ['Batch Filter', selectedBatch, '', '', ''],
      ['Status Filter', selectedStatus, '', '', ''],
      ['Total Graduates', '${_summary['total_graduates'] ?? 0}', '', '', ''],
      ['Employment Rate', '${_summary['employment_rate'] ?? '0%'}', '', '', ''],
      ['Job Alignment', '${_summary['job_alignment'] ?? '0%'}', '', '', ''],
      ['', '', '', '', ''],
    ];

    final dataRows = _filteredAlumni
        .map(
          (alumni) => [
            (alumni['name'] ?? 'N/A').toString(),
            (alumni['year'] ?? 'N/A').toString(),
            (alumni['status'] ?? 'N/A').toString(),
            (alumni['company'] ?? 'N/A').toString(),
            alumni['alignment'] == true ? 'Aligned' : 'Review Needed',
          ],
        )
        .toList();

    return [...summaryRows, ...dataRows];
  }

  Future<void> _downloadAccreditationReport() async {
    if (_isExportingReport) return;

    setState(() => _isExportingReport = true);
    try {
      final pdf = pw.Document();
      final generatedOn = DateTime.now();

      pdf.addPage(
        pw.MultiPage(
          pageTheme: const pw.PageTheme(margin: pw.EdgeInsets.all(32)),
          build: (context) {
            return [
              pw.Container(
                padding: const pw.EdgeInsets.all(18),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#4A152C'),
                  borderRadius: pw.BorderRadius.circular(14),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Department Accreditation Report',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Program: $selectedProgram',
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 12,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Batch Filter: $selectedBatch | Status Filter: $selectedStatus',
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 11,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Generated on ${_formatReportDate(generatedOn)}',
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 18),
              pw.Text(
                'Summary Metrics',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 16,
                  color: PdfColor.fromHex('#4A152C'),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColor.fromHex('#D7D7D7')),
                children: [
                  _pdfRow(['Metric', 'Value'], isHeader: true),
                  _pdfRow([
                    'Total Graduates',
                    '${_summary['total_graduates'] ?? 0}',
                  ]),
                  _pdfRow(['Employed', '${_summary['employed'] ?? 0}']),
                  _pdfRow([
                    'Employment Rate',
                    '${_summary['employment_rate'] ?? '0%'}',
                  ]),
                  _pdfRow([
                    'Job Alignment',
                    '${_summary['job_alignment'] ?? '0%'}',
                  ]),
                ],
              ),
              pw.SizedBox(height: 18),
              pw.Text(
                'Current Export Scope',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 16,
                  color: PdfColor.fromHex('#4A152C'),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColor.fromHex('#D7D7D7')),
                children: [
                  _pdfRow(['Filter', 'Value'], isHeader: true),
                  _pdfRow(['Program', selectedProgram]),
                  _pdfRow(['Batch', selectedBatch]),
                  _pdfRow(['Status', selectedStatus]),
                  _pdfRow(['Included Records', '${_filteredAlumni.length}']),
                ],
              ),
              pw.SizedBox(height: 18),
              pw.Text(
                'Accreditation Notes',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 16,
                  color: PdfColor.fromHex('#4A152C'),
                ),
              ),
              pw.SizedBox(height: 8),
              ..._pdfBulletList([
                'The current $selectedProgram alumni data supports department-level accreditation review and graduate outcome monitoring.',
                'Employment rate and job alignment indicators provide evidence for curriculum relevance and employability.',
                'The filtered alumni list below can be used as a reference for program-level validation and supporting documentation.',
              ]),
              pw.SizedBox(height: 18),
              pw.Text(
                'Filtered Alumni Records',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 16,
                  color: PdfColor.fromHex('#4A152C'),
                ),
              ),
              pw.SizedBox(height: 10),
              _filteredAlumni.isEmpty
                  ? pw.Text(
                      'No alumni records found for the current filter selection.',
                    )
                  : pw.Table(
                      border: pw.TableBorder.all(
                        color: PdfColor.fromHex('#D7D7D7'),
                      ),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(2.3),
                        1: const pw.FlexColumnWidth(0.9),
                        2: const pw.FlexColumnWidth(1.3),
                        3: const pw.FlexColumnWidth(2),
                        4: const pw.FlexColumnWidth(1.2),
                      },
                      children: [
                        _pdfRow([
                          'Name',
                          'Year',
                          'Status',
                          'Company',
                          'Alignment',
                        ], isHeader: true),
                        ..._filteredAlumni.map((alumni) {
                          final alignment = alumni['alignment'] == true
                              ? 'Aligned'
                              : 'Review Needed';
                          return _pdfRow([
                            (alumni['name'] ?? 'N/A').toString(),
                            (alumni['year'] ?? 'N/A').toString(),
                            (alumni['status'] ?? 'N/A').toString(),
                            (alumni['company'] ?? 'N/A').toString(),
                            alignment,
                          ]);
                        }),
                      ],
                    ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      final filename =
          '${selectedProgram.toLowerCase()}_accreditation_report_${generatedOn.millisecondsSinceEpoch}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: filename);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Accreditation report ready: $filename'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export accreditation report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExportingReport = false);
      }
    }
  }

  pw.TableRow _pdfRow(List<String> values, {bool isHeader = false}) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: isHeader ? PdfColor.fromHex('#F3E9ED') : PdfColors.white,
      ),
      children: values
          .map(
            (value) => pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: isHeader ? pw.FontWeight.bold : null,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  List<pw.Widget> _pdfBulletList(List<String> items) {
    return items
        .map(
          (item) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '- ',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Expanded(
                  child: pw.Text(
                    item,
                    style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }

  String _formatReportDate(DateTime date) {
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _exportCsv() async {
    try {
      final path = await CsvExportService.exportRows(
        filename:
            'department_alumni_${DateTime.now().millisecondsSinceEpoch}.csv',
        headers: const ['Name', 'Year', 'Status', 'Company', 'Alignment'],
        rows: _buildDepartmentExportRows(),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFFF7F1E7), bgLight, Colors.white],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = constraints.maxWidth;
          final isCompact = contentWidth < 640;
          final isHeroStacked = contentWidth < 900;
          final horizontalPadding = isCompact ? 16.0 : 32.0;
          final tableHeight = isCompact ? 420.0 : 520.0;

          return ListView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              isCompact ? 16 : 32,
              horizontalPadding,
              isCompact ? 16 : 32,
            ),
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
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Dean Analytics',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Department Alumni Analysis",
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Supporting accreditation and program monitoring for $selectedProgram with a clearer view of graduate outcomes.",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.82),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _isLoading || _isExportingReport
                                      ? null
                                      : _downloadAccreditationReport,
                                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                                  label: Text(
                                    _isExportingReport
                                        ? "Preparing Report..."
                                        : "Export Accreditation Report",
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(0, 52),
                                    side: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.30),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _filteredAlumni.isEmpty ? null : _exportCsv,
                                  icon: const Icon(Icons.table_view_outlined, size: 18),
                                  label: const Text("Export CSV"),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(0, 52),
                                    side: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.30),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
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
                                    'Dean Analytics',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  "Department Alumni Analysis",
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Supporting accreditation and program monitoring for $selectedProgram with a clearer view of graduate outcomes.",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.82),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _isLoading || _isExportingReport
                                    ? null
                                    : _downloadAccreditationReport,
                                icon: const Icon(Icons.picture_as_pdf, size: 18),
                                label: Text(
                                  _isExportingReport
                                      ? "Preparing Report..."
                                      : "Export Accreditation Report",
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 52),
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.30),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _filteredAlumni.isEmpty ? null : _exportCsv,
                                icon: const Icon(Icons.table_view_outlined, size: 18),
                                label: const Text("Export CSV"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 52),
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.30),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildMetricCard(
                    "Total Graduates",
                    "${_summary['total_graduates']}",
                    Icons.people,
                    Colors.blue,
                    contentWidth,
                  ),
                  _buildMetricCard(
                    "Employed",
                    "${_summary['employed']}",
                    Icons.work,
                    Colors.green,
                    contentWidth,
                  ),
                  _buildMetricCard(
                    "Employment Rate",
                    "${_summary['employment_rate']}",
                    Icons.trending_up,
                    accentGold,
                    contentWidth,
                  ),
                  _buildMetricCard(
                    "Job Alignment",
                    "${_summary['job_alignment']}",
                    Icons.check_circle_outline,
                    Colors.purple,
                    contentWidth,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildFilterBar(),
              const SizedBox(height: 16),
              SizedBox(
                height: tableHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.035),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: primaryMaroon,
                          ),
                        )
                      : _filteredAlumni.isEmpty
                      ? const Center(child: Text("No records found."))
                      : _buildDataTable(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDataTable() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    const Color(0xFFF8F9FA),
                  ),
                  columns: const [
                    DataColumn(
                      label: Text(
                        "Name",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        "Year",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        "Status",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        "Company/Organization",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Center(
                        child: Text(
                          "Job Alignment",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                  rows: _filteredAlumni
                      .map(
                        (a) => DataRow(
                          cells: [
                            DataCell(
                              Text(
                                a['name'] ?? 'N/A',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            DataCell(Text(a['year'].toString())),
                            DataCell(_buildStatusBadge(a['status'] ?? 'N/A')),
                            DataCell(Text(a['company'] ?? 'N/A')),
                            DataCell(
                              Center(
                                child: Icon(
                                  a['alignment'] == true
                                      ? Icons.verified
                                      : Icons.help_outline,
                                  color: a['alignment'] == true
                                      ? Colors.green
                                      : Colors.grey,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterBar() {
    final isCompact = MediaQuery.of(context).size.width < 900;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (_assignedProgram == null)
            _buildDropdownFilter("Program", selectedProgram, _programOptions, (
              v,
            ) {
              setState(() {
                selectedProgram = v!;
                selectedBatch = 'All Batches';
              });
              _loadFilterOptions();
            })
          else
            _buildLockedProgramFilter(),
          _buildDropdownFilter(
            "Batch",
            selectedBatch,
            _batchOptions,
            (v) => setState(() => selectedBatch = v!),
          ),
          _buildDropdownFilter(
            "Status",
            selectedStatus,
            _statusOptions,
            (v) => setState(() => selectedStatus = v!),
          ),
          if (isCompact)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _fetchAlumniData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryMaroon,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text("Apply Filter"),
              ),
            )
          else
            ElevatedButton(
              onPressed: _fetchAlumniData,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryMaroon,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text("Apply Filter"),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
    double contentWidth,
  ) {
    final cardWidth = contentWidth >= 1180
        ? (contentWidth - 48) / 4
        : contentWidth >= 760
        ? (contentWidth - 16) / 2
        : double.infinity;
    return SizedBox(
      width: cardWidth,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
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
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownFilter(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: bgLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: DropdownButton<String>(
            value: items.contains(value) ? value : items.first,
            underline: const SizedBox(),
            isDense: true,
            items: items
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildLockedProgramFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Program',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: bgLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, color: accentGold, size: 18),
              const SizedBox(width: 10),
              Text(
                _assignedProgram ?? selectedProgram,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = status == "Employed"
        ? Colors.green
        : (status == "Unemployed" ? Colors.red : Colors.orange);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
