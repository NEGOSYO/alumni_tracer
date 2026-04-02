import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../services/csv_export_service.dart';
import '../../services/filter_options_service.dart';
import '../../services/signed_tracer_filter.dart';
import 'admin_accreditation_module.dart';

class TracerDataPage extends StatefulWidget {
  const TracerDataPage({super.key});

  @override
  State<TracerDataPage> createState() => _TracerDataPageState();
}

class _TracerDataPageState extends State<TracerDataPage> {
  final Color primaryMaroon = const Color(0xFF4A152C);
  final Color accentGold = const Color(0xFFC5A046);
  final Color bgLight = const Color(0xFFF8F9FA);
  final Color borderColor = const Color(0xFFE0E0E0);

  List<Map<String, dynamic>> _allData = [];
  List<Map<String, dynamic>> _filteredList = [];
  List<Map<String, dynamic>> _signedRecords = [];
  Map<String, dynamic>? _reportData;
  bool _isLoading = true;
  bool _isExportingPdf = false;
  String _generatedOn = '';
  String selectedStatus = "All Status";
  String selectedRelated = "All Degree Related";
  List<String> _statusOptions = const ['All Status'];
  List<String> _relatedOptions = const ['All Degree Related'];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
    _fetchTracerData();
  }

  Future<void> _loadFilterOptions() async {
    try {
      final options = await FilterOptionsService.fetch();
      if (!mounted) return;
      setState(() {
        _statusOptions = ['All Status', ...options.statuses];
        _relatedOptions = ['All Degree Related', ...options.relatedOptions];
        if (!_statusOptions.contains(selectedStatus)) {
          selectedStatus = _statusOptions.first;
        }
        if (!_relatedOptions.contains(selectedRelated)) {
          selectedRelated = _relatedOptions.first;
        }
      });
    } catch (_) {
      // Preserve existing fallback filters if the backend list is unavailable.
    }
  }

  Future<void> _fetchTracerData() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        ApiService.uri('get_tracer_submissions.php'),
        headers: ApiService.authHeaders(),
      );
      final reportResponse = await http.get(
        ApiService.uri('get_reports.php'),
        headers: ApiService.authHeaders(),
      );

      if (response.statusCode == 200 && reportResponse.statusCode == 200) {
        final decoded = json.decode(response.body);
        final reportDecoded = json.decode(reportResponse.body);
        final List<dynamic> jsonData = decoded is List
            ? decoded
            : (decoded is Map ? decoded['alumni'] ?? [] : []);
        final List<dynamic> signedRecordData = decoded is Map
            ? decoded['signed_records'] ?? []
            : [];
        final signedRecords = signedRecordData
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        final report = reportDecoded is Map
            ? Map<String, dynamic>.from(reportDecoded['report'] ?? const {})
            : <String, dynamic>{};
        setState(() {
          _allData = SignedTracerFilter.keepSignedOnly(
            jsonData.map((item) {
              final map = Map<String, dynamic>.from(item);
              map['full_name'] = map['full_name'] ?? map['name'] ?? 'N/A';
              map['job_related'] =
                  map['job_related'] ?? map['related_job'] ?? 'N/A';
              map['company_name'] =
                  map['company_name'] ?? map['employer'] ?? 'N/A';
              map['contact_number'] =
                  map['contact_number'] ?? map['contact'] ?? 'N/A';
              map['honors'] = map['honors'] ?? map['honors_awards'] ?? 'N/A';
              map['pre_grad_experience'] =
                  map['pre_grad_experience'] ?? map['pre_grad_exp'] ?? 'N/A';
              map['first_job_timing'] =
                  map['first_job_timing'] ?? map['time_to_first_job'] ?? 'N/A';
              map['employment_type'] =
                  map['employment_type'] ?? map['job_type'] ?? 'N/A';
              map['income_range'] =
                  map['income_range'] ?? map['monthly_income'] ?? 'N/A';
              map['not_related_reason'] =
                  map['not_related_reason'] ??
                  map['underutilized_reason'] ??
                  'N/A';
              map['job_duration'] =
                  map['job_duration'] ?? map['employment_duration'] ?? 'N/A';
              map['promotion'] = map['promotion'] ?? map['promoted'] ?? 'N/A';
              map['classification'] =
                  map['classification'] ??
                  map['employment_classification'] ??
                  'N/A';
              map['satisfaction'] =
                  map['satisfaction'] ?? map['job_satisfaction'] ?? 'N/A';
              map['submitted_at'] =
                  map['submitted_at'] ?? map['date_submitted'] ?? 'N/A';
              return map;
            }).toList(),
            signedRecords: signedRecords,
          );
          _filteredList = _allData;
          _signedRecords = signedRecords;
          _reportData = report;
          _generatedOn = reportDecoded is Map
              ? (reportDecoded['generated_on']?.toString() ?? '')
              : '';
          _isLoading = false;
        });
      } else {
        debugPrint(
          "HTTP Error: submissions=${response.statusCode}, reports=${reportResponse.statusCode}",
        );
        setState(() => _isLoading = false);
        _showErrorSnackBar("Failed to load accreditation data.");
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
      setState(() => _isLoading = false);
      _showErrorSnackBar("Error loading data: $e");
    }
  }

  void _runFilter() {
    setState(() {
      _filteredList = _allData.where((item) {
        final name = (item['full_name'] ?? "").toString().toLowerCase();
        final query = _searchController.text.toLowerCase();

        final matchesSearch = name.contains(query);
        final matchesStatus =
            selectedStatus == "All Status" ||
            item['employment_status'] == selectedStatus;
        final matchesRelated =
            selectedRelated == "All Degree Related" ||
            item['job_related'] == selectedRelated;

        return matchesSearch && matchesStatus && matchesRelated;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 600 ? 16.0 : 32.0;
    final isCompact = screenWidth < 700;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFFF7F1E7), bgLight, Colors.white],
        ),
      ),
      width: double.infinity,
      child: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryMaroon))
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                24,
                horizontalPadding,
                32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
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
                          color: primaryMaroon.withValues(alpha: 0.17),
                          blurRadius: 26,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Wrap(
                      spacing: 18,
                      runSpacing: 18,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: isCompact ? double.infinity : 620,
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
                                  'Admin Oversight',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Tracer Governance & Report Oversight',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Review signed tracer records, validate institutional data quality, and manage accreditation-ready reporting in one workspace.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _buildHeroChip(
                              Icons.fact_check_outlined,
                              '${_signedRecords.length} signed records',
                            ),
                            _buildHeroChip(
                              Icons.assignment_turned_in_outlined,
                              '${_allData.length} validated responses',
                            ),
                            FilledButton.icon(
                              onPressed: _isExportingPdf
                                  ? null
                                  : _downloadAccreditationReport,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: primaryMaroon,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.picture_as_pdf_outlined),
                              label: Text(
                                _isExportingPdf
                                    ? 'Preparing PDF...'
                                    : 'Generate Report',
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _filteredList.isEmpty
                                  ? null
                                  : _exportCsv,
                              style: FilledButton.styleFrom(
                                backgroundColor: accentGold,
                                foregroundColor: primaryMaroon,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.table_view_outlined),
                              label: const Text('Export CSV'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildAnalyticsCards(),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: accentGold.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.filter_alt_outlined,
                                color: accentGold,
                              ),
                            ),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tracer Response Explorer',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Search responses, review employment outcomes, and open complete tracer details.',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _buildFilterAndSearchBar(),
                        const SizedBox(height: 18),
                        _buildResponsiveTracerTable(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  AdminAccreditationModule(
                    reportData: _reportData,
                    onGenerateReport: _downloadAccreditationReport,
                    totalResponses: _allData.length,
                    employedCount: _employmentCount("Employed"),
                    selfEmployedCount: _employmentCount("Self-Employed"),
                    unemployedCount: _employmentCount("Unemployed"),
                  ),
                  const SizedBox(height: 24),
                  _buildSignedSubmissionSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildSignedSubmissionSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryMaroon.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.fact_check_outlined, color: primaryMaroon),
              ),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Signed Tracer Submission Records',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Separate signed submissions are preserved here for admin review and PDF download.',
                    style: TextStyle(color: Colors.black54, height: 1.4),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_signedRecords.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: bgLight,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'No signed tracer submissions are available yet.',
              ),
            )
          else
            Column(
              children: _signedRecords
                  .map((record) => _buildSignedRecordCard(record))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accentGold),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignedRecordCard(Map<String, dynamic> record) {
    final referenceId = (record['reference_id'] ?? '').toString();
    final fullName = (record['full_name'] ?? record['name'] ?? 'Unknown Alumni')
        .toString();
    final program = (record['program'] ?? 'N/A').toString();
    final signedAt =
        (record['submission_timestamp'] ?? record['signed_at'] ?? 'N/A')
            .toString();
    final agreementVersion = (record['agreement_version'] ?? 'N/A').toString();
    final pdfUrl = (record['pdf_download_url'] ?? '').toString();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 760;
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: bgLight,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              SizedBox(
                width: isCompact ? double.infinity : 420,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Reference ID: $referenceId',
                      style: TextStyle(
                        color: primaryMaroon,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Program: $program | Signed: $signedAt | Agreement: $agreementVersion',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: isCompact ? double.infinity : null,
                child: FilledButton.icon(
                  onPressed: pdfUrl.isEmpty
                      ? null
                      : () => _openDownload(pdfUrl),
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryMaroon,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Download PDF'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openDownload(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showErrorSnackBar('The download link is invalid.');
      return;
    }

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_blank',
    );
    if (!launched) {
      _showErrorSnackBar('Unable to open the signed submission PDF.');
    }
  }

  // ignore: unused_element
  Widget _buildAnalyticsCards() {
    int total = _allData.length;
    int employed = _allData
        .where((e) => e['employment_status'] == "Employed")
        .length;
    int selfEmployed = _allData
        .where((e) => e['employment_status'] == "Self-Employed")
        .length;
    int unemployed = _allData
        .where((e) => e['employment_status'] == "Unemployed")
        .length;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _statCard(
          "Total Responses",
          total.toString(),
          Icons.people,
          Colors.blue,
        ),
        _statCard("Employed", employed.toString(), Icons.work, Colors.green),
        _statCard(
          "Self-Employed",
          selfEmployed.toString(),
          Icons.storefront,
          Colors.purple,
        ),
        _statCard(
          "Unemployed",
          unemployed.toString(),
          Icons.person_off,
          Colors.red,
        ),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return SizedBox(
      width: 240,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildFilterAndSearchBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 760;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: isCompact ? constraints.maxWidth : 420,
              child: TextField(
                controller: _searchController,
                onChanged: (val) => _runFilter(),
                decoration: InputDecoration(
                  hintText: "Search alumni by name...",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: borderColor),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: isCompact ? constraints.maxWidth : null,
              child: _dropdown(
                "Status",
                selectedStatus,
                _statusOptions,
                (val) {
                  setState(() {
                    selectedStatus = val!;
                    _runFilter();
                  });
                },
              ),
            ),
            SizedBox(
              width: isCompact ? constraints.maxWidth : null,
              child: _dropdown(
                "Related",
                selectedRelated,
                _relatedOptions,
                (val) {
                  setState(() {
                    selectedRelated = val!;
                    _runFilter();
                  });
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _dropdown(
    String hint,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildTracerTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(bgLight),
        columns: const [
          DataColumn(label: Text("ALUMNI NAME")),
          DataColumn(label: Text("STATUS")),
          DataColumn(label: Text("JOB TITLE")),
          DataColumn(label: Text("RELATED")),
          DataColumn(label: Text("ACTION")),
        ],
        rows: _filteredList.map((data) {
          final isUnemployed = data['employment_status'] == "Unemployed";

          return DataRow(
            cells: [
              DataCell(
                Text(
                  data['full_name'] ?? "N/A",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataCell(_statusBadge(data['employment_status'] ?? "N/A")),

              // ✅ FIX: Hide job title if unemployed
              DataCell(Text(isUnemployed ? "—" : (data['job_title'] ?? "N/A"))),

              DataCell(Text(data['job_related'] ?? "N/A")),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.visibility, color: Colors.blue),
                  onPressed: () => _showTracerDetails(data),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildResponsiveTracerTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minTableWidth = constraints.maxWidth < 900
            ? 860.0
            : constraints.maxWidth;
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: minTableWidth),
              child: DataTable(
                columnSpacing: 28,
                headingRowColor: WidgetStateProperty.all(bgLight),
                columns: const [
                  DataColumn(label: Text("ALUMNI NAME")),
                  DataColumn(label: Text("STATUS")),
                  DataColumn(label: Text("JOB TITLE")),
                  DataColumn(label: Text("RELATED")),
                  DataColumn(label: Text("ACTION")),
                ],
                rows: _filteredList.map((data) {
                  final isUnemployed =
                      data['employment_status'] == "Unemployed";

                  return DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 220,
                          child: Text(
                            data['full_name'] ?? "N/A",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        _statusBadge(data['employment_status'] ?? "N/A"),
                      ),
                      DataCell(
                        SizedBox(
                          width: 220,
                          child: Text(
                            isUnemployed ? "-" : (data['job_title'] ?? "N/A"),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(data['job_related'] ?? "N/A")),
                      DataCell(
                        IconButton(
                          icon: const Icon(
                            Icons.visibility,
                            color: Colors.blue,
                          ),
                          onPressed: () => _showTracerDetails(data),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _statusBadge(String status) {
    Color color = Colors.grey;
    if (status == "Employed") color = Colors.green;
    if (status == "Self-Employed") color = Colors.purple;
    if (status == "Unemployed") color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  List<List<String>> _buildTracerExportRows() {
    final generatedOn = _generatedOn.isNotEmpty
        ? _generatedOn
        : _formatReportDate(DateTime.now());
    final summary = [
      ['Generated On', generatedOn, '', '', '', ''],
      ['Status Filter', selectedStatus, '', '', '', ''],
      ['Degree Related Filter', selectedRelated, '', '', '', ''],
      ['Filtered Responses', _filteredList.length.toString(), '', '', '', ''],
      ['Signed Records', _signedRecords.length.toString(), '', '', '', ''],
      ['', '', '', '', '', ''],
    ];

    final rows = _filteredList
        .map(
          (data) => [
            (data['full_name'] ?? 'N/A').toString(),
            (data['employment_status'] ?? 'N/A').toString(),
            (data['program'] ?? 'N/A').toString(),
            (data['company_name'] ?? 'N/A').toString(),
            (data['job_related'] ?? 'N/A').toString(),
            (data['submitted_at'] ?? 'N/A').toString(),
          ],
        )
        .toList();

    return [...summary, ...rows];
  }

  Future<void> _exportCsv() async {
    try {
      final path = await CsvExportService.exportRows(
        filename:
            'tracer_responses_${DateTime.now().millisecondsSinceEpoch}.csv',
        headers: const [
          'Alumni Name',
          'Employment Status',
          'Program',
          'Company',
          'Degree Related',
          'Submitted At',
        ],
        rows: _buildTracerExportRows(),
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
      _showErrorSnackBar('Failed to export CSV.');
    }
  }

  Future<void> _downloadAccreditationReport() async {
    if (_isExportingPdf) return;

    setState(() => _isExportingPdf = true);
    final report = _reportData ?? const <String, dynamic>{};
    final kpis = _asMap(report['kpis']);
    final comparison = _asMap(report['comparison']);
    final bsit = _asMap(comparison['bsit']);
    final bssw = _asMap(comparison['bssw']);
    final findings = _asStringList(report['findings']);
    final actions = _asStringList(report['actions']);
    final generatedOn = _generatedOn.isNotEmpty
        ? _generatedOn
        : _formatReportDate(DateTime.now());

    final employmentRate = _asDouble(kpis['employment_rate']);
    final relevanceRate = _asDouble(kpis['job_relevance_rate']);
    final skillsAverage = _asDouble(kpis['skills_utilization']);
    final peoAverage = _asDouble(kpis['peo_average']);
    final total = _asInt(kpis['total_responses']);
    final filteredCount = _filteredList.length;
    final filterSummaryRows = [
      ['Generated On', generatedOn],
      ['Status Filter', selectedStatus],
      ['Degree Related Filter', selectedRelated],
      ['Filtered Response Count', '$filteredCount'],
      ['Signed Record Count', '${_signedRecords.length}'],
    ];
    final filteredSnapshot = _filteredList.take(10).map((data) {
      return [
        (data['full_name'] ?? 'N/A').toString(),
        (data['employment_status'] ?? 'N/A').toString(),
        (data['program'] ?? 'N/A').toString(),
        (data['company_name'] ?? 'N/A').toString(),
      ];
    }).toList();

    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            margin: const pw.EdgeInsets.all(32),
            theme: pw.ThemeData.withFont(
              base: await PdfGoogleFonts.openSansRegular(),
              bold: await PdfGoogleFonts.openSansBold(),
            ),
          ),
          build: (context) => [
            pw.Container(
              padding: const pw.EdgeInsets.all(18),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#4A152C'),
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Accreditation Tracer Report',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Generated on $generatedOn',
                    style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 11,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'This report summarizes graduate employability, curriculum relevance, PEO attainment, side-by-side program comparison, and recommended improvement actions for accreditation use.',
                    style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 11,
                      lineSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Top 5 KPIs',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 16,
                color: PdfColor.fromHex('#4A152C'),
              ),
            ),
            pw.SizedBox(height: 10),
            _pdfMetricTable([
              ['Employment Rate', '${employmentRate.toStringAsFixed(1)}%'],
              ['Job Relevance', '${relevanceRate.toStringAsFixed(1)}%'],
              ['Skills Utilization', '${skillsAverage.toStringAsFixed(1)}/5'],
              ['PEO Attainment', '${peoAverage.toStringAsFixed(1)}/5'],
              ['Total Tracer Responses', '$total'],
            ]),
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
            _pdfMetricTable(filterSummaryRows),
            pw.SizedBox(height: 18),
            pw.Text(
              'Program Comparison',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 16,
                color: PdfColor.fromHex('#4A152C'),
              ),
            ),
            pw.SizedBox(height: 10),
            _pdfMetricTable([
              ['Metric', 'BSIT', 'BSSW'],
              [
                'Employment',
                _asString(bsit['employment']),
                _asString(bssw['employment']),
              ],
              [
                'Job Relevance',
                _asString(bsit['relevance']),
                _asString(bssw['relevance']),
              ],
              [
                'Skills Utilization',
                _asString(bsit['skills']),
                _asString(bssw['skills']),
              ],
              [
                'PEO Attainment',
                _asString(bsit['peo']),
                _asString(bssw['peo']),
              ],
              [
                'Career Growth',
                _asString(bsit['growth']),
                _asString(bssw['growth']),
              ],
            ], header: true),
            pw.SizedBox(height: 18),
            pw.Text(
              'Key Findings',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 16,
                color: PdfColor.fromHex('#4A152C'),
              ),
            ),
            pw.SizedBox(height: 8),
            ..._pdfBulletList(
              findings.isNotEmpty
                  ? findings
                  : [
                      'Employment rate is ${employmentRate.toStringAsFixed(1)}%, providing direct evidence of graduate employability.',
                      'Job relevance is ${relevanceRate.toStringAsFixed(1)}%, supporting curriculum and labor market alignment.',
                      'Average skills utilization is ${skillsAverage.toStringAsFixed(1)}/5, showing how much alumni use college-acquired skills at work.',
                      'Average PEO attainment is ${peoAverage.toStringAsFixed(1)}/5, which can be used as outcomes-based compliance evidence.',
                      'BSIT and BSSW comparison provides accreditation-ready program analysis instead of isolated statistics.',
                    ],
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              'Institutional Impact',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 16,
                color: PdfColor.fromHex('#4A152C'),
              ),
            ),
            pw.SizedBox(height: 8),
            ..._pdfBulletList([
              'The tracer results indicate how the institution contributes to graduate readiness for employment, professional practice, and long-term career growth.',
              'Employment, job relevance, and skills utilization metrics show the extent to which the curriculum, faculty guidance, and practicum experiences translate into workplace competence.',
              'PEO attainment evidence demonstrates whether the academic program is achieving its intended educational objectives among graduates.',
              'Program comparison data helps the school identify which interventions are working well in BSIT and BSSW and where targeted improvement is still needed.',
              'These findings support continuous quality assurance by linking graduate outcomes to curriculum review, partnerships, student support services, and accreditation action planning.',
            ]),
            pw.SizedBox(height: 18),
            pw.Text(
              'Recommended Improvement Actions',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 16,
                color: PdfColor.fromHex('#4A152C'),
              ),
            ),
            pw.SizedBox(height: 8),
            ..._pdfBulletList(
              actions.isNotEmpty
                  ? actions
                  : [
                      'If job relevance is low, revise curriculum mapping and improve internship or employer matching.',
                      'If skills utilization is below target, strengthen practicum, laboratory, and field-based competency activities.',
                      'If a PEO average is weak, align the weakest PEO with course outcomes, assessment tools, and faculty interventions.',
                      'Track promotion, licensure, certification, and CPD more consistently to strengthen career growth evidence.',
                    ],
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              'Filtered Response Snapshot',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 16,
                color: PdfColor.fromHex('#4A152C'),
              ),
            ),
            pw.SizedBox(height: 10),
            filteredSnapshot.isEmpty
                ? pw.Text(
                    'No filtered tracer records are available for the current export scope.',
                    style: const pw.TextStyle(fontSize: 11),
                  )
                : _pdfMetricTable([
                    ['Alumni', 'Status', 'Program', 'Company'],
                    ...filteredSnapshot,
                  ], header: true),
          ],
        ),
      );

      final bytes = await pdf.save();
      final filename =
          'accreditation_tracer_report_${DateTime.now().millisecondsSinceEpoch}.pdf';

      await Printing.sharePdf(bytes: bytes, filename: filename);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF report ready: $filename'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Failed to generate PDF report: $e');
    } finally {
      if (mounted) {
        setState(() => _isExportingPdf = false);
      }
    }
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

  pw.Widget _pdfMetricTable(List<List<String>> rows, {bool header = false}) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColor.fromHex('#D7D7D7')),
      children: [
        for (var rowIndex = 0; rowIndex < rows.length; rowIndex++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: header && rowIndex == 0
                  ? PdfColor.fromHex('#F1E8D0')
                  : (rowIndex.isEven
                        ? PdfColors.white
                        : PdfColor.fromHex('#FAFAFA')),
            ),
            children: [
              for (final cell in rows[rowIndex])
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    cell,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: header && rowIndex == 0
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                    ),
                  ),
                ),
            ],
          ),
      ],
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
                pw.Text('• ', style: const pw.TextStyle(fontSize: 11)),
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

  int _employmentCount(String status) {
    return _allData
        .where((item) => item['employment_status']?.toString() == status)
        .length;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return <String, dynamic>{};
  }

  List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return const [];
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _asString(dynamic value, {String fallback = 'No data'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  void _showTracerDetails(Map<String, dynamic> data) {
    final isUnemployed = data['employment_status'] == "Unemployed";
    final isNotRelated = data['job_related']?.toString().toLowerCase() == "no";
    final isWantMoreHours =
        data['want_more_hours']?.toString().toLowerCase() == "yes";
    final careerTimeline = _decodeCareerTimeline(data['career_timeline']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Tracer Details: ${data['full_name'] ?? 'Unknown'}"),
        content: SizedBox(
          width: MediaQuery.of(context).size.width < 700
              ? MediaQuery.of(context).size.width - 48
              : 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailSection("Graduate Profile", [
                  _detailRow("Sex", data['sex']),
                  _detailRow("Age", data['age']),
                  _detailRow("Civil Status", data['civil_status']),
                  _detailRow("Contact", data['contact_number']),
                  _detailRow("Address", data['address']),
                  _detailRow("Year Graduated", data['year_graduated']),
                  _detailRow("Honors / Awards", data['honors']),
                  _detailRow(
                    "Pre-graduation Experience",
                    data['pre_grad_experience'],
                  ),
                  _detailRow("Study Mode", data['study_mode']),
                ]),

                const Divider(height: 32),

                _detailSection("Employment Info", [
                  _detailRow("Status", data['employment_status']),

                  if (!isUnemployed) ...[
                    _detailRow(
                      "Time to First Employment",
                      data['first_job_timing'],
                    ),
                    _detailRow(
                      "First Job Related to Degree",
                      data['first_job_related'],
                    ),
                    _detailRow("Employment Type", data['employment_type']),
                    _detailRow("Job Title", data['job_title']),
                    _detailRow("Company/Organization", data['company_name']),
                    _detailRow("Sector", data['sector']),
                    _detailRow("Country of Work", data['country']),
                    _detailRow("Income", data['income_range']),
                    _detailRow("Related to Degree", data['job_related']),
                    if (isNotRelated)
                      _detailRow(
                        "Reason for working outside field",
                        data['not_related_reason'],
                      ),
                    _detailRow(
                      "How long in current position?",
                      data['job_duration'],
                    ),
                    _detailRow("Promoted since first job?", data['promotion']),
                    _detailRow(
                      "Would you like to work more hours?",
                      data['want_more_hours'],
                    ),

                    if (isWantMoreHours)
                      _detailRow(
                        "Reason for seeking more hours",
                        data['more_hours_reason'],
                      ),

                    _detailRow(
                      "Employment Classification",
                      data['classification'],
                    ),
                    _detailRow("Job Satisfaction", data['satisfaction']),
                  ],

                  if (isUnemployed)
                    _detailRow("Reason", data['unemployment_reason']),
                ]),

                if (careerTimeline.isNotEmpty) ...[
                  const Divider(height: 32),
                  _detailSection(
                    "Career Timeline",
                    careerTimeline.asMap().entries.map((entry) {
                      final item = entry.value;
                      final title =
                          item['position'] ?? item['job_title'] ?? 'Employment';
                      final employer =
                          item['employer'] ?? item['company'] ?? 'N/A';
                      final start = item['start_date'] ?? 'N/A';
                      final end =
                          (item['is_current'] == true ||
                              item['is_current'] == 'true')
                          ? 'Present'
                          : (item['end_date'] ?? 'N/A');
                      return _detailRow(
                        "Job ${entry.key + 1}",
                        "$title at $employer ($start - $end)",
                      );
                    }).toList(),
                  ),
                ],

                const Divider(height: 32),
                _detailRow("Submitted On", data['submitted_at']),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _detailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: primaryMaroon,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _detailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(
              value?.toString() ?? "N/A",
              style: TextStyle(color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _decodeCareerTimeline(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      } catch (_) {
        return [];
      }
    }

    return [];
  }
}
