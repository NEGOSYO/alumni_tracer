import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import '../services/content_service.dart';
import '../state/user_store.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  double _headerOpacity = 0.0;
  late AnimationController _heroAnimationController;
  late Animation<double> _heroFadeAnimation;
  late Animation<Offset> _heroSlideAnimation;

  final GlobalKey _homeKey = GlobalKey();
  final GlobalKey _featuresKey = GlobalKey();
  final GlobalKey _announcementsKey = GlobalKey();
  final GlobalKey _jobsKey = GlobalKey();
  final GlobalKey _statsKey = GlobalKey();
  final GlobalKey _aboutKey = GlobalKey();
  final GlobalKey _contactKey = GlobalKey();

  List<Map<String, dynamic>> announcements = [];
  List<Map<String, dynamic>> jobs = [];
  bool isLoading = true;

  // 🎨 Modern Color Palette
  final Color primaryMaroon = const Color(0xFF4A152C);
  final Color secondaryMaroon = const Color(0xFF6B3B47);
  final Color accentGold = const Color(0xFFC5A046);
  final Color lightMaroon = const Color(0xFFF8F6F7);
  final Color darkText = const Color(0xFF2D3748);
  final Color lightText = const Color(0xFF718096);
  final Color successGreen = const Color(0xFF48BB78);
  final Color warningAmber = const Color(0xFFD69E2E);
  final Color backgroundWhite = const Color(0xFFFFFFFF);
  final Color cardShadow = const Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _fetchData();
    _scrollController.addListener(_onScroll);

    // Hero animations
    _heroAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _heroFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _heroAnimationController, curve: Curves.easeOut),
    );

    _heroSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _heroAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _heroAnimationController.forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _heroAnimationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    double offset = _scrollController.offset;
    double newOpacity = (offset / 300).clamp(0.0, 1.0);
    if (newOpacity != _headerOpacity) {
      setState(() => _headerOpacity = newOpacity);
    }
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    try {
      final results = await Future.wait([
        ContentService.fetchAnnouncements(),
        ContentService.fetchJobs(),
      ]);

      if (!mounted) return;
      setState(() {
        announcements = results[0];
        jobs = results[1];
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Connection Error: $e");
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _showDetailsDialog(
    String title,
    String description,
    String date, {
    bool isJob = false,
  }) {
    // Check if user is logged in
    final isLoggedIn = _isUserLoggedIn();

    if (!isLoggedIn) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Login Required"),
          content: Text(
            "Please log in to view full details of this ${isJob ? 'job opportunity' : 'announcement'}.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryMaroon,
                foregroundColor: Colors.white,
              ),
              child: const Text("Login"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentGold,
                foregroundColor: primaryMaroon,
              ),
              child: const Text("Register"),
            ),
          ],
        ),
      );
      return;
    }

    // Show details if logged in
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(description),
              const SizedBox(height: 15),
              Text(
                "Posted on: $date",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  bool _isUserLoggedIn() {
    return UserStore.value != null;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    bool isTablet = screenWidth >= 950 && screenWidth < 1200;
    final useDrawerNavigation = screenWidth < 1180;

    return Scaffold(
      extendBodyBehindAppBar: true,
      endDrawer: useDrawerNavigation ? _buildMobileDrawer() : null,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _fetchData,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildHeroSection(),
                  _buildFeaturesSection(),
                  _buildAnnouncementsSection(),
                  _buildJobsSection(),
                  _buildStatsSection(),
                  _buildAboutSection(),
                  _buildContactSection(),
                  _buildFooter(),
                ],
              ),
            ),
          ),
          _buildModernHeader(useDrawerNavigation, isTablet),
        ],
      ),
    );
  }

  // ================= MODERN HEADER =================
  Widget _buildModernHeader(bool isMobile, bool isTablet) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 640
        ? 16.0
        : screenWidth < 1000
        ? 24.0
        : 40.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 80,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            primaryMaroon.withValues(alpha: _headerOpacity),
            secondaryMaroon.withValues(alpha: _headerOpacity),
          ],
        ),
        boxShadow: _headerOpacity > 0.5
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                ),
              ]
            : [],
        border: _headerOpacity > 0
            ? Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              )
            : null,
      ),
      child: Row(
        children: [
          // Logo Section
          Row(
            children: [
              Image.asset(
                'assets/jmclogo.png',
                height: 52,
                width: 52,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(Icons.school, color: accentGold, size: 38);
                },
              ),
              const SizedBox(width: 12),
              const Text(
                "JMCFI ALUMNI HUB",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  letterSpacing: 0.8,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const Spacer(),
          if (isMobile)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              ),
            )
          else
            Row(
              children: [
                _navLink("Home", () => _scrollToSection(_homeKey)),
                _navLink("Features", () => _scrollToSection(_featuresKey)),
                _navLink(
                  "Announcements",
                  () => _scrollToSection(_announcementsKey),
                ),
                _navLink("Jobs", () => _scrollToSection(_jobsKey)),
                _navLink("About", () => _scrollToSection(_aboutKey)),
                _navLink("Contact", () => _scrollToSection(_contactKey)),
                const SizedBox(width: 32),
                // Login Button
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "Login",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 16),
                // Register Button
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentGold,
                    foregroundColor: primaryMaroon,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    elevation: 4,
                    shadowColor: accentGold.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "Get Started",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _navLink(String text, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
    );
  }

  // ================= HERO SECTION =================
  Widget _buildHeroSection() {
    final screenSize = MediaQuery.of(context).size;
    final isCompactWidth = screenSize.width < 900;
    final isVeryCompactWidth = screenSize.width < 640;
    final isPhoneWidth = screenSize.width < 430;
    final isShortHeight = screenSize.height < 760;
    final horizontalPadding = isVeryCompactWidth ? 20.0 : 40.0;
    final titleFontSize = isVeryCompactWidth
        ? 34.0
        : isCompactWidth
        ? 44.0
        : 56.0;
    final subtitleFontSize = isVeryCompactWidth
        ? 16.0
        : isCompactWidth
        ? 18.0
        : 20.0;
    final titleGap = isShortHeight ? 20.0 : 32.0;
    final subtitleGap = isShortHeight ? 16.0 : 24.0;
    final ctaGap = isShortHeight ? 32.0 : 48.0;
    final statsGap = isShortHeight ? 40.0 : 80.0;
    final heroTopSpacing = isVeryCompactWidth ? 118.0 : 132.0;

    return Container(
      key: _homeKey,
      constraints: BoxConstraints(minHeight: screenSize.height),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryMaroon, secondaryMaroon, const Color(0xFF2A1A1F)],
        ),
      ),
      child: Stack(
        children: [
          // Background Pattern
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/download.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),

          // Floating Elements
          Positioned(
            top: 100,
            right: 100,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accentGold.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 150,
            left: 80,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main Content
          Center(
            child: FadeTransition(
              opacity: _heroFadeAnimation,
              child: SlideTransition(
                position: _heroSlideAnimation,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    heroTopSpacing,
                    horizontalPadding,
                    24,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // University Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: accentGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                            color: accentGold.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/jmclogo.png',
                              height: 20,
                              width: 20,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.workspace_premium,
                                  color: accentGold,
                                  size: 20,
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "ESTABLISHED 2026",
                              style: TextStyle(
                                color: accentGold,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: titleGap),

                      // Main Title
                      Text(
                        "ALUMNI CONNECT",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w900,
                          letterSpacing: isVeryCompactWidth ? 1 : 2,
                          height: 1.1,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      SizedBox(height: subtitleGap),

                      // Subtitle
                      Container(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Text(
                          "Bridging the gap between education and career success. Track graduate outcomes, build lasting connections, and shape the future of our alumni community.",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: subtitleFontSize,
                            height: 1.6,
                            fontWeight: FontWeight.w300,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      SizedBox(height: ctaGap),

                      // CTA Buttons
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          // Primary CTA
                          SizedBox(
                            width: isPhoneWidth ? double.infinity : null,
                            child: ElevatedButton.icon(
                              onPressed: () => _scrollToSection(_featuresKey),
                              icon: const Icon(Icons.explore, size: 20),
                              label: const Text(
                                "EXPLORE FEATURES",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentGold,
                                foregroundColor: primaryMaroon,
                                padding: EdgeInsets.symmetric(
                                  horizontal: isPhoneWidth ? 20 : 32,
                                  vertical: 20,
                                ),
                                minimumSize: Size(
                                  isPhoneWidth ? screenSize.width : 0,
                                  56,
                                ),
                                elevation: 8,
                                shadowColor: accentGold.withValues(alpha: 0.3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),

                          // Secondary CTA
                          SizedBox(
                            width: isPhoneWidth ? double.infinity : null,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _scrollToSection(_announcementsKey),
                              icon: const Icon(Icons.announcement, size: 20),
                              label: const Text(
                                "VIEW UPDATES",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: isPhoneWidth ? 20 : 32,
                                  vertical: 20,
                                ),
                                minimumSize: Size(
                                  isPhoneWidth ? screenSize.width : 0,
                                  56,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: statsGap),

                      // Stats Row
                      Container(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: Wrap(
                          alignment: WrapAlignment.spaceEvenly,
                          spacing: isPhoneWidth ? 18 : 24,
                          runSpacing: 18,
                          children: [
                            _buildStatItem("New", "Alumni Platform"),
                            _buildStatItem("Jobs", "Opportunity Board"),
                            _buildStatItem("Links", "Industry Partners"),
                            _buildStatItem("24/7", "Online Access"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Scroll Indicator
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => _scrollToSection(_featuresKey),
                child: Column(
                  children: [
                    Text(
                      "Scroll to explore",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white.withValues(alpha: 0.7),
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return SizedBox(
      width: 120,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ================= FEATURES =================
  Widget _buildFeaturesSection() {
    return Container(
      key: _featuresKey,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey.shade50, Colors.white, Colors.grey.shade50],
        ),
      ),
      child: Column(
        children: [
          // Section Header
          Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                Text(
                  "POWERFUL FEATURES",
                  style: TextStyle(
                    color: primaryMaroon,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Everything You Need to Build Strong Alumni Connections",
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  "Our comprehensive platform provides all the tools you need to track alumni success, foster meaningful connections, and drive career opportunities.",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black54,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 60),

          // Features Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 1200
                  ? 4
                  : constraints.maxWidth > 800
                  ? 3
                  : constraints.maxWidth > 600
                  ? 2
                  : 1;

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
                childAspectRatio: 1.1,
                children: [
                  _buildFeatureCard(
                    icon: Icons.analytics,
                    title: "Career Tracking",
                    description:
                        "Monitor graduate employment rates, salary data, and career progression across all disciplines.",
                    color: primaryMaroon,
                  ),
                  _buildFeatureCard(
                    icon: Icons.business,
                    title: "Industry Partnerships",
                    description:
                        "Connect alumni with leading companies and create internship and job opportunities.",
                    color: secondaryMaroon,
                  ),
                  _buildFeatureCard(
                    icon: Icons.groups,
                    title: "Community Building",
                    description:
                        "Foster meaningful connections between alumni, students, and faculty through events and networking.",
                    color: accentGold,
                  ),
                  _buildFeatureCard(
                    icon: Icons.insights,
                    title: "Data Analytics",
                    description:
                        "Generate comprehensive reports and insights to improve curriculum and career services.",
                    color: primaryMaroon,
                  ),
                  _buildFeatureCard(
                    icon: Icons.notifications_active,
                    title: "Stay Connected",
                    description:
                        "Be part of the alumni community with timely updates on opportunities, events, and success stories.",
                    color: secondaryMaroon,
                  ),
                  _buildFeatureCard(
                    icon: Icons.security,
                    title: "Secure Platform",
                    description:
                        "Enterprise-grade security ensures your data is protected with role-based access control.",
                    color: accentGold,
                  ),
                  _buildFeatureCard(
                    icon: Icons.mobile_friendly,
                    title: "Mobile Access",
                    description:
                        "Access your alumni network anytime, anywhere with our responsive mobile application.",
                    color: primaryMaroon,
                  ),
                  _buildFeatureCard(
                    icon: Icons.support,
                    title: "24/7 Support",
                    description:
                        "Get help whenever you need it with our dedicated support team and comprehensive documentation.",
                    color: secondaryMaroon,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 60),

          // Call to Action
          Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                Text(
                  "Ready to Transform Your Alumni Network?",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: primaryMaroon,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  "Join thousands of alumni who are already benefiting from our comprehensive tracking and networking platform.",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => _scrollToSection(_contactKey),
                  icon: const Icon(Icons.contact_mail),
                  label: const Text(
                    "GET STARTED TODAY",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryMaroon,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 20,
                    ),
                    elevation: 8,
                    shadowColor: primaryMaroon.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shadowColor: color.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, color.withValues(alpha: 0.02)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ================= ANNOUNCEMENTS =================
  Widget _buildAnnouncementsSection() {
    return Container(
      key: _announcementsKey,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
      color: Colors.white,
      child: Column(
        children: [
          // Section Header
          Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                Text(
                  "LATEST ANNOUNCEMENTS",
                  style: TextStyle(
                    color: primaryMaroon,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Stay Connected with University Updates",
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  "Get the latest news, events, and opportunities from our alumni community and university partners.",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black54,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 60),

          // Announcements Grid
          isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF8B0000),
                    ),
                  ),
                )
              : announcements.isEmpty
              ? Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.announcement_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No announcements available",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 1200
                        ? 3
                        : constraints.maxWidth > 800
                        ? 2
                        : 1;
                    final displayedAnnouncements = announcements
                        .take(4)
                        .toList();

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 24,
                        childAspectRatio: 1.1,
                      ),
                      itemCount: displayedAnnouncements.length,
                      itemBuilder: (context, index) {
                        final ann = displayedAnnouncements[index];
                        return _buildAnnouncementCard(ann);
                      },
                    );
                  },
                ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> ann) {
    return Card(
      elevation: 8,
      shadowColor: primaryMaroon.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.grey.shade50],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accentGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: accentGold.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Text(
                (ann['category'] ?? "General").toString(),
                style: TextStyle(
                  color: primaryMaroon,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Title
            Text(
              (ann['title'] ?? "No title").toString(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 12),

            // Description
            Expanded(
              child: Text(
                (ann['description'] ?? "No description available.").toString(),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 16),

            // Date and Read More
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDate((ann['created_at'] ?? "").toString()),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextButton(
                  onPressed: () => _showDetailsDialog(
                    (ann['title'] ?? "No title").toString(),
                    (ann['description'] ?? "No description available.")
                        .toString(),
                    (ann['created_at'] ?? "").toString(),
                    isJob: false,
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: primaryMaroon,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    "Read More",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ================= JOBS =================
  Widget _buildJobsSection() {
    return Container(
      key: _jobsKey,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [lightMaroon, Colors.white, lightMaroon],
        ),
      ),
      child: Column(
        children: [
          // Section Header
          Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                Text(
                  "CAREER OPPORTUNITIES",
                  style: TextStyle(
                    color: primaryMaroon,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Discover Your Next Career Move",
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  "Explore exciting job opportunities from our partner companies and alumni network. Connect with employers and advance your career.",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black54,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 60),

          // Jobs Grid
          isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF8B0000),
                    ),
                  ),
                )
              : jobs.isEmpty
              ? Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.work_outline,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No job postings found",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 1200
                        ? 3
                        : constraints.maxWidth > 800
                        ? 2
                        : 1;
                    final displayedJobs = jobs.take(4).toList();

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 24,
                        childAspectRatio: 1.1,
                      ),
                      itemCount: displayedJobs.length,
                      itemBuilder: (context, index) {
                        final job = displayedJobs[index];
                        return _buildJobCard(job);
                      },
                    );
                  },
                ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    return Card(
      elevation: 8,
      shadowColor: accentGold.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, accentGold.withValues(alpha: 0.02)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Company Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: primaryMaroon.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: primaryMaroon.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.business, size: 14, color: primaryMaroon),
                  const SizedBox(width: 6),
                  Text(
                    (job['company'] ?? "Company").toString(),
                    style: TextStyle(
                      color: primaryMaroon,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Job Title
            Text(
              (job['title'] ?? "No title").toString(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 12),

            // Description
            Expanded(
              child: Text(
                (job['description'] ?? "No description available.").toString(),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 16),

            // Date and Apply Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _formatDate((job['date_posted'] ?? "").toString()),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(
                  width: 170,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => _showDetailsDialog(
                      (job['title'] ?? "No title").toString(),
                      (job['description'] ?? "No description available.")
                          .toString(),
                      (job['date_posted'] ?? "").toString(),
                      isJob: true,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryMaroon,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "Apply Now",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ================= STATS =================
  Widget _buildStatsSection() {
    return Container(
      key: _statsKey,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryMaroon, secondaryMaroon, const Color(0xFF2A1A1F)],
        ),
      ),
      child: Column(
        children: [
          // Section Header
          Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: const Column(
              children: [
                Text(
                  "WHAT THIS PLATFORM SUPPORTS",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  "How This System Helps Alumni",
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Text(
                  "As a newly launched alumni tracer system, this platform focuses on opportunity sharing, alumni engagement, and future data gathering for better alumni programs.",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 60),

          // Stats Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 1200
                  ? 4
                  : constraints.maxWidth > 800
                  ? 3
                  : constraints.maxWidth > 600
                  ? 2
                  : 1;

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
                childAspectRatio: 1.2,
                children: [
                  _buildStatCard(
                    value: "New",
                    title: "Platform Launch",
                    subtitle: "A newly introduced space for alumni services",
                    icon: Icons.people,
                    color: accentGold,
                  ),
                  _buildStatCard(
                    value: "Jobs",
                    title: "Opportunity Sharing",
                    subtitle: "Partner openings and career posts for alumni",
                    icon: Icons.trending_up,
                    color: Colors.green.shade400,
                  ),
                  _buildStatCard(
                    value: "Links",
                    title: "Industry Linkages",
                    subtitle:
                        "Connections with partner organizations and offices",
                    icon: Icons.business,
                    color: Colors.blue.shade400,
                  ),
                  _buildStatCard(
                    value: "24/7",
                    title: "Online Access",
                    subtitle: "Alumni services available anytime online",
                    icon: Icons.access_time,
                    color: Colors.purple.shade400,
                  ),
                  _buildStatCard(
                    value: "Forms",
                    title: "Tracer Study",
                    subtitle:
                        "Collecting graduate information for future reports",
                    icon: Icons.sentiment_satisfied,
                    color: Colors.orange.shade400,
                  ),
                  _buildStatCard(
                    value: "News",
                    title: "Announcements",
                    subtitle: "School and alumni office updates in one place",
                    icon: Icons.star,
                    color: Colors.teal.shade400,
                  ),
                  _buildStatCard(
                    value: "Events",
                    title: "Alumni Activities",
                    subtitle:
                        "Support for seminars, fairs, and engagement programs",
                    icon: Icons.category,
                    color: Colors.indigo.shade400,
                  ),
                  _buildStatCard(
                    value: "Goals",
                    title: "Future Insights",
                    subtitle:
                        "Data gathered over time will guide alumni programs",
                    icon: Icons.verified,
                    color: Colors.green.shade600,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 60),

          // Call to Action
          Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                const Text(
                  "Join Our Growing Network",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  "Be part of a community that's transforming careers and building lasting professional connections.",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => _scrollToSection(_contactKey),
                  icon: const Icon(Icons.group_add),
                  label: const Text(
                    "BECOME A MEMBER",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentGold,
                    foregroundColor: primaryMaroon,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 20,
                    ),
                    elevation: 8,
                    shadowColor: accentGold.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: color),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ================= ABOUT =================
  Widget _buildAboutSection() {
    return Container(
      key: _aboutKey,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.grey.shade50, Colors.white],
        ),
      ),
      child: Column(
        children: [
          // Section Header
          Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                Text(
                  "OUR MISSION",
                  style: TextStyle(
                    color: primaryMaroon,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Transforming Alumni Networks Into Career Pathways",
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 60),

          // About Content Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 800;
              return Column(
                children: [
                  if (isMobile) ...[
                    _buildAboutCard(
                      icon: Icons.gps_fixed,
                      title: "Our Vision",
                      description:
                          "To build a connected alumni community where graduates can access opportunities, stay informed, and remain engaged with the institution.",
                      color: primaryMaroon,
                    ),
                    const SizedBox(height: 24),
                    _buildAboutCard(
                      icon: Icons.lightbulb,
                      title: "Our Values",
                      description:
                          "We value service, transparency, collaboration, and accessibility in delivering support to alumni and strengthening school-industry connections.",
                      color: accentGold,
                    ),
                    const SizedBox(height: 24),
                    _buildAboutCard(
                      icon: Icons.people,
                      title: "Our Community",
                      description:
                          "This platform brings together alumni, the alumni office, academic departments, and partner organizations in one accessible online space.",
                      color: secondaryMaroon,
                    ),
                    const SizedBox(height: 24),
                    _buildAboutCard(
                      icon: Icons.trending_up,
                      title: "Our Purpose",
                      description:
                          "As a newly developed system, our purpose is to share opportunities, post announcements, support tracer studies, and build reliable alumni data over time.",
                      color: Colors.green.shade600,
                    ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: _buildAboutCard(
                            icon: Icons.gps_fixed,
                            title: "Our Vision",
                            description:
                                "To build a connected alumni community where graduates can access opportunities, stay informed, and remain engaged with the institution.",
                            color: primaryMaroon,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _buildAboutCard(
                            icon: Icons.lightbulb,
                            title: "Our Values",
                            description:
                                "We value service, transparency, collaboration, and accessibility in delivering support to alumni and strengthening school-industry connections.",
                            color: accentGold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: _buildAboutCard(
                            icon: Icons.people,
                            title: "Our Community",
                            description:
                                "This platform brings together alumni, the alumni office, academic departments, and partner organizations in one accessible online space.",
                            color: secondaryMaroon,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _buildAboutCard(
                            icon: Icons.trending_up,
                            title: "Our Purpose",
                            description:
                                "As a newly developed system, our purpose is to share opportunities, post announcements, support tracer studies, and build reliable alumni data over time.",
                            color: Colors.green.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),

          const SizedBox(height: 60),

          // Call to Action
          Container(
            constraints: const BoxConstraints(maxWidth: 700),
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryMaroon.withValues(alpha: 0.05),
                  accentGold.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: primaryMaroon.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.volunteer_activism, size: 48, color: primaryMaroon),
                const SizedBox(height: 16),
                const Text(
                  "Join Our Growing Community",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "Whether you're a recent graduate or a seasoned professional, there's a place for you in our alumni network.",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterPage()),
                    );
                  },
                  icon: const Icon(Icons.person_add),
                  label: const Text(
                    "REGISTER NOW",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryMaroon,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 16,
                    ),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shadowColor: color.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, color.withValues(alpha: 0.02)],
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(
                fontSize: 15,
                color: Colors.black54,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ================= CONTACT =================
  Widget _buildContactSection() {
    return Container(
      key: _contactKey,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryMaroon, secondaryMaroon, const Color(0xFF2A1A1F)],
        ),
      ),
      child: Column(
        children: [
          // Section Header
          Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                const Text(
                  "GET IN TOUCH",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Contact The Alumni Office",
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  "This portal does not receive messages directly. Please use the contact details below to reach the alumni office manually for records, tracer, events, and account concerns.",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 60),

          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 760;
              final cards = [
                _buildContactCard(
                  icon: Icons.mail_outline,
                  title: "General Inquiries",
                  primary: "marla.villasor@jmc.edu.ph",
                  secondary:
                      "Official email for alumni concerns and portal assistance",
                ),
                _buildContactCard(
                  icon: Icons.phone_outlined,
                  title: "Office Phone",
                  primary: "1234",
                  secondary: "Temporary display number during deployment",
                ),
                _buildContactCard(
                  icon: Icons.location_on_outlined,
                  title: "Campus Office",
                  primary: "Jose Maria College Foundation, Inc. School",
                  secondary: "Temporary display location for deployment",
                ),
                _buildContactCard(
                  icon: Icons.public_outlined,
                  title: "Facebook Page",
                  primary: "Temporary Facebook page display",
                  secondary: "For announcements, office updates, and events",
                ),
              ];

              return Container(
                constraints: const BoxConstraints(maxWidth: 860),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: isCompact
                    ? Column(
                        children: cards
                            .map(
                              (card) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: card,
                              ),
                            )
                            .toList(),
                      )
                    : Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: cards
                            .map(
                              (card) => SizedBox(
                                width: (constraints.maxWidth - 16) / 2,
                                child: card,
                              ),
                            )
                            .toList(),
                      ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String primary,
    required String secondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: lightMaroon,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardShadow),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: primaryMaroon.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: primaryMaroon),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: primaryMaroon,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  primary,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  secondary,
                  style: TextStyle(fontSize: 13, height: 1.5, color: lightText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() => Container(
    padding: const EdgeInsets.fromLTRB(40, 20, 40, 28),
    color: const Color(0xFF1A1A1A),
    width: double.infinity,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Container(
          padding: const EdgeInsets.only(top: 18),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              Text(
                "© 2026 University Alumni Tracer. All rights reserved.",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                "Connecting generations of success",
                style: TextStyle(
                  color: accentGold,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildMobileDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFFF6F0F2),
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                primaryMaroon,
                const Color(0xFF5D1934),
                const Color(0xFFF6F0F2),
              ],
              stops: const [0.0, 0.34, 0.34],
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.1),
                        Colors.white.withValues(alpha: 0.03),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.14),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/jmclogo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.school,
                              color: primaryMaroon,
                              size: 30,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "ALUMNI CONNECT",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Quick access to your portal sections",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCFAFB),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            _buildDrawerItem(
                              icon: Icons.home_rounded,
                              title: "Home",
                              accent: primaryMaroon,
                              onTap: () {
                                Navigator.pop(context);
                                _scrollToSection(_homeKey);
                              },
                            ),
                            _buildDrawerItem(
                              icon: Icons.auto_awesome_rounded,
                              title: "Features",
                              accent: accentGold,
                              onTap: () {
                                Navigator.pop(context);
                                _scrollToSection(_featuresKey);
                              },
                            ),
                            _buildDrawerItem(
                              icon: Icons.campaign_rounded,
                              title: "Announcements",
                              accent: secondaryMaroon,
                              onTap: () {
                                Navigator.pop(context);
                                _scrollToSection(_announcementsKey);
                              },
                            ),
                            _buildDrawerItem(
                              icon: Icons.work_rounded,
                              title: "Jobs",
                              accent: primaryMaroon,
                              onTap: () {
                                Navigator.pop(context);
                                _scrollToSection(_jobsKey);
                              },
                            ),
                            _buildDrawerItem(
                              icon: Icons.info_rounded,
                              title: "About",
                              accent: accentGold,
                              onTap: () {
                                Navigator.pop(context);
                                _scrollToSection(_aboutKey);
                              },
                            ),
                            _buildDrawerItem(
                              icon: Icons.contact_mail_rounded,
                              title: "Contact",
                              accent: secondaryMaroon,
                              onTap: () {
                                Navigator.pop(context);
                                _scrollToSection(_contactKey);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginPage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.login_rounded),
                          label: const Text("Login"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryMaroon,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterPage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: const Text("Get Started"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryMaroon,
                            side: BorderSide(
                              color: primaryMaroon.withValues(alpha: 0.25),
                            ),
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: accent.withValues(alpha: 0.05),
              border: Border.all(color: accent.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: darkText,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: accent.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDate(String dateString) {
  try {
    final date = DateTime.parse(dateString);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return "Today";
    } else if (difference.inDays == 1) {
      return "Yesterday";
    } else if (difference.inDays < 7) {
      return "${difference.inDays} days ago";
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return "$weeks week${weeks > 1 ? 's' : ''} ago";
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return "$months month${months > 1 ? 's' : ''} ago";
    } else {
      final years = (difference.inDays / 365).floor();
      return "$years year${years > 1 ? 's' : ''} ago";
    }
  } catch (e) {
    return dateString; // Return original string if parsing fails
  }
}

// ================= HOVER CARD =================
class HoverCard extends StatefulWidget {
  final Widget child;
  const HoverCard({super.key, required this.child});

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, isHovered ? -10 : 0, 0),
        child: widget.child,
      ),
    );
  }
}
