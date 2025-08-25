import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  String scanResult = '';
  bool isScanned = false;

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) async {
      if (!isScanned) {
        // Hentikan pemindaian setelah hasil pertama ditemukan
        controller.pauseCamera();
        setState(() {
          scanResult = scanData.code ?? 'Tidak ada data';
          isScanned = true;
        });

        // Simpan riwayat pemindaian ke Firestore
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance.collection('scan_history').add({
            'userId': user.uid,
            'scannedAt': FieldValue.serverTimestamp(),
            'scannedData': scanResult,
          });
        }
      }
    });
  }

  void _reScan() {
    setState(() {
      isScanned = false;
      scanResult = '';
    });
    controller?.resumeCamera();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw Exception('Could not launch $uri');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pemindai QR Code'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 4,
            child: QRView(key: qrKey, onQRViewCreated: _onQRViewCreated),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isScanned
                        ? 'Hasil Pindaian: $scanResult'
                        : 'Arahkan kamera ke QR Code',
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  if (isScanned)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _launchUrl(scanResult),
                          icon: const Icon(Icons.open_in_browser),
                          label: const Text('Buka di Browser'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _reScan,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Pindai Ulang'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
