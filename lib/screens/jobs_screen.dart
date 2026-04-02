import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../services/api_service.dart';

class JobsScreen extends StatefulWidget {
  final int userId; // optional if you want to track logged-in user

  const JobsScreen({super.key, required this.userId});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  List jobs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchJobs();
  }

  Future<void> fetchJobs() async {
    try {
      final url = ApiService.uri('get_jobs.php');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          jobs = data['jobs'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to fetch jobs. Check your connection.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Job Opportunities"),
        backgroundColor: const Color(0xFF4A152C),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : jobs.isEmpty
          ? const Center(child: Text("No jobs available."))
          : ListView.builder(
              itemCount: jobs.length,
              itemBuilder: (context, index) {
                final job = jobs[index];
                return Card(
                  margin: const EdgeInsets.all(10),
                  child: ListTile(
                    title: Text(job['title'] ?? "No Title"),
                    subtitle: Text(job['description'] ?? "No Description"),
                    trailing: Text(job['date_posted'] ?? ""),
                    onTap: () {
                      // Optional: Navigate to job details or apply
                    },
                  ),
                );
              },
            ),
    );
  }
}
