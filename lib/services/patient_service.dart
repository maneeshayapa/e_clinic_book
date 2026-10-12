import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/models.dart';
import 'mock_data.dart';

abstract class PatientService {
  Future<List<Patient>> getAll();
  Future<void> add(Patient patient);
  Future<void> update(Patient patient);
}

class MockPatientService implements PatientService {
  final List<Patient> _items = MockData.patients();
  @override
  Future<List<Patient>> getAll() async => List.of(_items);
  @override
  Future<void> add(Patient patient) async => _items.add(patient);
  @override
  Future<void> update(Patient patient) async {}
}

class FirebasePatientService implements PatientService {
  FirebasePatientService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  @override
  Future<List<Patient>> getAll() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final ownProfile = await _users.doc(user.uid).get();
    final ownData = ownProfile.data();
    if (ownData == null) {
      throw StateError('Your Firestore user profile could not be found.');
    }

    if (ownData['role'] == UserRole.patient.name) {
      if (!_hasPatientDetails(ownData)) return [];
      return [_patientFromData(ownProfile)];
    }
    if (ownData['role'] != UserRole.doctor.name) {
      throw StateError('Your Firestore user profile has an invalid role.');
    }

    final assignedPatients = await _users
        .where('role', isEqualTo: UserRole.patient.name)
        .where('primaryDoctorUid', isEqualTo: user.uid)
        .get();
    final appointmentPatients = await _users
        .where('role', isEqualTo: UserRole.patient.name)
        .where('appointmentDoctorUids', arrayContains: user.uid)
        .get();
    final profiles = {
      for (final document in assignedPatients.docs) document.id: document,
      for (final document in appointmentPatients.docs) document.id: document,
    };
    return profiles.values.map(_patientFromData).toList();
  }

  bool _hasPatientDetails(Map<String, dynamic> data) => [
        'name',
        'email',
        'nic',
        'dob',
        'gender',
        'phone',
        'address',
      ].every(data.containsKey);

  @override
  Future<void> add(Patient patient) async {
    await _users.doc(patient.id).set(
      {..._patientToData(patient), 'role': UserRole.patient.name},
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> update(Patient patient) async {
    await _users.doc(patient.id).set(
      {..._patientToData(patient), 'role': UserRole.patient.name},
      SetOptions(merge: true),
    );
  }

  Map<String, Object?> _patientToData(Patient patient) => {
        'name': patient.name,
        'email': patient.email,
        'nic': patient.nic,
        'dob': Timestamp.fromDate(patient.dob),
        'gender': patient.gender,
        'phone': patient.phone,
        'address': patient.address,
        'bloodGroup': patient.bloodGroup,
        if (patient.primaryDoctorUid != null)
          'primaryDoctorUid': patient.primaryDoctorUid,
      };

  Patient _patientFromData(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (data == null) {
      throw FormatException('Patient profile ${document.id} has no data.');
    }
    final nic = data['nic'];
    final dob = data['dob'];
    final gender = data['gender'];
    final phone = data['phone'];
    final address = data['address'];
    final name = data['name'];
    final email = data['email'];
    final primaryDoctorUid = data['primaryDoctorUid'];
    final appointmentDoctorUids = data['appointmentDoctorUids'];
    if (nic is! String ||
        dob is! Timestamp ||
        gender is! String ||
        phone is! String ||
        address is! String ||
        name is! String ||
        email is! String ||
        (primaryDoctorUid != null && primaryDoctorUid is! String) ||
        (appointmentDoctorUids != null &&
            (appointmentDoctorUids is! List ||
                appointmentDoctorUids.any((doctorUid) => doctorUid is! String)))) {
      throw FormatException(
        'Patient profile ${document.id} is missing required fields.',
      );
    }

    return Patient(
      id: document.id,
      name: name,
      email: email,
      nic: nic,
      dob: dob.toDate(),
      gender: gender,
      phone: phone,
      address: address,
      bloodGroup: data['bloodGroup'] is String
          ? data['bloodGroup'] as String
          : 'Unknown',
      primaryDoctorUid: primaryDoctorUid as String?,
      appointmentDoctorUids:
          (appointmentDoctorUids as List<dynamic>?)?.cast<String>() ??
              const [],
    );
  }
}
