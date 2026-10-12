import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/routes/app_router.dart';
import 'core/localization/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'providers/app_state.dart';
import 'services/report_storage_service.dart';

const _missingSupabaseConfigurationMessage =
    'Supabase report storage is unavailable. Configure SUPABASE_URL and '
    'SUPABASE_ANON_KEY with --dart-define to upload or download report files.';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error) {
    runApp(StartupErrorApp(message: error.toString()));
    return;
  }
  final reportStorageService = await _initializeReportStorage();
  runApp(
    EClinicApp(
      state: AppState.withFirebaseAuth(
        reportStorageService: reportStorageService,
      ),
    ),
  );
}

Future<ReportStorageService> _initializeReportStorage() async {
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    return UnavailableReportStorageService(
      _missingSupabaseConfigurationMessage,
    );
  }

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
      accessToken: () async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return null;
        final token = await user.getIdTokenResult();
        if (token.claims?['role'] != 'authenticated') {
          throw StateError(
            'Firebase ID token is missing the Supabase role claim. '
            'Run the trusted Supabase claims sync script, then sign in again.',
          );
        }
        return token.token;
      },
    );
    return SupabaseReportStorageService(Supabase.instance.client);
  } catch (error, stackTrace) {
    debugPrint('[Supabase] initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    return UnavailableReportStorageService(
      'Supabase report storage could not be initialized: $error',
    );
  }
}

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'E-Clinic Book',
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'E-Clinic Book could not start',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Check your Firebase setup and try starting the app '
                      'again.',
                    ),
                    SelectableText(message),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class EClinicApp extends StatefulWidget {
  const EClinicApp({super.key, this.state});

  final AppState? state;

  @override
  State<EClinicApp> createState() => _EClinicAppState();
}

class _EClinicAppState extends State<EClinicApp> {
  late final AppState _state = (widget.state ??
      AppState.withFirebaseAuth(
        reportStorageService: UnavailableReportStorageService(
          _missingSupabaseConfigurationMessage,
        ),
      ))
    ..init();
  late final GoRouter _router = buildRouter(_state);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _state,
      child: Consumer<AppState>(
        builder: (context, state, _) => MaterialApp.router(
          title: 'E-Clinic Book',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode:
              state.darkModeEnabled ? ThemeMode.dark : ThemeMode.light,
          locale: state.appLocale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: _router,
        ),
      ),
    );
  }
}
