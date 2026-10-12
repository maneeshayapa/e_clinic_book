import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/appointment_service.dart';
import '../services/auth_service.dart';
import '../services/clinic_visit_service.dart';
import '../services/doctor_service.dart';
import '../services/patient_service.dart';
import '../services/qr_service.dart';
import '../services/report_service.dart';
import '../services/report_storage_service.dart';

/// Single app-wide Provider state. UI talks only to this class, which talks to
/// the abstract services. Firebase Auth is used by [AppState.withFirebaseAuth];
/// other services remain mock-backed until their Firebase implementations exist.
class AppState extends ChangeNotifier {
  AppState({
    required this.auth,
    required this.patientService,
    required this.appointmentService,
    required this.visitService,
    required this.doctorService,
    required this.reportService,
    required this.reportStorageService,
    required this.qr,
  });

  factory AppState.mock() => AppState(
        auth: MockAuthService(),
        patientService: MockPatientService(),
        appointmentService: MockAppointmentService(),
        visitService: MockClinicVisitService(),
        doctorService: MockDoctorService(),
        reportService: MockReportService(),
        reportStorageService: MockReportStorageService(),
        qr: MockQrService(),
      );

  factory AppState.withFirebaseAuth({
    required ReportStorageService reportStorageService,
  }) =>
      AppState(
        auth: FirebaseAuthService(),
        patientService: FirebasePatientService(),
        appointmentService: FirebaseAppointmentService(),
        visitService: FirebaseClinicVisitService(),
        doctorService: FirebaseDoctorService(),
        reportService: FirebaseReportService(),
        reportStorageService: reportStorageService,
        qr: MockQrService(),
      );

  final AuthService auth;
  final PatientService patientService;
  final AppointmentService appointmentService;
  final ClinicVisitService visitService;
  final DoctorService doctorService;
  final ReportService reportService;
  final ReportStorageService reportStorageService;
  final QrService qr;

  AppUser? user;
  bool loading = true;
  String? error;
  bool notificationsEnabled = true;
  bool darkModeEnabled = false;
  String localeCode = 'en';
  List<Patient> patients = [];
  List<Doctor> doctors = [];
  List<ClinicVisit> visits = [];
  List<Appointment> appointments = [];
  List<LabReport> reports = [];
  List<AppNotification> notifications = [];

  bool get isLoggedIn => user != null;
  bool get isDoctor => user?.role == UserRole.doctor;

  void _filterPatientsForDoctorAppointments() {
    final signedInUser = user;
    if (signedInUser == null || signedInUser.role != UserRole.doctor) return;

    appointments = appointments
        .where((appointment) => appointment.doctorId == signedInUser.id)
        .toList();
    final bookedPatientIds = appointments
        .map((appointment) => appointment.patientId)
        .toSet();
    patients = patients
        .where((patient) =>
            patient.primaryDoctorUid == signedInUser.id ||
            patient.appointmentDoctorUids.contains(signedInUser.id) ||
            bookedPatientIds.contains(patient.id))
        .toList();
  }

  String _loadErrorMessage(String stage, Object error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'Firestore denied access while $stage. Patient data was not '
          'treated as an empty result; verify the deployed Firestore rules, '
          'account role, and doctor UID links.';
    }
    return 'Failed while $stage: $error';
  }

  Future<void> init() async {
    loading = true;
    error = null;
    notifyListeners();
    var stage = 'restoring the signed-in account';
    try {
      stage = 'loading app preferences';
      await _loadPreferences();
      user = await auth.currentUser();
      stage = 'loading the doctor directory';
      doctors = await doctorService.getAll();
      stage = 'loading appointments';
      appointments = await appointmentService.getAll();
      stage = 'loading patient profiles';
      patients = await patientService.getAll();
      _filterPatientsForDoctorAppointments();
      stage = 'loading clinic visits';
      visits = await visitService.getAll()
        ..sort((a, b) => b.date.compareTo(a.date));
      stage = 'loading lab reports';
      reports = await reportService.getAll();
      stage = 'loading notifications';
      notifications = await reportService.getNotifications();
    } catch (e) {
      error = _loadErrorMessage(stage, e);
    }
    loading = false;
    notifyListeners();
  }

  Locale get appLocale => Locale(localeCode);

  Future<void> _loadPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    notificationsEnabled = preferences.getBool('notificationsEnabled') ?? true;
    darkModeEnabled = preferences.getBool('darkModeEnabled') ?? false;
    final savedLocale = preferences.getString('localeCode') ?? 'en';
    localeCode = const {'en', 'si', 'ta'}.contains(savedLocale)
        ? savedLocale
        : 'en';
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('notificationsEnabled', enabled);
    notificationsEnabled = enabled;
    notifyListeners();
  }

  Future<void> setDarkModeEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('darkModeEnabled', enabled);
    darkModeEnabled = enabled;
    notifyListeners();
  }

  Future<void> setLocaleCode(String code) async {
    if (!const {'en', 'si', 'ta'}.contains(code)) {
      throw ArgumentError.value(code, 'code', 'Unsupported app language.');
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('localeCode', code);
    localeCode = code;
    notifyListeners();
  }

  // ---- auth ----
  Future<AppUser> login(String email, String password, {UserRole? role}) async {
    final signedInUser = await auth.login(email, password, role: role);
    user = signedInUser;
    patients = [];
    doctors = [];
    visits = [];
    appointments = [];
    reports = [];
    notifications = [];
    loading = true;
    error = null;
    notifyListeners();
    var stage = 'loading the doctor directory';
    try {
      doctors = await doctorService.getAll();
      stage = 'loading appointments';
      appointments = await appointmentService.getAll();
      stage = 'loading patient profiles';
      patients = await patientService.getAll();
      _filterPatientsForDoctorAppointments();
      stage = 'loading clinic visits';
      visits = await visitService.getAll()
        ..sort((a, b) => b.date.compareTo(a.date));
      stage = 'loading lab reports';
      reports = await reportService.getAll();
    } catch (e) {
      error = 'Signed in, but ${_loadErrorMessage(stage, e)}';
    }
    loading = false;
    notifyListeners();
    return signedInUser;
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    required Patient patient,
  }) async {
    user = await auth.register(
        name: name, email: email, password: password, role: role);
    if (role == UserRole.patient) {
      final p = Patient(
          id: user!.id,
          name: name,
          nic: patient.nic,
          dob: patient.dob,
          gender: patient.gender,
          phone: patient.phone,
          email: email,
          address: patient.address);
      await patientService.add(p);
      patients = await patientService.getAll();
    }
    notifyListeners();
  }

  Future<void> completePatientProfile(Patient patient) async {
    final currentUser = user;
    if (currentUser == null || currentUser.role != UserRole.patient) {
      throw StateError('Sign in as a patient to complete this profile.');
    }
    if (patient.id != currentUser.id) {
      throw StateError("Cannot update another user's patient profile.");
    }

    await patientService.add(patient);
    patients = await patientService.getAll();
    notifyListeners();
  }

  Future<void> logout() async {
    await auth.logout();
    user = null;
    patients = [];
    doctors = [];
    visits = [];
    appointments = [];
    reports = [];
    notifications = [];
    notifyListeners();
  }

  // ---- lookups ----
  Patient? patientById(String id) {
    for (final p in patients) {
      if (p.id == id) return p;
    }
    return null;
  }

  Patient? get currentPatient => user == null ? null : patientById(user!.id);

  ClinicVisit? visitById(String id) {
    for (final v in visits) {
      if (v.id == id) return v;
    }
    return null;
  }

  LabReport? reportById(String id) {
    for (final r in reports) {
      if (r.id == id) return r;
    }
    return null;
  }

  List<ClinicVisit> visitsFor(String patientId) =>
      visits.where((v) => v.patientId == patientId).toList();
  List<LabReport> reportsFor(String patientId) =>
      reports.where((r) => r.patientId == patientId).toList();
  List<Appointment> appointmentsFor(String patientId) =>
      appointments.where((a) => a.patientId == patientId).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
  List<Medicine> medicinesFor(String patientId) =>
      visitsFor(patientId).expand((v) => v.medicines).toList();
  ClinicVisit? lastVisit(String patientId) {
    final l = visitsFor(patientId);
    return l.isEmpty ? null : l.first;
  }

  // ---- mutations ----
  Future<void> addVisit(ClinicVisit v) async {
    await visitService.add(v);
    visits = await visitService.getAll()
      ..sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  Future<void> addAppointment(Appointment a) async {
    await appointmentService.add(a);
    final existingIndex =
        appointments.indexWhere((appointment) => appointment.id == a.id);
    if (existingIndex == -1) {
      appointments = [...appointments, a];
    } else {
      appointments[existingIndex] = a;
    }
    appointments.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  Future<void> setAppointmentStatus(String id, AppointmentStatus s) async {
    await appointmentService.setStatus(id, s);
    final appointmentIndex =
        appointments.indexWhere((appointment) => appointment.id == id);
    if (appointmentIndex != -1) {
      appointments[appointmentIndex].status = s;
    }
    notifyListeners();
  }

  Future<void> addReport(LabReport report) async {
    await reportService.add(report);
    reports = await reportService.getAll();
    reports.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  String newReportId() => reportService.newId();

  Future<void> uploadLabReport(
    LabReport report,
    Uint8List fileBytes,
    String fileName,
    String contentType,
  ) async {
    late final String storagePath;
    try {
      storagePath = await reportStorageService.uploadReportFile(
        patientId: report.patientId,
        reportId: report.id,
        fileName: fileName,
        fileBytes: fileBytes,
        contentType: contentType,
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[LabReport] stage="Supabase file upload" '
        'error=${error.runtimeType}: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      Error.throwWithStackTrace(
        LabReportOperationException(
          stage: 'Supabase file upload',
          cause: error,
          stackTrace: stackTrace,
        ),
        stackTrace,
      );
    }
    final storedReport = LabReport(
      id: report.id,
      patientId: report.patientId,
      doctorId: report.doctorId,
      primaryDoctorUid: report.primaryDoctorUid,
      name: report.name,
      type: report.type,
      lab: report.lab,
      date: report.date,
      status: report.status,
      notes: report.notes,
      fileName: fileName.replaceAll(RegExp(r'[/\\]'), '_'),
      storagePath: storagePath,
    );
    try {
      await reportService.add(storedReport);
    } catch (metadataError, stackTrace) {
      try {
        await reportStorageService.deleteReportFile(storagePath);
      } catch (cleanupError, cleanupStackTrace) {
        debugPrint(
          '[LabReport] stage="Supabase cleanup after metadata failure" '
          'error=${cleanupError.runtimeType}: $cleanupError',
        );
        debugPrintStack(stackTrace: cleanupStackTrace);
        Error.throwWithStackTrace(
          LabReportOperationException(
            stage: 'Firestore metadata save and Supabase cleanup',
            cause: StateError(
              'Metadata save failed ($metadataError); cleanup also failed '
              '($cleanupError).',
            ),
            stackTrace: stackTrace,
          ),
          stackTrace,
        );
      }
      if (metadataError is LabReportOperationException) {
        Error.throwWithStackTrace(metadataError, stackTrace);
      }
      debugPrint(
        '[LabReport] stage="Firestore metadata save" '
        'error=${metadataError.runtimeType}: $metadataError',
      );
      debugPrintStack(stackTrace: stackTrace);
      Error.throwWithStackTrace(
        LabReportOperationException(
          stage: 'Firestore metadata save',
          cause: metadataError,
          stackTrace: stackTrace,
        ),
        stackTrace,
      );
    }
    reports = [
      ...reports.where((existing) => existing.id != storedReport.id),
      storedReport,
    ];
    reports.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  Future<Uint8List> downloadLabReportFile(String storagePath) =>
      reportStorageService.downloadReportFile(storagePath);

  Future<void> updateProfile(Patient p,
      {String? name, String? phone, String? address}) async {
    if (name != null) p.name = name;
    if (phone != null) p.phone = phone;
    if (address != null) p.address = address;
    await patientService.update(p);
    notifyListeners();
  }

  void markNotificationRead(AppNotification n) {
    n.read = true;
    notifyListeners();
  }
}
