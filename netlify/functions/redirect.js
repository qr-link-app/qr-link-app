const admin = require("firebase-admin");

// Service Account Key (harus diatur sebagai variabel lingkungan di Netlify)
const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_KEY);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

exports.handler = async (event, context) => {
  const linkId = event.queryStringParameters.id;

  if (!linkId) {
    return {
      statusCode: 400,
      body: "ID tidak ditemukan.",
    };
  }

  try {
    const docRef = db.collection("qr_codes").doc(linkId);
    const doc = await docRef.get();

    if (!doc.exists) {
      return {
        statusCode: 404,
        body: "Link tidak ditemukan.",
      };
    }

    const data = doc.data();

    if (data.isActive) {
      await docRef.update({
        scans: admin.firestore.FieldValue.increment(1),
      });
      return {
        statusCode: 301,
        headers: {
          Location: data.originalLink,
        },
      };
    } else {
      return {
        statusCode: 403,
        body: "Link ini telah dinonaktifkan oleh pemiliknya.",
      };
    }
  } catch (error) {
    console.error("Terjadi kesalahan:", error);
    return {
      statusCode: 500,
      body: "Terjadi kesalahan server.",
    };
  }
};
