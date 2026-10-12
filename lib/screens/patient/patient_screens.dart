import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/cards.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/date_field.dart';

/// Wraps content with loading/error handling and the current patient.
class _PatientScope extends StatelessWidget {
  final Widget Function(BuildContext, AppState, Patient) builder;
  const _PatientScope({required this.builder});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (s.loading) return const LoadingWidget();
    if (s.error != null) return ErrorState(message: s.error!, onRetry: s.init);
    final p = s.currentPatient;
    if (p == null) return _MissingPatientProfile(state: s);
    return builder(context, s, p);
  }
}

class _MissingPatientProfile extends StatefulWidget {
  const _MissingPatientProfile({required this.state});

  final AppState state;

  @override
  State<_MissingPatientProfile> createState() => _MissingPatientProfileState();
}

class _MissingPatientProfileState extends State<_MissingPatientProfile> {
  final _form = GlobalKey<FormState>();
  final _nic = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  DateTime? _dob;
  String? _gender;
  bool _saving = false;

  @override
  void dispose() {
    _nic.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final user = widget.state.user!;
    setState(() => _saving = true);
    try {
      await widget.state.completePatientProfile(
        Patient(
          id: user.id,
          name: user.name,
          email: user.email,
          nic: _nic.text.trim(),
          dob: _dob!,
          gender: _gender!,
          phone: _phone.text.trim(),
          address: _address.text.trim(),
        ),
      );
    } catch (error) {
      if (mounted) {
        showSnack(
          context,
          error.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.person_add_alt_1_outlined,
                    size: 52,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Complete your patient profile',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your account is signed in, but its patient details are not '
                    'saved yet. Enter them once to keep your profile available '
                    'after a refresh.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  CustomTextField(
                    controller: _nic,
                    label: 'NIC',
                    icon: Icons.badge_outlined,
                    validator: (value) {
                      final error = requiredField(value, 'NIC');
                      if (error != null) return error;
                      return RegExp(r'^(\d{9}[VvXx]|\d{12})$')
                              .hasMatch(value!.trim())
                          ? null
                          : 'Enter a valid NIC (9 digits + V, or 12 digits)';
                    },
                  ),
                  DateField(
                    label: 'Date of Birth',
                    value: _dob,
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                    onChanged: (date) => _dob = date,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _gender,
                    decoration: const InputDecoration(
                      labelText: 'Gender',
                      prefixIcon: Icon(Icons.wc),
                    ),
                    items: [
                      for (final gender in AppConstants.genders)
                        DropdownMenuItem(value: gender, child: Text(gender)),
                    ],
                    validator: (value) =>
                        value == null ? 'Select gender' : null,
                    onChanged: (value) => _gender = value,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: _phone,
                    label: 'Phone Number',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (value) =>
                        RegExp(r'^\+?\d{9,12}$').hasMatch((value ?? '').trim())
                            ? null
                            : 'Enter a valid phone number',
                  ),
                  CustomTextField(
                    controller: _address,
                    label: 'Address',
                    icon: Icons.home_outlined,
                    maxLines: 2,
                    validator: (value) => requiredField(value, 'Address'),
                  ),
                  CustomButton(
                    label: 'Save Patient Profile',
                    loading: _saving,
                    onPressed: _saving ? null : _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

List<Widget> _bellAndSettings(BuildContext context) => [
      IconButton(
          onPressed: () => context.push('/notifications'),
          icon: const Icon(Icons.notifications_outlined)),
      IconButton(
          onPressed: () => context.push('/settings'),
          icon: const Icon(Icons.settings_outlined)),
    ];

class PatientHomeScreen extends StatelessWidget {
  const PatientHomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text('E-Clinic Book'.localized(context)),
            actions: _bellAndSettings(context)),
        body: _PatientScope(builder: (context, s, p) {
          final last = s.lastVisit(p.id);
          final today = DateTime.now();
          final next = s
              .appointmentsFor(p.id)
              .where((a) =>
                  a.status == AppointmentStatus.upcoming &&
                  !a.date
                      .isBefore(DateTime(today.year, today.month, today.day)))
              .toList();
          final meds = last?.medicines ?? [];
          return ListView(padding: const EdgeInsets.all(16), children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [AppTheme.primary, Color(0xFF2BA6B5)]),
                  borderRadius: BorderRadius.circular(22)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome back,'.localized(context),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 16)),
                    Text(p.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('Patient ID: ${p.id}',
                        style: const TextStyle(color: Colors.white)),
                  ]),
            ),
            const SizedBox(height: 16),
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => context.push('/qr'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    QrCodeView(data: s.qr.encodePatient(p.id), size: 90),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('My QR Code',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 17)),
                            SizedBox(height: 4),
                            Text(
                                'Show this to your doctor to open your clinic book quickly.'),
                          ]),
                    ),
                    const Icon(Icons.chevron_right),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Health Summary',
              icon: Icons.monitor_heart_outlined,
              child: Row(children: [
                _Vital('Blood Pressure', last?.bp ?? '-'),
                _Vital('Weight', last == null ? '-' : '${last.weight} kg'),
                _Vital('Last Visit', last == null ? '-' : fmtDate(last.date)),
              ]),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.9,
              children: [
                _Quick(Icons.menu_book_outlined, 'Clinic Book',
                    () => context.go('/patient/clinic-book')),
                _Quick(Icons.calendar_month_outlined, 'Appointments',
                    () => context.go('/patient/appointments')),
                _Quick(Icons.biotech_outlined, 'Medical Reports',
                    () => context.go('/patient/reports')),
                _Quick(Icons.medication_outlined, 'Prescriptions',
                    () => context.push('/patient/prescriptions')),
              ],
            ),
            const SizedBox(height: 20),
            const _Heading('Next Appointment'),
            next.isEmpty
                ? const SectionCard(child: Text('No upcoming appointments'))
                : AppointmentCard(
                    appt: next.first,
                    onTap: () => context.go('/patient/appointments')),
            const SizedBox(height: 20),
            const _Heading('Latest Clinic Visit'),
            last == null
                ? const SectionCard(child: Text('No visits recorded yet'))
                : ClinicVisitCard(
                    visit: last,
                    onTap: () => context.push('/visit/${last.id}')),
            const SizedBox(height: 20),
            const _Heading('Current Prescriptions'),
            if (meds.isEmpty)
              const SectionCard(child: Text('No active prescriptions')),
            for (final m in meds)
              Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PrescriptionCard(medicine: m)),
          ]);
        }),
      );
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text.localized(context),
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
      );
}

class _Vital extends StatelessWidget {
  final String label, value;
  const _Vital(this.label, this.value);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: AppTheme.primary)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ]),
      );
}

class _Quick extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Quick(this.icon, this.label, this.onTap);
  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Icon(icon, color: AppTheme.primary, size: 28),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w700))),
            ]),
          ),
        ),
      );
}

class ClinicBookScreen extends StatelessWidget {
  const ClinicBookScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Digital Clinic Book'.localized(context))),
        body: _PatientScope(builder: (context, s, p) {
          final visits = s.visitsFor(p.id);
          return ListView(padding: const EdgeInsets.all(16), children: [
            SectionCard(
              title: 'Patient Information',
              icon: Icons.badge_outlined,
              child: Column(children: [
                InfoRow('Name', p.name),
                InfoRow('Patient ID', p.id),
                InfoRow('NIC', p.nic),
                InfoRow('Date of Birth', fmtDate(p.dob)),
                InfoRow('Blood Group', p.bloodGroup),
              ]),
            ),
            const SizedBox(height: 20),
            Text('Clinic Visits'.localized(context),
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            if (visits.isEmpty)
              const SizedBox(
                  height: 200,
                  child: EmptyState(
                      icon: Icons.menu_book_outlined,
                      message: 'No clinic visits yet.')),
            for (final v in visits)
              Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ClinicVisitCard(
                      visit: v, onTap: () => context.push('/visit/${v.id}'))),
          ]);
        }),
      );
}

class PrescriptionsScreen extends StatelessWidget {
  const PrescriptionsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Prescriptions'.localized(context))),
        body: _PatientScope(builder: (context, s, p) {
          final meds = s.medicinesFor(p.id);
          if (meds.isEmpty) {
            return const EmptyState(
                icon: Icons.medication_outlined,
                message: 'No prescriptions found.');
          }
          return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: meds.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => PrescriptionCard(medicine: meds[i]));
        }),
      );
}

class PatientAppointmentsScreen extends StatelessWidget {
  const PatientAppointmentsScreen({super.key});

  void _cancel(BuildContext context, AppState s, Appointment a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Cancel appointment?'.localized(context)),
        content: Text('${a.clinic} on ${fmtDate(a.date)} at ${a.time}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: Text('Keep'.localized(context))),
          TextButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: Text('Cancel it'.localized(context))),
        ],
      ),
    );
    if (ok == true) {
      try {
        await s.setAppointmentStatus(a.id, AppointmentStatus.cancelled);
        if (context.mounted) showSnack(context, 'Appointment cancelled');
      } catch (error) {
        if (context.mounted) {
          showSnack(
            context,
            error.toString().replaceFirst('Exception: ', ''),
            error: true,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Appointments'.localized(context))),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showBookSheet(context),
          icon: const Icon(Icons.add),
          label: Text('Book Appointment'.localized(context)),
        ),
        body: _PatientScope(builder: (context, s, p) {
          final all = s.appointmentsFor(p.id);
          final upcoming =
              all.where((a) => a.status == AppointmentStatus.upcoming).toList();
          final previous =
              all.where((a) => a.status != AppointmentStatus.upcoming).toList();
          if (all.isEmpty) {
            return const EmptyState(
                icon: Icons.event_busy, message: 'No appointments yet.');
          }
          return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                const _Heading('Upcoming'),
                if (upcoming.isEmpty)
                  const SectionCard(child: Text('No upcoming appointments')),
                for (final a in upcoming)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppointmentCard(
                          appt: a, onTap: () => _cancel(context, s, a))),
                const SizedBox(height: 16),
                const _Heading('Previous'),
                if (previous.isEmpty)
                  const SectionCard(child: Text('No previous appointments')),
                for (final a in previous)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppointmentCard(appt: a)),
              ]);
        }),
      );
}

void _showBookSheet(BuildContext context) {
  final s = context.read<AppState>();
  final p = s.currentPatient!;
  final form = GlobalKey<FormState>();
  final doctors = s.doctors;
  final preferredDoctorId = doctors
          .where((doctor) => doctor.id == p.primaryDoctorUid)
          .firstOrNull
          ?.id ??
      doctors.firstOrNull?.id;
  String? doctorId = preferredDoctorId;
  String? clinic;
  String? time;
  DateTime? date;
  const times = [
    '08:30 AM',
    '09:00 AM',
    '09:30 AM',
    '10:00 AM',
    '11:00 AM',
    '02:00 PM'
  ];
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.of(sheet).viewInsets.bottom + 20),
      child: Form(
        key: form,
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Book Appointment'.localized(sheet),
                  style: Theme.of(sheet)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              if (doctors.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Text(
                    'No doctors are currently available for booking. '
                    'Please contact the clinic.',
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: preferredDoctorId,
                  decoration: const InputDecoration(
                    labelText: 'Doctor',
                    prefixIcon: Icon(Icons.medical_services_outlined),
                  ),
                  items: [
                    for (final doctor in doctors)
                      DropdownMenuItem(
                        value: doctor.id,
                        child: Text(
                          doctor.hospital.isEmpty
                              ? doctor.name
                              : '${doctor.name} · ${doctor.hospital}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  validator: (value) =>
                      value == null ? 'Select a doctor' : null,
                  onChanged: (value) => doctorId = value,
                ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                    labelText: 'Clinic',
                    prefixIcon: Icon(Icons.local_hospital_outlined)),
                items: [
                  for (final c in AppConstants.clinics)
                    DropdownMenuItem(value: c, child: Text(c))
                ],
                validator: (v) => v == null ? 'Select a clinic' : null,
                onChanged: (v) => clinic = v,
              ),
              const SizedBox(height: 14),
              DateField(
                  label: 'Date',
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  onChanged: (d) => date = d),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                    labelText: 'Time', prefixIcon: Icon(Icons.access_time)),
                items: [
                  for (final t in times)
                    DropdownMenuItem(value: t, child: Text(t))
                ],
                validator: (v) => v == null ? 'Select a time' : null,
                onChanged: (v) => time = v,
              ),
              const SizedBox(height: 20),
              CustomButton(
                label: 'Confirm Booking',
                onPressed: doctors.isEmpty
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        try {
                          final selectedDoctor = doctors
                              .where((doctor) => doctor.id == doctorId)
                              .firstOrNull;
                          if (selectedDoctor == null) {
                            showSnack(
                              context,
                              'Select an available doctor.',
                              error: true,
                            );
                            return;
                          }
                          await s.addAppointment(Appointment(
                            id: 'A-${DateTime.now().microsecondsSinceEpoch}',
                            patientId: p.id,
                            patientName: p.name,
                            date: date!,
                            time: time!,
                            hospital: selectedDoctor.hospital.isEmpty
                                ? 'Negombo General Hospital'
                                : selectedDoctor.hospital,
                            clinic: clinic!,
                            doctor: selectedDoctor.name,
                            doctorId: doctorId,
                          ));
                          if (sheet.mounted) Navigator.of(sheet).pop();
                          if (context.mounted) {
                            showSnack(context, 'Appointment booked');
                          }
                        } catch (error) {
                          if (context.mounted) {
                            showSnack(
                              context,
                              error.toString().replaceFirst('Exception: ', ''),
                              error: true,
                            );
                          }
                        }
                      },
              ),
            ]),
      ),
    ),
  );
}

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Laboratory Reports'.localized(context))),
        body: _PatientScope(builder: (context, s, p) {
          final list = s.reportsFor(p.id);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _showPatientReportUpload(context, p),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Upload Report'),
                  ),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const EmptyState(
                        icon: Icons.biotech_outlined,
                        message: 'No laboratory reports yet.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => ReportCard(
                          report: list[i],
                          onTap: () => context.push('/report/${list[i].id}'),
                        ),
                      ),
              ),
            ],
          );
        }),
      );
}

void _showPatientReportUpload(BuildContext context, Patient patient) {
  showDialog<void>(
    context: context,
    builder: (_) => _PatientReportUploadDialog(patient: patient),
  );
}

class _PatientReportUploadDialog extends StatefulWidget {
  const _PatientReportUploadDialog({required this.patient});

  final Patient patient;

  @override
  State<_PatientReportUploadDialog> createState() =>
      _PatientReportUploadDialogState();
}

class _PatientReportUploadDialogState
    extends State<_PatientReportUploadDialog> {
  static const _laboratoryOptions = [
    'Negombo General Hospital Lab',
    'Colombo National Hospital Lab',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();
  final _testNameController = TextEditingController();
  final _laboratoryController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedLaboratory;
  DateTime _date = DateTime.now();
  Uint8List? _fileBytes;
  String? _fileName;
  String? _contentType;
  bool _uploading = false;

  @override
  void dispose() {
    _testNameController.dispose();
    _laboratoryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _chooseFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result.isEmpty) return;

      final file = result.first;
      final extension = file.extension?.toLowerCase();
      final contentType = switch (extension) {
        'pdf' => 'application/pdf',
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        _ => null,
      };
      if (contentType == null) {
        _showError('Choose a PDF, JPG, JPEG, or PNG file.');
        return;
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        _showError('The selected file is empty.');
        return;
      }
      if (!mounted) return;
      setState(() {
        _fileBytes = bytes;
        _fileName = file.name;
        _contentType = contentType;
      });
    } catch (_) {
      if (mounted) _showError('Could not select or read the report file.');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final fileBytes = _fileBytes;
    final fileName = _fileName;
    final contentType = _contentType;
    if (fileBytes == null || fileName == null || contentType == null) {
      _showError('Select a PDF, JPG, JPEG, or PNG report file.');
      return;
    }

    setState(() => _uploading = true);
    try {
      final state = context.read<AppState>();
      await state.uploadLabReport(
        LabReport(
          id: state.newReportId(),
          patientId: widget.patient.id,
          name: _testNameController.text.trim(),
          type: 'Laboratory Test',
          lab: _selectedLaboratory == 'Other'
              ? _laboratoryController.text.trim()
              : _selectedLaboratory!,
          date: _date,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        ),
        fileBytes,
        fileName,
        contentType,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Report uploaded successfully.')),
      );
    } catch (error) {
      if (mounted) {
        _showError('Could not upload report: $error');
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Upload Laboratory Report'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Hospital / Laboratory',
                      prefixIcon: Icon(Icons.local_hospital_outlined),
                    ),
                    items: [
                      for (final laboratory in _laboratoryOptions)
                        DropdownMenuItem(
                          value: laboratory,
                          child: Text(
                            laboratory,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    validator: (value) => value == null
                        ? 'Select a hospital or laboratory.'
                        : null,
                    onChanged: _uploading
                        ? null
                        : (value) => setState(() {
                              _selectedLaboratory = value;
                              if (value != 'Other') {
                                _laboratoryController.clear();
                              }
                            }),
                  ),
                  if (_selectedLaboratory == 'Other')
                    TextFormField(
                      controller: _laboratoryController,
                      decoration: const InputDecoration(
                        labelText: 'Facility name',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Enter the hospital or laboratory name.'
                              : null,
                    ),
                  TextFormField(
                    controller: _testNameController,
                    decoration: const InputDecoration(
                      labelText: 'Report Type / Test Name',
                      prefixIcon: Icon(Icons.biotech_outlined),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter the report type or test name.'
                        : null,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Report Date'),
                    subtitle: Text(fmtDate(_date)),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: _uploading
                        ? null
                        : () async {
                            final selected = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (selected != null && mounted) {
                              setState(() => _date = selected);
                            }
                          },
                  ),
                  TextFormField(
                    controller: _notesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _uploading ? null : _chooseFile,
                    icon: const Icon(Icons.attach_file),
                    label: Text(_fileName ?? 'Choose PDF or image'),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _uploading ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _uploading ? null : _submit,
            child: _uploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save / Upload Report'),
          ),
        ],
      );
}

class PatientQrScreen extends StatelessWidget {
  const PatientQrScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('My QR Code'.localized(context))),
        body: _PatientScope(
            builder: (context, s, p) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(p.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          Text(p.id,
                              style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16)),
                          const SizedBox(height: 20),
                          QrCodeView(data: s.qr.encodePatient(p.id), size: 240),
                          const SizedBox(height: 20),
                          Text(
                              'Show this code to your doctor'
                                  .localized(context),
                              style: TextStyle(color: Colors.grey.shade600)),
                        ]),
                      ),
                    ),
                  ),
                )),
      );
}

class PatientProfileScreen extends StatelessWidget {
  const PatientProfileScreen({super.key});

  void _edit(BuildContext context, AppState s, Patient p) {
    final name = TextEditingController(text: p.name),
        phone = TextEditingController(text: p.phone),
        address = TextEditingController(text: p.address);
    final form = GlobalKey<FormState>();
    showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 8),
              CustomTextField(
                  controller: name,
                  label: 'Full Name',
                  validator: (v) => requiredField(v, 'Name')),
              CustomTextField(
                  controller: phone,
                  label: 'Phone',
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      RegExp(r'^\+?\d{9,12}$').hasMatch((v ?? '').trim())
                          ? null
                          : 'Enter a valid phone number'),
              CustomTextField(
                  controller: address,
                  label: 'Address',
                  maxLines: 2,
                  validator: (v) => requiredField(v, 'Address')),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(d).pop(),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              await s.updateProfile(p,
                  name: name.text.trim(),
                  phone: phone.text.trim(),
                  address: address.text.trim());
              if (d.mounted) Navigator.of(d).pop();
              if (context.mounted) showSnack(context, 'Profile updated');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text('Profile'.localized(context)),
            actions: _bellAndSettings(context)),
        body: _PatientScope(
            builder: (context, s, p) =>
                ListView(padding: const EdgeInsets.all(16), children: [
                  Center(
                    child: Column(children: [
                      const CircleAvatar(
                          radius: 48,
                          backgroundColor: Color(0xFFD9EEF1),
                          child: Icon(Icons.person,
                              size: 52, color: AppTheme.primary)),
                      const SizedBox(height: 10),
                      Text(p.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      Text(p.id,
                          style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    child: Column(children: [
                      InfoRow('NIC', p.nic),
                      InfoRow('Date of Birth', fmtDate(p.dob)),
                      InfoRow('Gender', p.gender),
                      InfoRow('Phone', p.phone),
                      InfoRow('Email', p.email),
                      InfoRow('Address', p.address),
                      InfoRow('Blood Group', p.bloodGroup),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  CustomButton(
                      label: 'Edit Profile',
                      icon: Icons.edit_outlined,
                      onPressed: () => _edit(context, s, p)),
                  const SizedBox(height: 10),
                  CustomButton(
                      label: 'Change Password',
                      icon: Icons.lock_outline,
                      outlined: true,
                      onPressed: () => showChangePasswordDialog(context)),
                  const SizedBox(height: 10),
                  CustomButton(
                      label: 'Logout',
                      icon: Icons.logout,
                      outlined: true,
                      onPressed: () => s.logout()),
                ])),
      );
}

void showChangePasswordDialog(BuildContext context) {
  final form = GlobalKey<FormState>();
  final cur = TextEditingController(),
      next = TextEditingController(),
      conf = TextEditingController();
  showDialog<void>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('Change Password'),
      content: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 8),
            CustomTextField(
                controller: cur,
                label: 'Current password',
                obscure: true,
                validator: validatePassword),
            CustomTextField(
                controller: next,
                label: 'New password',
                obscure: true,
                validator: validatePassword),
            CustomTextField(
                controller: conf,
                label: 'Confirm new password',
                obscure: true,
                validator: (v) =>
                    v != next.text ? 'Passwords do not match' : null),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(d).pop(),
            child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
          onPressed: () {
            if (!form.currentState!.validate()) return;
            Navigator.of(d).pop();
            showSnack(context, 'Password changed (mock)');
          },
          child: const Text('Update'),
        ),
      ],
    ),
  );
}
