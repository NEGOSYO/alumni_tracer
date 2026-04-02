import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/api_service.dart';

class JobsPage extends StatefulWidget {
  const JobsPage({super.key});

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  final Color primaryMaroon = const Color(0xFF4A152C);
  final Color accentGold = const Color(0xFFC5A046);
  final Color bgLight = const Color(0xFFF7F8FA);
  final Color borderColor = const Color(0xFFE5E7EB);
  final Color softRose = const Color(0xFFF8F1F4);

  bool isLoading = false;
  bool isSaving = false;
  List jobs = [];

  @override
  void initState() {
    super.initState();
    fetchJobs();
  }

  Future<void> fetchJobs() async {
    setState(() => isLoading = true);
    try {
      final url = ApiService.uri('get_jobs.php');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          jobs = data['jobs'] ?? [];
        });
      }
    } catch (e) {
      debugPrint("Error fetching jobs: $e");
    }
    setState(() => isLoading = false);
  }

  Future<bool> saveJob(
    String title,
    String description,
    String company,
    String location,
    String salary,
    String requirements,
    String contactEmail, {
    String? id,
  }) async {
    final url = ApiService.uri('add_job.php');

    setState(() => isSaving = true);

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id": id ?? "",
          "title": title,
          "description": description,
          "company": company,
          "location": location,
          "salary": salary,
          "requirements": requirements,
          "contact_email": contactEmail,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['status'] == 'success') {
          await fetchJobs();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Job posted successfully"),
                backgroundColor: Colors.green,
              ),
            );
          }

          setState(() => isSaving = false);
          return true;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Error: ${result['message'] ?? 'Unknown error'}"),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("HTTP Error: ${response.statusCode}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Network Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Network error. Check connection."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => isSaving = false);
    return false;
  }

  Future<void> deleteJob(String id) async {
    final url = ApiService.uri('delete_job.php');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id": id}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['status'] == 'success') {
          await fetchJobs();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Job deleted successfully"),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Delete Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 720;
    return Container(
      color: bgLight,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7F8FA), Color(0xFFF4F1F2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            isCompact ? 16 : 24,
            isCompact ? 16 : 24,
            isCompact ? 16 : 24,
            32,
          ),
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildQuickStats(),
            const SizedBox(height: 24),
            if (isLoading)
              Center(child: CircularProgressIndicator(color: primaryMaroon))
            else
              _buildJobsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isStacked = MediaQuery.of(context).size.width < 860;
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
      child: isStacked
          ? Column(
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
                    Icons.cases_outlined,
                    color: accentGold,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Job Opportunities Management",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Post and manage alumni openings with the same polished visual style used on the alumni jobs page.",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed: fetchJobs,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.30),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text("Refresh"),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showJobDialog(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentGold,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text("Post New Job"),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    Icons.cases_outlined,
                    color: accentGold,
                    size: 34,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Job Opportunities Management",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Post and manage alumni openings with the same polished visual style used on the alumni jobs page.",
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
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed: fetchJobs,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.30),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text("Refresh"),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showJobDialog(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentGold,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text("Post New Job"),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildQuickStats() {
    final withSalary = jobs
        .where((job) => (job['salary'] ?? '').toString().trim().isNotEmpty)
        .length;
    final withLocation = jobs
        .where((job) => (job['location'] ?? '').toString().trim().isNotEmpty)
        .length;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _statCard(
          "Open Roles",
          jobs.length.toString(),
          Icons.work_outline,
          primaryMaroon,
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
        border: Border.all(color: borderColor),
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

  Widget _buildJobsList() {
    if (jobs.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: jobs.asMap().entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: _buildJobCard(entry.value, entry.key),
        );
      }).toList(),
    );
  }

  Widget _buildJobCard(dynamic job, int index) {
    final title = (job['title'] ?? "No Title").toString();
    final company = (job['company'] ?? "Company not specified").toString();
    final description = (job['description'] ?? "No Description").toString();
    final location = (job['location'] ?? "Location not specified").toString();
    final salary = (job['salary'] ?? "Salary not specified").toString();
    final datePosted = (job['date_posted'] ?? 'Unknown').toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
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
                              color: accentGold.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              "Manage",
                              style: TextStyle(
                                color: primaryMaroon,
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
                const SizedBox(width: 8),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                      onPressed: () => _showJobDialog(job: job),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _confirmDelete(job['id'].toString()),
                    ),
                  ],
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
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              "Opportunity ${index + 1}",
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
        border: Border.all(color: borderColor),
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
          border: Border.all(color: borderColor),
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
              "No jobs posted yet",
              style: TextStyle(
                color: primaryMaroon,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Create your first posting and it will appear here in the updated jobs layout.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  void _showJobDialog({Map<String, dynamic>? job}) {
    final isEditing = job != null;

    final titleController = TextEditingController(text: job?['title'] ?? '');
    final descriptionController = TextEditingController(
      text: job?['description'] ?? '',
    );
    final companyController = TextEditingController(
      text: job?['company'] ?? '',
    );
    final locationController = TextEditingController(
      text: job?['location'] ?? '',
    );
    final salaryController = TextEditingController(text: job?['salary'] ?? '');
    final requirementsController = TextEditingController(
      text: job?['requirements'] ?? '',
    );
    final contactEmailController = TextEditingController(
      text: job?['contact_email'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? "Edit Job" : "Post New Job"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: "Job Title *"),
              ),
              TextField(
                controller: companyController,
                decoration: const InputDecoration(labelText: "Company Name *"),
              ),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(labelText: "Location *"),
              ),
              TextField(
                controller: salaryController,
                decoration: const InputDecoration(labelText: "Salary Range"),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: "Job Description *",
                ),
                maxLines: 3,
              ),
              TextField(
                controller: requirementsController,
                decoration: const InputDecoration(labelText: "Requirements"),
                maxLines: 2,
              ),
              TextField(
                controller: contactEmailController,
                decoration: const InputDecoration(labelText: "Contact Email *"),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: isSaving
                ? null
                : () async {
                    if (titleController.text.isEmpty ||
                        descriptionController.text.isEmpty ||
                        companyController.text.isEmpty ||
                        locationController.text.isEmpty ||
                        contactEmailController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Please fill required fields"),
                        ),
                      );
                      return;
                    }

                    final success = await saveJob(
                      titleController.text,
                      descriptionController.text,
                      companyController.text,
                      locationController.text,
                      salaryController.text,
                      requirementsController.text,
                      contactEmailController.text,
                      id: job?['id']?.toString(),
                    );

                    if (!context.mounted) return;

                    if (success) {
                      Navigator.pop(context);
                    }
                  },
            child: isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(isEditing ? "Update" : "Post"),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Job"),
        content: const Text(
          "Are you sure you want to delete this job posting?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              deleteJob(id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}
