import { createInterface } from 'node:readline/promises';
import { stdin, stdout } from 'node:process';
import { readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

const projectId = process.env.FIREBASE_PROJECT_ID ?? 'e-clinic-book-c5ee1';
const app = initializeApp({
  credential: applicationDefault(),
  projectId,
});
const firestore = getFirestore(app);
const scriptDirectory = dirname(fileURLToPath(import.meta.url));

async function ask(question) {
  const terminal = createInterface({ input: stdin, output: stdout });
  try {
    return (await terminal.question(question)).trim();
  } finally {
    terminal.close();
  }
}

async function readSupabaseConfig() {
  const envFile = await readFile(
    join(scriptDirectory, '..', '..', '.env.supabase'),
    'utf8',
  );
  const values = new Map();
  for (const line of envFile.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#') || !trimmed.includes('=')) {
      continue;
    }
    const separator = trimmed.indexOf('=');
    values.set(
      trimmed.slice(0, separator).trim(),
      trimmed.slice(separator + 1).trim(),
    );
  }

  const url = values.get('SUPABASE_URL');
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !serviceKey) {
    throw new Error(
      'Configure SUPABASE_URL in .env.supabase and set the server-only ' +
        'SUPABASE_SERVICE_ROLE_KEY environment variable.',
    );
  }
  return { url: url.replace(/\/+$/, ''), serviceKey };
}

async function updateStorageAssignment(patientUid, doctorUid) {
  const { url, serviceKey } = await readSupabaseConfig();
  const endpoint = `${url}/rest/v1/doctor_patient_assignments`;
  const response = doctorUid
    ? await fetch(`${endpoint}?on_conflict=patient_uid`, {
        method: 'POST',
        headers: {
          apikey: serviceKey,
          Authorization: `Bearer ${serviceKey}`,
          'Content-Type': 'application/json',
          Prefer: 'resolution=merge-duplicates,return=minimal',
        },
        body: JSON.stringify({
          patient_uid: patientUid,
          doctor_uid: doctorUid,
          updated_at: new Date().toISOString(),
        }),
      })
    : await fetch(`${endpoint}?patient_uid=eq.${encodeURIComponent(patientUid)}`, {
        method: 'DELETE',
        headers: {
          apikey: serviceKey,
          Authorization: `Bearer ${serviceKey}`,
          Prefer: 'return=minimal',
        },
      });

  if (!response.ok) {
    const responseText = await response.text();
    throw new Error(
      `Supabase assignment mirror failed (${response.status}): ${responseText}`,
    );
  }
}

async function listAndChoosePatient(doctors, patients) {
  const byDoctorUid = new Map(doctors.map((doctor) => [doctor.id, doctor.name]));
  stdout.write('\nPatient profiles and current assignment:\n');
  if (patients.length === 0) stdout.write('  None\n');
  for (const patient of patients) {
    const data = patient.data();
    const primaryDoctorUid = data.primaryDoctorUid;
    const assignment =
      typeof primaryDoctorUid === 'string'
        ? byDoctorUid.has(primaryDoctorUid)
          ? `${byDoctorUid.get(primaryDoctorUid)} (${primaryDoctorUid})`
          : `invalid doctor UID (${primaryDoctorUid})`
        : 'UNASSIGNED';
    stdout.write(
      `  ${patient.id}  ${data.name ?? '(no name)'}  [${assignment}]\n`,
    );
  }

  stdout.write('\nDoctor UIDs (choose explicitly):\n');
  for (const doctor of doctors) {
    stdout.write(`  ${doctor.id}  ${doctor.name}\n`);
  }
  return ask('\nPatient UID to assign/reassign (blank to skip): ');
}

async function migratePatientRecords(patientUid, doctorUid) {
  const update = doctorUid
    ? { primaryDoctorUid: doctorUid }
    : { primaryDoctorUid: FieldValue.delete() };
  const patientReference = firestore.collection('users').doc(patientUid);
  const patient = await patientReference.get();
  if (!patient.exists || patient.data()?.role !== 'patient') {
    throw new Error('The selected UID is not a registered patient profile.');
  }

  const collections = ['clinicVisits', 'labReports'];
  const recordSnapshots = await Promise.all(
    collections.map((collection) =>
      firestore.collection(collection).where('patientId', '==', patientUid).get(),
    ),
  );
  const references = recordSnapshots.flatMap((snapshot) =>
    snapshot.docs.map((document) => document.ref),
  );
  const writes = [{ reference: patientReference, data: update }, ...references.map(
    (reference) => ({ reference, data: update }),
  )];

  for (let offset = 0; offset < writes.length; offset += 450) {
    const batch = firestore.batch();
    for (const write of writes.slice(offset, offset + 450)) {
      batch.update(write.reference, write.data);
    }
    await batch.commit();
  }
  return references.length;
}

async function assignPatient(patientUid, doctors) {
  const patientReference = firestore.collection('users').doc(patientUid);
  const patient = await patientReference.get();
  if (!patient.exists || patient.data()?.role !== 'patient') {
    throw new Error('The selected UID is not a registered patient profile.');
  }

  const doctorUid = await ask(
    'Primary doctor UID from the list above (or UNASSIGN): ',
  );
  const normalizedDoctorUid =
    doctorUid.toUpperCase() === 'UNASSIGN' ? null : doctorUid;
  const doctor = doctors.find((candidate) => candidate.id === normalizedDoctorUid);
  if (normalizedDoctorUid && !doctor) {
    throw new Error('Choose a doctor UID from the displayed doctor list.');
  }

  const data = patient.data();
  if (normalizedDoctorUid) {
    const requiredFields = [
      'name',
      'email',
      'nic',
      'dob',
      'gender',
      'phone',
      'address',
    ];
    const missingFields = requiredFields.filter((field) => !(field in data));
    if (missingFields.length > 0) {
      throw new Error(
        `Complete the patient profile before assigning a doctor. ` +
          `Missing: ${missingFields.join(', ')}.`,
      );
    }
  }
  const oldDoctorUid = data.primaryDoctorUid ?? '(unassigned)';
  const newDoctorUid = normalizedDoctorUid ?? '(unassigned)';
  stdout.write(
    `Patient: ${data.name ?? '(no name)'} (${patientUid})\n` +
      `Current primary doctor: ${oldDoctorUid}\n` +
      `New primary doctor: ${newDoctorUid}\n` +
      'Existing visit and report metadata will be retained and scoped to ' +
      'the new assignment.\n',
  );
  if (await ask(`Type UPDATE ${patientUid} to confirm: `) !== `UPDATE ${patientUid}`) {
    throw new Error('Patient assignment was not confirmed.');
  }

  await updateStorageAssignment(patientUid, null);
  const migratedRecords = await migratePatientRecords(
    patientUid,
    normalizedDoctorUid,
  );
  if (normalizedDoctorUid) {
    await updateStorageAssignment(patientUid, normalizedDoctorUid);
  }

  stdout.write(
    `Assignment updated. ${migratedRecords} existing clinical record(s) ` +
      `were retained and scoped to ${newDoctorUid}.\n`,
  );
}

async function listUnresolvedAppointments(doctorsByUid, patientsByUid) {
  const snapshot = await firestore.collection('appointments').get();
  const unresolved = snapshot.docs.filter((appointment) => {
    const data = appointment.data();
    const doctorUid = data.doctorId;
    const patient = patientsByUid.get(data.patientId);
    return (
      typeof doctorUid !== 'string' ||
      !doctorsByUid.has(doctorUid) ||
      !patient ||
      patient.primaryDoctorUid !== doctorUid
    );
  });

  stdout.write('\nAppointments needing explicit UID review:\n');
  if (unresolved.length === 0) stdout.write('  None\n');
  for (const appointment of unresolved) {
    const data = appointment.data();
    stdout.write(
      `  ${appointment.id}  patient=${data.patientId ?? '(missing)'}  ` +
        `stored doctor=${data.doctor ?? '(missing)'}\n`,
    );
  }
  return unresolved;
}

async function main() {
  const [doctorSnapshot, patientSnapshot] = await Promise.all([
    firestore.collection('users').where('role', '==', 'doctor').get(),
    firestore.collection('users').where('role', '==', 'patient').get(),
  ]);
  const doctors = doctorSnapshot.docs.map((document) => ({
    id: document.id,
    name: document.data().name ?? '(no name)',
  }));
  const patients = patientSnapshot.docs;
  const patientUid = await listAndChoosePatient(doctors, patients);
  if (patientUid) await assignPatient(patientUid, doctors);

  const doctorsByUid = new Map(doctors.map((doctor) => [doctor.id, doctor]));
  const patientsByUid = new Map(
    (await firestore.collection('users').where('role', '==', 'patient').get()).docs
      .map((patient) => [patient.id, patient.data()]),
  );
  const unresolved = await listUnresolvedAppointments(
    doctorsByUid,
    patientsByUid,
  );
  if (unresolved.length === 0) return;

  const appointmentId = await ask(
    '\nAppointment ID to resolve (blank to leave unresolved): ',
  );
  if (!appointmentId) return;
  const appointmentReference =
    firestore.collection('appointments').doc(appointmentId);
  const appointment = await appointmentReference.get();
  const appointmentData = appointment.data();
  if (!appointment.exists || !appointmentData) {
    throw new Error('The selected appointment does not exist.');
  }
  const patient = patientsByUid.get(appointmentData.patientId);
  const doctorUid = await ask('Verified primary doctor UID: ');
  const doctor = doctorsByUid.get(doctorUid);
  if (
    !patient ||
    !doctor ||
    patient.primaryDoctorUid !== doctorUid ||
    appointmentData.doctor !== doctor.name
  ) {
    throw new Error(
      'The UID, current patient assignment, and stored doctor name must all ' +
        'match. No appointment fields were changed.',
    );
  }
  if (
    await ask(`Type LINK ${appointmentId} ${doctorUid} to confirm: `) !==
    `LINK ${appointmentId} ${doctorUid}`
  ) {
    throw new Error('Appointment resolution was not confirmed.');
  }
  await appointmentReference.update({ doctorId: doctorUid });
  stdout.write(
    `Appointment ${appointmentId} linked to its verified primary doctor. ` +
      'All other appointment fields were preserved.\n',
  );
}

main().catch((error) => {
  console.error(`Assignment management failed: ${error.message}`);
  process.exitCode = 1;
});
