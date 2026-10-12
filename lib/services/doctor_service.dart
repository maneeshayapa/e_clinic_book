import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/models.dart';
import 'mock_data.dart';

abstract class DoctorService {
  Future<List<Doctor>> getAll();
}

class MockDoctorService implements DoctorService {
  @override
  Future<List<Doctor>> getAll() async => List.of(MockData.doctors);
}

class FirebaseDoctorService implements DoctorService {
  FirebaseDoctorService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  @override
  Future<List<Doctor>> getAll() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final users = _firestore.collection('users');
    final profile = await users.doc(user.uid).get();
    final profileData = profile.data();
    if (profileData == null) {
      throw StateError('Your Firestore user profile could not be found.');
    }

    if (profileData['role'] == UserRole.doctor.name) {
      return [_doctorFromData(user.uid, profileData)];
    }
    if (profileData['role'] != UserRole.patient.name) {
      throw StateError('Your Firestore user profile has an invalid role.');
    }

    final snapshot =
        await users.where('role', isEqualTo: UserRole.doctor.name).get();
    return snapshot.docs
        .map((document) => _doctorFromData(document.id, document.data()))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Doctor _doctorFromData(String id, Map<String, dynamic> data) {
    final name = data['name'];
    final email = data['email'];
    if (name is! String || email is! String) {
      throw FormatException('Doctor profile $id is missing its name or email.');
    }
    return Doctor(
      id: id,
      name: name,
      email: email,
      speciality: data['speciality'] is String ? data['speciality'] : '',
      hospital: data['hospital'] is String ? data['hospital'] : '',
    );
  }
}
