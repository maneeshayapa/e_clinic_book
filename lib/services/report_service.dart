import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'mock_data.dart';

abstract class ReportService {
  String newId();
  Future<List<LabReport>> getAll();
  Future<void> add(LabReport report);
  Future<List<AppNotification>> getNotifications();
}

class LabReportOperationException implements Exception {
  const LabReportOperationException({
    required this.stage,
    required this.cause,
    required this.stackTrace,
  });

  final String stage;
  final Object cause;
  final StackTrace stackTrace;

  @override
  String toString() => '$stage failed: $cause';
}

Future<T> _runLabReportOperation<T>(
  String stage,
  Future<T> Function() operation,
) async {
  try {
    return await operation();
  } catch (error, stackTrace) {
    debugPrint(
      '[LabReport] stage="$stage" error=${error.runtimeType}: $error',
    );
    debugPrintStack(stackTrace: stackTrace);
    Error.throwWithStackTrace(
      LabReportOperationException(
        stage: stage,
        cause: error,
        stackTrace: stackTrace,
      ),
      stackTrace,
    );
  }
}

class MockReportService implements ReportService {
  final List<LabReport> _reports = MockData.reports();

  @override
  String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  @override
  Future<List<LabReport>> getAll() async => List.of(_reports);

  @override
  Future<void> add(LabReport report) async => _reports.add(report);

  @override
  Future<List<AppNotification>> getNotifications() async =>
      MockData.notifications();
}

class FirebaseReportService implements ReportService {
  FirebaseReportService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection('labReports');

  @override
  String newId() => _reports.doc().id;

  @override
  Future<List<LabReport>> getAll() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final profile = await _firestore.collection('users').doc(user.uid).get();
    final role = profile.data()?['role'];
    final Query<Map<String, dynamic>> query;
    if (role == UserRole.doctor.name) {
      query = _reports.where('primaryDoctorUid', isEqualTo: user.uid);
    } else if (role == UserRole.patient.name) {
      query = _reports.where('patientId', isEqualTo: user.uid);
    } else {
      throw StateError('Your account has no valid patient or doctor role.');
    }

    final snapshot = await query.get();
    final reports = snapshot.docs
        .map((document) => _reportFromData(document.id, document.data()))
        .toList();
    reports.sort((a, b) => b.date.compareTo(a.date));
    return reports;
  }

  @override
  Future<void> add(LabReport report) async {
    await _validateReporterAndPatient(report);
    await _runLabReportOperation(
      'Firestore metadata write (labReports/{reportId})',
      () => _reports.doc(report.id).set(_reportToData(report)),
    );
  }

  Future<void> _validateReporterAndPatient(LabReport report) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw LabReportOperationException(
        stage: 'Reporter authentication validation',
        cause: StateError('Sign in to create a lab report.'),
        stackTrace: StackTrace.current,
      );
    }

    final reporterProfile = await _runLabReportOperation(
      'Reporter profile read (users/{reporterUid})',
      () => _firestore.collection('users').doc(user.uid).get(),
    );
    final role = reporterProfile.data()?['role'];
    if (role == UserRole.patient.name) {
      if (report.patientId != user.uid ||
          report.doctorId != null ||
          report.primaryDoctorUid != null) {
        throw LabReportOperationException(
          stage: 'Patient ownership validation',
          cause: StateError(
            'Patients can only create lab reports for their own account.',
          ),
          stackTrace: StackTrace.current,
        );
      }
    } else if (role == UserRole.doctor.name) {
      if (report.doctorId != user.uid ||
          report.primaryDoctorUid != user.uid) {
        throw LabReportOperationException(
          stage: 'Doctor identity validation',
          cause: StateError('The report doctor must match your account.'),
          stackTrace: StackTrace.current,
        );
      }
      await _validateDoctorPatientAssignment(user.uid, report.patientId);
    } else {
      throw LabReportOperationException(
        stage: 'Reporter profile validation',
        cause: StateError('Only patients and doctors can create lab reports.'),
        stackTrace: StackTrace.current,
      );
    }
  }

  Future<void> _validateDoctorPatientAssignment(
    String doctorUid,
    String patientId,
  ) async {
    final patientProfile = await _runLabReportOperation(
      'Patient profile read (users/{patientUid})',
      () => _firestore.collection('users').doc(patientId).get(),
    );
    if (patientProfile.data()?['role'] != UserRole.patient.name) {
      throw LabReportOperationException(
        stage: 'Patient profile validation',
        cause: StateError(
          'Lab reports can only be created for registered patients.',
        ),
        stackTrace: StackTrace.current,
      );
    }
    if (patientProfile.data()?['primaryDoctorUid'] != doctorUid) {
      throw LabReportOperationException(
        stage: 'Patient assignment validation',
        cause: StateError(
          'Lab reports can only be created for patients assigned to you.',
        ),
        stackTrace: StackTrace.current,
      );
    }
  }

  Map<String, dynamic> _reportToData(LabReport report) => {
        'patientId': report.patientId,
        'doctorId': report.doctorId,
        'primaryDoctorUid': report.primaryDoctorUid,
        'name': report.name,
        'type': report.type,
        'lab': report.lab,
        'date': Timestamp.fromDate(report.date),
        'status': report.status,
        if (report.notes != null && report.notes!.isNotEmpty)
          'notes': report.notes,
        if (report.fileName != null) 'fileName': report.fileName,
        if (report.storagePath != null) 'storagePath': report.storagePath,
      };

  LabReport _reportFromData(String id, Map<String, dynamic> data) {
    final date = data['date'];
    if (date is! Timestamp) {
      throw FormatException('Lab report $id has an invalid date.');
    }

    return LabReport(
      id: id,
      patientId: _stringField(data, 'patientId', id),
      doctorId: _optionalStringField(data, 'doctorId', id),
      primaryDoctorUid: _optionalStringField(data, 'primaryDoctorUid', id),
      name: _stringField(data, 'name', id),
      type: _stringField(data, 'type', id),
      lab: _stringField(data, 'lab', id),
      date: date.toDate(),
      status: _stringField(data, 'status', id),
      fileName: data['fileName'] as String?,
      storagePath: data['storagePath'] as String?,
      notes: _optionalStringField(data, 'notes', id),
    );
  }

  String _stringField(Map<String, dynamic> data, String field, String id) {
    final value = data[field];
    if (value is! String || value.isEmpty) {
      throw FormatException('Lab report $id has an invalid $field field.');
    }
    return value;
  }

  String? _optionalStringField(
    Map<String, dynamic> data,
    String field,
    String id,
  ) {
    final value = data[field];
    if (value == null) return null;
    if (value is! String || value.isEmpty) {
      throw FormatException('Lab report $id has an invalid $field field.');
    }
    return value;
  }

  @override
  Future<List<AppNotification>> getNotifications() async =>
      MockData.notifications();
}
