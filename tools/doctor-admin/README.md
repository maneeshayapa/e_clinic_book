# Provision a doctor account

The app intentionally allows public registration only for patients. Use this
local Admin SDK tool to create a doctor account in Firebase Authentication and
write its `users/{uid}` profile with `role: "doctor"`. Provisioning is an
administrative action; it is not exposed in the client app.

## One-time setup

1. In Google Cloud Console → **IAM & Admin → Service Accounts**, create or
   select a service account for `e-clinic-book-c5ee1`. Grant only the roles
   needed to manage Firebase Authentication users and Firestore profiles
   (Firebase Authentication Admin and Cloud Datastore User). Create a JSON
   key, store it outside this repository, and do not commit or share it.
2. In PowerShell, set the credential path for the current terminal:

   ```powershell
   $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\secure\firebase-admin-key.json"
   ```

3. From this directory, install the tool dependency and run it:

   ```powershell
   npm install
   npm run provision
   ```

The script asks for the doctor's name and email, and requires typing
`PROVISION` to confirm. If that email already exists in Firebase
Authentication, it reuses the account without changing its password.
Otherwise it creates the account and asks for a password twice without
echoing it in the terminal. It then creates or updates the matching
`users/{uid}` Firestore profile as a doctor.

The doctor signs in through the existing app login page with that email and
password. The app reads the profile role and routes the account to the doctor
dashboard. Existing patient registration and login are unchanged.

Provisioning also assigns the Firebase custom claims required for private
Supabase report Storage (`role: "authenticated"` and `app_role: "doctor"`).
The JWT `role` claim is separate from the Firestore profile's `role: "doctor"`.
The Firestore role is not overwritten by setting custom claims.

## Synchronize existing Firebase users for Supabase

Use the bulk script to set the Firebase custom JWT claim
`role: "authenticated"` for existing Firebase Auth accounts. It determines
`app_role` from the trusted Firestore user profile and leaves the Firestore
`role` field untouched.

From this directory, with `GOOGLE_APPLICATION_CREDENTIALS` set as above:

```powershell
npm run sync-supabase-claims
npm run sync-supabase-claims -- --apply
```

The first command is a dry run. The `--apply` command requires typing
`SYNC SUPABASE CLAIMS` interactively, preserves unrelated Firebase custom
claims, and reports counts without printing account emails or UIDs. Users must
sign out and back in after applying claims so new Firebase ID tokens include
the `role: "authenticated"` claim.

To provision another doctor, run the same command again with that account's
name and email. The profile is stored in Firestore and persists, so routine
sign-in testing does not require changing the role again. Never put Admin SDK
credentials in Flutter code or the `web/` directory.

## Assign primary doctors to patients

The client app intentionally has no admin role or patient-assignment control.
Use this trusted Admin SDK workflow to review unassigned profiles and make
each primary assignment explicitly; it never auto-assigns a patient.

Before running it:

1. In the Supabase SQL Editor, run
   [`supabase-assignment-access.sql`](./supabase-assignment-access.sql). This
   creates the private assignment mirror and replaces doctor-wide Storage
   access policies with patient-assignment-scoped policies.
2. In Supabase **Project Settings → API**, obtain the server-only
   `service_role` key. Do not use the public anon/publishable key for this
   operation. Do not put the service key in `.env.supabase`, Flutter defines,
   source files, or version control.
3. Set `GOOGLE_APPLICATION_CREDENTIALS` to the secured Firebase Admin SDK
   credential as described above. Ensure `.env.supabase` exists at the project
   root with the `SUPABASE_URL`.
4. From the project root, deploy the restrictive Firestore rules before doing
   any patient assignments. This intentionally fails closed for doctors until
   each patient and their existing records are explicitly assigned:

   ```powershell
   firebase deploy --only firestore:rules --project e-clinic-book-c5ee1
   ```

From this directory in an interactive PowerShell terminal, read the Supabase
service key without echoing it, then run the tool:

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

The tool lists patient profiles with their current assignment and available
doctor UIDs. Enter one patient UID and the intended doctor's UID; it requires
an exact confirmation before changing anything. Enter `UNASSIGN` only when
intentionally removing a primary assignment. Existing clinic visit and report
documents for that patient are preserved and get (or have removed) only their
`primaryDoctorUid` access field. The corresponding Supabase assignment mirror
is updated for private report file access.

Assign a patient only after their profile has the required name, email, NIC,
date of birth, gender, phone, and address fields; the tool rejects assignment
of incomplete profiles. Incomplete/unassigned accounts remain available for
review in this trusted workflow and are not exposed to doctors.

Existing appointments with a missing, invalid, or mismatched doctor UID are
listed separately and are never assigned based on name alone. An appointment
can be resolved only after you provide a doctor UID that matches the patient's
current primary assignment and the appointment's stored doctor display name;
the tool requires an explicit `LINK <appointmentId> <doctorUid>` confirmation
and changes only its `doctorId`.

Patients without a primary assignment appear in a doctor's patient list after
booking with that doctor. The booking shares the patient's profile details and
appointment with that doctor, but does not grant access to the patient's
permanent medical records. No patient or historical record is deleted by these
workflows.
