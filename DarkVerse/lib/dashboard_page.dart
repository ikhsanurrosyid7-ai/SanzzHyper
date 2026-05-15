// dashboard_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

import 'nik_check.dart';
import 'admin_page.dart';
import 'owner_page.dart';
import 'home_page.dart';
import 'seller_page.dart';
import 'change_password_page.dart';
import 'tools_gateway.dart';
import 'login_page.dart';
import 'bug_sender.dart';
import 'contact_page.dart';
import 'profile_page.dart';
import 'riwayat_page.dart';
import 'info_page.dart';
import '.dart';

class DashboardPage extends StatefulWidget {
  final String username;
  final String password;
  final String role;
  final String expiredDate;
  final String sessionKey;
  final List<Map<String, dynamic>> listBug;
  final List<Map<String, dynamic>> listDoos;
  final List<dynamic> news;

  const DashboardPage({
    super.key,
    required this.username,
    required this.password,
    required this.role,
    required this.expiredDate,
    required this.listBug,
    required this.listDoos,
    required this.sessionKey,
    required this.news,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late WebSocketChannel channel;

  late String sessionKey;
  late String username;
  late String password;
  late String role;
  late String expiredDate;
  late List<Map<String, dynamic>> listBug;
  late List<Map<String, dynamic>> listDoos;
  late List<dynamic> newsList;

  String androidId = "unknown";
  File? _profileImage;
  VideoPlayerController? _menuVideoController;

  int _bottomNavIndex = 0;
  Widget _selectedPage = const Placeholder();

  int onlineUsers = 0;
  int activeConnections = 0;

  // === TEMA WARNA MERAH GELAP ===
  final Color bgDark = Colors.black;
  final Color primaryDark = const Color(0xFF1A0A0A);
  final Color accentDark = const Color(0xFF2A0A0A);
  final Color primaryWhite = Colors.white;
  final Color accentGrey = Colors.grey.shade400;
  final Color cardGlass = const Color(0xFF2A1515);
  final Color borderGlass = const Color(0xFF4A2020);
  final Color primaryRed = const Color(0xFFB71C1C);
  final Color redGlow = const Color(0x55D32F2F);
  final Color lightRed = const Color(0xFFE53935);
  final Color liveGreen = const Color(0xFF22C55E);

  @override
  void initState() {
    super.initState();
    sessionKey = widget.sessionKey;
    username = widget.username;
    password = widget.password;
    role = widget.role;
    expiredDate = widget.expiredDate;
    listBug = widget.listBug;
    listDoos = widget.listDoos;
    newsList = widget.news;

    _controller = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();

    _selectedPage = _buildNewsPage();

    _initAndroidIdAndConnect();
    _loadProfileImage();
    _initMenuVideo();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('profile_image_$username');
    if (imagePath != null && imagePath.isNotEmpty) {
      setState(() {
        _profileImage = File(imagePath);
      });
    }
  }

  void _initMenuVideo() {
    _menuVideoController =
        VideoPlayerController.asset('assets/videos/banner.mp4')
          ..initialize().then((_) {
            setState(() {});
            _menuVideoController?.setLooping(true);
            _menuVideoController?.play();
          });
  }

  Future<void> _initAndroidIdAndConnect() async {
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    androidId = deviceInfo.id;
    _connectToWebSocket();
  }

  void _connectToWebSocket() {
    channel = WebSocketChannel.connect(Uri.parse('$apiBaseUrl'));
    channel.sink.add(jsonEncode({
      "type": "validate",
      "key": sessionKey,
      "androidId": androidId,
    }));
    channel.sink.add(jsonEncode({"type": "stats"}));

    channel.stream.listen((event) {
      final data = jsonDecode(event);
      if (data['type'] == 'myInfo') {
        if (data['valid'] == false) {
          if (data['reason'] == 'androidIdMismatch') {
            _handleInvalidSession("Your account has logged on another device.");
          } else if (data['reason'] == 'keyInvalid') {
            _handleInvalidSession("Key is not valid. Please login again.");
          }
        }
      }
      if (data['type'] == 'stats') {
        setState(() {
          onlineUsers = data['onlineUsers'] ?? 0;
          activeConnections = data['activeConnections'] ?? 0;
        });
      }
    });
  }

  Future<void> _openUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception("Could not launch $uri");
    }
  }

  void _handleInvalidSession(String message) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: primaryDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text("⚠️ Session Expired",
            style: TextStyle(color: lightRed, fontWeight: FontWeight.bold)),
        content: Text(message, style: TextStyle(color: accentGrey)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
            child: Text("OK",
                style: TextStyle(color: primaryWhite, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _onBottomNavTapped(int index) {
    setState(() {
      _bottomNavIndex = index;
      if (index == 0) {
        _selectedPage = _buildNewsPage();
      } else if (index == 1) {
        _selectedPage = HomePage(
          username: username,
          password: password,
          listBug: listBug,
          role: role,
          expiredDate: expiredDate,
          sessionKey: sessionKey,
        );
      } else if (index == 2) {
        _selectedPage = InfoPage(sessionKey: sessionKey);
      } else if (index == 3) {
        _selectedPage = ToolsPage(
            sessionKey: sessionKey, userRole: role, listDoos: listDoos);
      }
    });
  }

  void _onSidebarTabSelected(int index) {
    setState(() {
      if (index == 1) {
        _selectedPage = SellerPage(keyToken: sessionKey);
      } else if (index == 2) {
        _selectedPage = AdminPage(sessionKey: sessionKey);
      } else if (index == 3) {
        _selectedPage = OwnerPage(sessionKey: sessionKey, username: username);
      }
    });
    Navigator.pop(context);
  }

  // ===================== NEWS PAGE =====================
  Widget _buildNewsPage() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          // === STATS CARD: Online & Koneksi + LIVE ===
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: cardGlass,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderGlass, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: redGlow,
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(child: _buildStatItem(icon: Icons.people_alt_outlined, label: "Online", value: "$onlineUsers")),
                  Container(width: 1, height: 36, color: borderGlass),
                  Expanded(child: _buildStatItem(icon: Icons.wifi_rounded, label: "Koneksi", value: "$activeConnections")),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: liveGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: liveGreen.withOpacity(0.5), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: liveGreen,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: liveGreen, blurRadius: 6)],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text("LIVE", style: TextStyle(color: liveGreen, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Orbitron', letterSpacing: 1)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 22),

          // === BERITA TERBARU ===
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(width: 3, height: 18, decoration: BoxDecoration(color: primaryRed, borderRadius: BorderRadius.circular(4), boxShadow: [BoxShadow(color: redGlow, blurRadius: 8)])),
                    const SizedBox(width: 8),
                    const Text("Berita Terbaru", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Orbitron')),
                  ],
                ),
                Text("${newsList.length} artikel", style: TextStyle(color: accentGrey, fontSize: 12, fontFamily: 'ShareTechMono')),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // News Slider
          SizedBox(
            height: 200,
            child: newsList.isEmpty
                ? Center(child: Text("Tidak ada berita", style: TextStyle(color: accentGrey)))
                : PageView.builder(
                    controller: PageController(viewportFraction: 0.92),
                    itemCount: newsList.length,
                    itemBuilder: (context, index) {
                      final item = newsList[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: cardGlass,
                          border: Border.all(color: borderGlass),
                          boxShadow: [BoxShadow(color: redGlow, blurRadius: 12, offset: const Offset(0, 5))],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (item['image'] != null && item['image'].toString().isNotEmpty) NewsMedia(url: item['image']),
                              Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.black.withOpacity(0.7), Colors.transparent], begin: Alignment.bottomCenter, end: Alignment.topCenter))),
                              Positioned(
                                top: 12,
                                left: 12,
                                child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: primaryRed, borderRadius: BorderRadius.circular(6)), child: const Text("NEWS", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Orbitron', letterSpacing: 1))),
                              ),
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(6)), child: Text("${index + 1}/${newsList.length}", style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'ShareTechMono'))),
                              ),
                              Positioned(
                                bottom: 14,
                                left: 14,
                                right: 14,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['title'] ?? 'No Title', style: const TextStyle(color: Colors.white, fontSize: 15, fontFamily: "Orbitron", fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 3),
                                    Text(item['desc'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.7), fontFamily: "ShareTechMono", fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          const SizedBox(height: 24),

          // === AKSI CEPAT ===
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(width: 3, height: 18, decoration: BoxDecoration(color: primaryRed, borderRadius: BorderRadius.circular(4), boxShadow: [BoxShadow(color: redGlow, blurRadius: 8)])),
                const SizedBox(width: 8),
                const Text("Aksi Cepat", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Orbitron')),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Info Channel Card
          _buildAksiCepatCard(
            icon: FontAwesomeIcons.telegram,
            iconColor: const Color(0xFF29B6F6),
            iconBg: const Color(0xFF0D1A2E),
            title: "Info Channel",
            subtitle: "Join Chanel Slaber",
            buttonLabel: "Join",
            onTap: () => _openUrl("https://t.me/SlaberXTeam"),
          ),

          const SizedBox(height: 10),

          // Bug Sender Card
          _buildAksiCepatCard(
            icon: Icons.wifi_tethering_rounded,
            iconColor: lightRed,
            iconBg: const Color(0xFF2A0A0A),
            title: "Bug Sender",
            subtitle: "Kelola WhatsApp sender aktif",
            buttonLabel: "Buka",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BugSenderPage(
                    sessionKey: sessionKey,
                    username: username,
                    role: role,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 10),

          // === CARD UCAPAN ===
          _buildAksiCepatCard(
            icon: Icons.card_giftcard_rounded,
            iconColor: const Color(0xFFFFB74D),
            iconBg: const Color(0xFF2D1F0A),
            title: "Ucapan",
            subtitle: "Kirim ucapan spesial untuk teman",
            buttonLabel: "Buka",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UcapanPage(),
                ),
              );
            },
          ),

          const SizedBox(height: 10),

          // === CARD TOKO (BARU) ===
          _buildAksiCepatCard(
            icon: Icons.shopping_bag_rounded,
            iconColor: const Color(0xFF4CAF50),
            iconBg: const Color(0xFF0A2E1A),
            title: "Toko",
            subtitle: "Belanja produk eksklusif",
            buttonLabel: "Lihat",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TokoPage(),
                ),
              );
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ===================== AKSI CEPAT CARD =====================
  Widget _buildAksiCepatCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardGlass,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderGlass, width: 1),
          boxShadow: [BoxShadow(color: redGlow, blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderGlass)),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Orbitron')),
                  const SizedBox(height: 3),
                  Text(subtitle, style: TextStyle(color: accentGrey, fontSize: 12, fontFamily: 'ShareTechMono')),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: primaryRed.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primaryRed.withOpacity(0.5)),
                ),
                child: Text(buttonLabel, style: TextStyle(color: lightRed, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Orbitron')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== STAT ITEM =====================
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Icon(icon, color: primaryRed, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(color: primaryWhite, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'ShareTechMono')),
              Text(label, style: TextStyle(color: accentGrey, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  // ===================== DRAWER =====================
  Widget _buildCustomDrawer() {
    return Drawer(
      backgroundColor: bgDark,
      width: MediaQuery.of(context).size.width * 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 250,
            color: Colors.black,
            child: Stack(
              children: [
                if (_menuVideoController != null && _menuVideoController!.value.isInitialized)
                  SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _menuVideoController!.value.size.width,
                        height: _menuVideoController!.value.size.height,
                        child: VideoPlayer(_menuVideoController!),
                      ),
                    ),
                  ),
                Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.2), Colors.black.withOpacity(0.85)]))),
                SafeArea(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: primaryRed, width: 2.5), boxShadow: [BoxShadow(color: redGlow, blurRadius: 18, spreadRadius: 2)]),
                          child: ClipOval(
                            child: _profileImage != null ? Image.file(_profileImage!, fit: BoxFit.cover) : Image.asset('assets/images/logo.png', fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text("Halo, $username 👋", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Orbitron')),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(width: 7, height: 7, decoration: BoxDecoration(color: liveGreen, shape: BoxShape.circle)),
                            const SizedBox(width: 5),
                            Text("${role.toUpperCase()} · Exp: $expiredDate", style: TextStyle(color: accentGrey, fontSize: 12, fontFamily: 'ShareTechMono')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: bgDark,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                children: [
                  if (role == "reseller") _buildDrawerMenuItem(icon: Icons.storefront, label: "Seller Page", onTap: () => _onSidebarTabSelected(1)),
                  if (role == "admin") _buildDrawerMenuItem(icon: Icons.admin_panel_settings, label: "Admin Page", onTap: () => _onSidebarTabSelected(2)),
                  if (role == "owner") _buildDrawerMenuItem(icon: Icons.workspace_premium, label: "Owner Page", onTap: () => _onSidebarTabSelected(3)),
                  _buildDrawerMenuItem(
                    icon: Icons.history_rounded,
                    label: "Riwayat Aktivitas",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => RiwayatPage(sessionKey: sessionKey, role: role)));
                    },
                  ),
                  _buildDrawerMenuItem(
                    icon: Icons.send_rounded,
                    label: "Manage Sender",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => BugSenderPage(sessionKey: sessionKey, username: username, role: role)));
                    },
                  ),
                  _buildDrawerMenuItem(
                    icon: Icons.shopping_bag_rounded,
                    label: "Toko",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const TokoPage()));
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildDrawerMenuItem(
                    icon: Icons.logout,
                    label: "Log Out",
                    isLogout: true,
                    onTap: () async {
                      Navigator.pop(context);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();
                      if (!mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isLogout ? Colors.red.withOpacity(0.15) : cardGlass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isLogout ? Colors.red.withOpacity(0.4) : borderGlass),
      ),
      child: ListTile(
        leading: Icon(icon, color: isLogout ? Colors.redAccent : primaryRed, size: 22),
        title: Text(label, style: TextStyle(color: isLogout ? Colors.redAccent : primaryWhite, fontWeight: FontWeight.w600, fontSize: 15, fontFamily: 'Orbitron')),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onTap: onTap,
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case "owner": return Colors.white;
      case "vip": return Colors.white70;
      case "reseller": return Colors.lightGreenAccent;
      case "premium": return Colors.orangeAccent;
      default: return Colors.white54;
    }
  }

  // ===================== BUILD =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: bgDark.withOpacity(0.92),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Halo, $username 👋", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17, fontFamily: 'Orbitron')),
            Row(
              children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: liveGreen, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text("${role.toUpperCase()} · Exp: $expiredDate", style: TextStyle(color: accentGrey, fontSize: 11, fontFamily: 'ShareTechMono')),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: primaryRed, width: 1.5), boxShadow: [BoxShadow(color: redGlow, blurRadius: 8)]),
              child: ClipOval(child: Image.asset('assets/images/logo.png', fit: BoxFit.cover)),
            ),
          ),
          IconButton(icon: Icon(Icons.headset_mic_outlined, color: primaryWhite), tooltip: 'Customer Service', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ContactPage()))),
          IconButton(icon: const Icon(FontAwesomeIcons.userCircle, color: Colors.white), tooltip: 'My Profile', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(username: username, password: password, role: role, expiredDate: expiredDate, sessionKey: sessionKey)))),
        ],
      ),
      drawer: _buildCustomDrawer(),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [bgDark, primaryDark, bgDark])),
        child: SafeArea(child: FadeTransition(opacity: _animation, child: _selectedPage)),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: primaryDark, border: Border(top: BorderSide(color: borderGlass)), boxShadow: [BoxShadow(color: redGlow, blurRadius: 12, offset: const Offset(0, -2))]),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          selectedItemColor: lightRed,
          unselectedItemColor: accentGrey,
          currentIndex: _bottomNavIndex,
          onTap: _onBottomNavTapped,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Orbitron', fontSize: 10),
          unselectedLabelStyle: const TextStyle(fontSize: 10, fontFamily: 'Orbitron'),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "Home"),
            BottomNavigationBarItem(icon: Icon(FontAwesomeIcons.whatsapp), label: "WA Blast"),
            BottomNavigationBarItem(icon: Icon(Icons.campaign_outlined), label: "Info"),
            BottomNavigationBarItem(icon: Icon(Icons.tune_rounded), label: "Tools"),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    channel.sink.close(status.goingAway);
    _controller.dispose();
    _menuVideoController?.dispose();
    super.dispose();
  }
}

// ===================== NEWS MEDIA WIDGET =====================
class NewsMedia extends StatefulWidget {
  final String url;
  const NewsMedia({super.key, required this.url});

  @override
  State<NewsMedia> createState() => _NewsMediaState();
}

class _NewsMediaState extends State<NewsMedia> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    if (_isVideo(widget.url)) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          setState(() {});
          _controller?.setLooping(true);
          _controller?.setVolume(0.0);
          _controller?.play();
        });
    }
  }

  bool _isVideo(String url) {
    return url.endsWith(".mp4") || url.endsWith(".webm") || url.endsWith(".mov") || url.endsWith(".mkv");
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isVideo(widget.url)) {
      if (_controller != null && _controller!.value.isInitialized) {
        return AspectRatio(aspectRatio: _controller!.value.aspectRatio, child: VideoPlayer(_controller!));
      } else {
        return const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)));
      }
    } else {
      return Image.network(
        widget.url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: const Color(0xFF2A1515), child: const Icon(Icons.broken_image, color: Colors.white38)),
      );
    }
  }
}

// ===================== HALAMAN UCAPAN =====================
class UcapanPage extends StatefulWidget {
  const UcapanPage({super.key});

  @override
  State<UcapanPage> createState() => _UcapanPageState();
}

class _UcapanPageState extends State<UcapanPage> {
  List<Map<String, String>> _ucapanList = [
    {'nama': 'Developer', 'pesan': 'Developer Ganteng @Adezgtg 🎉', 'waktu': '2 jam lalu'},
    {'nama': 'Yonn', 'pesan': 'Sukses terus buat aplikasinya, mantap! 🚀', 'waktu': 'kemarin'},
    {'nama': 'RS', 'pesan': 'Terima kasih atas bantuannya, sangat berkesan ❤️', 'waktu': '3 hari lalu'},
  ];

  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _pesanController = TextEditingController();

  void _tambahUcapan() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A0A0A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Tambah Ucapan', style: TextStyle(color: Colors.white, fontFamily: 'Orbitron')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _namaController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Nama Anda',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                filled: true,
                fillColor: const Color(0xFF2A1515),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pesanController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Tulis ucapan...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                filled: true,
                fillColor: const Color(0xFF2A1515),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              if (_namaController.text.isNotEmpty && _pesanController.text.isNotEmpty) {
                setState(() {
                  _ucapanList.insert(0, {'nama': _namaController.text, 'pesan': _pesanController.text, 'waktu': 'baru saja'});
                });
                _namaController.clear();
                _pesanController.clear();
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB71C1C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Kirim', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _hapusUcapan(int index) => setState(() => _ucapanList.removeAt(index));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Ucapan', style: TextStyle(fontFamily: 'Orbitron', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        actions: [IconButton(icon: const Icon(Icons.add, color: Color(0xFFE53935)), onPressed: _tambahUcapan, tooltip: 'Tambah Ucapan')],
      ),
      body: _ucapanList.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.card_giftcard_rounded, size: 80, color: Color(0xFFFFB74D)),
                  const SizedBox(height: 20),
                  Text('Belum ada ucapan', style: TextStyle(color: Colors.grey.shade400, fontSize: 16, fontFamily: 'Orbitron')),
                  const SizedBox(height: 10),
                  TextButton.icon(onPressed: _tambahUcapan, icon: const Icon(Icons.add, color: Color(0xFFE53935)), label: const Text('Buat ucapan pertama', style: TextStyle(color: Color(0xFFE53935)))),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _ucapanList.length,
              itemBuilder: (context, index) {
                final ucapan = _ucapanList[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A0A0A),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF4A2020)),
                    boxShadow: [BoxShadow(color: const Color(0x55D32F2F), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(backgroundColor: const Color(0xFFB71C1C), child: Text(ucapan['nama']![0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    title: Text(ucapan['nama']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Orbitron')),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(ucapan['pesan']!, style: TextStyle(color: Colors.grey.shade300, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(ucapan['waktu']!, style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontFamily: 'ShareTechMono')),
                      ],
                    ),
                    trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _hapusUcapan(index)),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(onPressed: _tambahUcapan, backgroundColor: const Color(0xFFB71C1C), child: const Icon(Icons.add, color: Colors.white)),
    );
  }
}

// ===================== HALAMAN TOKO =====================
class TokoPage extends StatelessWidget {
  const TokoPage({super.key});

  final List<Map<String, dynamic>> produkList = const [
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Toko', style: TextStyle(fontFamily: 'Orbitron', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        itemCount: produkList.length,
        itemBuilder: (context, index) {
          final produk = produkList[index];
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A0A0A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF4A2020)),
              boxShadow: [BoxShadow(color: const Color(0x55D32F2F), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18)),
                  child: Image.network(
                    produk['gambar'],
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(height: 120, color: Colors.grey.shade800, child: const Icon(Icons.image_not_supported, color: Colors.white38)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(produk['nama'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Orbitron'), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(produk['deskripsi'], style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontFamily: 'ShareTechMono'), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(produk['harga'], style: const TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Orbitron')),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFB71C1C).withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFB71C1C).withOpacity(0.5))),
                            child: const Text('Beli', style: TextStyle(color: Color(0xFFE53935), fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}