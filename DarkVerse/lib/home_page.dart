// home_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '.dart';

class HomePage extends StatefulWidget {
  final String username;
  final String password;
  final String sessionKey;
  final List<Map<String, dynamic>> listBug;
  final String role;
  final String expiredDate;

  const HomePage({
    super.key,
    required this.username,
    required this.password,
    required this.sessionKey,
    required this.listBug,
    required this.role,
    required this.expiredDate,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final targetController = TextEditingController();
  late AnimationController _pulseController;

  String selectedBugId = "";
  String _selectedBugMode = "number";
  bool _isSending = false;
  String? _responseMessage;
  
  // --- Sender Type Selection ---
  String _selectedSenderType = "private"; // 'private' or 'global'
  List<String> activeSenders = [];
  bool _isLoadingSenders = false;
  String? _senderError;

  // === TEMA WARNA MERAH GELAP ===
  final Color bgDark = Colors.black;
  final Color cardBg = const Color(0xFF1A0A0A);
  final Color primaryRed = const Color(0xFFB71C1C);
  final Color accentRed = const Color(0xFFE53935);
  final Color borderColor = const Color(0xFF3A1515);
  final Color redGlow = const Color(0x55D32F2F);
  final Color liveGreen = const Color(0xFF22C55E);
  final Color textWhite = Colors.white;
  final Color textGrey = const Color(0xFF9E9E9E);

  late VideoPlayerController _videoController;
  late ChewieController _chewieController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    if (widget.listBug.isNotEmpty) {
      selectedBugId = widget.listBug[0]['bug_id'];
    }

    _initializeVideoPlayer();
    _fetchActiveSenders();
  }

  void _initializeVideoPlayer() {
    _videoController = VideoPlayerController.asset('assets/videos/banner.mp4');
    _videoController.initialize().then((_) {
      setState(() {
        _videoController.setVolume(0.1);
        _chewieController = ChewieController(
          videoPlayerController: _videoController,
          autoPlay: true,
          looping: true,
          showControls: false,
          autoInitialize: true,
        );
        _isVideoInitialized = true;
      });
    }).catchError((e) {
      setState(() => _isVideoInitialized = false);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    targetController.dispose();
    _videoController.dispose();
    if (_isVideoInitialized) _chewieController.dispose();
    super.dispose();
  }

  String? formatPhoneNumber(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^\d+]'), '');
    if (!cleaned.startsWith('+') || cleaned.length < 8) return null;
    return cleaned;
  }

  bool isValidGroupLink(String input) {
    return input.contains('chat.whatsapp.com') && input.contains('https://');
  }

  Future<void> _fetchActiveSenders() async {
    setState(() {
      _isLoadingSenders = true;
      _senderError = null;
    });

    try {
      final res = await http.get(
        Uri.parse("$apiBaseUrl/mySender?key=${widget.sessionKey}"),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data["valid"] == true) {
          final globalConnections = data["globalConnections"] as List<dynamic>? ?? [];
          setState(() {
            activeSenders = globalConnections
                .whereType<Map>()
                .map(
                  (item) => item["sessionName"]?.toString() ?? 
                           item["id"]?.toString() ?? 
                           "Unknown",
                )
                .toList();
          });
        } else {
          setState(() {
            _senderError = data["message"] ?? "Gagal memuat sender aktif";
            activeSenders = [];
          });
        }
      } else {
        setState(() {
          _senderError = "Server error: ${res.statusCode}";
          activeSenders = [];
        });
      }
    } catch (e) {
      setState(() {
        _senderError = "Connection failed: $e";
        activeSenders = [];
      });
    } finally {
      setState(() {
        _isLoadingSenders = false;
      });
    }
  }

  Future<void> _sendBug() async {
    final rawInput = targetController.text.trim();
    final key = widget.sessionKey;

    if (_selectedBugMode == "number") {
      final target = formatPhoneNumber(rawInput);
      if (target == null || key.isEmpty) {
        _showAlert("❌ Invalid Number",
            "Gunakan nomor internasional (misal: +62, 1, 44), bukan 08xxx.");
        return;
      }
    } else {
      if (!isValidGroupLink(rawInput)) {
        _showAlert("❌ Invalid Link",
            "Masukkan link group WA yang valid (contoh: https://chat.whatsapp.com/...).");
        return;
      }
    }

    // Check if global sender is available when selected
    if (_selectedSenderType == "global" && activeSenders.isEmpty) {
      await _fetchActiveSenders();
      if (activeSenders.isEmpty) {
        _showAlert(
          "❌ Global Sender Kosong",
          "Belum ada global sender aktif saat ini.",
        );
        return;
      }
    }

    setState(() {
      _isSending = true;
      _responseMessage = null;
    });

    try {
      final res = await http.get(Uri.parse(
          "$apiBaseUrl/sendBug?key=$key&target=$rawInput&bug=$selectedBugId&senderType=$_selectedSenderType"));
      final data = jsonDecode(res.body);

      if (data["cooldown"] == true) {
        final wait = data["wait"];
        setState(() => _responseMessage = wait == null
            ? "⏳ Cooldown: Tunggu beberapa saat."
            : "⏳ Cooldown: tunggu $wait detik lagi.");
      } else if (data["valid"] == false) {
        setState(() => _responseMessage = "❌ Key Invalid: Silakan login ulang.");
      } else if (data["sended"] == false) {
        setState(() => _responseMessage = "⚠️ ${data["message"] ?? "Gagal mengirim bug."}");
      } else {
        final senderLabel = _selectedSenderType == "global" ? "global sender" : "sender pribadi";
        setState(() => _responseMessage = "✅ Berhasil mengirim bug dengan $senderLabel!");
        targetController.clear();
      }
    } catch (_) {
      setState(() => _responseMessage = "❌ Error: Terjadi kesalahan. Coba lagi.");
    } finally {
      setState(() => _isSending = false);
      if (_selectedSenderType == "global") {
        _fetchActiveSenders();
      }
    }
  }

  void _showAlert(String title, String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: primaryRed.withOpacity(0.5)),
        ),
        title: Text(title,
            style: TextStyle(
              color: accentRed,
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.bold,
            )),
        content: Text(msg,
            style: TextStyle(color: textGrey, fontFamily: 'ShareTechMono')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK",
                style: TextStyle(color: accentRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(color: redGlow, blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: primaryRed, width: 2.5),
              boxShadow: [
                BoxShadow(color: redGlow, blurRadius: 14, spreadRadius: 2),
              ],
            ),
            child: CircleAvatar(
              radius: 32,
              backgroundColor: Colors.transparent,
              backgroundImage: const AssetImage('assets/images/logo.png'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Orbitron',
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: primaryRed.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: primaryRed.withOpacity(0.5), width: 1),
                      ),
                      child: Text(
                        widget.role.toUpperCase(),
                        style: TextStyle(
                          color: accentRed,
                          fontFamily: 'Orbitron',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Exp: ${widget.expiredDate}",
                      style: TextStyle(
                        color: textGrey,
                        fontFamily: 'ShareTechMono',
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: liveGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: liveGreen.withOpacity(0.5), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: liveGreen,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: liveGreen, blurRadius: 5),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      "LIVE",
                      style: TextStyle(
                        color: liveGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Orbitron',
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (!_isVideoInitialized) {
      return Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Center(
          child: CircularProgressIndicator(color: accentRed, strokeWidth: 3),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: redGlow, blurRadius: 20, spreadRadius: 2),
        ],
        border: Border.all(color: primaryRed.withOpacity(0.4), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: _videoController.value.aspectRatio,
          child: Chewie(controller: _chewieController),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          _buildModeTab(
            label: "BUG NOMOR",
            icon: Icons.phone_android_rounded,
            mode: "number",
          ),
          _buildModeTab(
            label: "BUG GROUP",
            icon: Icons.group_rounded,
            mode: "group",
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required String label,
    required IconData icon,
    required String mode,
  }) {
    final isActive = _selectedBugMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedBugMode = mode;
          targetController.clear();
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? primaryRed : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive ? [BoxShadow(color: redGlow, blurRadius: 10)] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isActive ? Colors.white : textGrey, size: 18),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : textGrey,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  fontFamily: 'Orbitron',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSenderTypeSelector() {
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.swap_horiz_rounded, color: accentRed, size: 18),
              const SizedBox(width: 8),
              Text(
                "PILIH SENDER",
                style: TextStyle(
                  color: textWhite,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  fontFamily: 'Orbitron',
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedSenderType = "private"),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedSenderType == "private"
                          ? primaryRed.withOpacity(0.3)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedSenderType == "private"
                            ? accentRed
                            : borderColor,
                        width: _selectedSenderType == "private" ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.person_rounded,
                          color: _selectedSenderType == "private" ? accentRed : textGrey,
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "PRIVATE",
                          style: TextStyle(
                            color: _selectedSenderType == "private" ? accentRed : textGrey,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            fontFamily: 'Orbitron',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Sender pribadi",
                          style: TextStyle(color: textGrey, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedSenderType = "global");
                    if (activeSenders.isEmpty) {
                      _fetchActiveSenders();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedSenderType == "global"
                          ? primaryRed.withOpacity(0.3)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedSenderType == "global"
                            ? accentRed
                            : borderColor,
                        width: _selectedSenderType == "global" ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.public_rounded,
                          color: _selectedSenderType == "global" ? accentRed : textGrey,
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "GLOBAL",
                          style: TextStyle(
                            color: _selectedSenderType == "global" ? accentRed : textGrey,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            fontFamily: 'Orbitron',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Sender global aktif",
                          style: TextStyle(color: textGrey, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Active Senders Info
          if (_selectedSenderType == "global") ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        "SENDER AKTIF",
                        style: TextStyle(
                          color: textGrey,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Orbitron',
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _fetchActiveSenders,
                        icon: Icon(Icons.refresh_rounded, color: accentRed, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_isLoadingSenders)
                    const Center(
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (_senderError != null)
                    Text(
                      _senderError!,
                      style: TextStyle(color: accentRed, fontSize: 12),
                    )
                  else if (activeSenders.isEmpty)
                    Text(
                      "Tidak ada global sender aktif",
                      style: TextStyle(color: textGrey, fontSize: 12),
                    )
                  else
                    ...activeSenders.map((sender) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.circle, color: liveGreen, size: 8),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              sender,
                              style: TextStyle(color: textWhite, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: accentRed, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Menggunakan sender pribadi dari session Anda",
                      style: TextStyle(color: textGrey, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildModeSelector(),
        const SizedBox(height: 16),

        _buildSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _selectedBugMode == "number" ? Icons.phone_android_rounded : Icons.link_rounded,
                    color: accentRed,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _selectedBugMode == "number" ? "NOMOR TARGET" : "LINK GROUP WA",
                    style: TextStyle(
                      color: textWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      fontFamily: 'Orbitron',
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetController,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontFamily: 'ShareTechMono'),
                cursorColor: accentRed,
                keyboardType: _selectedBugMode == "number" ? TextInputType.phone : TextInputType.url,
                decoration: InputDecoration(
                  hintText: _selectedBugMode == "number" ? "Contoh: +62xxxxxxxxxx" : "Contoh: https://chat.whatsapp.com/...",
                  hintStyle: TextStyle(color: textGrey.withOpacity(0.5), fontSize: 13),
                  filled: true,
                  fillColor: bgDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderColor, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryRed, width: 2),
                  ),
                  prefixIcon: Icon(
                    _selectedBugMode == "number" ? Icons.phone_android_rounded : Icons.link_rounded,
                    color: accentRed,
                    size: 20,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        _buildSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.settings_rounded, color: accentRed, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "PILIH BUG",
                    style: TextStyle(
                      color: textWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      fontFamily: 'Orbitron',
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: bgDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    dropdownColor: cardBg,
                    value: selectedBugId.isNotEmpty ? selectedBugId : null,
                    isExpanded: true,
                    iconEnabledColor: accentRed,
                    iconSize: 26,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'ShareTechMono'),
                    items: widget.listBug.map((bug) {
                      return DropdownMenuItem<String>(
                        value: bug['bug_id'],
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: accentRed,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(bug['bug_name'], style: const TextStyle(color: Colors.white)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => selectedBugId = value ?? ""),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(color: redGlow, blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSendButton() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          height: 62,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [primaryRed, const Color(0xFFD32F2F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryRed.withOpacity(0.3 + _pulseController.value * 0.3),
                blurRadius: 20 + _pulseController.value * 10,
                spreadRadius: _pulseController.value * 2,
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isSending ? null : _sendBug,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 0,
            ),
            child: _isSending
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 22),
                      SizedBox(width: 12),
                      Text(
                        "SEND BUG ATTACK",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 2,
                          fontFamily: 'Orbitron',
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildResponseMessage() {
    if (_responseMessage == null) return const SizedBox.shrink();

    Color bg, border, text;
    IconData icon;

    if (_responseMessage!.startsWith('✅')) {
      bg = Colors.green.withOpacity(0.15);
      border = Colors.greenAccent;
      text = Colors.greenAccent;
      icon = Icons.check_circle_outline_rounded;
    } else if (_responseMessage!.startsWith('❌')) {
      bg = Colors.red.withOpacity(0.15);
      border = accentRed;
      text = accentRed;
      icon = Icons.error_outline_rounded;
    } else {
      bg = primaryRed.withOpacity(0.15);
      border = accentRed;
      text = accentRed;
      icon = Icons.info_outline_rounded;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, color: text, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _responseMessage!,
                style: TextStyle(
                  color: text,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  fontFamily: 'ShareTechMono',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderPanel(),
              const SizedBox(height: 16),
              _buildVideoPlayer(),
              const SizedBox(height: 16),
              _buildInputPanel(),
              const SizedBox(height: 16),
              _buildSenderTypeSelector(), // Added sender selector here
              const SizedBox(height: 24),
              _buildSendButton(),
              _buildResponseMessage(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}