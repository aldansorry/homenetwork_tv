import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _controller = TextEditingController();
  String message = "";
  bool isLoading = false;

  /// Cek apakah input cuma ID YouTube (11 karakter, alphanumeric + _ - )
  bool _isYoutubeId(String text) {
    final regex = RegExp(r'^[a-zA-Z0-9_-]{11}$');
    return regex.hasMatch(text);
  }

  Future<void> downloadAudio() async {
    String urlInput = _controller.text.trim();

    if (urlInput.isEmpty) {
      setState(() => message = "URL kosong");
      return;
    }

    // Auto tambahkan prefix jika yang dimasukkan hanya ID
    if (_isYoutubeId(urlInput)) {
      urlInput = "https://www.youtube.com/watch?v=$urlInput";
    }

    final uri = Uri.parse(
      "http://localhost:3000/downloader/youtube?url=$urlInput",
    );

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
      setState(() => message = "Error saja");
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Downloader",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 20),

          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: "Masukkan URL / YouTube ID",
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading ? null : downloadAudio,
              child: isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text("Submit"),
            ),
          ),

          const SizedBox(height: 20),

          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: message == "Berhasil" ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
