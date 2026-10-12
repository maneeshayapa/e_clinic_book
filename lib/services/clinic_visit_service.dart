import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/models.dart';
import 'mock_data.dart';

abstract class ClinicVisitService {
  Future<List<ClinicVisit>> getAll();
  Future<void> add(ClinicVisit visit);
}

class MockClinicVisitService implements ClinicVisitService {
  final List<ClinicVisit> _items = MockData.visits();

  @override
  Future<List<ClinicVisit>> getAll() async => List.of(_items);

  @override
  Future<void> add(ClinicVisit visit) async => _items.add(visit);
}

class FirebaseClinicVisitService implements ClinicVisitService {
  FirebaseClinicVisitService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _visits =>
      _firestore.collection('clinicVisits');

  @override
  Future<List<ClinicVisit>> getAll() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final profile = await _firestore.collection('users').doc(user.uid).get();
    final role = profile.data()?['role'];
    final Query<Map<String, dynamic>> query;
    if (role == UserRole.doctor.name) {
      query = _visits.where('primaryDoctorUid', isEqualTo: user.uid);
    } else if (role == UserRole.patient.name) {
      query = _visits.where('patientId', isEqualTo: user.uid);
    } else {
      throw StateError('Your account has no valid patient or doctor role.');
    }

    final snapshot = await query.get();
    final visits = snapshot.docs
        .map((document) => _visitFromData(document.id, document.data()))
        .toList();
    visits.sort((a, b) => b.date.compareTo(a.date));
    return visits;
  }

  @override
  Future<void> add(ClinicVisit visit) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in to add a clinic visit.');
    if (visit.doctorId != user.uid || visit.primaryDoctorUid != user.uid) {
      throw StateError(
        'Clinic visits can only be added by the patient’s assigned doctor.',
      );
    }
    final patient =
        await _firestore.collection('users').doc(visit.patientId).get();
    if (patient.data()?['primaryDoctorUid'] != user.uid) {
      throw StateError(
        'Clinic visits can only be added for your assigned patients.',
      );
    }
    await _visits.doc(visit.id).set(_visitToData(visit));
  }

  Map<String, dynamic> _visitToData(ClinicVisit visit) => {
        'patientId': visit.patientId,
        'doctorId': visit.doctorId,
        'primaryDoctorUid': visit.primaryDoctorUid,
        'date': Timestamp.fromDate(visit.date),
        'hospital': visit.hospital,
        'clinic': visit.clinic,
        'doctor': visit.doctor,
        'symptoms': visit.symptoms,
        'bp': visit.bp,
        'heartRate': visit.heartRate,
        'temperature': visit.temperature,
        'weight': visit.weight,
        'height': visit.height,
        'diagnosis': visit.diagnosis,
        'treatment': visit.treatment,
        'medicines': visit.medicines
            .map((medicine) => {
                  'name': medicine.name,
                  'dosage': medicine.dosage,
                  'frequency': medicine.frequency,
                  'duration': medicine.duration,
                  'instructions': medicine.instructions,
                })
            .toList(),
        'notes': visit.notes,
        'nextVisit': visit.nextVisit == null
            ? null
            : Timestamp.fromDate(visit.nextVisit!),
      };

  ClinicVisit _visitFromData(String id, Map<String, dynamic> data) {
    final date = data['date'];
    if (date is! Timestamp) {
      throw FormatException('Clinic visit $id has no valid date.');
    }

    final medicinesData = data['medicines'];
    if (medicinesData != null && medicinesData is! List) {
      throw FormatException('Clinic visit $id has invalid medicines data.');
    }
    final medicines = (medicinesData as List<dynamic>? ?? [])
        .map((medicine) {
          if (medicine is! Map<String, dynamic>) {
            throw FormatException(
              'Clinic visit $id contains an invalid medicine.',
            );
          }
          return Medicine(
            name: _stringField(medicine, 'name', id),
            dosage: _stringField(medicine, 'dosage', id),
            frequency: _stringField(medicine, 'frequency', id),
            duration: _stringField(medicine, 'duration', id),
            instructions: _stringField(medicine, 'instructions', id),
          );
        })
        .toList();
    final nextVisit = data['nextVisit'];
    if (nextVisit != null && nextVisit is! Timestamp) {
      throw FormatException('Clinic visit $id has an invalid next visit date.');
    }

    return ClinicVisit(
      id: id,
      patientId: _stringField(data, 'patientId', id),
      doctorId: _optionalStringField(data, 'doctorId', id),
      primaryDoctorUid: _optionalStringField(data, 'primaryDoctorUid', id),
      date: date.toDate(),
      hospital: _stringField(data, 'hospital', id),
      clinic: _stringField(data, 'clinic', id),
      doctor: _stringField(data, 'doctor', id),
      symptoms: _stringField(data, 'symptoms', id),
      bp: _stringField(data, 'bp', id),
      heartRate: _stringField(data, 'heartRate', id),
      temperature: _stringField(data, 'temperature', id),
      weight: _stringField(data, 'weight', id),
      height: _stringField(data, 'height', id),
      diagnosis: _stringField(data, 'diagnosis', id),
      treatment: _stringField(data, 'treatment', id),
      medicines: medicines,
      notes: _stringField(data, 'notes', id),
      nextVisit: (nextVisit as Timestamp?)?.toDate(),
    );
  }

  String _stringField(Map<String, dynamic> data, String field, String id) {
    final value = data[field];
    if (value is! String) {
      throw FormatException('Clinic visit $id has an invalid $field field.');
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
      throw FormatException('Clinic visit $id has an invalid $field field.');
    }
    return value;
  }
}
