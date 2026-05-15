// landing.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // --- TEMA WARNA MERAH GELAP ---
  final Color primaryDark = const Color(0xFF000000); // Hitam pekat
  final Color primaryBlack = const Color(0xFF0A0A0A); // Hitam gelap
  final Color accentDark = const Color(0xFF1A0A0A); // Merah sangat gelap
  final Color glassBorder = Colors.white.withOpacity(0.08);
  final Color cardBg = Colors.white.withOpacity(0.03);
  final Color whiteAccent = Colors.white.withOpacity(0.9);
  final Color whiteMuted = Colors.white.withOpacity(0.6);
  final Color whiteDim = Colors.white.withOpacity(0.3);

  // Warna merah
  final Color primaryRed = const Color(0xFFB71C1C); // Merah gelap
  final Color darkRed = const Color(0xFF8B0000);    // Merah tua untuk gradien
  final Color redGlow = const Color(0xFFD32F2F).withOpacity(0.3);

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: const Offset(0, 0)).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception("Could not launch $uri");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryDark,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              primaryDark,
              primaryBlack,
              accentDark,
              primaryBlack,
              primaryDark,
            ],
            stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),

                    // --- FOTO DI TENGAH ATAS DENGAN GLOW MERAH ---
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [primaryRed, darkRed],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: redGlow,
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF000000),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              "assets/images/logo.png",
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: accentDark,
                                  child: Icon(
                                    Icons.person,
                                    size: 60,
                                    color: primaryRed,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // --- GARIS DEKORASI MERAH ---
                    Container(
                      width: 50,
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryRed, darkRed],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // --- LOGO VORLEXZ STARS ---
                    Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [Colors.white, primaryRed],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: const Text(
                            "RED-CRASHER",
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: primaryRed.withOpacity(0.3)),
                          ),
                          child: Text(
                            "New Project Sanzz",
                            style: TextStyle(
                              fontSize: 11,
                              color: primaryRed.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // --- BADGES (Secure, Fast, Reliable) DENGAN AKSEN MERAH ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildBadge("Secure", Icons.security, primaryRed),
                        const SizedBox(width: 12),
                        _buildBadge("Fast", Icons.speed, primaryRed),
                        const SizedBox(width: 12),
                        _buildBadge("Reliable", Icons.verified, primaryRed),
                      ],
                    ),

                    const SizedBox(height: 50),

                    // --- TOMBOL SIGN IN (BERWARNA MERAH) ---
                    Container(
                      width: double.infinity,
                      height: 55,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryRed, darkRed],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: primaryRed.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pushNamed(context, "/login");
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                            const SizedBox(width: 10),
                            const Text(
                              "Sign In",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // --- TOMBOL BELI AKSES VIA TG (DENGAN BORDER MERAH) ---
                    Container(
                      width: double.infinity,
                      height: 55,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primaryRed.withOpacity(0.5)),
                      ),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => _openUrl("https://t.me/Sanzz_Reals01"),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FaIcon(FontAwesomeIcons.telegram, color: primaryRed, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              "Buy Access",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: primaryRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // --- TOMBOL HUBUNGI KAMI (TELEGRAM & WHATSAPP) DENGAN AKSEN MERAH ---
                    Row(
                      children: [
                        Expanded(
                          child: _buildContactButton(
                            icon: FontAwesomeIcons.telegram,
                            label: "Telegram",
                            url: "https://t.me/Sanzz_Reals01",
                            color: primaryRed,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _buildContactButton(
                            icon: FontAwesomeIcons.whatsapp,
                            label: "WhatsApp",
                            url: "https://wa.me/6288985106973",
                            color: primaryRed,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // --- FOOTER DENGAN TEKS MERAH MUDA ---
                    Text(
                      "© 2026 RED-CRASHER PROJECT",
                      style: TextStyle(
                        color: primaryRed.withOpacity(0.6),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, IconData icon, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accentColor, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: accentColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactButton({
    required IconData icon,
    required String label,
    required String url,
    required Color color,
  }) {
    return InkWell(
      onTap: () => _openUrl(url),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}