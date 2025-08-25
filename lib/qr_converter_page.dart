import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class QrConverterPage extends StatefulWidget {
  const QrConverterPage({super.key});

  @override
  State<QrConverterPage> createState() => _QrConverterPageState();
}

class _QrConverterPageState extends State<QrConverterPage> {
  final _linkController = TextEditingController();
  String _qrData = '';
  final GlobalKey _qrKey = GlobalKey();

  Future<void> _generateQrCode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _linkController.text.isEmpty) {
      _showSnackBar('Masukkan link terlebih dahulu.');
      return;
    }

    try {
      // Simpan data QR code ke Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('qr_codes')
          .add({
            'originalLink': _linkController.text.trim(),
            'ownerId': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
            'isActive': true,
            'scans': 0,
          });

      // Buat link dinamis yang akan di-QR-kan
      // Ganti URL ini dengan URL Netlify Functions Anda
      final dynamicLink =
          'https://qr-link-id.netlify.app/.netlify/functions/redirect?id=${docRef.id}';

      setState(() {
        _qrData = dynamicLink;
      });

      _showSnackBar('QR Code berhasil dibuat!', color: Colors.green);
    } catch (e) {
      _showSnackBar(
        'Gagal membuat QR Code: ${e.toString()}',
        color: Colors.red,
      );
    }
  }

  Future<void> _shareQrCode() async {
    try {
      RenderRepaintBoundary boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      var image = await boundary.toImage();
      ByteData? byteData = await image.toByteData(format: ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to convert image to byte data.');
      }

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/qr_code.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Ini QR Code yang saya buat dengan aplikasi. Coba pindai!');
    } catch (e) {
      _showSnackBar('Gagal berbagi: ${e.toString()}', color: Colors.red);
    }
  }

  void _showSnackBar(String message, {Color? color}) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
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
              Column(
                children: [
                  RepaintBoundary(
                    key: _qrKey,
                    child: Container(
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
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _shareQrCode,
                    icon: const Icon(Icons.share, color: Colors.white),
                    label: const Text('Bagikan QR Code'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 5,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
