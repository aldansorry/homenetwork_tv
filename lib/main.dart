import 'package:flutter/material.dart';
import 'pages/main_menu.dart';

void main() {
  runApp(const HomeNetworkApp());
}

class HomeNetworkApp extends StatelessWidget {
  const HomeNetworkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HomeNetwork',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: false),
      home: const MainMenu(),
    );
  }
}
