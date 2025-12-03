import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'pages/main_menu.dart';
import 'constants/tv_constants.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  // Enable TV mode
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  
  runApp(const HomeNetworkApp());
}

class HomeNetworkApp extends StatelessWidget {
  const HomeNetworkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HomeNetwork TV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: false,
        brightness: Brightness.dark,
        primarySwatch: Colors.red,
        primaryColor: Color(TvConstants.tvFocusColor),
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        // TV-optimized text theme
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: TvConstants.tvFontSizeTitle,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          displayMedium: TextStyle(
            fontSize: TvConstants.tvFontSizeSubtitle,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          bodyLarge: TextStyle(
            fontSize: TvConstants.tvFontSizeBody,
            color: Colors.white70,
          ),
          bodyMedium: TextStyle(
            fontSize: TvConstants.tvFontSizeSmall,
            color: Colors.white70,
          ),
        ),
        // TV-optimized button theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(
              TvConstants.tvButtonMinWidth,
              TvConstants.tvButtonHeight,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: TvConstants.tvSpacingMedium,
              vertical: TvConstants.tvSpacingSmall,
            ),
            textStyle: const TextStyle(
              fontSize: TvConstants.tvFontSizeBody,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // TV-optimized card theme
        cardTheme: const CardThemeData(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          margin: EdgeInsets.all(TvConstants.tvSpacingMedium),
        ),
      ),
      home: const MainMenu(),
    );
  }
}
