import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/config/app_constants.dart';
import 'data/services/app_state_service.dart';
import 'presentation/providers/providers.dart';
import 'presentation/pages/main_navigation.dart';
import 'presentation/pages/onboarding_page.dart';
import 'presentation/pages/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file
  await dotenv.load(fileName: '.env');

  // Initialize AppState Service
  final appStateService = AppStateService();
  await appStateService.init();

  // Initialize Supabase (auto-handles JWT session persistence)
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  runApp(
    ProviderScope(
      overrides: [
        onboardingServiceProvider.overrideWithValue(appStateService),
      ],
      child: MyApp(appStateService: appStateService),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  final AppStateService appStateService;

  const MyApp({super.key, required this.appStateService});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  bool? _onboardingCompleted; // เก็บค่าไว้ใน state

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Load environment variables first
      await AppConstants.initialize();

      // Initialize Hive
      final hiveService = ref.read(hiveServiceProvider);
      await hiveService.initialize();

      // Check onboarding status
      _checkOnboarding();

      ref.read(appInitializationProvider.notifier).state = AppInitialization.initialized;
    } catch (e) {
      ref.read(appInitializationProvider.notifier).state =
          AppInitialization(isInitialized: false, error: e.toString());
      debugPrint('Failed to initialize app: $e');
    }
  }

  Future<void> _checkOnboarding() async {
    // เช็คครั้งเดียวตอนเริ่มแอป พร้อมหน่วงเวลาขั้นต่ำเพื่อให้เห็น Splash Screen ชัดเจนและสมูท
    final results = await Future.wait([
      widget.appStateService.isOnboardingCompleted(),
      Future.delayed(const Duration(milliseconds: 1500)),
    ]);
    final completed = results[0] as bool;
    if (mounted) {
      setState(() => _onboardingCompleted = completed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initializationState = ref.watch(appInitializationProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Starmory',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        actionIconTheme: ActionIconThemeData(
          backButtonIconBuilder: (context) =>
              const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF1F2937)),
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
        actionIconTheme: ActionIconThemeData(
          backButtonIconBuilder: (context) =>
              const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF1F2937)),
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
    // Show splash screen while loading and checking onboarding
    if (_onboardingCompleted == null) {
      currentScreen = const SplashScreen(key: ValueKey('splash'));
    } else if (_onboardingCompleted!) {
      currentScreen = const MainNavigationScreen(key: ValueKey('main_nav'));
    } else {
      currentScreen = const OnboardingPage(key: ValueKey('onboarding'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
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
