import '../models/models.dart';

/// Seed data used only by the Mock* services. Never referenced from widgets.
class MockData {
  static final _now = DateTime.now();

  static List<Patient> patients() => [
        Patient(id: 'P-1001', name: 'Nimal Fernando', nic: '198512345678', dob: DateTime(1985, 3, 14), gender: 'Male', phone: '0771234567', email: 'nimal@example.com', address: '12 Lake Road, Negombo', bloodGroup: 'O+', primaryDoctorUid: 'D-2001'),
        Patient(id: 'P-1002', name: 'Sunethra Silva', nic: '195809876543', dob: DateTime(1958, 7, 2), gender: 'Female', phone: '0712345678', email: 'sunethra@example.com', address: '45 Temple Lane, Colombo 07', bloodGroup: 'A+', primaryDoctorUid: 'D-2002'),
        Patient(id: 'P-1003', name: 'Kamal Jayasuriya', nic: '197204561239', dob: DateTime(1972, 11, 23), gender: 'Male', phone: '0759876543', email: 'kamal@example.com', address: '8 Hill Street, Kandy', bloodGroup: 'B-'),
      ];

  static const doctors = [
    Doctor(id: 'D-2001', name: 'Dr. Kasun Perera', speciality: 'General Physician', hospital: 'Negombo General Hospital', email: 'kasun@hospital.lk'),
    Doctor(id: 'D-2002', name: 'Dr. Anjali Wickramasinghe', speciality: 'Cardiologist', hospital: 'Colombo National Hospital', email: 'anjali@hospital.lk'),
  ];

  static const _para = Medicine(name: 'Paracetamol', dosage: '500 mg', frequency: '3 times daily', duration: '5 days', instructions: 'After meals');

  static List<ClinicVisit> visits() => [
        ClinicVisit(id: 'V-1', patientId: 'P-1001', date: DateTime(2026, 10, 4), hospital: 'Negombo General Hospital', clinic: 'General Clinic', doctor: 'Dr. Kasun Perera', symptoms: 'Fever, body aches, sore throat', bp: '120/80', heartRate: '76', temperature: '36.7', weight: '65', height: '170', diagnosis: 'Viral fever', treatment: 'Rest, fluids and symptomatic treatment', medicines: const [_para, Medicine(name: 'Cetirizine', dosage: '10 mg', frequency: 'Once at night', duration: '5 days', instructions: 'Before bed')], notes: 'Return if fever persists beyond 3 days.', nextVisit: DateTime(2026, 11, 4)),
        ClinicVisit(id: 'V-2', patientId: 'P-1001', date: DateTime(2026, 9, 6), hospital: 'Negombo General Hospital', clinic: 'Diabetes Clinic', doctor: 'Dr. Kasun Perera', symptoms: 'Routine review', bp: '125/82', heartRate: '78', temperature: '36.6', weight: '66', height: '170', diagnosis: 'Type 2 diabetes - controlled', treatment: 'Continue medication and diet plan', medicines: const [Medicine(name: 'Metformin', dosage: '500 mg', frequency: 'Twice daily', duration: '30 days', instructions: 'With meals')], notes: 'HbA1c improving.', nextVisit: DateTime(2026, 10, 4)),
        ClinicVisit(id: 'V-3', patientId: 'P-1001', date: DateTime(2026, 7, 12), hospital: 'Colombo National Hospital', clinic: 'Cardiology Clinic', doctor: 'Dr. Anjali Wickramasinghe', symptoms: 'Occasional chest tightness', bp: '130/85', heartRate: '82', temperature: '36.5', weight: '67', height: '170', diagnosis: 'Mild hypertension', treatment: 'Lifestyle changes, low salt diet', medicines: const [Medicine(name: 'Amlodipine', dosage: '5 mg', frequency: 'Once daily', duration: '30 days', instructions: 'Morning')], notes: 'ECG normal.'),
        ClinicVisit(id: 'V-4', patientId: 'P-1002', date: DateTime(2026, 9, 18), hospital: 'Colombo National Hospital', clinic: 'Medical Clinic', doctor: 'Dr. Kasun Perera', symptoms: 'Joint pain, fatigue', bp: '135/85', heartRate: '80', temperature: '36.6', weight: '58', height: '155', diagnosis: 'Osteoarthritis', treatment: 'Physiotherapy and pain management', medicines: const [Medicine(name: 'Diclofenac', dosage: '50 mg', frequency: 'Twice daily', duration: '7 days', instructions: 'After meals')], notes: 'Avoid stairs where possible.', nextVisit: DateTime(2026, 10, 18)),
        ClinicVisit(id: 'V-5', patientId: 'P-1003', date: DateTime(2026, 8, 25), hospital: 'Kandy Teaching Hospital', clinic: 'General Clinic', doctor: 'Dr. Kasun Perera', symptoms: 'Cough and cold', bp: '118/76', heartRate: '72', temperature: '37.1', weight: '74', height: '175', diagnosis: 'Upper respiratory infection', treatment: 'Steam inhalation and rest', medicines: const [Medicine(name: 'Amoxicillin', dosage: '500 mg', frequency: '3 times daily', duration: '7 days', instructions: 'Complete the course')], notes: ''),
      ];

  static List<Appointment> appointments() => [
        Appointment(id: 'A-1', patientId: 'P-1001', patientName: 'Nimal Fernando', date: DateTime(_now.year, _now.month, _now.day), time: '09:30 AM', hospital: 'Negombo General Hospital', clinic: 'General Clinic', doctor: 'Dr. Kasun Perera', doctorId: 'D-2001'),
        Appointment(id: 'A-2', patientId: 'P-1002', patientName: 'Sunethra Silva', date: DateTime(_now.year, _now.month, _now.day), time: '10:15 AM', hospital: 'Colombo National Hospital', clinic: 'Medical Clinic', doctor: 'Dr. Anjali Wickramasinghe', doctorId: 'D-2002'),
        Appointment(id: 'A-3', patientId: 'P-1001', patientName: 'Nimal Fernando', date: _now.add(const Duration(days: 30)), time: '09:00 AM', hospital: 'Negombo General Hospital', clinic: 'Diabetes Clinic', doctor: 'Dr. Kasun Perera', doctorId: 'D-2001'),
        Appointment(id: 'A-4', patientId: 'P-1001', patientName: 'Nimal Fernando', date: DateTime(2026, 9, 6), time: '09:00 AM', hospital: 'Negombo General Hospital', clinic: 'Diabetes Clinic', doctor: 'Dr. Kasun Perera', status: AppointmentStatus.completed, doctorId: 'D-2001'),
        Appointment(id: 'A-5', patientId: 'P-1002', patientName: 'Sunethra Silva', date: _now.add(const Duration(days: 14)), time: '11:00 AM', hospital: 'Negombo General Hospital', clinic: 'General Clinic', doctor: 'Dr. Kasun Perera', doctorId: 'D-2001'),
      ];

  static List<LabReport> reports() => [
        LabReport(id: 'R-1', patientId: 'P-1001', name: 'Full Blood Count', type: 'Blood Test', lab: 'Negombo General Hospital Lab', date: DateTime(2026, 10, 4)),
        LabReport(id: 'R-2', patientId: 'P-1001', name: 'Lipid Profile', type: 'Blood Test', lab: 'Negombo General Hospital Lab', date: DateTime(2026, 9, 20)),
        LabReport(id: 'R-3', patientId: 'P-1002', name: 'Fasting Blood Sugar', type: 'Blood Test', lab: 'Colombo National Hospital Lab', date: DateTime(2026, 9, 18)),
      ];

  static List<AppNotification> notifications() => [
        AppNotification(id: 'N-1', title: 'Appointment reminder', body: 'Your clinic appointment is tomorrow at 9:30 AM.', date: _now),
        AppNotification(id: 'N-2', title: 'Report available', body: 'Your laboratory report is available.', date: _now.subtract(const Duration(days: 1))),
        AppNotification(id: 'N-3', title: 'Next visit', body: 'Your next clinic visit is scheduled for 04 Nov 2026.', date: _now.subtract(const Duration(days: 2))),
        AppNotification(id: 'N-4', title: 'New prescription', body: 'A new prescription was added by Dr. Kasun Perera.', date: _now.subtract(const Duration(days: 3)), read: true),
        AppNotification(id: 'N-5', title: 'Profile updated', body: 'Your profile details were updated successfully.', date: _now.subtract(const Duration(days: 6)), read: true),
      ];
}
