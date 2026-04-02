import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/content_service.dart';
import '../../state/user_store.dart';
import '../widgets/sidebar.dart';
import 'announcement_page.dart';
import 'career_overview.dart';
import 'career_reports.dart';
import 'dean_dashboard.dart';
import 'department_alumni.dart';
import 'settings_page.dart';

class DeanMainLayout extends StatefulWidget {
  final Map<String, dynamic> user;

  const DeanMainLayout({super.key, required this.user});

  @override
  State<DeanMainLayout> createState() => _DeanMainLayoutState();
}

class _DeanMainLayoutState extends State<DeanMainLayout> {
  int _selectedIndex = 0;
  bool _isSidebarCollapsed = false;
  bool _hasInitializedLayout = false;
  final GlobalKey _notificationKey = GlobalKey();
  Timer? _notificationTimer;
  List<dynamic> _notifications = [];

  final Color primaryMaroon = const Color(0xFF4A152C);
  final Color accentGold = const Color(0xFFC5A046);
  final Color bgLight = const Color(0xFFF7F8FA);

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    if (UserStore.value == null) UserStore.set(widget.user);
    _pages = [
      DeanDashboard(user: widget.user),
      const DepartmentAlumniPage(),
      const CareerReportsPage(),
      const CareerOverviewPage(),
      const AnnouncementPage(),
      SettingsPage(user: widget.user),
    ];
    _fetchNotifications();
    _notificationTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _fetchNotifications();
    });
  }

  Future<void> _fetchNotifications() async {
    try {
      final announcements = await ContentService.fetchAnnouncements();
      if (!mounted) return;
      setState(() {
        _notifications = announcements.take(10).map((item) {
          return {
            'title': item['title']?.toString() ?? 'Announcement',
            'time': item['created_at']?.toString() ?? 'Just now',
            'type': item['category']?.toString() ?? 'Announcement',
            'description': item['description']?.toString() ?? '',
          };
        }).toList();
      });
    } catch (e) {
      debugPrint("Notifications Error: $e");
    }
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  void _showNotifications() async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final button =
        _notificationKey.currentContext!.findRenderObject() as RenderBox;
    final buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);
    final buttonSize = button.size;

    await showMenu(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(
          buttonPosition.dx,
          buttonPosition.dy + buttonSize.height,
          buttonSize.width,
          buttonSize.height,
        ),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          enabled: false,
          child: Container(
            width: MediaQuery.of(context).size.width < 420
                ? MediaQuery.of(context).size.width - 48
                : 320,
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Notifications',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _notifications.isEmpty
                      ? const Center(child: Text('No notifications yet'))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _notifications.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final note = _notifications[index];
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: accentGold.withValues(
                                  alpha: 0.2,
                                ),
                                child: const Icon(
                                  Icons.announcement_outlined,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                note['title']?.toString() ?? 'Update',
                                style: const TextStyle(fontSize: 14),
                              ),
                              subtitle: Text(
                                note['type']?.toString().isNotEmpty == true
                                    ? '${note['type']} • ${note['time'] ?? 'Just now'}'
                                    : note['time']?.toString() ?? 'Just now',
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;

    if (!_hasInitializedLayout) {
      _isSidebarCollapsed = isTablet;
      _hasInitializedLayout = true;
    }

    return Scaffold(
      backgroundColor: bgLight,
      drawer: isMobile
          ? Drawer(
              child: Sidebar(
                role: "dean",
                selectedIndex: _selectedIndex,
                isInDrawer: true,
                onItemSelected: (index) {
                  setState(() => _selectedIndex = index);
                  Navigator.pop(context);
                },
              ),
            )
          : null,
      body: Row(
        children: [
          if (!isMobile)
            Sidebar(
              role: "dean",
              selectedIndex: _selectedIndex,
              isCollapsed: _isSidebarCollapsed,
              onToggleSidebar: () =>
                  setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
              onItemSelected: (index) => setState(() => _selectedIndex = index),
            ),
          Expanded(
            child: Column(
              children: [
                _buildHeader(isMobile),
                Expanded(
                  child: IndexedStack(index: _selectedIndex, children: _pages),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 640;
    final liveUser = UserStore.value ?? widget.user;

    return Container(
      height: isCompact ? 88 : 86,
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFF9F5F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: const Border(bottom: BorderSide(color: Color(0xFFE8E1E4))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          if (isMobile)
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
          SizedBox(width: isCompact ? 8 : 12),
          if (!isMobile)
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F1F4),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE7DCE1)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.analytics_outlined,
                      color: primaryMaroon,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Review tracer trends, employment insights, and department records.",
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            const Spacer(),
          IconButton(
            key: _notificationKey,
            onPressed: _showNotifications,
            icon: Badge(
              label: Text(_notifications.length.toString()),
              isLabelVisible: _notifications.isNotEmpty,
              backgroundColor: accentGold,
              child: Icon(
                Icons.notifications_none_outlined,
                color: primaryMaroon,
              ),
            ),
          ),
          SizedBox(width: isCompact ? 8 : 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isCompact)
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      liveUser['name']?.toString() ?? "Dean",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: primaryMaroon,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      liveUser['role']?.toString() ?? "Dean",
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              if (!isCompact) const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentGold, primaryMaroon.withValues(alpha: 0.9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  backgroundColor: primaryMaroon,
                  radius: 18,
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
