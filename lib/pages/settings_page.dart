import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../services/settings_service.dart';
import '../constants/app_constants.dart';
import '../constants/tv_constants.dart';
import '../utils/url_validator.dart';
import '../widgets/tv_button.dart';
import '../widgets/tv_focusable_widget.dart';

/// Settings page for configuring application settings
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _backendUrlController = TextEditingController();
  final TextEditingController _youtubeUrlController = TextEditingController();
  String _statusMessage = '';
  bool _isLoadingDownloader = false;
  bool _isSavingBackendUrl = false;

  @override
  void initState() {
    super.initState();
    _loadBackendUrl();
  }

  @override
  void dispose() {
    _backendUrlController.dispose();
    _youtubeUrlController.dispose();
    super.dispose();
  }

  /// Load current backend URL from settings
  Future<void> _loadBackendUrl() async {
    final url = await SettingsService.getBackendUrl();
    if (mounted) {
      setState(() {
        _backendUrlController.text = url;
      });
    }
  }

  /// Save backend URL to settings
  Future<void> _saveBackendUrl() async {
    final url = _backendUrlController.text.trim();

    if (url.isEmpty) {
      _showMessage('Backend URL tidak boleh kosong', isError: true);
      return;
    }

    if (!UrlValidator.isValidHttpUrl(url)) {
      _showMessage(
        'URL harus dimulai dengan http:// atau https://',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSavingBackendUrl = true;
      _statusMessage = '';
    });

    try {
      final success = await SettingsService.setBackendUrl(url);
      if (success) {
        _showMessage('Backend URL berhasil disimpan', isError: false);
      } else {
        _showMessage('Gagal menyimpan Backend URL', isError: true);
      }
    } catch (error) {
      _showMessage('Error: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSavingBackendUrl = false;
        });
      }
    }
  }

  /// Show status message
  void _showMessage(String message, {required bool isError}) {
    if (mounted) {
      setState(() {
        _statusMessage = message;
      });
    }
  }

  /// Check if input is YouTube ID (11 characters, alphanumeric + _ -)
  bool _isYouTubeId(String text) {
    final regex = RegExp(r'^[a-zA-Z0-9_-]{11}$');
    return regex.hasMatch(text);
  }

  /// Download audio from YouTube
  Future<void> _downloadAudioFromYouTube() async {
    String urlInput = _youtubeUrlController.text.trim();

    if (urlInput.isEmpty) {
      _showMessage('URL kosong', isError: true);
      return;
    }

    // Auto add prefix if input is only ID
    if (_isYouTubeId(urlInput)) {
      urlInput = 'https://www.youtube.com/watch?v=$urlInput';
    }

    final backendUrl = await SettingsService.getBackendUrl();
    final apiUrl =
        '$backendUrl${AppConstants.apiEndpointDownloaderYoutube}?url=$urlInput';

    setState(() {
      _isLoadingDownloader = true;
      _statusMessage = '';
    });

    try {
      final response = await http.post(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        _showMessage('Berhasil', isError: false);
      } else {
        _showMessage('Error: ${response.statusCode}', isError: true);
      }
    } catch (error) {
      _showMessage('Error: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDownloader = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.colorBackgroundDark),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(TvConstants.tvSafeAreaPadding),
          child: ListView(
            children: [
              _buildTitle(),
              const SizedBox(height: TvConstants.tvSpacingXLarge),
              _buildBackendUrlSection(),
              const SizedBox(height: TvConstants.tvSpacingXLarge),
              _buildYouTubeDownloaderSection(),
              const SizedBox(height: TvConstants.tvSpacingLarge),
              _buildStatusMessage(),
            ],
          ),
        ),
      ),
    );
  }

  /// Build page title
  Widget _buildTitle() {
    return Row(
      children: [
        // 🔙 Tombol Home
        TvFocusableWidget(
          onTap: () {
            Navigator.pop(context); // kembali ke Home
          },
          child: Container(
            padding: const EdgeInsets.all(TvConstants.tvSpacingSmall),
            decoration: BoxDecoration(
              color: Color(TvConstants.tvFocusColor).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.home,
              color: Colors.white,
              size: TvConstants.tvIconSizeLarge,
            ),
          ),
        ),

        const SizedBox(width: 16),

        // 🔡 Title Settings
        const Text(
          'Settings',
          style: TextStyle(
            fontSize: TvConstants.tvFontSizeTitle,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  /// Build backend URL configuration section
  Widget _buildBackendUrlSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Backend URL',
          style: TextStyle(
            fontSize: TvConstants.tvFontSizeSubtitle,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: TvConstants.tvSpacingSmall),
        TextField(
          controller: _backendUrlController,
          style: const TextStyle(
            color: Colors.white,
            fontSize: TvConstants.tvFontSizeBody,
          ),
          decoration: InputDecoration(
            labelText: 'Backend URL',
            labelStyle: const TextStyle(
              color: Colors.white70,
              fontSize: TvConstants.tvFontSizeBody,
            ),
            hintText: AppConstants.defaultBackendUrl,
            hintStyle: const TextStyle(
              color: Colors.white38,
              fontSize: TvConstants.tvFontSizeBody,
            ),
            border: const OutlineInputBorder(),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white38, width: 2),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(
                color: Color(AppConstants.colorPrimaryRed),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.all(TvConstants.tvSpacingMedium),
          ),
        ),
        const SizedBox(height: TvConstants.tvSpacingSmall),
        TvButton(
          label: 'Save Backend URL',
          icon: Icons.save,
          onPressed: _isSavingBackendUrl ? null : _saveBackendUrl,
          autofocus: true,
        ),
      ],
    );
  }

  /// Build YouTube downloader section
  Widget _buildYouTubeDownloaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'YouTube Downloader',
          style: TextStyle(
            fontSize: TvConstants.tvFontSizeSubtitle,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: TvConstants.tvSpacingSmall),
        TextField(
          controller: _youtubeUrlController,
          style: const TextStyle(
            color: Colors.white,
            fontSize: TvConstants.tvFontSizeBody,
          ),
          decoration: InputDecoration(
            labelText: 'Masukkan URL / YouTube ID',
            labelStyle: const TextStyle(
              color: Colors.white70,
              fontSize: TvConstants.tvFontSizeBody,
            ),
            border: const OutlineInputBorder(),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white38, width: 2),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(
                color: Color(AppConstants.colorPrimaryRed),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.all(TvConstants.tvSpacingMedium),
          ),
        ),
        const SizedBox(height: TvConstants.tvSpacingSmall),
        TvButton(
          label: 'Download',
          icon: Icons.download,
          onPressed: _isLoadingDownloader ? null : _downloadAudioFromYouTube,
        ),
      ],
    );
  }

  /// Build status message widget
  Widget _buildStatusMessage() {
    if (_statusMessage.isEmpty) return const SizedBox.shrink();

    final isSuccess =
        _statusMessage.contains('berhasil') || _statusMessage == 'Berhasil';

    return Text(
      _statusMessage,
      style: TextStyle(
        fontSize: 14,
        color: isSuccess ? Colors.green : Colors.red,
      ),
      textAlign: TextAlign.center,
    );
  }
}
