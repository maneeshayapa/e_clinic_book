import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'mock_data.dart';

abstract class AppointmentService {
  Future<List<Appointment>> getAll();
  Future<void> add(Appointment appointment);
  Future<void> setStatus(String id, AppointmentStatus status);
}

class MockAppointmentService implements AppointmentService {
  final List<Appointment> _items = MockData.appointments();

  @override
  Future<List<Appointment>> getAll() async => List.of(_items);

  @override
  Future<void> add(Appointment appointment) async => _items.add(appointment);

  @override
  Future<void> setStatus(String id, AppointmentStatus status) async =>
      _items.firstWhere((appointment) => appointment.id == id).status = status;
}

class FirebaseAppointmentService implements AppointmentService {
  FirebaseAppointmentService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @visibleForTesting
  static Set<String> verifiedBookedDoctorUids({
    required Iterable<String> appointmentDoctorUids,
    required Map<String, Map<String, dynamic>> doctorProfiles,
  }) =>
      appointmentDoctorUids
          .where(
            (doctorId) =>
                doctorProfiles[doctorId]?['role'] == UserRole.doctor.name,
          )
          .toSet();

  CollectionReference<Map<String, dynamic>> get _appointments =>
      _firestore.collection('appointments');

  @override
  Future<List<Appointment>> getAll() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final profile = await _firestore.collection('users').doc(user.uid).get();
    final role = profile.data()?['role'];
    final Query<Map<String, dynamic>> query;
    if (role == UserRole.doctor.name) {
      query = _appointments.where('doctorId', isEqualTo: user.uid);
    } else if (role == UserRole.patient.name) {
      query = _appointments.where('patientId', isEqualTo: user.uid);
    } else {
      throw StateError('Your account has no valid patient or doctor role.');
    }

    final snapshot = await query.get();
    final appointments = snapshot.docs
        .map((document) => _appointmentFromData(document.id, document.data()))
        .toList();
    appointments.sort((a, b) => b.date.compareTo(a.date));
    if (role == UserRole.patient.name) {
      await _syncBookedDoctorAccess(profile, appointments);
    }
    return appointments;
  }

  Future<void> _syncBookedDoctorAccess(
    DocumentSnapshot<Map<String, dynamic>> profile,
    List<Appointment> appointments,
  ) async {
    final appointmentDoctorIds = appointments
        .map((appointment) => appointment.doctorId)
        .whereType<String>()
        .toSet();
    if (appointmentDoctorIds.isEmpty) return;

    final profileDoctorIds = profile.data()?['appointmentDoctorUids'];
    final existingDoctorIds = <String>{};
    if (profileDoctorIds != null) {
      if (profileDoctorIds is! List ||
          profileDoctorIds.any((doctorId) => doctorId is! String)) {
        throw FormatException(
          'Patient profile ${profile.id} has invalid appointment doctor IDs.',
        );
      }
      existingDoctorIds.addAll(profileDoctorIds.cast<String>());
    }
    final unlinkedDoctorIds =
        appointmentDoctorIds.difference(existingDoctorIds);
    if (unlinkedDoctorIds.isEmpty) return;

    final doctorProfiles = await Future.wait(
      unlinkedDoctorIds.map(
        (doctorId) => _firestore.collection('users').doc(doctorId).get(),
      ),
    );
    final profilesById = <String, Map<String, dynamic>>{};
    for (final doctorProfile in doctorProfiles) {
      final data = doctorProfile.data();
      if (data != null) profilesById[doctorProfile.id] = data;
    }
    final verifiedDoctorIds = verifiedBookedDoctorUids(
      appointmentDoctorUids: unlinkedDoctorIds,
      doctorProfiles: profilesById,
    ).toList();
    if (verifiedDoctorIds.isEmpty) return;

    await profile.reference.set(
      {
        'appointmentDoctorUids': FieldValue.arrayUnion(verifiedDoctorIds),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> add(Appointment appointment) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in to create an appointment.');
    }
    if (appointment.status != AppointmentStatus.upcoming) {
      throw StateError('New appointments must have upcoming status.');
    }

    final profile = await _firestore.collection('users').doc(user.uid).get();
    final profileData = profile.data();
    final role = profileData?['role'];
    if (role == UserRole.patient.name) {
      if (appointment.patientId != user.uid) {
        throw StateError(
          'You can only book an appointment for your own account.',
        );
      }
      final doctorId = appointment.doctorId;
      if (doctorId == null || doctorId.isEmpty) {
        throw StateError('Select an available doctor.');
      }
      final doctorProfile =
          await _firestore.collection('users').doc(doctorId).get();
      if (doctorProfile.data()?['role'] != UserRole.doctor.name) {
        throw StateError('Select a valid available doctor.');
      }
      if ((appointment.doctor.trim()).isEmpty) {
        throw StateError('Select a valid available doctor.');
      }
    } else if (role == UserRole.doctor.name) {
      if (appointment.doctorId != user.uid) {
        throw StateError(
          'The appointment doctor must match your approved profile.',
        );
      }
      if ((appointment.doctor.trim()).isEmpty) {
        throw StateError('The appointment doctor name is required.');
      }
      final patient =
          await _firestore.collection('users').doc(appointment.patientId).get();
      if (patient.data()?['role'] != UserRole.patient.name) {
        throw StateError('Select a registered patient.');
      }
    } else {
      throw StateError('Your account has no valid patient or doctor role.');
    }

    final appointmentReference = _appointments.doc(appointment.id);
    if (role == UserRole.patient.name) {
      final batch = _firestore.batch();
      batch.set(appointmentReference, _appointmentToData(appointment));
      batch.set(
        _firestore.collection('users').doc(user.uid),
        {
          'appointmentDoctorUids':
              FieldValue.arrayUnion([appointment.doctorId]),
        },
        SetOptions(merge: true),
      );
      await batch.commit();
      return;
    }

    await appointmentReference.set(_appointmentToData(appointment));
  }

  @override
  Future<void> setStatus(String id, AppointmentStatus status) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in to update an appointment.');
    if (status == AppointmentStatus.upcoming) {
      throw StateError('Appointments cannot be changed back to upcoming.');
    }

    final userProfile =
        await _firestore.collection('users').doc(user.uid).get();
    final role = userProfile.data()?['role'];
    final appointmentReference = _appointments.doc(id);
    final appointment = await appointmentReference.get();
    final data = appointment.data();
    if (data == null) throw StateError('Appointment $id was not found.');

    if (role == UserRole.patient.name) {
      if (data['patientId'] != user.uid ||
          data['status'] != AppointmentStatus.upcoming.name ||
          status != AppointmentStatus.cancelled) {
        throw StateError(
          'Patients can only cancel their own upcoming appointments.',
        );
      }
    } else if (role == UserRole.doctor.name) {
      if (data['status'] != AppointmentStatus.upcoming.name) {
        throw StateError(
          'Only upcoming appointments can be completed or cancelled.',
        );
      }
      if (data['doctorId'] != user.uid) {
        throw StateError('You can only update your own appointments.');
      }
    } else {
      throw StateError('Your account has no valid patient or doctor role.');
    }

    // Updating only status preserves the other appointment fields.
    await appointmentReference.update({'status': status.name});
  }

  Map<String, dynamic> _appointmentToData(Appointment appointment) => {
        'patientId': appointment.patientId,
        'patientName': appointment.patientName,
        'date': Timestamp.fromDate(appointment.date),
        'time': appointment.time,
        'hospital': appointment.hospital,
        'clinic': appointment.clinic,
        'doctor': appointment.doctor,
        'status': appointment.status.name,
        if (appointment.doctorId != null) 'doctorId': appointment.doctorId,
      };

  Appointment _appointmentFromData(String id, Map<String, dynamic> data) {
    final date = data['date'];
    if (date is! Timestamp) {
      throw FormatException('Appointment $id has an invalid date.');
    }

    final statusValue = data['status'];
    final doctorId = data['doctorId'];
    if (doctorId != null && (doctorId is! String || doctorId.isEmpty)) {
      throw FormatException('Appointment $id has an invalid doctor ID.');
    }
    final normalizedStatus =
        statusValue is String ? statusValue.trim().toLowerCase() : null;
    final status = AppointmentStatus.values.where(
      (value) => value.name == normalizedStatus,
    );
    if (status.isEmpty) {
      throw FormatException('Appointment $id has an invalid status.');
    }

    return Appointment(
      id: id,
      patientId: _stringField(data, 'patientId', id),
      patientName: _stringField(data, 'patientName', id),
      date: date.toDate(),
      time: _stringField(data, 'time', id),
      hospital: _stringField(data, 'hospital', id),
      clinic: _stringField(data, 'clinic', id),
      doctor: _stringField(data, 'doctor', id),
      status: status.first,
      doctorId: doctorId as String?,
    );
  }

  String _stringField(Map<String, dynamic> data, String field, String id) {
    final value = data[field];
    if (value is! String) {
      throw FormatException('Appointment $id has an invalid $field field.');
    }
    return value;
  }
}
