import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/theme.dart';
import 'ui/app_shell.dart';
import 'ui/screens/home/home_screen.dart';
import 'ui/screens/tab_screens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // TV: immersive, no system chrome.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const NuvioApp());
}

class NuvioApp extends StatelessWidget {
  const NuvioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nuvio',
      debugShowCheckedModeBanner: false,
      theme: buildNuvioTheme(),
      home: const AppShell(
        tabContentBuilders: {
          NuvioTab.home: _buildHome,
          NuvioTab.search: _buildSearch,
          NuvioTab.library: _buildLibrary,
          NuvioTab.settings: _buildSettings,
        },
      ),
    );
  }

  static Widget _buildHome(BuildContext context) => const HomeScreen();
  static Widget _buildSearch(BuildContext context) => const SearchScreen();
  static Widget _buildLibrary(BuildContext context) => const LibraryScreen();
  static Widget _buildSettings(BuildContext context) => const SettingsScreen();
}
