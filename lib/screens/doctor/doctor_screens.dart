import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../services/report_service.dart';
import '../../widgets/cards.dart';
import '../../widgets/common_widgets.dart';
import '../patient/patient_screens.dart' show showChangePasswordDialog;

Widget _guard(AppState s, Widget Function() build) {
  if (s.loading) return const LoadingWidget();
  if (s.error != null) return ErrorState(message: s.error!, onRetry: s.init);
  return build();
}

class DoctorHomeScreen extends StatelessWidget {
  const DoctorHomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final hour = DateTime.now().hour;
    final greet = hour < 12
        ? 'Good Morning'
        : (hour < 17 ? 'Good Afternoon' : 'Good Evening');
    final shortName = (s.user?.name ?? 'Doctor').split(' ').take(2).join(' ');
    final now = DateTime.now();
    final todays = s.appointments
        .where((a) =>
            isSameDay(a.date, now) && a.status == AppointmentStatus.upcoming)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('E-Clinic Book'), actions: [
        IconButton(
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications_outlined)),
        IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined)),
      ]),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/doctor/scan'),
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan QR')),
      body: _guard(
          s,
          () => ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  children: [
                    Text('$greet, $shortName',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 14),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.5,
                      children: [
                        StatTile(
                            icon: Icons.today,
                            label: "Today's Appointments",
                            value: '${todays.length}'),
                        StatTile(
                            icon: Icons.people,
                            label: 'Total Patients',
                            value: '${s.patients.length}',
                            color: Colors.indigo),
                        StatTile(
                            icon: Icons.pending_actions,
                            label: 'Pending Visits',
                            value:
                                '${s.appointments.where((a) => a.status == AppointmentStatus.upcoming).length}',
                            color: Colors.orange.shade800),
                        StatTile(
                            icon: Icons.task_alt,
                            label: 'Completed Visits',
                            value:
                                '${s.appointments.where((a) => a.status == AppointmentStatus.completed).length}',
                            color: Colors.green.shade700),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text("Today's Appointments".localized(context),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    if (todays.isEmpty)
                      const SectionCard(child: Text('No appointments today')),
                    for (final a in todays)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppointmentCard(
                              appt: a,
                              showPatient: true,
                              onTap: () => _showAppointmentSheet(context, a))),
                  ])),
    );
  }
}

void _showAppointmentSheet(BuildContext context, Appointment a) {
  final s = context.read<AppState>();
  var updating = false;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, setSheetState) {
        Future<void> updateStatus(AppointmentStatus status) async {
          if (updating) return;
          setSheetState(() => updating = true);
          try {
            await s.setAppointmentStatus(a.id, status);
            if (sheet.mounted) Navigator.of(sheet).pop();
            if (context.mounted) {
              showSnack(
                context,
                status == AppointmentStatus.completed
                    ? 'Marked as completed'
                    : 'Appointment cancelled',
              );
            }
          } catch (error) {
            if (context.mounted) {
              showSnack(
                context,
                _appointmentStatusErrorMessage(error),
                error: true,
              );
            }
          } finally {
            if (sheet.mounted) setSheetState(() => updating = false);
          }
        }

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              24 + MediaQuery.viewInsetsOf(sheet).bottom,
            ),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Appointment Details'.localized(sheet),
                      style: Theme.of(sheet)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  InfoRow('Patient', a.patientName),
                  InfoRow('Date', fmtDate(a.date)),
                  InfoRow('Time', a.time),
                  InfoRow('Clinic', a.clinic),
                  InfoRow('Hospital', a.hospital),
                  InfoRow('Status', statusLabel(a.status)),
                  const SizedBox(height: 14),
                  if (s.patientById(a.patientId) != null)
                    CustomButton(
                      label: 'View Patient',
                      icon: Icons.folder_shared_outlined,
                      onPressed: updating
                          ? null
                          : () {
                              Navigator.of(sheet).pop();
                              context.push('/doctor/patient/${a.patientId}');
                            },
                    )
                  else
                    const Text(
                      'Patient medical records are available only to their '
                      'primary doctor.',
                    ),
                  if (a.status == AppointmentStatus.upcoming) ...[
                    const SizedBox(height: 10),
                    CustomButton(
                      label: 'Mark as Completed',
                      icon: Icons.check_circle_outline,
                      outlined: !updating,
                      loading: updating,
                      onPressed: updating
                          ? null
                          : () => updateStatus(AppointmentStatus.completed),
                    ),
                    const SizedBox(height: 10),
                    CustomButton(
                      label: 'Cancel Appointment',
                      icon: Icons.cancel_outlined,
                      outlined: !updating,
                      loading: updating,
                      onPressed: updating
                          ? null
                          : () => updateStatus(AppointmentStatus.cancelled),
                    ),
                  ],
                ]),
          ),
        );
      },
    ),
  );
}

String _appointmentStatusErrorMessage(Object error) {
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'Firestore denied this status change. Confirm the latest Firestore '
        'rules are deployed and sign in with an authorized doctor account.';
  }
  return error.toString().replaceFirst('Exception: ', '');
}

class DoctorPatientsScreen extends StatefulWidget {
  const DoctorPatientsScreen({super.key});
  @override
  State<DoctorPatientsScreen> createState() => _DoctorPatientsScreenState();
}

class _DoctorPatientsScreenState extends State<DoctorPatientsScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final q = _q.trim().toLowerCase();
    final list = s.patients
        .where((p) =>
            q.isEmpty ||
            p.name.toLowerCase().contains(q) ||
            p.id.toLowerCase().contains(q) ||
            p.nic.toLowerCase().contains(q) ||
            p.phone.contains(q))
        .toList();
    return Scaffold(
      appBar: AppBar(
          title: Text('Search Patients'.localized(context)),
          actions: [
        IconButton(
            onPressed: () => context.push('/doctor/scan'),
            icon: const Icon(Icons.qr_code_scanner))
      ]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: InputDecoration(
                hintText: 'Patient ID, NIC, name or phone'.localized(context),
                prefixIcon: const Icon(Icons.search)),
          ),
        ),
        Expanded(
          child: _guard(
            s,
            () => list.isEmpty
                ? EmptyState(
                    icon: Icons.person_search,
                    message: q.isEmpty
                        ? 'No patients are assigned to or have booked with '
                            'your account yet.'
                        : 'No patients match your search.')
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final lv = s.lastVisit(list[i].id);
                      return PatientCard(
                          patient: list[i],
                          lastVisit: lv == null ? 'None' : fmtDate(lv.date),
                          onView: () =>
                              context.push('/doctor/patient/${list[i].id}'));
                    },
                  ),
          ),
        ),
      ]),
    );
  }
}

class DoctorAppointmentsScreen extends StatelessWidget {
  const DoctorAppointmentsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final now = DateTime.now();
    final todays = s.appointments
        .where((a) =>
            isSameDay(a.date, now) && a.status == AppointmentStatus.upcoming)
        .toList();
    final upcoming = s.appointments
        .where((a) =>
            a.status == AppointmentStatus.upcoming && !isSameDay(a.date, now))
        .toList();
    final done = s.appointments
        .where((a) => a.status == AppointmentStatus.completed)
        .toList();
    final cancelled = s.appointments
        .where((a) => a.status == AppointmentStatus.cancelled)
        .toList();
    Widget section(String title, List<Appointment> l) =>
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 10),
              child: Text(title.localized(context),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800))),
          if (l.isEmpty) const SectionCard(child: Text('Nothing here')),
          for (final a in l)
            Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppointmentCard(
                    appt: a,
                    showPatient: true,
                    onTap: () => _showAppointmentSheet(context, a))),
        ]);
    return Scaffold(
      appBar: AppBar(title: Text('Appointments'.localized(context))),
      body: _guard(
        s,
        () => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            section('Today', todays),
            section('Upcoming', upcoming),
            section('Completed', done),
            section('Cancelled', cancelled),
          ],
        ),
      ),
    );
  }
}

class DoctorProfileScreen extends StatelessWidget {
  const DoctorProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final u = s.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), actions: [
        IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined))
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Center(
          child: Column(children: [
            const CircleAvatar(
                radius: 48,
                backgroundColor: Color(0xFFD9EEF1),
                child: Icon(Icons.medical_information,
                    size: 48, color: AppTheme.primary)),
            const SizedBox(height: 10),
            Text(u?.name ?? '',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            Text(u?.id ?? '',
                style: const TextStyle(
                    color: AppTheme.primary, fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 16),
        SectionCard(
            child: Column(children: [
          InfoRow('Email', u?.email ?? ''),
          const InfoRow('Speciality', 'General Physician'),
          const InfoRow('Hospital', 'Negombo General Hospital')
        ])),
        const SizedBox(height: 16),
        CustomButton(
            label: 'Scan Patient QR',
            icon: Icons.qr_code_scanner,
            onPressed: () => context.push('/doctor/scan')),
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
      ]),
    );
  }
}

class DoctorPatientScreen extends StatelessWidget {
  final String patientId;
  const DoctorPatientScreen({super.key, required this.patientId});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = s.patientById(patientId);
    if (p == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const EmptyState(
              icon: Icons.person_off, message: 'Patient not found.'));
    }
    final canViewMedicalRecords = p.primaryDoctorUid == s.user?.id;
    final patientAppointments = s.appointmentsFor(p.id);
    final visits = s.visitsFor(p.id);
    final meds = s.medicinesFor(p.id);
    final reports = s.reportsFor(p.id);
    final last = s.lastVisit(p.id);
    final tabs = <Widget>[
      Tab(text: 'Overview'.localized(context)),
      Tab(text: 'Appointments'.localized(context)),
      if (canViewMedicalRecords) ...[
        Tab(text: 'Clinic History'.localized(context)),
        Tab(text: 'Prescriptions'.localized(context)),
        Tab(text: 'Lab Reports'.localized(context)),
      ],
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(p.name),
          actions: [
            if (canViewMedicalRecords)
              IconButton(
                tooltip: 'Add Lab Report',
                onPressed: () => _showAddLabReportDialog(context, p),
                icon: const Icon(Icons.upload_file_outlined),
              ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: tabs,
          ),
        ),
        floatingActionButton: canViewMedicalRecords
            ? FloatingActionButton.extended(
                onPressed: () =>
                    context.push('/doctor/add-visit?patientId=${p.id}'),
                icon: const Icon(Icons.add),
                label: const Text('Add Visit'),
              )
            : null,
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                SectionCard(
                  title: 'Patient Information',
                  icon: Icons.badge_outlined,
                  child: Column(children: [
                    InfoRow('Name', p.name),
                    InfoRow('Patient ID', p.id),
                    InfoRow('NIC', p.nic),
                    InfoRow('DOB', '${fmtDate(p.dob)} (${p.age} yrs)'),
                    InfoRow('Gender', p.gender),
                    InfoRow('Blood Group', p.bloodGroup),
                    InfoRow('Phone', p.phone),
                    InfoRow('Email', p.email),
                    InfoRow('Address', p.address),
                  ]),
                ),
                if (canViewMedicalRecords) ...[
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'Latest Vitals',
                    icon: Icons.monitor_heart_outlined,
                    child: last == null
                        ? const Text('No visits recorded')
                        : Column(children: [
                            InfoRow('Date', fmtDate(last.date)),
                            InfoRow('BP', last.bp),
                            InfoRow('Heart rate', '${last.heartRate} bpm'),
                            InfoRow('Weight', '${last.weight} kg'),
                            InfoRow('Diagnosis', last.diagnosis)
                          ]),
                  ),
                ],
              ]),
            patientAppointments.isEmpty
                ? const EmptyState(
                    icon: Icons.event_busy_outlined,
                    message: 'No appointments yet.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                    itemCount: patientAppointments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => AppointmentCard(
                      appt: patientAppointments[i],
                      showPatient: false,
                      onTap: () =>
                          _showAppointmentSheet(context, patientAppointments[i]),
                    ),
                  ),
            if (canViewMedicalRecords) ...[
              visits.isEmpty
                  ? const EmptyState(
                      icon: Icons.menu_book_outlined,
                      message: 'No clinic visits yet.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                      itemCount: visits.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => ClinicVisitCard(
                        visit: visits[i],
                        onTap: () => context.push('/visit/${visits[i].id}'),
                      ),
                    ),
              meds.isEmpty
                  ? const EmptyState(
                      icon: Icons.medication_outlined,
                      message: 'No prescriptions.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                      itemCount: meds.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) =>
                          PrescriptionCard(medicine: meds[i]),
                    ),
              reports.isEmpty
                  ? Column(children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: _AddLabReportButton(patient: p),
                      ),
                      const Expanded(
                        child: EmptyState(
                          icon: Icons.biotech_outlined,
                          message: 'No lab reports.',
                        ),
                      ),
                    ])
                  : Column(children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: _AddLabReportButton(patient: p),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                          itemCount: reports.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => ReportCard(
                            report: reports[i],
                            onTap: () =>
                                context.push('/report/${reports[i].id}'),
                          ),
                        ),
                      ),
                    ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddLabReportButton extends StatelessWidget {
  const _AddLabReportButton({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _showAddLabReportDialog(context, patient),
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Add Lab Report'),
        ),
      );
}

void _showAddLabReportDialog(BuildContext context, Patient patient) {
  showDialog<void>(
    context: context,
    builder: (_) => _AddLabReportDialog(patient: patient),
  );
}

class _AddLabReportDialog extends StatefulWidget {
  const _AddLabReportDialog({required this.patient});

  final Patient patient;

  @override
  State<_AddLabReportDialog> createState() => _AddLabReportDialogState();
}

class _AddLabReportDialogState extends State<_AddLabReportDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _typeController = TextEditingController();
  final _labController = TextEditingController();
  static const _laboratoryOptions = [
    'Negombo General Hospital Lab',
    'Colombo National Hospital Lab',
    'Other',
  ];
  String? _selectedLaboratory;
  DateTime _date = DateTime.now();
  Uint8List? _fileBytes;
  String? _fileName;
  String? _contentType;
  bool _uploading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _labController.dispose();
    super.dispose();
  }

  Future<void> _chooseFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (files.isEmpty) return;

      final file = files.first;
      final bytes = await file.readAsBytes();
      final extension = file.extension?.toLowerCase();
      if (extension == null) {
        _showError('The selected file has no valid extension.');
        return;
      }
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
      if (!mounted) return;
      setState(() {
        _fileBytes = bytes;
        _fileName = file.name;
        _contentType = contentType;
      });
    } catch (error) {
      debugPrint(
        '[LabReport] stage="File selection" '
        'error=${error.runtimeType}: $error',
      );
      debugPrintStack();
      if (mounted) _showError('Could not select or read the file: $error');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fileBytes == null || _fileName == null || _contentType == null) {
      _showError('Select a PDF, JPG, JPEG, or PNG file.');
      return;
    }

    setState(() => _uploading = true);
    try {
      final state = context.read<AppState>();
      final report = LabReport(
        id: state.newReportId(),
        patientId: widget.patient.id,
        doctorId: state.user?.id,
        primaryDoctorUid: widget.patient.primaryDoctorUid,
        name: _nameController.text.trim(),
        type: _typeController.text.trim(),
        lab: _selectedLaboratory == 'Other'
            ? _labController.text.trim()
            : _selectedLaboratory!,
        date: _date,
      );
      await state.uploadLabReport(
        report,
        _fileBytes!,
        _fileName!,
        _contentType!,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lab report uploaded successfully.')),
      );
    } catch (error) {
      final stage = error is LabReportOperationException
          ? error.stage
          : 'Report upload preparation';
      _showError('Could not upload lab report during $stage: $error');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add Lab Report'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Patient: ${widget.patient.name}'),
                  const SizedBox(height: 12),
                  _textField(_nameController, 'Report name'),
                  _textField(_typeController, 'Report type'),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Hospital or laboratory',
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
                        ? 'Select a hospital or laboratory'
                        : null,
                    onChanged: _uploading
                        ? null
                        : (value) => setState(() {
                              _selectedLaboratory = value;
                              if (value != 'Other') _labController.clear();
                            }),
                  ),
                  if (_selectedLaboratory == 'Other')
                    _textField(
                      _labController,
                      'Other hospital or laboratory name',
                    ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Report date'),
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
                            if (selected != null) {
                              setState(() => _date = selected);
                            }
                          },
                  ),
                  OutlinedButton.icon(
                    onPressed: _uploading ? null : _chooseFile,
                    icon: const Icon(Icons.attach_file),
                    label: Text(_fileName ?? 'Select PDF or image'),
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
                : const Text('Upload'),
          ),
        ],
      );

  Widget _textField(TextEditingController controller, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Required' : null,
        ),
      );
}

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});
  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool _scanning = false;

  Future<void> _scan() async {
    final s = context.read<AppState>();
    setState(() => _scanning = true);
    final id =
        await s.qr.scan(); // swap MockQrService for a camera-based one later
    if (!mounted) return;
    setState(() => _scanning = false);
    if (id == null || s.patientById(id) == null) {
      showSnack(context, 'Patient not found for this QR code', error: true);
      return;
    }
    context.push('/doctor/patient/$id');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0B2A31),
        appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            title:
                const Text('Scan QR', style: TextStyle(color: Colors.white))),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Text('Scan Patient QR Code',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('Align the QR code inside the frame',
                  style: TextStyle(color: Colors.white70)),
              Expanded(
                child: Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.tealAccent, width: 3),
                        borderRadius: BorderRadius.circular(24)),
                    child: Center(
                        child: _scanning
                            ? const CircularProgressIndicator(
                                color: Colors.tealAccent)
                            : const Icon(Icons.qr_code_2,
                                size: 120, color: Colors.white24)),
                  ),
                ),
              ),
              CustomButton(
                  label: _scanning ? 'Scanning...' : 'Simulate Scan',
                  icon: Icons.qr_code_scanner,
                  onPressed: _scanning ? null : _scan),
              const SizedBox(height: 8),
              const Text('Camera scanning will be connected later.',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
            ]),
          ),
        ),
      );
}
