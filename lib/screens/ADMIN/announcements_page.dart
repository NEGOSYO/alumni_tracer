import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/api_service.dart';

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  final Color primaryMaroon = const Color(0xFF4A152C);
  final Color accentGold = const Color(0xFFC5A046);
  final Color bgLight = const Color(0xFFF7F8FA);
  final Color borderColor = const Color(0xFFE5E7EB);
  final Color softRose = const Color(0xFFF8F1F4);

  bool isLoading = false;
  bool isSaving = false;
  List announcements = [];

  Color getCategoryColor(String category) {
    switch (category) {
      case "Events":
        return Colors.blue;
      case "Reminders":
        return Colors.orange;
      case "Job Opportunities":
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  void initState() {
    super.initState();
    fetchAnnouncements();
  }

  Future<void> fetchAnnouncements() async {
    setState(() => isLoading = true);
    try {
      final url = ApiService.uri('get_announcements.php');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        setState(() {
          announcements = decoded is List
              ? decoded
              : (decoded is Map ? decoded['announcements'] ?? [] : []);
        });
      }
    } catch (e) {
      debugPrint("Error fetching announcements: $e");
    }
    setState(() => isLoading = false);
  }

  Future<bool> saveAnnouncement(
    String title,
    String desc,
    String category, {
    String? id,
  }) async {
    final url = ApiService.uri('add_announcement.php');

    setState(() => isSaving = true);

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id": id ?? "",
          "title": title,
          "description": desc,
          "category": category,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['status'] == 'success') {
          await fetchAnnouncements();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Announcement saved successfully"),
                backgroundColor: Colors.green,
              ),
            );
          }

          setState(() => isSaving = false);
          return true;
        } else {
          _showError(result['message'] ?? "Unknown Error");
        }
      }
    } catch (e) {
      debugPrint("Connection failed: $e");
      _showError("Could not connect to server.");
    }

    setState(() => isSaving = false);
    return false;
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Future<void> deleteAnnouncement(String id) async {
    try {
      final url = ApiService.uri(
        'delete_announcement.php',
        queryParameters: {'id': id},
      );

      final response = await http.post(url, body: {"id": id});
      final result = jsonDecode(response.body);

      if (result['status'] == 'success') {
        await fetchAnnouncements();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Announcement deleted"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        _showError(result['message'] ?? "Delete failed");
      }
    } catch (e) {
      debugPrint("Delete error: $e");
      _showError("Failed to delete announcement");
    }
  }

  void _showAnnouncementDialog({Map<String, dynamic>? announcement}) {
    final isEditing = announcement != null;

    final titleController = TextEditingController(
      text: isEditing ? announcement['title'] : "",
    );
    final descController = TextEditingController(
      text: isEditing ? announcement['description'] : "",
    );

    String selectedCategory = isEditing
        ? (announcement['category'] ?? "Events")
        : "Events";

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEditing ? "Edit Announcement" : "Create Announcement"),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: "Title"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: "Description"),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                items: ["Events", "Reminders", "Job Opportunities", "GENERAL"]
                    .map(
                      (cat) => DropdownMenuItem(value: cat, child: Text(cat)),
                    )
                    .toList(),
                onChanged: (value) => selectedCategory = value!,
                decoration: const InputDecoration(labelText: "Category"),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryMaroon,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: isSaving
                ? null
                : () async {
                    final success = await saveAnnouncement(
                      titleController.text,
                      descController.text,
                      selectedCategory,
                      id: isEditing ? announcement['id'] : null,
                    );

                    if (success && mounted) {
                      Navigator.pop(context);
                    }
                  },
            child: isSaving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
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
      builder: (_) => AlertDialog(
        title: const Text("Delete Announcement?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await deleteAnnouncement(id);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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
        child: isLoading
            ? Center(child: CircularProgressIndicator(color: primaryMaroon))
            : ListView(
                padding: EdgeInsets.fromLTRB(
                  isCompact ? 16 : 24,
                  isCompact ? 16 : 24,
                  isCompact ? 16 : 24,
                  32,
                ),
                children: [
                  _buildHeroHeader(),
                  const SizedBox(height: 24),
                  _buildQuickStats(),
                  const SizedBox(height: 24),
                  if (announcements.isEmpty)
                    _buildEmptyState()
                  else
                    ...announcements.asMap().entries.map((entry) {
                      final ann = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: _buildAnnouncementCard(ann, entry.key),
                      );
                    }),
                ],
              ),
      ),
    );
  }

  Widget _buildHeroHeader() {
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
                    Icons.campaign_outlined,
                    color: accentGold,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Manage Announcements",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Create and oversee public updates with the same polished card system as the alumni jobs experience.",
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
                      onPressed: fetchAnnouncements,
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
                      onPressed: () => _showAnnouncementDialog(),
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
                      label: const Text("Create New"),
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
                    Icons.campaign_outlined,
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
                        "Manage Announcements",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Create and oversee public updates with the same polished card system as the alumni jobs experience.",
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
                      onPressed: fetchAnnouncements,
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
                      onPressed: () => _showAnnouncementDialog(),
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
                      label: const Text("Create New"),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildQuickStats() {
    final events = announcements
        .where((ann) => (ann['category'] ?? '') == 'Events')
        .length;
    final reminders = announcements
        .where((ann) => (ann['category'] ?? '') == 'Reminders')
        .length;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _statCard(
          "Total Posts",
          announcements.length.toString(),
          Icons.feed_outlined,
          primaryMaroon,
        ),
        _statCard(
          "Events",
          events.toString(),
          Icons.event_available_outlined,
          accentGold,
        ),
        _statCard(
          "Reminders",
          reminders.toString(),
          Icons.notifications_active_outlined,
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

  Widget _buildAnnouncementCard(dynamic ann, int index) {
    final catColor = getCategoryColor(ann['category'] ?? "");
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
                      colors: [primaryMaroon.withValues(alpha: 0.95), catColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(Icons.campaign_outlined, color: accentGold),
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
                              ann['title'] ?? "No Title",
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
                              color: catColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              ann['category']?.toString() ?? "GENERAL",
                              style: TextStyle(
                                color: catColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _metaPill(
                            Icons.schedule_outlined,
                            (ann['created_at'] ?? ann['date'] ?? 'Recent')
                                .toString(),
                          ),
                          _metaPill(Icons.label_outline, "Post ${index + 1}"),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: Colors.blue,
                        size: 20,
                      ),
                      onPressed: () =>
                          _showAnnouncementDialog(announcement: ann),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                      onPressed: () => _confirmDelete(ann['id'].toString()),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              ann['description'] ?? "",
              style: TextStyle(color: Colors.grey.shade700, height: 1.55),
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
                Icons.campaign_outlined,
                color: primaryMaroon,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              "No announcements yet",
              style: TextStyle(
                color: primaryMaroon,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Create your first update for alumni and it will appear here in the new card layout.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
