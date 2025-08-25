import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'qr_converter_page.dart';
import 'qr_scanner_page.dart';
import 'qr_detail_page.dart';

class QrGeneratorPage extends StatefulWidget {
  const QrGeneratorPage({super.key});

  @override
  State<QrGeneratorPage> createState() => _QrGeneratorPageState();
}

class _QrGeneratorPageState extends State<QrGeneratorPage> {
  bool _isFabOpen = false;
  String _currentFilter = 'generate';
  final GlobalKey _qrKey = GlobalKey();

  void _toggleFab() {
    setState(() {
      _isFabOpen = !_isFabOpen;
    });
  }

  void _setFilter(String filter) {
    setState(() {
      _currentFilter = filter;
    });
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Stream<List<dynamic>> _fetchActivities() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    if (_currentFilter == 'generate') {
      return FirebaseFirestore.instance
          .collection('qr_codes')
          .where('ownerId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map(
                  (doc) => {
                    ...doc.data(),
                    'id': doc.id,
                    'type': 'generate',
                    'dynamicLink':
                        'https://qr-link-id.netlify.app/.netlify/functions/redirect?id=${doc.id}',
                  },
                )
                .toList(),
          );
    } else {
      // 'scan'
      return FirebaseFirestore.instance
          .collection('scan_history')
          .where('userId', isEqualTo: user.uid)
          .orderBy('scannedAt', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => {...doc.data(), 'id': doc.id, 'type': 'scan'})
                .toList(),
          );
    }
  }

  Future<void> _deactivateQrCode(String docId, bool isActive) async {
    await FirebaseFirestore.instance.collection('qr_codes').doc(docId).update({
      'isActive': !isActive,
    });
  }

  Future<void> _deleteQrCode(String docId) async {
    await FirebaseFirestore.instance.collection('qr_codes').doc(docId).delete();
  }

  Future<void> _deleteScannedQr(String docId) async {
    await FirebaseFirestore.instance
        .collection('scan_history')
        .doc(docId)
        .delete();
  }

  void _showActivityDetails(BuildContext context, dynamic data) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QrDetailPage(
          data: data,
          qrKey: _qrKey,
          onDelete: (id) {
            if (data['type'] == 'scan') {
              _deleteScannedQr(id);
            } else {
              _deleteQrCode(id);
            }
          },
          onDeactivate: _deactivateQrCode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My QR Links',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.purple),
              child: Text(
                'Menu',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_2),
              title: const Text('QR Dibuat'),
              onTap: () => _setFilter('generate'),
              selected: _currentFilter == 'generate',
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('QR Dipindai'),
              onTap: () => _setFilter('scan'),
              selected: _currentFilter == 'scan',
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<dynamic>>(
        stream: _fetchActivities(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'Tidak ada riwayat ${_currentFilter == 'generate' ? 'QR Dibuat' : 'QR Dipindai'}.',
              ),
            );
          }
          final activities = snapshot.data!;
          return ListView.builder(
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final data = activities[index];
              final isScan = data['type'] == 'scan';
              final title = isScan ? data['scannedData'] : data['originalLink'];
              final timestamp =
                  (isScan ? data['scannedAt'] : data['createdAt'])
                      as Timestamp?;
              final formattedDate = timestamp != null
                  ? DateFormat('dd MMM yyyy, HH:mm').format(timestamp.toDate())
                  : 'Tanggal tidak tersedia';

              return Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: Icon(
                    isScan ? Icons.qr_code_scanner : Icons.qr_code_2,
                    color: isScan ? Colors.purple : Colors.red,
                  ),
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${isScan ? 'Dipindai' : 'Dibuat'} pada $formattedDate',
                  ),
                  onTap: () => _showActivityDetails(context, data),
                  trailing: const Icon(Icons.arrow_forward_ios),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_isFabOpen) ...[
            FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const QrConverterPage(),
                  ),
                );
                _toggleFab();
              },
              heroTag: 'converterFab',
              backgroundColor: Colors.purple,
              child: const Icon(Icons.link, color: Colors.white),
            ),
            const SizedBox(height: 10),
            FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const QrScannerPage(),
                  ),
                );
                _toggleFab();
              },
              heroTag: 'scannerFab',
              backgroundColor: Colors.purple,
              child: const Icon(Icons.qr_code_scanner, color: Colors.white),
            ),
          ],
          const SizedBox(height: 10),
          FloatingActionButton(
            onPressed: _toggleFab,
            heroTag: 'mainFab',
            backgroundColor: Colors.purple,
            child: Icon(
              _isFabOpen ? Icons.close : Icons.add,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
