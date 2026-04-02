import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/content_service.dart';
import '../widgets/sidebar.dart';
import 'alumni_dashboard.dart';
import 'profile_page.dart';
import 'announcement_page.dart';
import 'jobs_page.dart';
import 'settings_page.dart';
import 'bsit_tracer.dart';
import 'bssw_tracer.dart';
import '../../state/user_store.dart';

class AlumniMainLayout extends StatefulWidget {
  final Map<String, dynamic> user;
  const AlumniMainLayout({super.key, required this.user});

  @override
  State<AlumniMainLayout> createState() => _AlumniMainLayoutState();
}

class _AlumniMainLayoutState extends State<AlumniMainLayout> {
  int _selectedIndex = 0;
  bool _isSidebarCollapsed = false;
  bool _hasInitializedLayout = false;
  final GlobalKey _notificationKey = GlobalKey();
  Timer? _notificationTimer;
  List<dynamic> _notifications = [];

  final Color bgLight = const Color(0xFFF8F9FA);
  final Color primaryMaroon = const Color(0xFF4A152C);
  final Color accentGold = const Color(0xFFC5A046);
  final Color borderColor = const Color(0xFFE0E0E0);

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    if (UserStore.value == null) UserStore.set(widget.user);
    _pages = [
      AlumniDashboard(
        user: widget.user,
        onModuleSelected: (index) => setState(() => _selectedIndex = index),
      ),
      ProfilePage(user: widget.user),
      AnnouncementPage(user: widget.user),
      AlumniJobsPage(user: widget.user),
      SettingsPage(user: widget.user),
      BSSWTracerPage(userId: widget.user['id']), // Corrected line
      BSITTracerPage(userId: widget.user['id']), // Corrected line
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
                : 330,
            height: 260,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 46), // 0.18 opacity
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
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
                                backgroundColor: primaryMaroon.withValues(
                                  alpha: 38,
                                ), // 0.15 opacity
                                child: const Icon(
                                  Icons.announcement_outlined,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                note['title'] ?? 'Update',
                                style: const TextStyle(fontSize: 14),
                              ),
                              subtitle: Text(
                                note['type']?.toString().isNotEmpty == true
                                    ? '${note['type']} • ${note['time'] ?? 'Just now'}'
                                    : note['time'] ?? 'Just now',
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
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 768;
    bool isTablet = screenWidth >= 768 && screenWidth < 1024;

    if (!_hasInitializedLayout) {
      _isSidebarCollapsed = isTablet;
      _hasInitializedLayout = true;
    }

    return Scaffold(
      backgroundColor: bgLight,
      drawer: isMobile
          ? Drawer(
              child: Sidebar(
                role: "alumni",
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
              role: "alumni",
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
    final liveUser = UserStore.value ?? widget.user;
    return Container(
      height: 86,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFF9F5F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(bottom: BorderSide(color: Color(0xFFE8E1E4))),
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
          if (!isMobile)
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
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
                      Icons.auto_awesome_outlined,
                      color: primaryMaroon,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Stay connected with jobs, tracer updates, and alumni news.',
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
          const SizedBox(width: 12),
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
          const SizedBox(width: 20),
          if (!isMobile)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  liveUser['name'] ?? "Alumni",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: primaryMaroon,
                  ),
                ),
                Text(
                  liveUser['role'] ?? "Alumni",
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          const SizedBox(width: 10),
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
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
