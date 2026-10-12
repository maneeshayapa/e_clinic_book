abstract class QrService {
  /// Payload encoded into the patient's QR code.
  String encodePatient(String patientId);

  /// Returns the scanned patient ID, or null if cancelled.
  Future<String?> scan();
}

class MockQrService implements QrService {
  @override
  String encodePatient(String patientId) => 'ECLINIC:$patientId';

  @override
  Future<String?> scan() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    return 'P-1002'; // pretend we scanned this patient
  }
}
