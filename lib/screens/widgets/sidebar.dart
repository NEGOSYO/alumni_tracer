import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

class Sidebar extends StatefulWidget {
  final String role;
  final int selectedIndex;
  final Function(int)? onItemSelected;
  final bool isCollapsed;
  final VoidCallback? onToggleSidebar;
  final bool isInDrawer;

  const Sidebar({
    super.key,
    required this.role,
    this.selectedIndex = 0,
    this.onItemSelected,
    this.isCollapsed = false,
    this.onToggleSidebar,
    this.isInDrawer = false,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  late bool _isCollapsed;

  static const Color _sidebarBg = Color(0xFF4A152C);
  static const Color _sidebarDeep = Color(0xFF32111F);
  static const Color _activeGold = Color(0xFFC5A046);

  @override
  void initState() {
    super.initState();
    _isCollapsed = widget.isCollapsed;
  }

  @override
  void didUpdateWidget(covariant Sidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _isCollapsed = widget.isCollapsed;
  }

  @override
  Widget build(BuildContext context) {
    final menuItems = _getMenuItems(widget.role);
    final sidebarWidth = _isCollapsed ? 88.0 : 292.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      width: sidebarWidth,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_sidebarBg, Color(0xFF5B1E37), _sidebarDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(6, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeroPanel(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                _isCollapsed ? 10 : 10,
                10,
                _isCollapsed ? 10 : 12,
                12,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < menuItems.length; i++)
                    _buildMenuTile(
                      context,
                      title: menuItems[i]['title'] as String,
                      icon: menuItems[i]['icon'] as IconData,
                      index: i,
                      isActive: i == widget.selectedIndex,
                    ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: _isCollapsed ? 8 : 10,
                      vertical: 12,
                    ),
                    child: Divider(
                      color: Colors.white.withValues(alpha: 0.14),
                      height: 1,
                    ),
                  ),
                  _buildMenuTile(
                    context,
                    title: 'Logout',
                    icon: Icons.logout_rounded,
                    index: -1,
                    isLogout: true,
                  ),
                ],
              ),
            ),
          ),
          _buildFooterCard(),
        ],
      ),
    );
  }

  Widget _buildHeroPanel() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        _isCollapsed ? 10 : 16,
        24,
        _isCollapsed ? 10 : 16,
        16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useCompactExpandedHeader =
              !_isCollapsed && constraints.maxWidth < 210;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _isCollapsed
                  ? Column(
                      children: [
                        Tooltip(
                          message: _getRoleHeader(widget.role),
                          child: Align(
                            alignment: Alignment.center,
                            child: _buildLogo(size: 42),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.center,
                          child: GestureDetector(
                            onTap: () {
                              if (widget.isInDrawer) {
                                Navigator.of(context).pop();
                                return;
                              }
                              setState(() => _isCollapsed = !_isCollapsed);
                              widget.onToggleSidebar?.call();
                            },
                            child: SizedBox(
                              width: 34,
                              height: 34,
                              child: Icon(
                                widget.isInDrawer
                                    ? Icons.close
                                    : Icons.menu_open_rounded,
                                color: Colors.white70,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : useCompactExpandedHeader
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _buildLogo(size: 44),
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () {
                            if (widget.isInDrawer) {
                              Navigator.of(context).pop();
                              return;
                            }
                            setState(() => _isCollapsed = !_isCollapsed);
                            widget.onToggleSidebar?.call();
                          },
                          child: const SizedBox(
                            width: 34,
                            height: 34,
                            child: Icon(
                              Icons.menu_rounded,
                              color: Colors.white70,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _getRoleHeader(widget.role),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _getRoleSubheader(widget.role),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.76),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              _buildLogo(size: 54),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getRoleHeader(widget.role),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _getRoleSubheader(widget.role),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.76,
                                        ),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            if (widget.isInDrawer) {
                              Navigator.of(context).pop();
                              return;
                            }
                            setState(() => _isCollapsed = !_isCollapsed);
                            widget.onToggleSidebar?.call();
                          },
                          child: SizedBox(
                            width: 34,
                            height: 34,
                            child: Icon(
                              widget.isInDrawer
                                  ? Icons.close
                                  : Icons.menu_rounded,
                              color: Colors.white70,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
              SizedBox(height: _isCollapsed ? 14 : 18),
              Container(
                height: 1,
                width: double.infinity,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLogo({required double size}) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset('assets/jmclogo.png', fit: BoxFit.contain),
    );
  }

  Widget _buildFooterCard() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _isCollapsed ? 10 : 12,
        0,
        _isCollapsed ? 10 : 12,
        12,
      ),
      child: Tooltip(
        message: 'Academic Year 2025-2026',
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(_isCollapsed ? 10 : 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: _isCollapsed
              ? const Icon(
                  Icons.calendar_month_outlined,
                  color: Colors.white70,
                  size: 18,
                )
              : const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Academic Year',
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '2025-2026',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required int index,
    bool isActive = false,
    bool isLogout = false,
  }) {
    final tile = Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: isActive
            ? _activeGold.withValues(alpha: 0.20)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: isActive
            ? Border.all(color: Colors.white.withValues(alpha: 0.10))
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            if (isLogout) {
              await AuthService.logout(context);
              return;
            }
            if (widget.onItemSelected != null && index >= 0) {
              widget.onItemSelected!(index);
            }
          },
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _isCollapsed ? 0 : 14,
              vertical: 13,
            ),
            child: _isCollapsed
                ? Center(
                    child: Icon(
                      icon,
                      color: isActive ? Colors.white : Colors.white70,
                      size: 24,
                    ),
                  )
                : Row(
                    children: [
                      Icon(
                        icon,
                        color: isActive ? Colors.white : Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isActive ? Colors.white : Colors.white70,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      if (isActive)
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );

    if (_isCollapsed) {
      return Tooltip(message: title, child: tile);
    }
    return tile;
  }

  String _getRoleHeader(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'ADMINISTRATOR';
      case 'dean':
        return 'Department Head';
      case 'alumni':
        return 'ALUMNI PORTAL';
      default:
        return 'Welcome';
    }
  }

  String _getRoleSubheader(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Data governance and oversight';
      case 'dean':
        return 'Live program analytics';
      case 'alumni':
        return 'Career and tracer access';
      default:
        return 'Portal Navigation';
    }
  }

  List<Map<String, dynamic>> _getMenuItems(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return [
          {'title': 'Dashboard', 'icon': Icons.grid_view_outlined},
          {'title': 'Alumni List', 'icon': Icons.people_outline},
          {'title': 'Tracer Governance', 'icon': Icons.analytics_outlined},
          {'title': 'Verify Users', 'icon': Icons.verified_user_outlined},
          {'title': 'Announcements', 'icon': Icons.campaign_outlined},
          {'title': 'Jobs', 'icon': Icons.work_outline},
          {'title': 'Settings', 'icon': Icons.settings_outlined},
        ];
      case 'dean':
        return [
          {'title': 'Dashboard', 'icon': Icons.grid_view_outlined},
          {'title': 'Department Alumni', 'icon': Icons.people_outline},
          {'title': 'Career Reports', 'icon': Icons.work_outline},
          {'title': 'Career Overview', 'icon': Icons.analytics_outlined},
          {'title': 'Announcements', 'icon': Icons.campaign_outlined},
          {'title': 'Settings', 'icon': Icons.settings_outlined},
        ];
      case 'alumni':
        return [
          {'title': 'Dashboard', 'icon': Icons.grid_view_outlined},
          {'title': 'Profile', 'icon': Icons.person_outline},
          {'title': 'Announcements', 'icon': Icons.campaign_outlined},
          {'title': 'Jobs', 'icon': Icons.work_outline},
          {'title': 'Settings', 'icon': Icons.settings_outlined},
        ];
      default:
        return [];
    }
  }
}
