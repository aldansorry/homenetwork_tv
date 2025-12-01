import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_page.dart';
import 'movie_list_page.dart';
import 'music_player_page.dart';
import 'settings_page.dart';
import '../constants/tv_constants.dart';
import '../constants/app_constants.dart';
import '../widgets/tv_focusable_widget.dart';

class MainMenu extends StatefulWidget {
  const MainMenu({super.key});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  int _selectedIndex = 0;
  final List<FocusNode> _menuFocusNodes = [];

  final List<Map<String, dynamic>> _menuItems = [
    {'icon': Icons.home, 'label': 'Home'},
    {'icon': Icons.movie, 'label': 'Movie'},
    {'icon': Icons.music_note, 'label': 'Music'},
    {'icon': Icons.settings, 'label': 'Settings'},
  ];

  final List<Widget> _pages = const [
    HomePage(),
    MovieListPage(),
    MusicPlayerPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    // Initialize focus nodes for menu items
    for (int i = 0; i < _menuItems.length; i++) {
      _menuFocusNodes.add(FocusNode());
    }
    // Auto focus first item
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _menuFocusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (var node in _menuFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onItemSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowLeft:
          if (_selectedIndex > 0) {
            _onItemSelected(_selectedIndex - 1);
            _menuFocusNodes[_selectedIndex].requestFocus();
          }
          break;
        case LogicalKeyboardKey.arrowRight:
          if (_selectedIndex < _menuItems.length - 1) {
            _onItemSelected(_selectedIndex + 1);
            _menuFocusNodes[_selectedIndex].requestFocus();
          }
          break;
        case LogicalKeyboardKey.select:
        case LogicalKeyboardKey.enter:
          _onItemSelected(_selectedIndex);
          break;
        default:
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(AppConstants.colorBackgroundDark),
        body: Row(
          children: [
            // TV-optimized sidebar navigation
            Container(
              width: 300,
              color: const Color(AppConstants.colorCardDark),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(TvConstants.tvSpacingLarge),
                      child: const Text(
                        'HomeNetwork',
                        style: TextStyle(
                          fontSize: TvConstants.tvFontSizeTitle,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Divider(color: Colors.white24),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(TvConstants.tvSpacingMedium),
                        itemCount: _menuItems.length,
                        itemBuilder: (context, index) {
                          final item = _menuItems[index];
                          final isSelected = index == _selectedIndex;
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: TvConstants.tvSpacingMedium,
                            ),
                            child: TvFocusableWidget(
                              focusNode: _menuFocusNodes[index],
                              autofocus: index == 0,
                              onTap: () => _onItemSelected(index),
                              child: Container(
                                padding: const EdgeInsets.all(TvConstants.tvSpacingMedium),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Color(TvConstants.tvFocusColor)
                                          .withOpacity(0.3)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      item['icon'] as IconData,
                                      size: TvConstants.tvIconSizeLarge,
                                      color: isSelected
                                          ? Color(TvConstants.tvFocusColor)
                                          : Colors.white70,
                                    ),
                                    const SizedBox(width: TvConstants.tvSpacingMedium),
                                    Text(
                                      item['label'] as String,
                                      style: TextStyle(
                                        fontSize: TvConstants.tvFontSizeBody,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Main content area
            Expanded(
              child: _pages[_selectedIndex],
            ),
          ],
        ),
      ),
    );
  }
}
