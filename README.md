# E-Clinic Book

Flutter clinic-book app. Patient accounts register in the app; doctor
accounts are provisioned using the trusted Admin SDK tool in
[`tools/doctor-admin`](./tools/doctor-admin/README.md). The existing
email/password login reads the Firestore role and routes each account to the
matching dashboard.

```powershell
flutter pub get
```

See [`tools/doctor-admin/README.md`](./tools/doctor-admin/README.md) to
provision a doctor account in Firebase Authentication and Firestore.

## Primary doctor assignments

Patient profiles may have a trusted `primaryDoctorUid` field containing the
doctor's Firebase Auth UID. There is no in-app admin role: public registration
cannot assign a primary doctor. Doctors see patients assigned to them and
patients who have booked an appointment with them. A booking shares the patient's
profile details with that doctor, but not the patient's permanent medical
record, which remains restricted to the primary assigned doctor.

Use the trusted Admin SDK assignment workflow documented in
[`tools/doctor-admin/README.md`](./tools/doctor-admin/README.md) to review
profiles and set/reassign a doctor. It also migrates existing visit and report
metadata for that patient without deleting records. Appointments
whose stored doctor name cannot be verified against the patient's current
primary doctor remain unavailable to doctor views until an administrator
explicitly resolves them; the workflow never guesses based on a name.

Existing patient profiles are not assigned automatically. Until assigned,
patients retain access to their own account and records and can book with an
available doctor. A doctor can see their profile and appointment after the
patient books with them; only the assigned primary doctor can open the
patient's medical chart.

When a patient next signs in, the app backfills profile access for existing
appointments whose `doctorId` matches a valid doctor profile. This link is
verified by UID and role, not by the appointment's display name. Appointments
without a valid doctor UID still require explicit administrator review.

### Security deployment and migration order

1. Run the assignment-scoped Supabase SQL setup below. This removes the
   documented doctor-wide Storage policies.
2. Deploy the reviewed `firestore.rules` before assigning patients. The new
   rules fail closed for doctor queries until records have an explicit UID
   assignment; the Admin SDK migration workflow can still update them.
3. Use the trusted Admin SDK workflow to assign each existing patient to the
   doctor chosen by the clinic. It backfills visit/report authorization fields
   and synchronizes private file access. Do not select a doctor based only on
   existing display names.
4. Explicitly resolve only legacy appointments whose stored doctor name, patient
   assignment, and selected doctor UID all match. The script leaves other
   appointments unresolved and visible to the patient.

No live patient assignments are made by this code change.

## Private Supabase storage for lab reports

Lab report metadata stays in Firestore. PDF/JPG/PNG files are kept in the
private Supabase Storage bucket `lab-reports`. The Flutter app authenticates
Supabase requests with the current Firebase ID token; it uses only Supabase's
public anon/publishable key. Never put a Supabase `service_role` or secret key
in the Flutter application.

### Firestore report metadata permissions

Report metadata is written to `labReports/{reportId}`. The doctor account must
have a Firestore profile at `users/{doctorUid}` with `role: "doctor"`, and the
patient ID saved in a report must be the patient's Firebase UID (the document
ID of `users/{patientUid}` with `role: "patient"`). The Firestore rules in
`firestore.rules` restrict report reads by role/ownership and allow report
creation only for the assigned doctor; patient access remains limited to the
patient's own reports.

If Firestore reports `permission-denied`, check the operation stage shown by
the app or its debug log. Confirm the patient has `primaryDoctorUid` set to
the signed-in doctor's Firebase UID and that assignment migration has run.
Then compare the deployed rules in the Firebase Console with the repository's
`firestore.rules`. Deploy the reviewed rules from the project root:

```powershell
firebase deploy --only firestore:rules --project e-clinic-book-c5ee1
```

Do not replace these rules with public or unrestricted access rules.

### Appointment status permissions

The doctor appointment controls update only the `status` field on the existing
`appointments/{appointmentId}` document. The checked-in Firestore rules allow
only the doctor identified by its `doctorId` UID to change an `upcoming`
appointment to `completed` or `cancelled`; patients may only cancel their own
upcoming appointments. Patients may book with any listed doctor; each new
booking uses that doctor's UID in `doctorId`, so it appears in that doctor's
appointment list. A booking does not by itself authorize access to the
patient's clinical visits or reports. Legacy records without a
verifiable doctor UID remain visible to the patient and require explicit
administrator review before appearing in a doctor's appointment list. Deploy
the reviewed rules before migrating assignments, as described above:

```powershell
firebase deploy --only firestore:rules --project e-clinic-book-c5ee1
```

Do not make appointment updates public or allow changes to fields other than
`status`.

### Supabase project and bucket

1. Create a Supabase project on the Free plan.
2. In **Storage**, create a bucket named `lab-reports` and leave **Public
   bucket** disabled.
3. Open the Supabase project's **Authentication → Third-Party Auth** settings
   (direct route: `https://supabase.com/dashboard/project/<project-ref>/auth/third-party`).
   Add Firebase Auth and set its project ID to `e-clinic-book-c5ee1`. Supabase
   uses this configured Firebase issuer/signing keys to verify incoming Firebase
   ID tokens. Requests have issuer
   `https://securetoken.google.com/e-clinic-book-c5ee1` and audience
   `e-clinic-book-c5ee1`.
4. Open **Project Settings → API** (or **Data API**) and copy the Project URL
   and the public `anon` / `publishable` key. Do not use a secret or
   `service_role` key.

### Assignment-scoped Storage policies

The former doctor-wide read policy allowed every doctor to read every private
report object, regardless of patient assignment. In the Supabase SQL Editor,
run [`tools/doctor-admin/supabase-assignment-access.sql`](./tools/doctor-admin/supabase-assignment-access.sql)
once. It creates a private assignment mirror, replaces the doctor-wide read,
upload, and delete policies with assignment-scoped policies, and leaves the
bucket private, patient-own reads, file paths, and authentication flow intact.
It does not add public access or object updates.

The trusted assignment tool synchronizes the mirror. Set
`SUPABASE_SERVICE_ROLE_KEY` only in the secured administrator terminal
environment; this key is never used by Flutter or written to repository files.
From `tools/doctor-admin`, with Firebase Admin credentials configured, run:

```powershell
$secure = Read-Host "Supabase service key" -AsSecureString
$pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
  $env:SUPABASE_SERVICE_ROLE_KEY = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
}
npm run manage-assignments
Remove-Item Env:SUPABASE_SERVICE_ROLE_KEY
```

The command reads the Supabase URL from the ignored `.env.supabase`, lists
patient assignments and unresolved appointments, requires explicit UID
confirmation, and updates Firestore and the Supabase assignment mirror.
Changing an assignment migrates the primary doctor UID on existing visit and
report metadata; it does not delete or alter the existing report files. If the
mirror sync fails after Firestore migration, report-file access fails closed;
rerun the assignment workflow after correcting its configuration.

The Supabase SQL function validates the Firebase issuer, audience, doctor
claim, and patient folder UID against the private assignment mirror. Patient
read access remains restricted to the patient's own Firebase UID. Keep the
bucket private and never add public read access.

The report form's two named laboratory choices come from existing sample
records and are examples, not an official directory. Select **Other** and enter
the exact facility name when needed. The name continues to be saved in the
existing Firestore `lab` field.

The trusted doctor provisioning tool adds Firebase custom claims
`role: "authenticated"` and `app_role: "doctor"` after confirming the
Firestore doctor profile. For existing Firebase users, run the bulk sync from
`tools/doctor-admin`; it defaults to a dry run and preserves Firestore roles:

```powershell
cd tools/doctor-admin
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\secure\firebase-admin-key.json"
npm run sync-supabase-claims
npm run sync-supabase-claims -- --apply
```

The tool copies `app_role` from each trusted Firestore user profile, replaces
only the Firebase custom JWT `role` with `authenticated`, preserves unrelated
custom claims, and never writes to Firestore. `--apply` requires interactive
confirmation. After applying claims, users must sign out and back in to obtain
new Firebase ID tokens. The app checks that a token has
`role: "authenticated"` before using it with Supabase. Never assign doctor
claims from Flutter or from user-editable data.

New Firebase accounts also need their custom claims synchronized by this
trusted tool before using Supabase report files. Do not set these claims in
the Flutter registration flow.

### Flutter configuration

Pass the Project URL and public anon/publishable key at build/run time; do not
commit real project values to source control:

```powershell
flutter run -d chrome `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_OR_PUBLISHABLE_KEY
```

Use the same `--dart-define` options for `flutter build web` or `flutter run`
on Android. These values are public client configuration; the bucket remains
private because Storage access is controlled by the policies above. The
application does not need Firebase Storage, a Supabase service-role key, or a
Firebase billing-plan upgrade.

Official references:

- [Supabase Firebase Auth third-party integration](https://supabase.com/docs/guides/auth/third-party/firebase-auth)
- [Supabase Storage access control](https://supabase.com/docs/guides/storage/security/access-control)
- [Firebase custom user claims](https://firebase.google.com/docs/auth/admin/custom-claims)
