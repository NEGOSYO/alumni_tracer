import 'package:flutter/material.dart';

class UserRegistrationsPage extends StatefulWidget {
  final List<dynamic> users;
  final bool isLoading;
  final VoidCallback onBack;
  final Future<void> Function() onRefresh;

  const UserRegistrationsPage({
    super.key,
    required this.users,
    required this.isLoading,
    required this.onBack,
    required this.onRefresh,
  });

  @override
  State<UserRegistrationsPage> createState() => _UserRegistrationsPageState();
}

class _UserRegistrationsPageState extends State<UserRegistrationsPage> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _filteredUsers = [];

  final Color primaryMaroon = const Color(0xFF4A152C);

  @override
  void initState() {
    super.initState();
    _filteredUsers = widget.users;
    _searchController.addListener(_filterUsers);
  }

  @override
  void didUpdateWidget(covariant UserRegistrationsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.users != widget.users) {
      _filteredUsers = widget.users;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = widget.users.where((user) {
        final name = (user['name'] ?? "").toString().toLowerCase();
        final course = (user['course'] ?? "").toString().toLowerCase();
        final email = (user['email'] ?? "")
            .toString()
            .toLowerCase(); // ✅ Added Email search
        return name.contains(query) ||
            course.contains(query) ||
            email.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8F9FA),
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 HEADER
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: widget.onBack,
                color: primaryMaroon,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "User Registrations",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: primaryMaroon,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: widget.onRefresh,
                color: Colors.grey,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 🔹 SEARCH BAR
          TextField(
            controller: _searchController,
            cursorColor: primaryMaroon,
            decoration: InputDecoration(
              hintText: "Search by name, course, or email...", // ✅ Updated hint
              prefixIcon: Icon(Icons.search, color: primaryMaroon),
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryMaroon),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 🔹 LIST
          Expanded(
            child: widget.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                ? const Center(child: Text("No users found"))
                : ListView.separated(
                    itemCount: _filteredUsers.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      // ✅ Pass 5 arguments to match the dashboard logic
                      return _regItem(
                        user['name'] ?? "Unknown",
                        user['course'] ?? "N/A",
                        user['status'] ?? "Pending",
                        user['email'] ?? "No Email",
                        user['year'] ?? "N/A",
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // 🔹 UPDATED ITEM UI
  Widget _regItem(
    String name,
    String course,
    String status,
    String email,
    String year,
  ) {
    final lowerStatus = status.toLowerCase();

    Color statusColor;
    if (lowerStatus == "approved" || lowerStatus == "verified") {
      statusColor = Colors.green;
    } else if (lowerStatus == "rejected") {
      statusColor = Colors.red;
    } else {
      statusColor = Colors.orange;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      title: Text(
        name,
        style: TextStyle(fontWeight: FontWeight.bold, color: primaryMaroon),
      ),
      subtitle: Column(
        // ✅ Switched to Column to show more details
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            "$course | Class of $year",
            style: TextStyle(
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            email,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          // ✅ Note: If using latest Flutter, consider using statusColor.withValues(alpha: 0.1)
          color: statusColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          status.toUpperCase(),
          style: TextStyle(
            color: statusColor,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
