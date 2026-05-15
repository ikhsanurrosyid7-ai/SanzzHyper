// login_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'splash.dart';
import '.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final userController = TextEditingController();
  final passController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool isLoading = false;
  bool _obscurePassword = true;
  String? androidId;

  late AnimationController _controller;
  late Animation<double> _fadeAnim;

  // --- Tema Warna Merah Gelap ---
  final Color bgDark = const Color(0xFF0A0A0A);       // Hitam
  final Color bgSecondary = const Color(0xFF1A0A0A);  // Merah sangat gelap
  final Color primaryRed = const Color(0xFFB71C1C);   // Merah tua (primary)
  final Color accentRed = const Color(0xFFD32F2F);    // Merah terang (accent)
  final Color lightRed = const Color(0xFFE53935);     // Merah muda untuk hover/glow
  final Color whiteText = Colors.white;
  final Color grayText = Colors.white70;

  @override
  void initState() {
    super.initState();
    _initAnim();
    initLogin();
  }

  void _initAnim() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  Future<void> initLogin() async {
    androidId = await getAndroidId();

    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString("username");
    final savedPass = prefs.getString("password");
    final savedKey = prefs.getString("key");

    if (savedUser != null && savedPass != null && savedKey != null) {
      final uri = Uri.parse(
          "$apiBaseUrl/myInfo?username=$savedUser&password=$savedPass&androidId=$androidId&key=$savedKey");
      try {
        final res = await http.get(uri);
        final data = jsonDecode(res.body);
        if (data['valid'] == true && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => SplashScreen(
                username: savedUser,
                password: savedPass,
                role: data['role'],
                sessionKey: data['key'],
                expiredDate: data['expiredDate'],
                listBug: (data['listBug'] as List? ?? [])
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList(),
                listDoos: (data['listDDoS'] as List? ?? [])
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList(),
                news: (data['news'] as List? ?? [])
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList(),
              ),
            ),
          );
        }
      } catch (_) {}
    }
  }

  Future<String> getAndroidId() async {
    final deviceInfo = DeviceInfoPlugin();
    final android = await deviceInfo.androidInfo;
    return android.id ?? "unknown_device";
  }

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;

    final username = userController.text.trim();
    final password = passController.text.trim();

    setState(() => isLoading = true);

    try {
      final validate = await http.post(
        Uri.parse("$apiBaseUrl/validate"),
        body: {
          "username": username,
          "password": password,
          "androidId": androidId ?? "unknown_device",
        },
      );

      final validData = jsonDecode(validate.body);

      if (validData['expired'] == true) {
        _showPopup(
          title: "⏳ Akses Habis",
          message: "Masa akses Anda telah berakhir. Silakan perpanjang.",
          color: accentRed,
          showContact: true,
        );
      } else if (validData['valid'] != true) {
        final String errorMsg = (validData['message'] ?? "").toLowerCase();
        if (errorMsg.contains("perangkat") ||
            errorMsg.contains("device") ||
            errorMsg.contains("another")) {
          _showPopup(
            title: "⚠️ Sesi Aktif",
            message: "Akun ini sedang login di perangkat lain. Logout terlebih dahulu.",
            color: accentRed,
          );
        } else {
          _showPopup(
            title: "❌ Login Gagal",
            message: "Username atau password salah.",
            color: accentRed,
          );
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        prefs.setString("username", username);
        prefs.setString("password", password);
        prefs.setString("key", validData['key']);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => SplashScreen(
                username: username,
                password: password,
                role: validData['role'],
                sessionKey: validData['key'],
                expiredDate: validData['expiredDate'],
                listBug: (validData['listBug'] as List? ?? [])
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList(),
                listDoos: (validData['listDDoS'] as List? ?? [])
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList(),
                news: (validData['news'] as List? ?? [])
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList(),
              ),
            ),
          );
        }
      }
    } catch (e) {
      _showPopup(
        title: "⚠️ Koneksi Error",
        message: "Gagal terhubung ke server. Periksa internet Anda.",
        color: accentRed,
      );
    }

    setState(() => isLoading = false);
  }

  void _showPopup({
    required String title,
    required String message,
    Color color = Colors.redAccent,
    bool showContact = false,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          if (showContact)
            TextButton(
              onPressed: () async {
                await launchUrl(Uri.parse("https://t.me/Adezgtg"),
                    mode: LaunchMode.externalApplication);
              },
              child: Text("Hubungi Admin", style: TextStyle(color: accentRed)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Tutup", style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    userController.dispose();
    passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              bgDark,
              bgSecondary,
              const Color(0xFF1A0A0A),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Hero(
                      tag: "logo",
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: accentRed, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: accentRed.withOpacity(0.5),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    Text(
                      "Welcome Back",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: whiteText,
                        letterSpacing: 1.2,
                        shadows: [
                          Shadow(
                            color: accentRed.withOpacity(0.6),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Masuk ke akun Anda",
                      style: TextStyle(
                        color: grayText,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 48),

                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildInput(userController, "Username", Icons.person_outline),
                          const SizedBox(height: 20),
                          _buildInput(passController, "Password", Icons.lock_outline, true),
                          const SizedBox(height: 40),
                          _buildButton(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String label, IconData icon, [bool isPassword = false]) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: bgDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentRed.withOpacity(0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accentRed.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: lightRed.withOpacity(0.8)),
          prefixIcon: Icon(icon, color: accentRed),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white54,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return "$label tidak boleh kosong";
          return null;
        },
      ),
    );
  }

  Widget _buildButton() {
    final double fullButtonWidth = MediaQuery.of(context).size.width - 56;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isLoading ? 60 : fullButtonWidth,
      height: 58,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryRed, accentRed],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: accentRed.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : login,
          borderRadius: BorderRadius.circular(30),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    "Sign In",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}