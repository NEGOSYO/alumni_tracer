import 'package:flutter/material.dart';

import '../../services/content_service.dart';

class AnnouncementPage extends StatefulWidget {
  const AnnouncementPage({super.key});

  @override
  State<AnnouncementPage> createState() => _AnnouncementPageState();
}

class _AnnouncementPageState extends State<AnnouncementPage> {
  static const Color primaryMaroon = Color(0xFF4A152C);
  static const Color accentGold = Color(0xFFC5A046);
  static const Color lightBackground = Color(0xFFF7F8FA);
  static const Color cardBorder = Color(0xFFE5E7EB);
  static const Color softRose = Color(0xFFF8F1F4);

  List<Map<String, dynamic>> announcements = [];
  List<Map<String, dynamic>> filteredAnnouncements = [];
  String selectedCategory = "All Categories";
  String searchQuery = "";
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchAnnouncements();
  }

  Future<void> fetchAnnouncements() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final decodedData = await ContentService.fetchAnnouncements();
      if (!mounted) return;
      setState(() {
        announcements = decodedData;
        applyFilters();
      });
    } catch (e) {
      debugPrint("Error fetching announcements: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void applyFilters() {
    setState(() {
      filteredAnnouncements = announcements.where((ann) {
        final title = (ann['title'] ?? "").toString().toLowerCase();
        final category = (ann['category'] ?? "General").toString();
        final matchesSearch = title.contains(searchQuery.toLowerCase());
        final matchesCategory = selectedCategory == "All Categories"
            ? true
            : category == selectedCategory;
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  Color getCategoryColor(String category) {
    switch (category) {
      case "Events":
        return Colors.blue;
      case "Reminders":
        return Colors.orange;
      case "Job Opportunities":
        return Colors.green;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBackground,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7F8FA), Color(0xFFF4F1F2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: RefreshIndicator(
          color: primaryMaroon,
          onRefresh: fetchAnnouncements,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            children: [
              _buildHeroHeader(),
              const SizedBox(height: 24),
              _buildQuickStats(),
              const SizedBox(height: 24),
              _buildFilterBar(),
              const SizedBox(height: 24),
              if (isLoading)
                Center(child: CircularProgressIndicator(color: primaryMaroon))
              else if (filteredAnnouncements.isEmpty)
                _buildEmptyState()
              else
                ...filteredAnnouncements.asMap().entries.map((entry) {
                  final ann = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: _buildAnnouncementCard(
                      title: (ann['title'] ?? "No Title").toString(),
                      date: ((ann['created_at'] ?? ann['date']) ?? "Recent")
                          .toString(),
                      category: (ann['category'] ?? "General").toString(),
                      description:
                          (ann['description'] ?? "No description provided.")
                              .toString(),
                      index: entry.key,
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    final isStacked = MediaQuery.of(context).size.width < 820;
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
                  "Announcements",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "View alumni office news, reminders, and opportunities in the same polished read-only experience used across the portal.",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
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
                        "Announcements",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "View alumni office news, reminders, and opportunities in the same polished read-only experience used across the portal.",
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
    final isNarrow = MediaQuery.of(context).size.width < 900;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
      ),
      child: isNarrow
          ? Column(
              children: [
                _searchField(),
                const SizedBox(height: 12),
                _categoryDropdown(),
              ],
            )
          : Row(
              children: [
                Expanded(flex: 3, child: _searchField()),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: _categoryDropdown()),
              ],
            ),
    );
  }

  Widget _searchField() {
    return TextField(
      onChanged: (value) {
        searchQuery = value;
        applyFilters();
      },
      decoration: InputDecoration(
        hintText: "Search announcements...",
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cardBorder),
        ),
      ),
    );
  }

  Widget _categoryDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: selectedCategory,
      items: [
        "All Categories",
        "Events",
        "Reminders",
        "Job Opportunities",
      ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: (value) {
        if (value != null) {
          selectedCategory = value;
          applyFilters();
        }
      },
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cardBorder),
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard({
    required String title,
    required String date,
    required String category,
    required String description,
    required int index,
  }) {
    final color = getCategoryColor(category);
    return Container(
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
                      colors: [primaryMaroon.withValues(alpha: 0.95), color],
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
                              title,
                              style: const TextStyle(
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
                              color: color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                color: color,
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
                          _metaPill(Icons.schedule_outlined, "Posted $date"),
                          _metaPill(Icons.label_outline, "Update ${index + 1}"),
                        ],
                      ),
                    ],
                  ),
                ),
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
              child: const Icon(
                Icons.campaign_outlined,
                color: primaryMaroon,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              "No announcements found",
              style: TextStyle(
                color: primaryMaroon,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Try a different search or refresh the page to check for new posts from the alumni office.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.5),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: fetchAnnouncements,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryMaroon,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Refresh Announcements"),
            ),
          ],
        ),
      ),
    );
  }
}
