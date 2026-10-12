// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e_clinic_book/main.dart';
import 'package:e_clinic_book/core/localization/app_localizations.dart';
import 'package:e_clinic_book/core/theme/app_theme.dart';
import 'package:e_clinic_book/models/models.dart';
import 'package:e_clinic_book/providers/app_state.dart';
import 'package:e_clinic_book/screens/doctor/doctor_screens.dart';
import 'package:e_clinic_book/screens/patient/patient_screens.dart';
import 'package:e_clinic_book/screens/shared/shared_screens.dart';
import 'package:e_clinic_book/services/appointment_service.dart';
import 'package:e_clinic_book/services/auth_service.dart';
import 'package:e_clinic_book/services/clinic_visit_service.dart';
import 'package:e_clinic_book/services/doctor_service.dart';
import 'package:e_clinic_book/services/mock_data.dart';
import 'package:e_clinic_book/services/patient_service.dart';
import 'package:e_clinic_book/services/qr_service.dart';
import 'package:e_clinic_book/services/report_service.dart';
import 'package:e_clinic_book/services/report_storage_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('settings preferences persist across app state instances', () async {
    final state = AppState.mock();
    await state.init();
    await state.setNotificationsEnabled(false);
    await state.setDarkModeEnabled(true);
    await state.setLocaleCode('si');

    final restoredState = AppState.mock();
    await restoredState.init();

    expect(restoredState.notificationsEnabled, isFalse);
    expect(restoredState.darkModeEnabled, isTrue);
    expect(restoredState.localeCode, 'si');
    expect(restoredState.appLocale.languageCode, 'si');
  });

  testWidgets('settings controls apply locale, theme, and notifications',
      (WidgetTester tester) async {
    final state = AppState.mock();
    await state.init();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: Consumer<AppState>(
          builder: (context, appState, _) => MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode:
                appState.darkModeEnabled ? ThemeMode.dark : ThemeMode.light,
            locale: appState.appLocale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const SettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.text(AppLocalizations(state.appLocale).text('Notifications')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark Mode'));
    await tester.pumpAndSettle();

    expect(state.notificationsEnabled, isFalse);
    expect(state.darkModeEnabled, isTrue);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('தமிழ்').last);
    await tester.pumpAndSettle();

    expect(state.localeCode, 'ta');
    expect(find.text('அமைப்புகள்'), findsOneWidget);
    expect(find.text('அறிவிப்புகள்'), findsOneWidget);
  });

  test('metadata permission failure reports Firestore stage and cleans up file',
      () async {
    final reportService = _TestReportService(
      addError: LabReportOperationException(
        stage: 'Firestore metadata write (labReports/{reportId})',
        cause: FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'Missing or insufficient permissions',
        ),
        stackTrace: StackTrace.current,
      ),
    );
    final storageService = _TestReportStorageService();
    final state = _uploadTestState(reportService, storageService);

    await expectLater(
      state.uploadLabReport(_testReport(), Uint8List.fromList([1]), 'test.pdf',
          'application/pdf'),
      throwsA(
        isA<LabReportOperationException>()
            .having((error) => error.stage, 'stage',
                contains('Firestore metadata write'))
            .having(
              (error) => error.toString(),
              'details',
              contains('permission-denied'),
            ),
      ),
    );

    expect(storageService.deletedPaths, ['patient-id/report-id/test.pdf']);
    expect(reportService.reports, isEmpty);
    expect(state.reports, isEmpty);
  });

  test('Supabase upload failure is identified and metadata is not written',
      () async {
    final reportService = _TestReportService();
    final storageService = _TestReportStorageService(
      uploadError: StateError('storage upload failed'),
    );
    final state = _uploadTestState(reportService, storageService);

    await expectLater(
      state.uploadLabReport(_testReport(), Uint8List.fromList([1]), 'test.pdf',
          'application/pdf'),
      throwsA(
        isA<LabReportOperationException>().having(
          (error) => error.stage,
          'stage',
          'Supabase file upload',
        ),
      ),
    );

    expect(reportService.reports, isEmpty);
    expect(storageService.deletedPaths, isEmpty);
  });

  testWidgets('startup error shows Firebase configuration guidance',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const StartupErrorApp(message: 'Firebase initialization failed'),
    );

    expect(find.text('E-Clinic Book could not start'), findsOneWidget);
    expect(find.text('Firebase initialization failed'), findsOneWidget);
    expect(find.textContaining('Check your Firebase setup'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsNothing);
  });

  test('missing Supabase configuration fails report upload explicitly',
      () async {
    const message =
        'Supabase report storage is unavailable. Configure SUPABASE_URL and '
        'SUPABASE_ANON_KEY with --dart-define to upload or download report files.';
    final reportService = _TestReportService();
    final storageService = UnavailableReportStorageService(message);
    final state = _uploadTestState(reportService, storageService);

    await expectLater(
      state.uploadLabReport(
        _testReport(),
        Uint8List.fromList([1]),
        'test.pdf',
        'application/pdf',
      ),
      throwsA(
        isA<LabReportOperationException>()
            .having((error) => error.stage, 'stage', 'Supabase file upload')
            .having(
              (error) => error.toString(),
              'details',
              contains('SUPABASE_URL'),
            ),
      ),
    );

    expect(reportService.reports, isEmpty);
  });

  test('lab report metadata retains assigned doctor UIDs on upload', () async {
    final reportService = _TestReportService();
    final state = _uploadTestState(
      reportService,
      _TestReportStorageService(),
    );
    final report = LabReport(
      id: 'assigned-report',
      patientId: 'patient-uid',
      doctorId: 'doctor-uid',
      primaryDoctorUid: 'doctor-uid',
      name: 'Test report',
      type: 'Blood test',
      lab: 'Test lab',
      date: DateTime(2026, 10, 9),
      notes: 'Fasting sample',
    );

    await state.uploadLabReport(
      report,
      Uint8List.fromList([1]),
      'test.pdf',
      'application/pdf',
    );

    expect(reportService.reports.single.doctorId, 'doctor-uid');
    expect(reportService.reports.single.primaryDoctorUid, 'doctor-uid');
    expect(reportService.reports.single.notes, 'Fasting sample');
  });

  test('patient report upload stores metadata and refreshes reports in state',
      () async {
    final reportService = _TestReportService();
    final state = _uploadTestState(
      reportService,
      MockReportStorageService(),
    );
    final report = LabReport(
      id: 'patient-report',
      patientId: 'patient-uid',
      name: 'Blood count',
      type: 'Laboratory Test',
      lab: 'Test lab',
      date: DateTime(2026, 10, 9),
      notes: 'Fasting sample',
    );

    await state.uploadLabReport(
      report,
      Uint8List.fromList([1]),
      'blood-count.pdf',
      'application/pdf',
    );

    expect(reportService.reports.single.patientId, 'patient-uid');
    expect(reportService.reports.single.notes, 'Fasting sample');
    expect(state.reports.single.id, 'patient-report');
    expect(state.reports.single.storagePath,
        'patient-uid/patient-report/blood-count.pdf');
  });

  testWidgets('patient reports page opens upload form and validates inputs',
      (WidgetTester tester) async {
    final state = AppState.mock();
    final login = state.login(
      'patient@example.com',
      'password',
      role: UserRole.patient,
    );
    await tester.binding.delayed(const Duration(milliseconds: 600));
    await login;
    state.reports = [];

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: ReportsScreen()),
      ),
    );

    expect(find.text('No laboratory reports yet.'), findsOneWidget);
    await tester.tap(find.text('Upload Report'));
    await tester.pumpAndSettle();

    expect(find.text('Upload Laboratory Report'), findsOneWidget);
    await tester.tap(find.text('Save / Upload Report'));
    await tester.pumpAndSettle();
    expect(find.text('Select a hospital or laboratory.'), findsOneWidget);
    expect(find.text('Enter the report type or test name.'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other').last);
    await tester.pumpAndSettle();
    expect(find.text('Facility name'), findsOneWidget);
    expect(state.reports, isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Upload Laboratory Report'), findsNothing);
  });

  testWidgets('app builds without crashing', (WidgetTester tester) async {
    final state = AppState.mock();
    await tester.pumpWidget(EClinicApp(state: state));
    await tester.pump(const Duration(seconds: 3));
    while (state.loading) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('doctor can open report upload from patient profile',
      (WidgetTester tester) async {
    final state = AppState.mock();
    final login = state.login(
      'doctor@example.com',
      'password',
      role: UserRole.doctor,
    );
    await tester.binding.delayed(const Duration(milliseconds: 600));
    await login;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(
          home: DoctorPatientScreen(patientId: 'P-1001'),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Add Lab Report'));
    await tester.pumpAndSettle();

    expect(find.text('Add Lab Report'), findsOneWidget);
    expect(find.text('Select PDF or image'), findsOneWidget);
  });

  testWidgets('lab report form requests a name when Other is selected',
      (WidgetTester tester) async {
    final state = AppState.mock();
    final login = state.login(
      'doctor@example.com',
      'password',
      role: UserRole.doctor,
    );
    await tester.binding.delayed(const Duration(milliseconds: 600));
    await login;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(
          home: DoctorPatientScreen(patientId: 'P-1001'),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Add Lab Report'));
    await tester.pumpAndSettle();

    expect(find.text('Hospital or laboratory'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other').last);
    await tester.pumpAndSettle();

    expect(find.text('Other hospital or laboratory name'), findsOneWidget);
  });

  testWidgets('doctor upcoming list includes appointments dated tomorrow',
      (WidgetTester tester) async {
    final today = DateTime.now();
    final state = AppState.mock()
      ..loading = false
      ..appointments = [
        Appointment(
          id: 'tomorrow',
          patientId: 'P-1001',
          patientName: 'Tomorrow Patient',
          date: DateTime(today.year, today.month, today.day + 1),
          time: '09:00 AM',
          hospital: 'Negombo General Hospital',
          clinic: 'General Clinic',
          doctor: 'Dr. Kasun Perera',
        ),
      ];

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: DoctorAppointmentsScreen()),
      ),
    );

    expect(find.text('Tomorrow Patient'), findsOneWidget);
  });

  test('completing appointment persists status and preserves its fields',
      () async {
    final appointment = _testAppointment('complete-this');
    final service = _TestAppointmentService([appointment]);
    final state = _appointmentTestState(service);
    await state.init();

    await state.setAppointmentStatus(
      appointment.id,
      AppointmentStatus.completed,
    );

    final persisted = (await service.getAll())
        .singleWhere((item) => item.id == appointment.id);
    final local = state.appointments.single;
    expect(persisted.status, AppointmentStatus.completed);
    expect(local.status, AppointmentStatus.completed);
    _expectAppointmentDetailsUnchanged(persisted, appointment);
  });

  test('cancelling appointment persists status and preserves its fields',
      () async {
    final appointment = _testAppointment('cancel-this');
    final service = _TestAppointmentService([appointment]);
    final state = _appointmentTestState(service);
    await state.init();

    await state.setAppointmentStatus(
      appointment.id,
      AppointmentStatus.cancelled,
    );

    final persisted = (await service.getAll())
        .singleWhere((item) => item.id == appointment.id);
    final local = state.appointments.single;
    expect(persisted.status, AppointmentStatus.cancelled);
    expect(local.status, AppointmentStatus.cancelled);
    _expectAppointmentDetailsUnchanged(persisted, appointment);
  });

  test('failed appointment status write leaves provider state unchanged',
      () async {
    final appointment = _testAppointment('failed-update');
    final service = _TestAppointmentService(
      [appointment],
      statusError: StateError('permission-denied'),
    );
    final state = _appointmentTestState(service);
    await state.init();
    var notifications = 0;
    state.addListener(() => notifications++);

    await expectLater(
      state.setAppointmentStatus(
        appointment.id,
        AppointmentStatus.completed,
      ),
      throwsA(isA<StateError>()),
    );

    expect(state.appointments.single.status, AppointmentStatus.upcoming);
    expect(
      (await service.getAll()).single.status,
      AppointmentStatus.upcoming,
    );
    expect(notifications, 0);
  });

  test('patient booking stores the selected doctor UID', () async {
    final state = AppState.mock();
    await state.login(
      'patient@example.com',
      'password',
      role: UserRole.patient,
    );
    final patient = state.currentPatient!;
    final doctor = state.doctors.firstWhere(
      (item) => item.id != patient.primaryDoctorUid,
    );
    final appointment = Appointment(
      id: 'patient-booking',
      patientId: patient.id,
      patientName: patient.name,
      date: DateTime(2026, 10, 12),
      time: '09:00 AM',
      hospital: 'Negombo General Hospital',
      clinic: 'General Clinic',
      doctor: doctor.name,
      doctorId: doctor.id,
    );

    await state.addAppointment(appointment);

    final savedAppointment = state.appointments.singleWhere(
      (item) => item.id == appointment.id,
    );
    expect(savedAppointment.patientId, patient.id);
    expect(savedAppointment.doctorId, doctor.id);
    expect(savedAppointment.doctor, doctor.name);
    expect(doctor.id, isNot(patient.primaryDoctorUid));
  });

  test('appointment profile backfill trusts doctor UID, not display name', () {
    final verifiedDoctorUids =
        FirebaseAppointmentService.verifiedBookedDoctorUids(
      appointmentDoctorUids: ['doctor-uid', 'not-a-doctor-uid'],
      doctorProfiles: {
        'doctor-uid': {
          'role': UserRole.doctor.name,
          'name': 'Current Doctor Name',
        },
        'not-a-doctor-uid': {
          'role': UserRole.patient.name,
          'name': 'Unrelated Profile',
        },
      },
    );

    expect(verifiedDoctorUids, {'doctor-uid'});
  });

  test('doctor patient list includes unique patients booked by doctor UID',
      () async {
    final firstBooking = _testAppointment(
      'first-booking',
      patientId: 'P-1003',
      patientName: 'Kamal Jayasuriya',
      doctorId: 'D-2001',
    );
    final duplicateBooking = _testAppointment(
      'duplicate-booking',
      patientId: 'P-1003',
      patientName: 'Kamal Jayasuriya',
      doctorId: 'D-2001',
    );
    final otherDoctorBooking = _testAppointment(
      'other-doctor-booking',
      patientId: 'P-1003',
      patientName: 'Kamal Jayasuriya',
      doctorId: 'D-2002',
    );
    final otherDoctorOnlyBooking = _testAppointment(
      'other-doctor-only-booking',
      patientId: 'P-1002',
      patientName: 'Sunethra Silva',
      doctorId: 'D-2002',
    );
    final state = _appointmentTestState(
      _TestAppointmentService([
        firstBooking,
        duplicateBooking,
        otherDoctorBooking,
        otherDoctorOnlyBooking,
      ]),
    );

    await state.login(
      'doctor@example.com',
      'password',
      role: UserRole.doctor,
    );

    expect(
      state.patients.where((patient) => patient.id == 'P-1003'),
      hasLength(1),
    );
    expect(
      state.appointments.every(
        (appointment) => appointment.doctorId == state.user!.id,
      ),
      isTrue,
    );
    expect(
      state.patients.map((patient) => patient.id).toSet(),
      {'P-1001', 'P-1003'},
    );
  });

  test(
      'doctor patient list retains booked patient from profile UID link '
      'when a legacy appointment has no doctor ID', () async {
    final legacyAppointment = _testAppointment(
      'legacy-booking',
      patientId: 'P-1003',
      doctorId: null,
    );
    final patients = MockPatientServiceWithPatients([
      ...MockData.patients().where((patient) => patient.id == 'P-1001'),
      Patient(
        id: 'P-1003',
        name: 'Test Patient',
        nic: 'test-nic',
        dob: DateTime(1990),
        gender: 'Other',
        phone: '000',
        email: 'test@example.com',
        address: 'Test address',
        appointmentDoctorUids: const ['D-2001'],
      ),
    ]);
    final state = _appointmentTestState(
      _TestAppointmentService([legacyAppointment]),
      patientService: patients,
    );

    await state.login(
      'doctor@example.com',
      'password',
      role: UserRole.doctor,
    );

    expect(state.patients.map((patient) => patient.id).toSet(),
        {'P-1001', 'P-1003'});
    expect(state.patients.where((patient) => patient.id == 'P-1003'),
        hasLength(1));
    expect(state.appointments, isEmpty);
  });

  test('Firestore permission errors are not reported as an empty patient list',
      () async {
    final state = _appointmentTestState(
      _TestAppointmentService([]),
      patientService: _FailingPatientService(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        ),
      ),
    );

    await state.login(
      'doctor@example.com',
      'password',
      role: UserRole.doctor,
    );

    expect(state.patients, isEmpty);
    expect(state.error, contains('Firestore denied access'));
    expect(state.error, contains('not treated as an empty result'));
  });

  testWidgets('doctor can reach and tap complete action in short viewport',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final appointment = _testAppointment('short-screen-completion');
    final service = _TestAppointmentService([appointment]);
    final state = _appointmentTestState(service)
      ..loading = false
      ..appointments = [appointment];

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: DoctorAppointmentsScreen()),
      ),
    );
    await tester.tap(find.text('Test Patient'));
    await tester.pumpAndSettle();

    final completeAction = find.text('Mark as Completed');
    await tester.ensureVisible(completeAction);
    await tester.pumpAndSettle();
    expect(completeAction, findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(completeAction);
    await tester.pumpAndSettle();

    expect(state.appointments.single.status, AppointmentStatus.completed);
    expect(tester.takeException(), isNull);
  });

  testWidgets('doctor login shows patients and cannot create appointments',
      (WidgetTester tester) async {
    final state = AppState.mock();
    await tester.pumpWidget(EClinicApp(state: state));
    await tester.pump(const Duration(seconds: 3));
    while (state.loading) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    final login = state.login(
      'doctor@example.com',
      'password',
      role: UserRole.doctor,
    );
    await tester.binding.delayed(const Duration(milliseconds: 600));
    await login;
    await state.setLocaleCode('en');
    await tester.pumpAndSettle();

    expect(state.patients, hasLength(2));
    expect(state.appointments, hasLength(4));
    expect(
      find.text(
        AppLocalizations(state.appLocale).text("Today's Appointments"),
      ),
      findsOneWidget,
    );
    expect(
      find.text(AppLocalizations(state.appLocale).text('Patients')),
      findsOneWidget,
    );

    await tester.tap(find.text('Appointments'));
    await tester.pumpAndSettle();
    expect(find.text('New Appointment'), findsNothing);

    await tester.tap(find.text('Patients'));
    await tester.pumpAndSettle();
    expect(find.text('Nimal Fernando'), findsOneWidget);
    expect(find.text('Sunethra Silva'), findsOneWidget);
    expect(find.text('Kamal Jayasuriya'), findsNothing);

    await tester.tap(find.text('View Patient').last);
    await tester.pumpAndSettle();
    expect(find.text('sunethra@example.com'), findsOneWidget);
    expect(find.byTooltip('Add Lab Report'), findsNothing);
    expect(find.text('Add Visit'), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byType(TabBar),
        matching: find.text('Appointments'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('11:00 AM'), findsOneWidget);
  });
}

AppState _uploadTestState(
  _TestReportService reportService,
  ReportStorageService storageService,
) =>
    AppState(
      auth: MockAuthService(),
      patientService: MockPatientService(),
      appointmentService: MockAppointmentService(),
      visitService: MockClinicVisitService(),
      doctorService: MockDoctorService(),
      reportService: reportService,
      reportStorageService: storageService,
      qr: MockQrService(),
    );

AppState _appointmentTestState(
  _TestAppointmentService service, {
  PatientService? patientService,
}) =>
    AppState(
      auth: MockAuthService(),
      patientService: patientService ?? MockPatientService(),
      appointmentService: service,
      visitService: MockClinicVisitService(),
      doctorService: MockDoctorService(),
      reportService: MockReportService(),
      reportStorageService: MockReportStorageService(),
      qr: MockQrService(),
    );

class MockPatientServiceWithPatients implements PatientService {
  MockPatientServiceWithPatients(this.patients);

  final List<Patient> patients;

  @override
  Future<List<Patient>> getAll() async => List.of(patients);

  @override
  Future<void> add(Patient patient) async {}

  @override
  Future<void> update(Patient patient) async {}
}

class _FailingPatientService implements PatientService {
  _FailingPatientService(this.error);

  final Object error;

  @override
  Future<List<Patient>> getAll() async => throw error;

  @override
  Future<void> add(Patient patient) async {}

  @override
  Future<void> update(Patient patient) async {}
}

Appointment _testAppointment(
  String id, {
  String patientId = 'patient-uid',
  String patientName = 'Test Patient',
  String? doctorId,
}) =>
    Appointment(
      id: id,
      patientId: patientId,
      patientName: patientName,
      date: DateTime(2026, 10, 10, 9),
      time: '09:00 AM',
      hospital: 'Test Hospital',
      clinic: 'General Clinic',
      doctor: 'Dr. Test',
      doctorId: doctorId,
    );

void _expectAppointmentDetailsUnchanged(
  Appointment actual,
  Appointment original,
) {
  expect(actual.patientId, original.patientId);
  expect(actual.patientName, original.patientName);
  expect(actual.date, original.date);
  expect(actual.time, original.time);
  expect(actual.hospital, original.hospital);
  expect(actual.clinic, original.clinic);
  expect(actual.doctor, original.doctor);
  expect(actual.doctorId, original.doctorId);
}

LabReport _testReport() => LabReport(
      id: 'report-id',
      patientId: 'patient-id',
      name: 'Test report',
      type: 'Blood test',
      lab: 'Test lab',
      date: DateTime(2026, 10, 9),
    );

class _TestReportService implements ReportService {
  _TestReportService({this.addError});

  final Object? addError;
  final List<LabReport> reports = [];

  @override
  String newId() => 'report-id';

  @override
  Future<List<LabReport>> getAll() async => List.of(reports);

  @override
  Future<void> add(LabReport report) async {
    if (addError != null) throw addError!;
    reports.add(report);
  }

  @override
  Future<List<AppNotification>> getNotifications() async => [];
}

class _TestReportStorageService implements ReportStorageService {
  _TestReportStorageService({this.uploadError});

  final Object? uploadError;
  final List<String> deletedPaths = [];

  @override
  Future<String> uploadReportFile({
    required String patientId,
    required String reportId,
    required String fileName,
    required Uint8List fileBytes,
    required String contentType,
  }) async {
    if (uploadError != null) throw uploadError!;
    return '$patientId/$reportId/$fileName';
  }

  @override
  Future<Uint8List> downloadReportFile(String storagePath) async =>
      Uint8List(0);

  @override
  Future<void> deleteReportFile(String storagePath) async {
    deletedPaths.add(storagePath);
  }
}

class _TestAppointmentService implements AppointmentService {
  _TestAppointmentService(
    List<Appointment> appointments, {
    this.statusError,
  }) : _appointments = appointments.map(_copyAppointment).toList();

  final List<Appointment> _appointments;
  final Object? statusError;

  @override
  Future<List<Appointment>> getAll() async =>
      _appointments.map(_copyAppointment).toList();

  @override
  Future<void> add(Appointment appointment) async {
    _appointments.add(_copyAppointment(appointment));
  }

  @override
  Future<void> setStatus(String id, AppointmentStatus status) async {
    if (statusError != null) throw statusError!;
    final appointment = _appointments.singleWhere((item) => item.id == id);
    appointment.status = status;
  }
}

Appointment _copyAppointment(Appointment appointment) => Appointment(
      id: appointment.id,
      patientId: appointment.patientId,
      patientName: appointment.patientName,
      date: appointment.date,
      time: appointment.time,
      hospital: appointment.hospital,
      clinic: appointment.clinic,
      doctor: appointment.doctor,
      status: appointment.status,
      doctorId: appointment.doctorId,
    );
