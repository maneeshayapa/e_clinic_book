import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/format.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import 'common_widgets.dart';

class PatientCard extends StatelessWidget {
  final Patient patient;
  final String lastVisit;
  final VoidCallback onView;
  const PatientCard(
      {super.key,
      required this.patient,
      required this.lastVisit,
      required this.onView});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            Row(children: [
              CircleAvatar(
                  radius: 26,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                  child: const Icon(Icons.person, color: AppTheme.primary)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(patient.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 17)),
                      Text('${patient.id}  •  Age ${patient.age}',
                          style: TextStyle(color: Colors.grey.shade600)),
                      Text('Last visit: $lastVisit',
                          style: TextStyle(color: Colors.grey.shade600)),
                    ]),
              ),
            ]),
            const SizedBox(height: 10),
            CustomButton(
                label: 'View Patient',
                icon: Icons.folder_shared_outlined,
                outlined: true,
                onPressed: onView),
          ]),
        ),
      );
}

Color statusColor(AppointmentStatus s) => switch (s) {
      AppointmentStatus.upcoming => AppTheme.primary,
      AppointmentStatus.completed => Colors.green.shade700,
      AppointmentStatus.cancelled => Colors.red.shade700,
    };

Future<void> downloadLabReportFile(
  BuildContext context,
  LabReport report,
) async {
  final fileName = report.fileName;
  if (report.storagePath == null || fileName == null) return;

  try {
    final bytes =
        await context.read<AppState>().downloadLabReportFile(report.storagePath!);
    if (!context.mounted) return;
    final extension = fileName.split('.').last.toLowerCase();
    final mimeType = switch (extension) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => 'application/octet-stream',
    };
    await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
    );
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not download lab report: $error')),
      );
    }
  }
}

String statusLabel(AppointmentStatus s) =>
    s.name[0].toUpperCase() + s.name.substring(1);

class AppointmentCard extends StatelessWidget {
  final Appointment appt;
  final bool showPatient;
  final VoidCallback? onTap;
  const AppointmentCard(
      {super.key, required this.appt, this.showPatient = false, this.onTap});
  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 56,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14)),
                child: Column(children: [
                  Text('${appt.date.day}',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary)),
                  Text(fmtDate(appt.date).substring(3, 6),
                      style: const TextStyle(color: AppTheme.primary)),
                ]),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(showPatient ? appt.patientName : appt.clinic,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                      Text(
                          '${appt.time}  •  ${showPatient ? appt.clinic : appt.doctor}'),
                      Text(appt.hospital,
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 13)),
                    ]),
              ),
              StatusChip(statusLabel(appt.status), statusColor(appt.status)),
            ]),
          ),
        ),
      );
}

class ClinicVisitCard extends StatelessWidget {
  final ClinicVisit visit;
  final VoidCallback onTap;
  const ClinicVisitCard({super.key, required this.visit, required this.onTap});
  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.event_note, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(fmtDate(visit.date),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
                const Spacer(),
                const Icon(Icons.chevron_right),
              ]),
              Text(visit.clinic,
                  style: const TextStyle(
                      color: AppTheme.primary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Doctor: ${visit.doctor}'),
              Text(
                  'BP ${visit.bp}  •  ${visit.weight} kg  •  ${visit.temperature}°C',
                  style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 6),
              Text('Diagnosis: ${visit.diagnosis}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              if (visit.medicines.isNotEmpty)
                Text('Rx: ${visit.medicines.map((m) => m.name).join(', ')}'),
              if (visit.nextVisit != null)
                Text('Next visit: ${fmtDate(visit.nextVisit!)}',
                    style: TextStyle(color: Colors.grey.shade600)),
            ]),
          ),
        ),
      );
}

class PrescriptionCard extends StatelessWidget {
  final Medicine medicine;
  final VoidCallback? onDelete;
  const PrescriptionCard({super.key, required this.medicine, this.onDelete});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.medication_outlined,
                  color: AppTheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(medicine.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 17)),
                    Text(medicine.dosage),
                    Text('${medicine.frequency}  •  ${medicine.duration}'),
                    Text(medicine.instructions,
                        style: TextStyle(color: Colors.grey.shade600)),
                  ]),
            ),
            if (onDelete != null)
              IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: Colors.red)),
          ]),
        ),
      );
}

class ReportCard extends StatelessWidget {
  final LabReport report;
  final VoidCallback onTap;
  const ReportCard({super.key, required this.report, required this.onTap});
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          onTap: onTap,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.biotech_outlined, color: Colors.blue.shade700),
          ),
          title: Text(report.name,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle:
              Text('${report.type}\n${report.lab}  •  ${fmtDate(report.date)}'),
          isThreeLine: true,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            StatusChip(report.status, Colors.green.shade700),
            if (report.storagePath != null && report.fileName != null)
              IconButton(
                tooltip: 'Download report file',
                onPressed: () => downloadLabReportFile(context, report),
                icon: const Icon(Icons.download_outlined),
              ),
          ]),
        ),
      );
}
