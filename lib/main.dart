import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/storage/local_store.dart';
import 'core/theme/theme.dart';
import 'data/repositories/addon_repository_impl.dart';
import 'data/repositories/catalog_repository_impl.dart';
import 'state/detail_controller.dart' show watchedItemsStoreProvider;
import 'state/home_controller.dart'
    show watchProgressStoreProvider, addonRepositoryProvider;
import 'state/settings_controller.dart';
import 'ui/app_shell.dart';
import 'ui/screens/home/home_screen.dart';
import 'ui/screens/onboarding/onboarding_screens.dart';
import 'ui/screens/tab_screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // TV: immersive, no system chrome.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final store = await LocalStore.create();
  runApp(ProviderScope(
    overrides: [
      addonRepositoryProvider
          .overrideWithValue(LocalAddonRepository(store)),
      watchProgressStoreProvider
          .overrideWithValue(WatchProgressStore(store)),
      watchedItemsStoreProvider
          .overrideWithValue(WatchedItemsStore(store)),
      localStoreProvider.overrideWithValue(store),
    ],
    child: const NuvioApp(),
  ));
}

class NuvioApp extends StatelessWidget {
  const NuvioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nuvio',
      debugShowCheckedModeBanner: false,
      theme: buildNuvioTheme(),
      home: const _OnboardingGate(
        child: AppShell(
          tabContentBuilders: {
            NuvioTab.home: _buildHome,
            NuvioTab.search: _buildSearch,
            NuvioTab.library: _buildLibrary,
            NuvioTab.settings: _buildSettings,
          },
        ),
      ),
    );
  }

  static Widget _buildHome(BuildContext context) => const HomeScreen();
  static Widget _buildSearch(BuildContext context) => const SearchScreen();
  static Widget _buildLibrary(BuildContext context) => const LibraryScreen();
  static Widget _buildSettings(BuildContext context) => const SettingsScreen();
}

/// Shows onboarding on first launch (experience mode + addon setup).
class _OnboardingGate extends StatefulWidget {
  const _OnboardingGate({required this.child});

  final Widget child;

  @override
  State<_OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<_OnboardingGate> {
  bool? _onboarded;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_onboarded == null) {
      final store = ProviderScope.containerOf(context).read(localStoreProvider);
      _onboarded = store.getBool(StorageKeys.onboardingComplete) ?? false;
    }
  }

  void _completeOnboarding() async {
    final store = ProviderScope.containerOf(context).read(localStoreProvider);
    await store.setBool(StorageKeys.onboardingComplete, true);
    setState(() => _onboarded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_onboarded == false) {
      return ExperienceModeSelectionScreen(
        onSelected: (_) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => EssentialAddonSetupScreen(
              onFinished: _completeOnboarding,
            ),
          ));
        },
      );
    }
    return widget.child;
  }
}
