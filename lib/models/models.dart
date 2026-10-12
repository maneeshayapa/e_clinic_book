enum UserRole { patient, doctor }

enum AppointmentStatus { upcoming, completed, cancelled }

class AppUser {
  final String id, name, email;
  final UserRole role;
  const AppUser({required this.id, required this.name, required this.email, required this.role});
}

class Patient {
  final String id, nic, gender, bloodGroup;
  final DateTime dob;
  String name, phone, email, address;
  final String? primaryDoctorUid;
  final List<String> appointmentDoctorUids;
  Patient({
    required this.id,
    required this.name,
    required this.nic,
    required this.dob,
    required this.gender,
    required this.phone,
    required this.email,
    required this.address,
    this.bloodGroup = 'Unknown',
    this.primaryDoctorUid,
    this.appointmentDoctorUids = const [],
  });
  int get age {
    final now = DateTime.now();
    var a = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) a--;
    return a;
  }
}

class Doctor {
  final String id, name, speciality, hospital, email;
  const Doctor({required this.id, required this.name, required this.speciality, required this.hospital, required this.email});
}

class Medicine {
  final String name, dosage, frequency, duration, instructions;
  const Medicine({
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.duration,
    required this.instructions,
  });
}

class ClinicVisit {
  final String id, patientId, hospital, clinic, doctor, symptoms;
  final String? doctorId, primaryDoctorUid;
  final String bp, heartRate, temperature, weight, height;
  final String diagnosis, treatment, notes;
  final DateTime date;
  final DateTime? nextVisit;
  final List<Medicine> medicines;
  const ClinicVisit({
    required this.id,
    required this.patientId,
    required this.date,
    required this.hospital,
    required this.clinic,
    required this.doctor,
    required this.symptoms,
    required this.bp,
    required this.heartRate,
    required this.temperature,
    required this.weight,
    required this.height,
    required this.diagnosis,
    required this.treatment,
    required this.medicines,
    required this.notes,
    this.nextVisit,
    this.doctorId,
    this.primaryDoctorUid,
  });
}

class Appointment {
  final String id, patientId, patientName, time, hospital, clinic, doctor;
  final String? doctorId;
  final DateTime date;
  AppointmentStatus status;
  Appointment({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.date,
    required this.time,
    required this.hospital,
    required this.clinic,
    required this.doctor,
    this.status = AppointmentStatus.upcoming,
    this.doctorId,
  });
}

class LabReport {
  final String id, patientId, name, type, lab, status;
  final String? doctorId, primaryDoctorUid;
  final String? notes;
  final DateTime date;
  final String? fileName, storagePath;
  const LabReport({
    required this.id,
    required this.patientId,
    required this.name,
    required this.type,
    required this.lab,
    required this.date,
    this.status = 'Available',
    this.fileName,
    this.storagePath,
    this.doctorId,
    this.primaryDoctorUid,
    this.notes,
  });
}

class AppNotification {
  final String id, title, body;
  final DateTime date;
  bool read;
  AppNotification({required this.id, required this.title, required this.body, required this.date, this.read = false});
}
