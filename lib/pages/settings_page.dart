import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/settings_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _backendUrlController = TextEditingController();
  final TextEditingController _youtubeController = TextEditingController();
  String message = "";
  bool isLoading = false;
  bool isSavingBackendUrl = false;

  @override
  void initState() {
    super.initState();
    _loadBackendUrl();
  }

  Future<void> _loadBackendUrl() async {
    final url = await SettingsService.getBackendUrl();
    if (mounted) {
      setState(() {
        _backendUrlController.text = url;
      });
    }
  }

  Future<void> saveBackendUrl() async {
    final url = _backendUrlController.text.trim();

    if (url.isEmpty) {
      setState(() => message = "Backend URL tidak boleh kosong");
      return;
    }

    // Validate URL format
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      setState(
        () => message = "URL harus dimulai dengan http:// atau https://",
      );
      return;
    }

    setState(() {
      isSavingBackendUrl = true;
      message = "";
    });

    try {
      final success = await SettingsService.setBackendUrl(url);
      if (success) {
        setState(() => message = "Backend URL berhasil disimpan");
      } else {
        setState(() => message = "Gagal menyimpan Backend URL");
      }
    } catch (e) {
      setState(() => message = "Error: $e");
    } finally {
      setState(() => isSavingBackendUrl = false);
    }
  }

  /// Cek apakah input cuma ID YouTube (11 karakter, alphanumeric + _ - )
  bool _isYoutubeId(String text) {
    final regex = RegExp(r'^[a-zA-Z0-9_-]{11}$');
    return regex.hasMatch(text);
  }

  Future<void> downloadAudio() async {
    String urlInput = _youtubeController.text.trim();

    if (urlInput.isEmpty) {
      setState(() => message = "URL kosong");
      return;
    }

    // Auto tambahkan prefix jika yang dimasukkan hanya ID
    if (_isYoutubeId(urlInput)) {
      urlInput = "https://www.youtube.com/watch?v=$urlInput";
    }

    final backendUrl = await SettingsService.getBackendUrl();
    final uri = Uri.parse("$backendUrl/downloader/youtube?url=$urlInput");

    setState(() {
      isLoading = true;
      message = "";
    });

    try {
      final response = await http.post(uri);

      if (response.statusCode == 200) {
        setState(() => message = "Berhasil");
      } else {
        setState(() => message = "Error saja");
      }
    } catch (e) {
      setState(() => message = "Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            children: [
              const Text(
                "Settings",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 30),

              // Backend URL Section
              const Text(
                "Backend URL",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _backendUrlController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Backend URL",
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintText: "http://localhost:3000",
                  hintStyle: const TextStyle(color: Colors.white38),
                  border: const OutlineInputBorder(),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white38),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFFF0000)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSavingBackendUrl ? null : saveBackendUrl,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF0000),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: isSavingBackendUrl
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text("Save Backend URL"),
                ),
              ),
              const SizedBox(height: 30),

              // YouTube Downloader Section
              const Text(
                "YouTube Downloader",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _youtubeController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Masukkan URL / YouTube ID",
                  labelStyle: const TextStyle(color: Colors.white70),
                  border: const OutlineInputBorder(),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white38),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFFF0000)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : downloadAudio,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF0000),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text("Download"),
                ),
              ),
              const SizedBox(height: 20),

              // Message
              if (message.isNotEmpty)
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: message.contains("berhasil") || message == "Berhasil"
                        ? Colors.green
                        : Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _backendUrlController.dispose();
    _youtubeController.dispose();
    super.dispose();
  }
}
