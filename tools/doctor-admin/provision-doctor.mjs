import { createInterface } from 'node:readline/promises';
import { stdin, stdout } from 'node:process';
import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';

const projectId = process.env.FIREBASE_PROJECT_ID ?? 'e-clinic-book-c5ee1';
const app = initializeApp({
  credential: applicationDefault(),
  projectId,
});
const auth = getAuth(app);
const firestore = getFirestore(app);

async function ask(question) {
  const terminal = createInterface({ input: stdin, output: stdout });
  try {
    return (await terminal.question(question)).trim();
  } finally {
    terminal.close();
  }
}

function askSecret(question) {
  if (!stdin.isTTY || typeof stdin.setRawMode !== 'function') {
    throw new Error('Run this command in an interactive terminal to enter a password safely.');
  }

  return new Promise((resolve, reject) => {
    let value = '';
    stdout.write(question);
    stdin.setRawMode(true);
    stdin.resume();
    stdin.setEncoding('utf8');

    const finish = (error) => {
      stdin.removeListener('data', onData);
      stdin.setRawMode(false);
      stdin.pause();
      stdout.write('\n');
      if (error) reject(error);
      else resolve(value);
    };

    const onData = (character) => {
      if (character === '\u0003') {
        finish(new Error('Password entry cancelled.'));
      } else if (character === '\r' || character === '\n') {
        finish();
      } else if (character === '\u007f' || character === '\b') {
        value = value.slice(0, -1);
      } else {
        value += character;
      }
    };

    stdin.on('data', onData);
  });
}

async function main() {
  const name = await ask('Doctor full name: ');
  const email = (await ask('Doctor email: ')).toLowerCase();
  if (!name || !email) {
    throw new Error('Doctor name and email are required.');
  }
  const confirmation = await ask(
    `This will create/promote ${email} as a doctor in ${projectId}. Type PROVISION to continue: `,
  );
  if (confirmation !== 'PROVISION') {
    throw new Error('Provisioning was not confirmed.');
  }

  let user;
  try {
    user = await auth.getUserByEmail(email);
    stdout.write(`Existing Firebase Auth account found (UID: ${user.uid}).\n`);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
    const password = await askSecret('Set account password (input is hidden): ');
    if (password.length < 6) {
      throw new Error('Firebase passwords must contain at least 6 characters.');
    }
    const passwordConfirmation = await askSecret('Confirm password: ');
    if (password !== passwordConfirmation) {
      throw new Error('The passwords do not match.');
    }
    user = await auth.createUser({
      email,
      password,
      displayName: name,
      emailVerified: false,
      disabled: false,
    });
    stdout.write(`Firebase Auth account created (UID: ${user.uid}).\n`);
  }

  await firestore.collection('users').doc(user.uid).set(
    {
      name,
      email: user.email ?? email,
      role: 'doctor',
      approvedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  await auth.setCustomUserClaims(user.uid, {
    ...user.customClaims,
    role: 'authenticated',
    app_role: 'doctor',
  });

  stdout.write(
    `Doctor profile provisioned in ${projectId}/users/${user.uid}.\n` +
      'Supabase JWT claims are role=authenticated and app_role=doctor. ' +
      'Firestore role=doctor was preserved. Sign out and back in to refresh ' +
      'the Firebase ID token.\n',
  );
}

main().catch((error) => {
  console.error(`Doctor provisioning failed: ${error.message}`);
  process.exitCode = 1;
});
