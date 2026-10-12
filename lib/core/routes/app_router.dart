import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../localization/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../screens/auth/auth_screens.dart';
import '../../screens/doctor/doctor_screens.dart';
import '../../screens/doctor/add_visit_screen.dart';
import '../../screens/patient/patient_screens.dart';
import '../../screens/shared/shared_screens.dart';

typedef _Tab = (String label, IconData icon, String path);

const _patientTabs = <_Tab>[
  ('Home', Icons.home_outlined, '/patient/home'),
  ('Clinic Book', Icons.menu_book_outlined, '/patient/clinic-book'),
  ('Appointments', Icons.calendar_month_outlined, '/patient/appointments'),
  ('Reports', Icons.biotech_outlined, '/patient/reports'),
  ('Profile', Icons.person_outline, '/patient/profile'),
];

const _doctorTabs = <_Tab>[
  ('Home', Icons.home_outlined, '/doctor/home'),
  ('Patients', Icons.people_outline, '/doctor/patients'),
  ('Appointments', Icons.calendar_month_outlined, '/doctor/appointments'),
  ('Profile', Icons.person_outline, '/doctor/profile'),
];

class _NavShell extends StatelessWidget {
  final Widget child;
  final List<_Tab> tabs;
  const _NavShell({required this.child, required this.tabs});

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    final i = tabs.indexWhere((t) => loc.startsWith(t.$3));
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: i < 0 ? 0 : i,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (n) => context.go(tabs[n].$3),
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: Icon(t.$2),
              label: t.$1.localized(context),
            )
        ],
      ),
    );
  }
}

GoRouter buildRouter(AppState s) {
  const authPaths = ['/login', '/register', '/forgot'];
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: s,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (!s.isLoggedIn) return (loc == '/splash' || authPaths.contains(loc)) ? null : '/login';
      final home = s.isDoctor ? '/doctor/home' : '/patient/home';
      if (authPaths.contains(loc)) return home;
      // Role guards (swap for Firebase custom-claims checks later)
      if (loc.startsWith('/doctor') && !s.isDoctor) return home;
      if ((loc.startsWith('/patient') || loc == '/qr') && s.isDoctor) return home;
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/forgot', builder: (_, __) => const ForgotPasswordScreen()),
      ShellRoute(
        builder: (_, __, child) => _NavShell(tabs: _patientTabs, child: child),
        routes: [
          GoRoute(path: '/patient/home', builder: (_, __) => const PatientHomeScreen()),
          GoRoute(path: '/patient/clinic-book', builder: (_, __) => const ClinicBookScreen()),
          GoRoute(path: '/patient/appointments', builder: (_, __) => const PatientAppointmentsScreen()),
          GoRoute(path: '/patient/reports', builder: (_, __) => const ReportsScreen()),
          GoRoute(path: '/patient/profile', builder: (_, __) => const PatientProfileScreen()),
        ],
      ),
      GoRoute(path: '/patient/prescriptions', builder: (_, __) => const PrescriptionsScreen()),
      GoRoute(path: '/qr', builder: (_, __) => const PatientQrScreen()),
      ShellRoute(
        builder: (_, __, child) => _NavShell(tabs: _doctorTabs, child: child),
        routes: [
          GoRoute(path: '/doctor/home', builder: (_, __) => const DoctorHomeScreen()),
          GoRoute(path: '/doctor/patients', builder: (_, __) => const DoctorPatientsScreen()),
          GoRoute(path: '/doctor/appointments', builder: (_, __) => const DoctorAppointmentsScreen()),
          GoRoute(path: '/doctor/profile', builder: (_, __) => const DoctorProfileScreen()),
        ],
      ),
      GoRoute(path: '/doctor/patient/:id', builder: (_, st) => DoctorPatientScreen(patientId: st.pathParameters['id']!)),
      GoRoute(path: '/doctor/add-visit', builder: (_, st) => AddVisitScreen(patientId: st.uri.queryParameters['patientId'])),
      GoRoute(path: '/doctor/scan', builder: (_, __) => const QrScannerScreen()),
      // Shared (both roles)
      GoRoute(path: '/visit/:id', builder: (_, st) => VisitDetailScreen(visitId: st.pathParameters['id']!)),
      GoRoute(path: '/report/:id', builder: (_, st) => ReportDetailScreen(reportId: st.pathParameters['id']!)),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(
        path: '/settings/privacy',
        builder: (_, __) =>
            const SettingsInfoScreen(info: SettingsInfo.privacy),
      ),
      GoRoute(
        path: '/settings/terms',
        builder: (_, __) => const SettingsInfoScreen(info: SettingsInfo.terms),
      ),
      GoRoute(
        path: '/settings/about',
        builder: (_, __) => const SettingsInfoScreen(info: SettingsInfo.about),
      ),
    ],
  );
}
