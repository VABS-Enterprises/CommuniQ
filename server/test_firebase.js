require('dotenv').config();
const admin = require('firebase-admin');

async function runTest() {
  console.log('--- CommuniQ Firebase Admin Setup Verification ---');

  // 1. Check if ENV vars are present
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  let privateKey = process.env.FIREBASE_PRIVATE_KEY;

  if (!projectId || !clientEmail || !privateKey) {
    console.error('❌ Missing one or more Firebase credentials in .env file.');
    console.log('Ensure FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, and FIREBASE_PRIVATE_KEY are set.');
    process.exit(1);
  }

  // Handle escaped newline characters in the .env file
  privateKey = privateKey.replace(/\\n/g, '\n');
  // Remove surrounding quotes if they exist from the .env reading
  if (privateKey.startsWith('"') && privateKey.endsWith('"')) {
    privateKey = privateKey.slice(1, -1);
  }

  console.log('✅ Found Firebase credentials in .env.');

  // 2. Try to initialize Firebase Admin
  try {
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId,
        clientEmail,
        privateKey,
      }),
    });
    console.log('✅ Firebase Admin SDK initialized successfully.');
  } catch (error) {
    console.error('❌ Failed to initialize Firebase Admin SDK:', error.message);
    process.exit(1);
  }

  const db = admin.firestore();

  // 3. Try to write to Firestore
  const testDocRef = db.collection('system').doc('connection_test');
  try {
    console.log('⏳ Attempting to write test document to Firestore...');
    await testDocRef.set({
      message: 'Node.js Backend successfully connected!',
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log('✅ Successfully wrote to Firestore.');
  } catch (error) {
    console.error('❌ Failed to write to Firestore:', error.message);
    if (error.message.includes('7 PERMISSION_DENIED')) {
      console.log('This usually means the Admin SDK key is invalid or for the wrong project.');
    }
    process.exit(1);
  }

  // 4. Try to read from Firestore
  try {
    console.log('⏳ Attempting to read test document back...');
    const doc = await testDocRef.get();
    if (doc.exists) {
      console.log('✅ Successfully read from Firestore. Message:', doc.data().message);
    } else {
      console.error('❌ Document was written but could not be found.');
      process.exit(1);
    }
  } catch (error) {
    console.error('❌ Failed to read from Firestore:', error.message);
    process.exit(1);
  }

  // 5. Leave it so the user can see it in Firebase Console!
  /*
  try {
    await testDocRef.delete();
    console.log('✅ Cleaned up test document.');
  } catch (error) {
    console.warn('⚠️ Could not delete test document, but connection is still working:', error.message);
  }
  */

  console.log('🎉 ALL TESTS PASSED! Your Node.js backend is fully connected to Firebase.');
  process.exit(0);
}

runTest();
