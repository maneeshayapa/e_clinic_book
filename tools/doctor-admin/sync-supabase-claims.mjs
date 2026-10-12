import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { stdin, stdout } from 'node:process';
import { createInterface } from 'node:readline/promises';

const projectId = process.env.FIREBASE_PROJECT_ID ?? 'e-clinic-book-c5ee1';
const applyChanges = process.argv.includes('--apply');
const app = initializeApp({
  credential: applicationDefault(),
  projectId,
});
const auth = getAuth(app);
const firestore = getFirestore(app);

async function confirmApply() {
  if (!stdin.isTTY) {
    throw new Error('Run --apply from an interactive terminal to confirm.');
  }

  const terminal = createInterface({ input: stdin, output: stdout });
  try {
    return (await terminal.question(
      'Type SYNC SUPABASE CLAIMS to update Firebase custom claims: ',
    )).trim() === 'SYNC SUPABASE CLAIMS';
  } finally {
    terminal.close();
  }
}

async function main() {
  if (applyChanges && !(await confirmApply())) {
    throw new Error('Claim synchronization was not confirmed.');
  }

  let pageToken;
  let scanned = 0;
  let changed = 0;
  let doctors = 0;
  let patients = 0;
  let withoutKnownProfileRole = 0;

  do {
    const page = await auth.listUsers(1000, pageToken);
    for (const user of page.users) {
      scanned++;
      const profile = await firestore.collection('users').doc(user.uid).get();
      const profileRole = profile.data()?.role;
      const nextClaims = {
        ...user.customClaims,
        role: 'authenticated',
      };

      if (profileRole === 'doctor' || profileRole === 'patient') {
        nextClaims.app_role = profileRole;
        if (profileRole === 'doctor') doctors++;
        else patients++;
      } else {
        delete nextClaims.app_role;
        withoutKnownProfileRole++;
      }

      const expectedAppRole =
        profileRole === 'doctor' || profileRole === 'patient'
          ? profileRole
          : undefined;
      if (
        user.customClaims?.role === 'authenticated' &&
        user.customClaims?.app_role === expectedAppRole
      ) {
        continue;
      }

      changed++;
      if (applyChanges) {
        await auth.setCustomUserClaims(user.uid, nextClaims);
      }
    }
    pageToken = page.pageToken;
  } while (pageToken);

  stdout.write(
    `${applyChanges ? 'Updated' : 'Dry run'} for Firebase project ${projectId}.\n` +
      `Accounts scanned: ${scanned}\n` +
      `Accounts requiring changes: ${changed}\n` +
      `Firestore doctor profiles: ${doctors}\n` +
      `Firestore patient profiles: ${patients}\n` +
      `Accounts without a recognized Firestore role: ${withoutKnownProfileRole}\n` +
      'Firestore user profiles were not modified.\n' +
      (applyChanges
        ? 'Users must sign out and back in to receive refreshed ID tokens.\n'
        : 'Review the counts, then rerun with --apply to make changes.\n'),
  );
}

main().catch((error) => {
  console.error(`Supabase claim synchronization failed: ${error.message}`);
  process.exitCode = 1;
});
