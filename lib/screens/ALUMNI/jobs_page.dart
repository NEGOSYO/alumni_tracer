import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/api_service.dart';
import '../../services/activity_service.dart';
import '../../services/content_service.dart';

class AlumniJobsPage extends StatefulWidget {
  final Map<String, dynamic> user;
  const AlumniJobsPage({super.key, required this.user});

  @override
  State<AlumniJobsPage> createState() => _AlumniJobsPageState();
}

class _AlumniJobsPageState extends State<AlumniJobsPage> {
  List<Map<String, dynamic>> jobs = [];
  List<Map<String, dynamic>> _applications = [];
  Set<int> _savedJobIds = <int>{};
  Set<int> _applyingJobIds = <int>{};
  bool isLoading = true;
  bool _isRefreshingMeta = false;
  final TextEditingController _searchController = TextEditingController();
  String _selectedLocation = 'All Locations';
  String _selectedSort = 'Newest';

  final Color primaryMaroon = const Color(0xFF4A152C);
  final Color accentGold = const Color(0xFFC5A046);
  final Color bgLight = const Color(0xFFF7F8FA);
  final Color cardBorder = const Color(0xFFE5E7EB);
  final Color softRose = const Color(0xFFF8F1F4);

  @override
  void initState() {
    super.initState();
    fetchJobs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchJobs() async {
    try {
      final fetchedJobs = await ContentService.fetchJobs().timeout(
        const Duration(seconds: 10),
      );
      await _loadJobMeta();
      if (!mounted) return;
      setState(() {
        jobs = fetchedJobs;
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to fetch jobs. Check your connection.'),
        ),
      );
    }
  }

  Future<void> _loadJobMeta() async {
    if (_isRefreshingMeta) return;
    _isRefreshingMeta = true;
    try {
      final userId = '${widget.user['id'] ?? ''}';
      if (userId.isEmpty) return;

      final responses = await Future.wait([
        http.get(
          ApiService.uri(
            'get_saved_jobs.php',
            queryParameters: {'user_id': userId},
          ),
        ),
        http.get(
          ApiService.uri(
            'get_job_applications.php',
            queryParameters: {'user_id': userId},
          ),
        ),
      ]);

      final savedPayload = jsonDecode(responses[0].body);
      final applicationsPayload = jsonDecode(responses[1].body);

      final savedList = savedPayload is Map
          ? (savedPayload['saved_jobs'] as List? ?? const [])
          : const [];
      final applicationList = applicationsPayload is Map
          ? (applicationsPayload['applications'] as List? ?? const [])
          : const [];

      if (!mounted) return;
      setState(() {
        _savedJobIds = savedList
            .whereType<Map>()
            .map((item) => int.tryParse('${item['job_id'] ?? ''}') ?? 0)
            .where((id) => id > 0)
            .toSet();
        _applications = applicationList
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      });
    } catch (_) {
      // Preserve current page behavior if saved/applied metadata fails to load.
    } finally {
      _isRefreshingMeta = false;
    }
  }

  List<String> get _locationOptions {
    final values = jobs
        .map((job) => (job['location'] ?? '').toString().trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All Locations', ...values];
  }

  List<Map<String, dynamic>> get _filteredJobs {
    final query = _searchController.text.trim().toLowerCase();
    final appliedIds = _applications
        .map((item) => int.tryParse('${item['job_id'] ?? ''}') ?? 0)
        .where((id) => id > 0)
        .toSet();

    final filtered = jobs.where((job) {
      final title = (job['title'] ?? '').toString().toLowerCase();
      final company = (job['company'] ?? '').toString().toLowerCase();
      final location = (job['location'] ?? '').toString();

      final matchesQuery =
          query.isEmpty || title.contains(query) || company.contains(query);
      final matchesLocation =
          _selectedLocation == 'All Locations' || location == _selectedLocation;

      return matchesQuery && matchesLocation;
    }).toList();

    filtered.sort((a, b) {
      if (_selectedSort == 'Company') {
        return (a['company'] ?? '').toString().compareTo(
          (b['company'] ?? '').toString(),
        );
      }
      if (_selectedSort == 'Saved First') {
        final aSaved = _savedJobIds.contains(
          int.tryParse('${a['id'] ?? ''}') ?? -1,
        );
        final bSaved = _savedJobIds.contains(
          int.tryParse('${b['id'] ?? ''}') ?? -1,
        );
        if (aSaved != bSaved) {
          return aSaved ? -1 : 1;
        }
      }
      if (_selectedSort == 'Applied First') {
        final aApplied = appliedIds.contains(
          int.tryParse('${a['id'] ?? ''}') ?? -1,
        );
        final bApplied = appliedIds.contains(
          int.tryParse('${b['id'] ?? ''}') ?? -1,
        );
        if (aApplied != bApplied) {
          return aApplied ? -1 : 1;
        }
      }
      return (b['date_posted'] ?? '').toString().compareTo(
        (a['date_posted'] ?? '').toString(),
      );
    });

    return filtered;
  }

  List<Map<String, dynamic>> get _savedJobs {
    return jobs.where((job) {
      final id = int.tryParse('${job['id'] ?? ''}') ?? 0;
      return _savedJobIds.contains(id);
    }).toList();
  }

  Future<void> applyForJob(String jobId, String jobTitle) async {
    final parsedJobId = int.tryParse(jobId) ?? 0;
    if (parsedJobId <= 0 || _applyingJobIds.contains(parsedJobId)) {
      return;
    }

    setState(() {
      _applyingJobIds = {..._applyingJobIds, parsedJobId};
    });

    try {
      final url = ApiService.uri('apply_job.php');
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": widget.user['id'], "job_id": jobId}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['status'] == 'success') {
          final matchedJob = jobs.cast<Map<String, dynamic>?>().firstWhere(
            (job) => (int.tryParse('${job?['id'] ?? ''}') ?? 0) == parsedJobId,
            orElse: () => null,
          );
          final existingIndex = _applications.indexWhere(
            (item) => int.tryParse('${item['job_id'] ?? ''}') == parsedJobId,
          );
          if (existingIndex == -1 && mounted) {
            setState(() {
              _applications = [
                {
                  'job_id': parsedJobId,
                  'job_title': jobTitle,
                  'job_company': matchedJob?['company'] ?? 'Company',
                  'applied_at': DateTime.now().toIso8601String(),
                },
                ..._applications,
              ];
            });
          }
          await ActivityService.logImportantFlow(
            action: 'job_application',
            title:
                '${widget.user['name'] ?? 'An alumni'} applied for $jobTitle',
            type: 'Jobs',
            userId: int.tryParse((widget.user['id'] ?? '').toString()),
            userName: widget.user['name']?.toString(),
            userEmail: widget.user['email']?.toString(),
            role: widget.user['role']?.toString() ?? 'alumni',
            targetId: jobId,
            targetType: 'job',
            metadata: {'job_title': jobTitle},
          );
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['status'] == 'success'
                  ? 'Successfully applied for $jobTitle!'
                  : result['message'] ?? 'Application failed',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _applyingJobIds = {..._applyingJobIds}..remove(parsedJobId);
        });
      }
    }
  }

  Future<void> _toggleSavedJob(Map<String, dynamic> job) async {
    final jobId = '${job['id'] ?? ''}';
    if (jobId.isEmpty) return;

    try {
      final response = await http.post(
        ApiService.uri('toggle_saved_job.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": widget.user['id'],
          "job_id": jobId,
        }),
      );
      if (response.statusCode != 200) return;
      final result = jsonDecode(response.body);
      if (result is Map && result['status'] == 'success') {
        await _loadJobMeta();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${result['message'] ?? 'Saved jobs updated'}')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update saved jobs right now.')),
      );
    }
  }

  void _showJobDetails(Map<String, dynamic> job) {
    final screenWidth = MediaQuery.of(context).size.width;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: screenWidth < 700 ? screenWidth - 32 : 640,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 520;
                    if (isCompact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 54,
                                height: 54,
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
                                child: Icon(
                                  Icons.work_outline,
                                  color: accentGold,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            (job['title'] ?? "Job Details").toString(),
                            style: TextStyle(
                              fontSize: 22,
                              color: primaryMaroon,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            (job['company'] ?? "Company not specified")
                                .toString(),
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 54,
                          height: 54,
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
                          child: Icon(Icons.work_outline, color: accentGold),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (job['title'] ?? "Job Details").toString(),
                                style: TextStyle(
                                  fontSize: 24,
                                  color: primaryMaroon,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                (job['company'] ?? "Company not specified")
                                    .toString(),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _detailChip(
                      Icons.location_on_outlined,
                      job['location'],
                      Colors.blueGrey,
                    ),
                    _detailChip(
                      Icons.payments_outlined,
                      job['salary'],
                      accentGold,
                    ),
                    _detailChip(
                      Icons.calendar_today_outlined,
                      job['date_posted'],
                      Colors.teal,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _sectionTitle("Job Description"),
                const SizedBox(height: 8),
                Text(
                  (job['description'] ?? "No description available").toString(),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Colors.grey.shade800,
                  ),
                ),
                if (job['requirements'] != null &&
                    job['requirements'].toString().isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _sectionTitle("Requirements"),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: softRose,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      job['requirements'].toString(),
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _sectionTitle("Application Contact"),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Text(
                    "Contact: ${(job['contact_email'] ?? 'Not provided').toString()}",
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                  ),
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 520;
                    if (isCompact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              applyForJob(
                                job['id'].toString(),
                                (job['title'] ?? 'this job').toString(),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryMaroon,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.send_outlined, size: 18),
                            label: const Text("Apply Now"),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              "Close",
                              style: TextStyle(color: primaryMaroon),
                            ),
                          ),
                        ],
                      );
                    }
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            "Close",
                            style: TextStyle(color: primaryMaroon),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            applyForJob(
                              job['id'].toString(),
                              (job['title'] ?? 'this job').toString(),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryMaroon,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.send_outlined, size: 18),
                          label: const Text("Apply Now"),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailChip(IconData icon, dynamic value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            value?.toString().isNotEmpty == true
                ? value.toString()
                : "Not specified",
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: primaryMaroon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7F8FA), Color(0xFFF4F1F2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: isLoading
            ? Center(child: CircularProgressIndicator(color: primaryMaroon))
            : jobs.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
                color: primaryMaroon,
                onRefresh: fetchJobs,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  children: [
                    _buildHeroHeader(),
                    const SizedBox(height: 24),
                    _buildFilterBar(),
                    const SizedBox(height: 24),
                    _buildQuickStats(),
                    const SizedBox(height: 24),
                    if (_applications.isNotEmpty) ...[
                      _buildApplicationHistory(),
                      const SizedBox(height: 24),
                    ],
                    if (_savedJobs.isNotEmpty) ...[
                      _buildSavedJobsPreview(),
                      const SizedBox(height: 24),
                    ],
                    ..._filteredJobs.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: _buildJobCard(entry.value, entry.key),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeroHeader() {
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
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(Icons.cases_outlined, color: accentGold, size: 34),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Job Opportunities",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Explore curated job openings for alumni and apply directly through the portal.",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: fetchJobs,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.30)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text("Refresh"),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final withSalary = _filteredJobs
        .where((job) => (job['salary'] ?? '').toString().trim().isNotEmpty)
        .length;
    final withLocation = _filteredJobs
        .where((job) => (job['location'] ?? '').toString().trim().isNotEmpty)
        .length;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _statCard(
          "Open Roles",
          _filteredJobs.length.toString(),
          Icons.work_outline,
          primaryMaroon,
        ),
        _statCard(
          "Saved Jobs",
          _savedJobIds.length.toString(),
          Icons.bookmark_border,
          Colors.deepOrange,
        ),
        _statCard(
          "Applications",
          _applications.length.toString(),
          Icons.fact_check_outlined,
          Colors.indigo,
        ),
        _statCard(
          "With Salary Info",
          withSalary.toString(),
          Icons.payments_outlined,
          accentGold,
        ),
        _statCard(
          "With Location",
          withLocation.toString(),
          Icons.location_on_outlined,
          Colors.teal,
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: MediaQuery.of(context).size.width < 700 ? double.infinity : 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 280,
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search title or company...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: bgLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          _buildDropdownControl(
            value: _selectedLocation,
            items: _locationOptions,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedLocation = value);
            },
          ),
          _buildDropdownControl(
            value: _selectedSort,
            items: const ['Newest', 'Company', 'Saved First', 'Applied First'],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedSort = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownControl({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bgLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButton<String>(
        value: items.contains(value) ? value : items.first,
        underline: const SizedBox(),
        items: items
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildApplicationHistory() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Application History',
            style: TextStyle(
              color: primaryMaroon,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ..._applications.take(3).map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: primaryMaroon.withValues(alpha: 0.1),
                child: Icon(Icons.send_outlined, color: primaryMaroon),
              ),
              title: Text((item['job_title'] ?? 'Job').toString()),
              subtitle: Text(
                '${item['job_company'] ?? 'Company'} • ${item['applied_at'] ?? 'Recently'}',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedJobsPreview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saved Jobs',
            style: TextStyle(
              color: primaryMaroon,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ..._savedJobs.take(3).map(
            (job) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: accentGold.withValues(alpha: 0.18),
                child: Icon(Icons.bookmark, color: accentGold),
              ),
              title: Text((job['title'] ?? 'Job').toString()),
              subtitle: Text((job['company'] ?? 'Company').toString()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job, int index) {
    final title = (job['title'] ?? "No Title").toString();
    final company = (job['company'] ?? "Company not specified").toString();
    final description = (job['description'] ?? "No description").toString();
    final location = (job['location'] ?? "Location not specified").toString();
    final salary = (job['salary'] ?? "Salary not specified").toString();
    final datePosted = (job['date_posted'] ?? 'Recently').toString();
    final jobId = int.tryParse('${job['id'] ?? ''}') ?? 0;
    final isSaved = _savedJobIds.contains(jobId);
    final isApplying = _applyingJobIds.contains(jobId);
    final isApplied = _applications.any(
      (item) => int.tryParse('${item['job_id'] ?? ''}') == jobId,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showJobDetails(job),
        borderRadius: BorderRadius.circular(24),
        child: Ink(
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
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primaryMaroon.withValues(alpha: 0.95),
                            const Color(0xFF7B2E4B),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: Text(
                          company.isNotEmpty
                              ? company.substring(0, 1).toUpperCase()
                              : 'J',
                          style: TextStyle(
                            color: accentGold,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: primaryMaroon,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isApplied
                                      ? Colors.green.withValues(alpha: 0.14)
                                      : (isApplying
                                            ? Colors.blue.withValues(alpha: 0.14)
                                            : accentGold.withValues(alpha: 0.14)),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  isApplied
                                      ? "Applied"
                                      : (isApplying ? "Applying..." : "Apply Now"),
                                  style: TextStyle(
                                    color: isApplied
                                        ? Colors.green
                                        : (isApplying ? Colors.blue : primaryMaroon),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            company,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _metaPill(Icons.location_on_outlined, location),
                    _metaPill(Icons.payments_outlined, salary),
                    _metaPill(Icons.schedule_outlined, "Posted $datePosted"),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      "Opportunity ${index + 1}",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _showJobDetails(job),
                      child: Text(
                        "View details",
                        style: TextStyle(
                          color: primaryMaroon,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: isSaved ? 'Remove from saved jobs' : 'Save job',
                      onPressed: () => _toggleSavedJob(job),
                      icon: Icon(
                        isSaved ? Icons.bookmark : Icons.bookmark_border_outlined,
                        color: isSaved ? accentGold : primaryMaroon,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: isApplied || isApplying
                          ? null
                          : () => applyForJob(
                              job['id'].toString(),
                              (job['title'] ?? 'this job').toString(),
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryMaroon,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: Icon(
                        isApplied
                            ? Icons.check_circle_outline
                            : (isApplying
                                  ? Icons.hourglass_top_rounded
                                  : Icons.arrow_forward_rounded),
                        size: 18,
                      ),
                      label: Text(
                        isApplied
                            ? "Applied"
                            : (isApplying ? "Applying..." : "Apply"),
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

  Widget _metaPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: primaryMaroon),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width < 500
            ? MediaQuery.of(context).size.width - 32
            : 420,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: softRose,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                Icons.work_off_outlined,
                color: primaryMaroon,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              "No job opportunities available",
              style: TextStyle(
                color: primaryMaroon,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Check back later or refresh the page to see newly posted openings for alumni.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.5),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: fetchJobs,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryMaroon,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Refresh Jobs"),
            ),
          ],
        ),
      ),
    );
  }
}
