import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui';
import 'dart:io';
import 'dart:typed_data'; // Tambahkan baris ini
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class QrDetailPage extends StatelessWidget {
  final dynamic data;
  final GlobalKey qrKey;
  final Function(String) onDelete;
  final Function(String, bool) onDeactivate;

  const QrDetailPage({
    super.key,
    required this.data,
    required this.qrKey,
    required this.onDelete,
    required this.onDeactivate,
  });

  Future<void> _shareQrCode(BuildContext context) async {
    try {
      RenderRepaintBoundary boundary =
          qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      var image = await boundary.toImage(pixelRatio: 3.0);
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal berbagi: ${e.toString()}')));
    }
  }

  void _showActionMenu(BuildContext context) {
    final isScan = data['type'] == 'scan';
    final docId = data['id'] as String;
    final isActive = data['isActive'] as bool? ?? false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isScan ? 'Opsi Pemindaian' : 'Opsi QR Code'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                if (!isScan) ...[
                  ListTile(
                    leading: const Icon(Icons.toggle_on),
                    title: Text(isActive ? 'Nonaktifkan' : 'Aktifkan'),
                    onTap: () {
                      onDeactivate(docId, isActive);
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Hapus',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    onDelete(docId);
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Batal'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isScan = data['type'] == 'scan';
    final originalLink = data['originalLink'] as String? ?? 'N/A';
    final scannedData = data['scannedData'] as String? ?? 'N/A';
    final isActive = data['isActive'] as bool? ?? false;
    final scans = data['scans'] as int? ?? 0;
    final time =
        (isScan ? data['scannedAt'] : data['createdAt'])?.toDate().toString() ??
        'N/A';
    final qrDataLink = data['dynamicLink'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(isScan ? 'Detail Pemindaian' : 'Detail QR Code'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          if (!isScan)
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showActionMenu(context),
            ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isScan ? 'Data: $scannedData' : 'Tautan Asli: $originalLink',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              if (!isScan && qrDataLink.isNotEmpty) ...[
                RepaintBoundary(
                  key: qrKey,
                  child: QrImageView(
                    data: qrDataLink,
                    version: QrVersions.auto,
                    size: 250.0,
                    gapless: false,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Status: ${isActive ? 'Aktif' : 'Nonaktif'}',
                  style: const TextStyle(fontSize: 16),
                ),
                Text(
                  'Pemindaian: $scans',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
              const SizedBox(height: 10),
              Text('Waktu: $time', style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
      floatingActionButton: isScan
          ? null
          : FloatingActionButton(
              onPressed: () => _shareQrCode(context),
              backgroundColor: Colors.blueAccent,
              child: const Icon(Icons.share, color: Colors.white),
            ),
    );
  }
}
