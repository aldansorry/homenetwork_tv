import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../constants/app_constants.dart';
import '../constants/tv_constants.dart';

class WebviewPage extends StatefulWidget {
  final String url;

  const WebviewPage({super.key, required this.url});

  @override
  State<WebviewPage> createState() => _WebviewPageState();
}

class _WebviewPageState extends State<WebviewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _handleKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.goBack ||
          event.logicalKey == LogicalKeyboardKey.browserBack ||
          event.logicalKey == LogicalKeyboardKey.backspace) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      autofocus: true,
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: const Color(AppConstants.colorBackgroundDark),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(AppConstants.colorPrimaryRed),
                  ),
                ),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.web, color: Colors.white),
                        SizedBox(width: 8),
                        Text("Web Interface", style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
