// bug_sender.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '.dart';

class BugSenderPage extends StatefulWidget {
  final String sessionKey;
  final String username;
  final String role;

  const BugSenderPage({
    super.key,
    required this.sessionKey,
    required this.username,
    required this.role,
  });

  @override
  State<BugSenderPage> createState() => _BugSenderPageState();
}

class _BugSenderPageState extends State<BugSenderPage> {
  // --- TEMA WARNA MERAH GELAP ---
  final Color bgDark = const Color(0xFF0A0000);       // Background hitam kemerahan
  final Color primaryRed = const Color(0xFFB71C1C);   // Merah gelap utama
  final Color accentRed = const Color(0xFFEF5350);    // Merah terang untuk aksen
  final Color lightRed = const Color(0xFFE53935);     // Merah lebih terang
  final Color primaryWhite = Colors.white;
  final Color textGrey = Colors.grey.shade400;
  final Color cardGlass = Colors.white.withOpacity(0.05);
  final Color borderGlass = Colors.white.withOpacity(0.1);

  List<dynamic> senderList = [];
  bool isLoading = false;
  String? errorMessage;

  bool get canAddGlobal =>
      ["owner", "developer"].contains(widget.role.toLowerCase());

  @override
  void initState() {
    super.initState();
    _fetchSenders();
  }

  Future<void> _fetchSenders() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final res = await http.get(
        Uri.parse("$apiBaseUrl/mySender?key=${widget.sessionKey}"),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data["valid"] == true) {
        final connections = data["connections"] as List<dynamic>? ?? [];
        connections.sort((a, b) {
          final ag = a["isGlobal"] == true ? 0 : 1;
          final bg = b["isGlobal"] == true ? 0 : 1;
          if (ag != bg) return ag.compareTo(bg);
          return (a["sessionName"] ?? "").toString().compareTo(
                (b["sessionName"] ?? "").toString(),
              );
        });
        setState(() => senderList = connections);
      } else {
        setState(
          () => errorMessage = data["message"] ?? "Failed to fetch senders",
        );
      }
    } catch (e) {
      setState(() => errorMessage = "Connection failed: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _addSender(String number, bool isGlobal) async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(
        Uri.parse(
          "$apiBaseUrl/getPairing?key=${widget.sessionKey}&number=$number&global=${isGlobal ? 1 : 0}",
        ),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data["valid"] == true) {
        _pairingDialog(number, data["pairingCode"].toString());
        _snack("Pairing code generated!");
      } else {
        _snack(data["message"] ?? "Failed to generate pairing code", err: true);
      }
    } catch (e) {
      _snack("Connection failed: $e", err: true);
    } finally {
      setState(() => isLoading = false);
      _fetchSenders();
    }
  }

  Future<void> _deleteSender(String id, bool isGlobal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: bgDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderGlass),
        ),
        title: const Text(
          "Confirm Delete",
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          isGlobal
              ? "Global sender ini akan dihapus untuk semua user."
              : "Delete sender ini?",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "DELETE",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => isLoading = true);
    try {
      final res = await http.delete(
        Uri.parse(
          "$apiBaseUrl/deleteSender?key=${widget.sessionKey}&id=$id&scope=${isGlobal ? 'global' : 'private'}",
        ),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data["valid"] == true) {
        _snack("Sender deleted successfully!");
        _fetchSenders();
      } else {
        _snack(data["message"] ?? "Failed to delete sender", err: true);
      }
    } catch (e) {
      _snack("Connection failed: $e", err: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _addDialog() {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (_) {
        var isGlobal = false;
        return StatefulBuilder(
          builder: (context, setLocal) => AlertDialog(
            backgroundColor: bgDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: borderGlass),
            ),
            title: Row(
              children: [
                Icon(Icons.add_circle, color: accentRed),
                const SizedBox(width: 12),
                const Text("Add Sender", style: TextStyle(color: Colors.white)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: c,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Enter phone number",
                    labelStyle: TextStyle(color: accentRed),
                    prefixIcon: Icon(Icons.phone, color: accentRed),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderGlass),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: accentRed, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  value: isGlobal,
                  onChanged: canAddGlobal
                      ? (v) => setLocal(() => isGlobal = v)
                      : null,
                  title: const Text(
                    "Global Sender",
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    canAddGlobal
                        ? "Tambah global sender untuk semua role."
                        : "Hanya owner & developer yang bisa add global sender.",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  activeColor: accentRed,
                  inactiveThumbColor: Colors.grey,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Semua role bisa memakai global sender, tapi yang boleh add cuma owner/developer.",
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("CANCEL", style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final number = c.text.trim();
                  if (number.isEmpty) {
                    _snack("Please enter phone number", err: true);
                    return;
                  }
                  if (isGlobal && !canAddGlobal) {
                    _snack(
                      "Hanya owner & developer yang dapat menambahkan Global Sender.",
                      err: true,
                    );
                    return;
                  }
                  Navigator.pop(context);
                  await _addSender(number, isGlobal);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryRed,
                  foregroundColor: primaryWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("SUBMIT"),
              ),
            ],
          ),
        );
      },
    );
  }

  void _pairingDialog(String number, String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: bgDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderGlass),
        ),
        title: const Text(
          "Pairing Required",
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Number: $number",
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accentRed, width: 2),
              ),
              child: SelectableText(
                code,
                style: TextStyle(
                  color: accentRed,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              _snack("Code copied to clipboard!");
            },
            child: Text("COPY", style: TextStyle(color: accentRed)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _fetchSenders();
            },
            child: const Text("CLOSE", style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, {bool err = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: err ? Colors.redAccent : primaryRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _card(Map<String, dynamic> s) {
    final name = (s["sessionName"] ?? "WhatsApp Sender").toString();
    final id = (s["id"] ?? name).toString();
    final isGlobal = s["isGlobal"] == true;
    final canDelete = s["canDelete"] != false;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardGlass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderGlass),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(isGlobal ? Icons.public : Icons.phone_android, color: accentRed),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isGlobal
                      ? accentRed.withOpacity(0.15)
                      : primaryRed.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isGlobal ? accentRed.withOpacity(0.5) : primaryRed.withOpacity(0.5),
                  ),
                ),
                child: Text(
                  isGlobal ? "GLOBAL" : "PRIVATE",
                  style: TextStyle(
                    color: isGlobal ? accentRed : primaryRed,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _fetchSenders,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text("REFRESH"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryWhite,
                    side: BorderSide(color: borderGlass),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: canDelete
                      ? () => _deleteSender(id, isGlobal)
                      : null,
                  icon: Icon(
                    canDelete ? Icons.delete_outline : Icons.lock_outline,
                    size: 16,
                  ),
                  label: Text(canDelete ? "DELETE" : "LOCKED"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canDelete
                        ? Colors.redAccent.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    foregroundColor: canDelete
                        ? Colors.redAccent
                        : Colors.white38,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        title: Text(
          "Manage Bug Sender",
          style: TextStyle(
            fontFamily: 'Orbitron',
            color: primaryWhite,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: accentRed.withOpacity(0.5), blurRadius: 10),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: accentRed),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: isLoading ? null : _fetchSenders,
            icon: Icon(Icons.refresh, color: accentRed),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardGlass,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderGlass),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: accentRed, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Global sender hanya bisa ditambah owner/developer, tapi semua role bisa memakai global sender.",
                    style: TextStyle(color: textGrey, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading && senderList.isEmpty
                ? Center(child: CircularProgressIndicator(color: accentRed))
                : errorMessage != null && senderList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: accentRed, size: 50),
                        const SizedBox(height: 16),
                        Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : senderList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.phone_android, color: accentRed.withOpacity(0.5), size: 60),
                        const SizedBox(height: 16),
                        const Text(
                          "No Senders Found",
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Tap + button to add your first sender",
                          style: TextStyle(color: textGrey, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchSenders,
                    color: accentRed,
                    backgroundColor: bgDark,
                    child: ListView.builder(
                      itemCount: senderList.length,
                      itemBuilder: (_, i) =>
                          _card(Map<String, dynamic>.from(senderList[i])),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [primaryRed, accentRed]),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: accentRed.withOpacity(0.4), blurRadius: 15, spreadRadius: 2),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _addDialog,
          backgroundColor: Colors.transparent,
          foregroundColor: primaryWhite,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}