import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'core/theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/onboarding_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/couple/couple_setup_screen.dart';
import 'screens/onboarding/guided_onboarding_screen.dart';
import 'screens/dashboard/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sharedPreferences = await SharedPreferences.getInstance();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Fallback if initializeApp fails
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkTheme = ref.watch(themeProvider);
    final authState = ref.watch(authStateProvider);
    final onboardingCompleted = ref.watch(onboardingCompletedProvider);
    final userProfileAsync = ref.watch(userProfileProvider);

    return MaterialApp(
      title: 'Kapookluxx',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDarkTheme ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) {
        return Container(
          color: isDarkTheme ? const Color(0xFF090A0F) : const Color(0xFFF1F5F9),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ClipRect(
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
      
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('th', 'TH'),
        Locale('en', 'US'),
      ],
      locale: const Locale('th', 'TH'),

      home: authState.when(
        data: (userId) {
          if (userId == null) {
            return const LoginScreen();
          } else {
            // Check couple room profile status
            return userProfileAsync.when(
              data: (profile) {
                if (profile == null || profile.coupleRoomId == null || profile.coupleRoomId!.isEmpty) {
                  return const CoupleSetupScreen();
                } else {
                  if (onboardingCompleted) {
                    return const MainNavigationScreen();
                  } else {
                    return const GuidedOnboardingScreen();
                  }
                }
              },
              loading: () => const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const CoupleSetupScreen(),
            );
          }
        },
        loading: () => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
        error: (err, stack) => Scaffold(
          body: Center(
            child: Text('เกิดข้อผิดพลาดในการโหลดระบบ: $err'),
          ),
        ),
      ),
    );
  }
}
