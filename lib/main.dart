import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:home_widget/home_widget.dart';

import 'constants/design_tokens.dart';
import 'core/config/app_constants.dart';
import 'core/services/widget_service.dart';
import 'data/services/app_state_service.dart';
import 'presentation/providers/providers.dart';
import 'presentation/pages/main_navigation.dart';
import 'presentation/pages/onboarding_page.dart';
import 'presentation/pages/splash_screen.dart';

/// Top-level background callback — called by WorkManager via home_widget
/// when the periodic refresh fires. Must be top-level (not inside a class).
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  // Background task: just push empty state — full refresh happens on app open.
  // For a richer background refresh, initialize Hive and call WidgetService here.
  // Keeping it minimal prevents battery drain.
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Load .env file
  await dotenv.load(fileName: '.env');

  // Initialize AppState Service
  final appStateService = AppStateService();
  await appStateService.init();

  // Initialize Supabase (auto-handles JWT session persistence)
  // ignore: deprecated_member_use
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  // Pre-resolve onboarding status before runApp so first frame goes directly to the app
  final onboardingCompleted = await appStateService.isOnboardingCompleted();

  // Initialize Home Screen Widget bridge
  await WidgetService.initialize();
  // Register interactivity callback so WorkManager can trigger widget updates
  HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
  Uri? initialWidgetUri;
  try {
    initialWidgetUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
  } catch (error, stackTrace) {
    debugPrint('Failed to retrieve initial widget URI: $error\n$stackTrace');
  }
  runApp(
    ProviderScope(
      overrides: [
        onboardingServiceProvider.overrideWithValue(appStateService),
      ],
      child: MyApp(
        appStateService: appStateService,
        initialOnboardingCompleted: onboardingCompleted,
        initialWidgetUri: initialWidgetUri,
      ),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  final AppStateService appStateService;
  final bool? initialOnboardingCompleted;
  final Uri? initialWidgetUri;

  const MyApp({
    super.key,
    required this.appStateService,
    this.initialOnboardingCompleted,
    this.initialWidgetUri,
  });

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  bool? _onboardingCompleted; // เก็บค่าไว้ใน state
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  Uri? _widgetLaunchUri;
  StreamSubscription<Uri?>? _widgetClickSubscription;
  String? _lastWidgetUri;
  DateTime? _lastWidgetUriTime;

  @override
  void initState() {
    super.initState();
    _onboardingCompleted = widget.initialOnboardingCompleted;
    _widgetLaunchUri = widget.initialWidgetUri;
    if (_widgetLaunchUri?.scheme == 'starmory') {
      _lastWidgetUri = _widgetLaunchUri.toString();
      _lastWidgetUriTime = DateTime.now();
    }
    _widgetClickSubscription = HomeWidget.widgetClicked.listen(
      _handleWidgetClick,
      onError: (Object error) {
        debugPrint('Failed to receive widget launch URI: $error');
      },
    );
    _initializeApp();
  }

  void _handleWidgetClick(Uri? uri) {
    if (!mounted || uri?.scheme != 'starmory') return;

    final uriString = uri.toString();
    final now = DateTime.now();
    if (_lastWidgetUri == uriString &&
        _lastWidgetUriTime != null &&
        now.difference(_lastWidgetUriTime!).inMilliseconds < 2000) {
      return;
    }
    _lastWidgetUri = uriString;
    _lastWidgetUriTime = now;
    _widgetLaunchUri = uri;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ref.read(appInitializationProvider).isInitialized) {
        setState(() {});
        return;
      }
      final navigator = _navigatorKey.currentState;
      if (navigator == null) {
        setState(() {});
        return;
      }

      navigator.pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(
          builder: (_) => MainNavigationScreen(initialWidgetUri: uri),
        ),
        (_) => false,
      );
    });
  }

  @override
  void dispose() {
    _widgetClickSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      // Load environment variables first
      await AppConstants.initialize();

      // Initialize Hive
      final hiveService = ref.read(hiveServiceProvider);
      await hiveService.initialize();

      // Check onboarding status if not pre-resolved
      if (_onboardingCompleted == null) {
        final completed = await widget.appStateService.isOnboardingCompleted();
        if (mounted) {
          setState(() => _onboardingCompleted = completed);
        }
      }

      ref.read(appInitializationProvider.notifier).state =
          AppInitialization.initialized;
    } catch (e) {
      ref.read(appInitializationProvider.notifier).state =
          AppInitialization(isInitialized: false, error: e.toString());
      debugPrint('Failed to initialize app: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final initializationState = ref.watch(appInitializationProvider);

    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Starmory',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        dialogTheme: DesignTokens.dialogTheme,
        actionIconTheme: ActionIconThemeData(
          backButtonIconBuilder: (context) => const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: Color(0xFF1F2937)),
        ),
        textTheme: GoogleFonts.notoSansThaiTextTheme(
          GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        dialogTheme: DesignTokens.dialogTheme,
        actionIconTheme: ActionIconThemeData(
          backButtonIconBuilder: (context) => const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: Color(0xFF1F2937)),
        ),
        textTheme: GoogleFonts.notoSansThaiTextTheme(
          GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        ),
      ),
      themeMode: ThemeMode.system,
      home: _buildHome(initializationState),
    );
  }

  Widget _buildHome(AppInitialization initializationState) {
    // Show error screen if initialization failed
    if (initializationState.error != null) {
      return InitializationErrorScreen(error: initializationState.error!);
    }

    Widget currentScreen;
    if (_widgetLaunchUri?.scheme == 'starmory' &&
        initializationState.isInitialized) {
      currentScreen = MainNavigationScreen(
        key: const ValueKey('main_nav'),
        initialWidgetUri: _widgetLaunchUri,
      );
    } else if (_widgetLaunchUri?.scheme == 'starmory') {
      currentScreen = const SplashScreen(key: ValueKey('splash'));
    } else if (_onboardingCompleted == null) {
      // Show splash screen while loading and checking onboarding
      currentScreen = const SplashScreen(key: ValueKey('splash'));
    } else if (_onboardingCompleted!) {
      currentScreen = const MainNavigationScreen(key: ValueKey('main_nav'));
    } else {
      currentScreen = const OnboardingPage(key: ValueKey('onboarding'));
    }

    return AnimatedSwitcher(
      duration: _widgetLaunchUri?.scheme == 'starmory'
          ? Duration.zero
          : const Duration(milliseconds: 400),
      child: currentScreen,
    );
  }
}

/// Initialization Error Screen
class InitializationErrorScreen extends StatelessWidget {
  final String error;

  const InitializationErrorScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                'Initialization Failed',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
