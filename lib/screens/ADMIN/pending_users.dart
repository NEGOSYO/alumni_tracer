import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/activity_service.dart';
import '../../services/api_service.dart';

class PendingUsersPage extends StatefulWidget {
  const PendingUsersPage({super.key});

  @override
  State<PendingUsersPage> createState() => _PendingUsersPageState();
}

class _PendingUsersPageState extends State<PendingUsersPage> {
  final Color bgLight = const Color(0xFFF8F9FA);
  final Color borderColor = const Color(0xFFE5E7EB);
  final Color primaryMaroon = const Color(0xFF4A152C);
  final Color accentGold = const Color(0xFFC5A046);

  // ✅ Live Data States
  List<dynamic> pendingUsers = [];
  bool isLoading = true;
  final Set<String> _selectedUserIds = <String>{};

  @override
  void initState() {
    super.initState();
    fetchPendingUsers();
  }

  // ✅ FETCH: Get users with status='pending'
  Future<void> fetchPendingUsers() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(ApiService.uri('get_pending_users.php'));

      if (response.statusCode == 200) {
        setState(() {
          pendingUsers = json.decode(response.body);
          _selectedUserIds.removeWhere(
            (id) => !pendingUsers.any((user) => user['id'].toString() == id),
          );
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
      setState(() => isLoading = false);
    }
  }

  // ✅ UPDATE: Approve or Reject in Database
  Future<void> _handleAction(String id, String name, bool isApprove) async {
    final action = isApprove ? 'approved' : 'rejected';

    try {
      final response = await http.post(
        ApiService.uri('approve_user.php'),
        body: {"id": id, "action": action},
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success']) {
          await ActivityService.logImportantFlow(
            action: isApprove ? 'approve_user' : 'reject_user',
            title:
                'Admin ${isApprove ? 'approved' : 'rejected'} the registration of $name',
            type: 'Verification',
            targetId: id,
            targetType: 'alumni_registration',
            description:
                'Registration for $name was ${isApprove ? 'approved' : 'rejected'}.',
            metadata: {
              'status': action,
              'target_user_id': id,
              'target_user_name': name,
            },
          );
          fetchPendingUsers(); // Refresh list
          _showSnackBar(
            isApprove ? "Approved $name" : "Rejected $name",
            isApprove,
          );
        }
      }
    } catch (e) {
      debugPrint("Action Error: $e");
    }
  }

  Future<void> _handleBulkAction(bool isApprove) async {
    if (_selectedUserIds.isEmpty) return;

    final action = isApprove ? 'approved' : 'rejected';
    final selectedUsers = pendingUsers
        .where((user) => _selectedUserIds.contains(user['id'].toString()))
        .map((user) => Map<String, dynamic>.from(user))
        .toList();

    try {
      final response = await http.post(
        ApiService.uri('approve_user.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'ids': _selectedUserIds.map(int.parse).toList(),
          'action': action,
        }),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          for (final user in selectedUsers) {
            final id = user['id']?.toString() ?? '';
            final name = user['name']?.toString() ?? 'Unknown User';
            await ActivityService.logImportantFlow(
              action: isApprove ? 'approve_user' : 'reject_user',
              title:
                  'Admin ${isApprove ? 'approved' : 'rejected'} the registration of $name',
              type: 'Verification',
              targetId: id,
              targetType: 'alumni_registration',
              description:
                  'Registration for $name was ${isApprove ? 'approved' : 'rejected'} through bulk action.',
              metadata: {
                'status': action,
                'target_user_id': id,
                'target_user_name': name,
                'bulk_action': true,
              },
            );
          }

          setState(() => _selectedUserIds.clear());
          fetchPendingUsers();
          _showSnackBar(
            result['message']?.toString() ??
                (isApprove
                    ? 'Selected users approved.'
                    : 'Selected users rejected.'),
            isApprove,
          );
        } else {
          _showSnackBar(
            result['message']?.toString() ?? 'Bulk action failed.',
            false,
          );
        }
      }
    } catch (e) {
      debugPrint("Bulk Action Error: $e");
      _showSnackBar('Bulk action failed.', false);
    }
  }

  void _toggleAllSelections(bool selected) {
    setState(() {
      if (selected) {
        _selectedUserIds
          ..clear()
          ..addAll(
            pendingUsers
                .map((user) => user['id']?.toString() ?? '')
                .where((id) => id.isNotEmpty),
          );
      } else {
        _selectedUserIds.clear();
      }
    });
  }

  void _showSnackBar(String message, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showUserDetails(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.all(32),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "User Details",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Text(
                "Review the alumni information before approval",
                style: TextStyle(color: Colors.grey),
              ),
              const Divider(height: 32),
              _buildPopupField("Full Name", user['name'] ?? 'N/A'),
              _buildPopupField("Email Address", user['email'] ?? 'N/A'),
              Row(
                children: [
                  Expanded(
                    child: _buildPopupField(
                      "Program",
                      user['program'] ?? 'N/A',
                    ),
                  ),
                  Expanded(
                    child: _buildPopupField(
                      "Year Graduated",
                      user['year_graduated'].toString(),
                    ),
                  ),
                ],
              ),
              _buildPopupField(
                "Student ID",
                user['sid'] ?? user['id'].toString(),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildBoxedButton(
                    "Reject",
                    const Color(0xFFFFEBEE),
                    Colors.red,
                    () {
                      Navigator.pop(context);
                      _handleAction(user['id'].toString(), user['name'], false);
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildBoxedButton(
                    "Approve",
                    const Color(0xFF0D0D1D),
                    Colors.white,
                    () {
                      Navigator.pop(context);
                      _handleAction(user['id'].toString(), user['name'], true);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopupField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildBoxedButton(
    String label,
    Color bgColor,
    Color textColor,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      height: 36,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: textColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF7F8FA), Color(0xFFF4F1F2)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryMaroon))
          : SingleChildScrollView(
              padding: EdgeInsets.all(
                MediaQuery.of(context).size.width < 600 ? 16 : 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildTableContainer(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    final width = MediaQuery.of(context).size.width;
    final isStacked = width < 980;
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
                    Icons.verified_user_outlined,
                    color: accentGold,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Pending Alumni Verification",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Review and approve newly registered alumni accounts in a cleaner verification workspace.",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: fetchPendingUsers,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text("Refresh"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 52),
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
                  ),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    Icons.verified_user_outlined,
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
                        "Pending Alumni Verification",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Review and approve newly registered alumni accounts in a cleaner verification workspace.",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: fetchPendingUsers,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text("Refresh"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 52),
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
                ),
              ],
            ),
    );
  }

  Widget _buildTableContainer() {
    final selectableIds = pendingUsers
        .map((user) => user['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    final hasSelection = _selectedUserIds.isNotEmpty;
    final areAllSelected =
        selectableIds.isNotEmpty &&
        _selectedUserIds.length == selectableIds.length;

    return Container(
      width: double.infinity,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                const Text(
                  "Pending Users List",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: hasSelection
                          ? () => _handleBulkAction(false)
                          : null,
                      icon: const Icon(Icons.close_rounded),
                      label: Text(
                        hasSelection
                            ? 'Reject (${_selectedUserIds.length})'
                            : 'Reject Selected',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: hasSelection
                          ? () => _handleBulkAction(true)
                          : null,
                      icon: const Icon(Icons.done_rounded),
                      label: Text(
                        hasSelection
                            ? 'Approve (${_selectedUserIds.length})'
                            : 'Approve Selected',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D0D1D),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (pendingUsers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(48.0),
              child: Center(child: Text("No pending verification requests.")),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        const Color(0xFFFAFAFA),
                      ),
                      columnSpacing: 24,
                      columns: [
                        DataColumn(
                          label: Checkbox(
                            value: areAllSelected,
                            tristate: hasSelection && !areAllSelected,
                            onChanged: (value) =>
                                _toggleAllSelections(value ?? false),
                          ),
                        ),
                        DataColumn(label: Text("Name")),
                        DataColumn(label: Text("Email")),
                        DataColumn(label: Text("Program")),
                        DataColumn(label: Text("Year")),
                        DataColumn(label: Text("Actions")),
                      ],
                      rows: pendingUsers
                          .map(
                            (user) => DataRow(
                              selected: _selectedUserIds.contains(
                                user['id'].toString(),
                              ),
                              cells: [
                                DataCell(
                                  Checkbox(
                                    value: _selectedUserIds.contains(
                                      user['id'].toString(),
                                    ),
                                    onChanged: (value) {
                                      final id = user['id'].toString();
                                      setState(() {
                                        if (value == true) {
                                          _selectedUserIds.add(id);
                                        } else {
                                          _selectedUserIds.remove(id);
                                        }
                                      });
                                    },
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 180,
                                    child: Text(
                                      user['name'] ?? 'N/A',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 220,
                                    child: Text(
                                      user['email'] ?? 'N/A',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 140,
                                    child: Text(
                                      user['program'] ?? 'N/A',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(user['year_graduated'].toString()),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 250,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.visibility_outlined,
                                              size: 22,
                                              color: Colors.blue,
                                            ),
                                            onPressed: () =>
                                                _showUserDetails(user),
                                          ),
                                          const SizedBox(width: 8),
                                          _buildBoxedButton(
                                            "Approve",
                                            const Color(0xFFE8F5E9),
                                            Colors.green,
                                            () => _handleAction(
                                              user['id'].toString(),
                                              user['name'],
                                              true,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          _buildBoxedButton(
                                            "Reject",
                                            const Color(0xFFFFEBEE),
                                            Colors.red,
                                            () => _handleAction(
                                              user['id'].toString(),
                                              user['name'],
                                              false,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
