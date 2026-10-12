import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../providers/app_state.dart';
import '../../widgets/cards.dart';
import '../../widgets/common_widgets.dart';

class VisitDetailScreen extends StatelessWidget {
  final String visitId;
  const VisitDetailScreen({super.key, required this.visitId});
  @override
  Widget build(BuildContext context) {
    final v = context.watch<AppState>().visitById(visitId);
    if (v == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const EmptyState(message: 'Visit not found.'));
    }
    return Scaffold(
      appBar: AppBar(title: Text('Clinic Visit'.localized(context))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SectionCard(
            title: 'Visit',
            icon: Icons.event_note,
            child: Column(children: [
              InfoRow('Date', fmtDate(v.date)),
              InfoRow('Hospital', v.hospital),
              InfoRow('Clinic', v.clinic),
              InfoRow('Doctor', v.doctor)
            ])),
        const SizedBox(height: 12),
        SectionCard(
            title: 'Symptoms',
            icon: Icons.sick_outlined,
            child: Text(v.symptoms)),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Vital Signs',
          icon: Icons.monitor_heart_outlined,
          child: Column(children: [
            InfoRow('Blood pressure', v.bp),
            InfoRow('Heart rate', '${v.heartRate} bpm'),
            InfoRow('Temperature', '${v.temperature} °C'),
            InfoRow('Weight', '${v.weight} kg'),
            InfoRow('Height', '${v.height} cm')
          ]),
        ),
        const SizedBox(height: 12),
        SectionCard(
            title: 'Diagnosis',
            icon: Icons.assignment_outlined,
            child: Text(v.diagnosis)),
        const SizedBox(height: 12),
        SectionCard(
            title: 'Treatment',
            icon: Icons.healing_outlined,
            child: Text(v.treatment)),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Prescription',
          icon: Icons.medication_outlined,
          child: v.medicines.isEmpty
              ? const Text('No medicines prescribed')
              : Column(children: [
                  for (final m in v.medicines)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: PrescriptionCard(medicine: m))
                ]),
        ),
        const SizedBox(height: 12),
        SectionCard(
            title: 'Doctor Notes',
            icon: Icons.note_alt_outlined,
            child: Text(v.notes.isEmpty ? 'No notes' : v.notes)),
        const SizedBox(height: 12),
        SectionCard(
            title: 'Next Appointment',
            icon: Icons.event_repeat,
            child: Text(
                v.nextVisit == null ? 'Not scheduled' : fmtDate(v.nextVisit!),
                style: const TextStyle(fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

class ReportDetailScreen extends StatelessWidget {
  final String reportId;
  const ReportDetailScreen({super.key, required this.reportId});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final r = s.reportById(reportId);
    if (r == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const EmptyState(message: 'Report not found.'));
    }
    final patient = s.patientById(r.patientId);
    final fileName = r.fileName ?? 'No file name';
    final storageNote = r.storagePath ?? 'Not uploaded yet';
    return Scaffold(
      appBar: AppBar(title: Text('Report Details'.localized(context))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SectionCard(
            title: r.name,
            icon: Icons.biotech_outlined,
            child: Column(children: [
              InfoRow('Report ID', r.id),
              InfoRow('Type', r.type),
              InfoRow('Lab', r.lab),
              InfoRow('Date', fmtDate(r.date)),
              if (r.notes != null && r.notes!.isNotEmpty)
                InfoRow('Notes', r.notes!),
              InfoRow('Status', r.status),
              InfoRow('Patient', patient?.name ?? r.patientId),
              InfoRow('Patient ID', r.patientId),
              InfoRow('Doctor ID', r.doctorId ?? 'Not assigned'),
              InfoRow(
                  'Primary Doctor UID', r.primaryDoctorUid ?? 'Not assigned'),
            ])),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Report file',
          icon: Icons.insert_drive_file_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Uploaded document',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(fileName,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                storageNote,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 160,
          decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade300)),
          child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.picture_as_pdf_outlined,
                size: 48, color: Colors.grey.shade500),
            const SizedBox(height: 6),
            Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Report preview',
                style: TextStyle(color: Colors.grey.shade600))
          ])),
        ),
        const SizedBox(height: 16),
        if (r.storagePath != null && r.fileName != null)
          CustomButton(
            label: 'View / Download Report',
            icon: Icons.download_outlined,
            onPressed: () => downloadLabReportFile(context, r),
          ),
      ]),
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text('Notifications'.localized(context))),
      body: !s.notificationsEnabled
          ? EmptyState(
              icon: Icons.notifications_off_outlined,
              message: 'Notifications are turned off in Settings.'
                  .localized(context),
            )
          : s.notifications.isEmpty
              ? EmptyState(
                  icon: Icons.notifications_off_outlined,
                  message: 'No notifications.'.localized(context))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: s.notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final n = s.notifications[i];
                    return Card(
                      child: ListTile(
                        onTap: () => s.markNotificationRead(n),
                        leading: CircleAvatar(
                            backgroundColor: AppTheme.primary
                                .withValues(alpha: n.read ? 0.06 : 0.15),
                            child: Icon(Icons.notifications,
                                color:
                                    n.read ? Colors.grey : AppTheme.primary)),
                        title: Text(n.title,
                            style: TextStyle(
                                fontWeight: n.read
                                    ? FontWeight.w500
                                    : FontWeight.w800)),
                        subtitle: Text('${n.body}\n${fmtDate(n.date)}'),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _saveSetting(Future<void> Function() save) async {
    try {
      await save();
    } catch (error) {
      if (mounted) {
        showSnack(
          context,
          error.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    }
  }

  Future<void> _logout() async {
    try {
      await context.read<AppState>().logout();
      if (mounted) context.go('/login');
    } catch (error) {
      if (mounted) {
        showSnack(
          context,
          error.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text('Settings'.localized(context))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: Column(children: [
            SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined),
              title: Text('Notifications'.localized(context)),
              subtitle: Text('In-app notifications'.localized(context)),
              value: state.notificationsEnabled,
              onChanged: (value) => _saveSetting(
                () => state.setNotificationsEnabled(value),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: Text('Language'.localized(context)),
              trailing: DropdownButton<String>(
                value: state.localeCode,
                underline: const SizedBox(),
                items: [
                  DropdownMenuItem(
                    value: 'en',
                    child: Text('English'.localized(context)),
                  ),
                  const DropdownMenuItem(
                    value: 'si',
                    child: Text('සිංහල'),
                  ),
                  const DropdownMenuItem(
                    value: 'ta',
                    child: Text('தமிழ்'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _saveSetting(() => state.setLocaleCode(value));
                  }
                },
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: Text('Dark Mode'.localized(context)),
              value: state.darkModeEnabled,
              onChanged: (value) => _saveSetting(
                () => state.setDarkModeEnabled(value),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text('Privacy'.localized(context)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/privacy'),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text('Terms & Conditions'.localized(context)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/terms'),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text('About E-Clinic Book'.localized(context)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/about'),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        CustomButton(
          label: 'Logout'.localized(context),
          icon: Icons.logout,
          outlined: true,
          onPressed: _logout,
        ),
      ]),
    );
  }
}

enum SettingsInfo { privacy, terms, about }

class SettingsInfoScreen extends StatelessWidget {
  const SettingsInfoScreen({super.key, required this.info});

  final SettingsInfo info;

  @override
  Widget build(BuildContext context) {
    final title = switch (info) {
      SettingsInfo.privacy => 'Privacy'.localized(context),
      SettingsInfo.terms => 'Terms & Conditions'.localized(context),
      SettingsInfo.about => 'About E-Clinic Book'.localized(context),
    };
    final content = switch (info) {
      SettingsInfo.privacy => [
          (
            'Your health information',
            'Your patient profile, appointments, clinic visits and reports are '
                'stored to provide the app services. Keep your sign-in details '
                'private and use Logout on shared devices.',
          ),
          (
            'Who can view your records',
            'Doctors can view your profile details when you book with them. '
                'Clinic visit history and reports are available only to your '
                'assigned primary doctor.',
          ),
          (
            'Uploaded report files',
            'Report details are stored in the clinic system and uploaded files '
                'are kept in private cloud storage. Do not upload documents '
                'that are unrelated to your care.',
          ),
          (
            'Your choices',
            'Contact your clinic to ask about correcting account details or '
                'your records. The Notifications setting controls in-app '
                'notification visibility on this device.',
          ),
        ],
      SettingsInfo.terms => [
          (
            'Purpose of the app',
            'E-Clinic Book helps patients and clinics organize appointments, '
                'clinic visit details and laboratory reports. It is not an '
                'emergency service and does not replace professional medical '
                'advice, diagnosis or treatment.',
          ),
          (
            'Your account',
            'Provide accurate information, protect your password and log out '
                'when using a shared device. Tell your clinic if you suspect '
                'someone else has used your account.',
          ),
          (
            'Appointments and records',
            'Check appointment details with the clinic. A booking request '
                'does not guarantee availability until confirmed by the '
                'clinic. Keep copies of important medical documents.',
          ),
          (
            'Safe use',
            'Do not use the app to report an emergency. Contact local '
                'emergency services or seek immediate medical care.',
          ),
        ],
      SettingsInfo.about => [
          (
            'E-Clinic Book',
            'Your Digital Clinic Book.\nVersion 1.0.0',
          ),
          (
            'What you can do',
            'Manage appointments, review clinic visit information and access '
                'laboratory reports shared with your account.',
          ),
        ],
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final section in content) ...[
            SectionCard(
              title: section.$1,
              child: Text(section.$2.localized(context)),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
