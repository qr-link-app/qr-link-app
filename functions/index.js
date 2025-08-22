const functions = require("firebase-functions");
const admin = require("firebase-admin");

// Inisialisasi Firebase Admin SDK
admin.initializeApp();

const db = admin.firestore();

// Fungsi untuk mengarahkan pengguna
exports.redirect = functions.https.onRequest(async (req, res) => {
  // Memastikan permintaan menggunakan metode GET
  if (req.method !== "GET") {
    return res.status(405).send("Metode Tidak Diperbolehkan");
  }

  // Mendapatkan ID dari parameter URL
  const linkId = req.query.id;

  if (!linkId) {
    return res.status(400).send("ID tidak ditemukan");
  }

  try {
    const docRef = db.collection("qr_codes").doc(linkId);
    const doc = await docRef.get();

    if (!doc.exists) {
      return res.status(404).send("Link tidak ditemukan.");
    }

    const data = doc.data();

    // Memeriksa apakah link aktif
    if (data.isActive) {
      // Meningkatkan jumlah pemindaian
      await docRef.update({
        scans: admin.firestore.FieldValue.increment(1),
      });

      // Mengalihkan pengguna ke link asli
      return res.redirect(301, data.originalLink);
    } else {
      // Jika link tidak aktif, tampilkan pesan
      return res
          .status(403)
          .send("Link ini telah dinonaktifkan oleh pemiliknya.");
    }
  } catch (error) {
    console.error("Terjadi kesalahan:", error);
    return res.status(500).send("Terjadi kesalahan server.");
  }
});
