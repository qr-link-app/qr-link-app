import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QrConverterPage extends StatefulWidget {
  const QrConverterPage({super.key});

  @override
  State<QrConverterPage> createState() => _QrConverterPageState();
}

class _QrConverterPageState extends State<QrConverterPage> {
  final _linkController = TextEditingController();
  String _qrData = '';

  Future<void> _generateQrCode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _linkController.text.isEmpty) return;

    // Simpan data QR code ke Firestore (langkah 1 dari QR Dinamis)
    final docRef = await FirebaseFirestore.instance.collection('qr_codes').add({
      'originalLink': _linkController.text.trim(),
      'ownerId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
      'scans': 0,
    });

    // Buat link dinamis yang akan di-QR-kan
    final dynamicLink = 'https://qr-app.com/redirect?id=${docRef.id}';

    setState(() {
      _qrData = dynamicLink;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('QR Code berhasil dibuat!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat QR Code Dinamis'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _linkController,
              decoration: InputDecoration(
                labelText: 'Masukkan Link (URL)',
                hintText: 'mis. https://www.google.com',
                prefixIcon: const Icon(Icons.link),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _generateQrCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 5,
              ),
              child: const Text(
                'Generate QR Code',
                style: TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 40),
            if (_qrData.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: _qrData,
                  version: QrVersions.auto,
                  size: 200.0,
                  gapless: false,
                  embeddedImage: const AssetImage(
                    'assets/images/qr_logo.png',
                  ), // Opsional
                  embeddedImageStyle: const QrEmbeddedImageStyle(
                    size: Size(40, 40),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
