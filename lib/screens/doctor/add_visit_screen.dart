import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/format.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/cards.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/date_field.dart';

class AddVisitScreen extends StatefulWidget {
  final String? patientId;
  const AddVisitScreen({super.key, this.patientId});
  @override
  State<AddVisitScreen> createState() => _AddVisitScreenState();
}

class _AddVisitScreenState extends State<AddVisitScreen> {
  final _form = GlobalKey<FormState>();
  final _c = {
    for (final k in [
      'hospital',
      'symptoms',
      'bp',
      'hr',
      'temp',
      'weight',
      'height',
      'diagnosis',
      'treatment',
      'notes'
    ])
      k: TextEditingController()
  };
  final List<Medicine> _meds = [];
  String? _patientId, _clinic;
  DateTime _date = DateTime.now();
  DateTime? _next;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _patientId = widget.patientId;
    _c['hospital']!.text = 'Negombo General Hospital';
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final s = context.read<AppState>();
    setState(() => _saving = true);
    String t(String k) => _c[k]!.text.trim();
    try {
      await s.addVisit(ClinicVisit(
        id: 'V-${DateTime.now().millisecondsSinceEpoch}',
        patientId: _patientId!,
        doctorId: s.user!.id,
        primaryDoctorUid: s.patientById(_patientId!)?.primaryDoctorUid,
        date: _date,
        hospital: t('hospital'),
        clinic: _clinic!,
        doctor: s.user?.name ?? 'Doctor',
        symptoms: t('symptoms'),
        bp: t('bp'),
        heartRate: t('hr'),
        temperature: t('temp'),
        weight: t('weight'),
        height: t('height'),
        diagnosis: t('diagnosis'),
        treatment: t('treatment'),
        medicines: List.of(_meds),
        notes: t('notes'),
        nextVisit: _next,
      ));
      if (!mounted) return;
      showSnack(context, 'Clinic visit saved');
      context.pop();
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
  Widget build(BuildContext context) {
    final patients = context.watch<AppState>().patients;
    return Scaffold(
      appBar: AppBar(title: const Text('Add Clinic Visit')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            DropdownButtonFormField<String>(
              initialValue: _patientId,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Patient', prefixIcon: Icon(Icons.person_outline)),
              items: [
                for (final p in patients)
                  DropdownMenuItem(
                      value: p.id,
                      child: Text('${p.name} (${p.id})',
                          overflow: TextOverflow.ellipsis))
              ],
              validator: (v) => v == null ? 'Select a patient' : null,
              onChanged: (v) => _patientId = v,
            ),
            const SizedBox(height: 14),
            DateField(
                label: 'Visit Date',
                value: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
                onChanged: (d) => _date = d),
            CustomTextField(
                controller: _c['hospital'],
                label: 'Hospital',
                icon: Icons.local_hospital_outlined,
                validator: (v) => requiredField(v, 'Hospital')),
            DropdownButtonFormField<String>(
              initialValue: _clinic,
              decoration: const InputDecoration(
                  labelText: 'Clinic',
                  prefixIcon: Icon(Icons.meeting_room_outlined)),
              items: [
                for (final c in AppConstants.clinics)
                  DropdownMenuItem(value: c, child: Text(c))
              ],
              validator: (v) => v == null ? 'Select a clinic' : null,
              onChanged: (v) => _clinic = v,
            ),
            const SizedBox(height: 14),
            CustomTextField(
                controller: _c['symptoms'],
                label: 'Symptoms',
                icon: Icons.sick_outlined,
                maxLines: 2,
                validator: (v) => requiredField(v, 'Symptoms')),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: CustomTextField(
                      controller: _c['bp'],
                      label: 'BP (120/80)',
                      validator: (v) => RegExp(r'^\d{2,3}/\d{2,3}$')
                              .hasMatch((v ?? '').trim())
                          ? null
                          : 'e.g. 120/80')),
              const SizedBox(width: 10),
              Expanded(
                  child: CustomTextField(
                      controller: _c['hr'],
                      label: 'Heart rate (bpm)',
                      keyboardType: TextInputType.number,
                      validator: (v) => validateNumber(v, 'Heart rate'))),
            ]),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: CustomTextField(
                      controller: _c['temp'],
                      label: 'Temp (°C)',
                      keyboardType: TextInputType.number,
                      validator: (v) => validateNumber(v, 'Temperature'))),
              const SizedBox(width: 10),
              Expanded(
                  child: CustomTextField(
                      controller: _c['weight'],
                      label: 'Weight (kg)',
                      keyboardType: TextInputType.number,
                      validator: (v) => validateNumber(v, 'Weight'))),
            ]),
            CustomTextField(
                controller: _c['height'],
                label: 'Height (cm)',
                icon: Icons.height,
                keyboardType: TextInputType.number,
                validator: (v) => validateNumber(v, 'Height')),
            CustomTextField(
                controller: _c['diagnosis'],
                label: 'Diagnosis',
                icon: Icons.assignment_outlined,
                maxLines: 2,
                validator: (v) => requiredField(v, 'Diagnosis')),
            CustomTextField(
                controller: _c['treatment'],
                label: 'Treatment',
                icon: Icons.healing_outlined,
                maxLines: 2,
                validator: (v) => requiredField(v, 'Treatment')),
            Row(children: [
              Text('Prescription',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  final m = await showAddMedicineDialog(context);
                  if (m != null) setState(() => _meds.add(m));
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Medicine'),
              ),
            ]),
            if (_meds.isEmpty)
              Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text('No medicines added',
                      style: TextStyle(color: Colors.grey.shade600))),
            for (var i = 0; i < _meds.length; i++)
              Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PrescriptionCard(
                      medicine: _meds[i],
                      onDelete: () => setState(() => _meds.removeAt(i)))),
            CustomTextField(
                controller: _c['notes'],
                label: 'Doctor Notes',
                icon: Icons.note_alt_outlined,
                maxLines: 3),
            DateField(
                label: 'Next Visit Date (optional)',
                value: _next,
                isRequired: false,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 730)),
                onChanged: (d) => _next = d),
            const SizedBox(height: 6),
            CustomButton(
                label: 'Save Visit',
                icon: Icons.save_outlined,
                loading: _saving,
                onPressed: _save),
            const SizedBox(height: 10),
            CustomButton(
                label: 'Cancel',
                outlined: true,
                onPressed: () => context.pop()),
          ]),
        ),
      ),
    );
  }
}

/// Add Prescription form (one medicine at a time; call repeatedly for multiple).
Future<Medicine?> showAddMedicineDialog(BuildContext context) {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      dose = TextEditingController(),
      freq = TextEditingController(),
      dur = TextEditingController(),
      instr = TextEditingController();
  return showDialog<Medicine>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('Add Medicine'),
      content: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 8),
            CustomTextField(
                controller: name,
                label: 'Medicine Name',
                validator: (v) => requiredField(v, 'Medicine name')),
            CustomTextField(
                controller: dose,
                label: 'Dosage (e.g. 500 mg)',
                validator: (v) => requiredField(v, 'Dosage')),
            CustomTextField(
                controller: freq,
                label: 'Frequency (e.g. 3 times daily)',
                validator: (v) => requiredField(v, 'Frequency')),
            CustomTextField(
                controller: dur,
                label: 'Duration (e.g. 5 days)',
                validator: (v) => requiredField(v, 'Duration')),
            CustomTextField(
                controller: instr, label: 'Instructions', maxLines: 2),
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
            Navigator.of(d).pop(Medicine(
                name: name.text.trim(),
                dosage: dose.text.trim(),
                frequency: freq.text.trim(),
                duration: dur.text.trim(),
                instructions: instr.text.trim()));
          },
          child: const Text('Add'),
        ),
      ],
    ),
  );
}
