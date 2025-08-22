import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'qr_converter_page.dart';
import 'qr_scanner_page.dart';

class QrGeneratorPage extends StatefulWidget {
  const QrGeneratorPage({super.key});

  @override
  State<QrGeneratorPage> createState() => _QrGeneratorPageState();
}

class _QrGeneratorPageState extends State<QrGeneratorPage> {
  bool _isFabOpen = false;
  String _currentFilter = 'all'; // 'all', 'generate', 'scan'

  void _toggleFab() {
    setState(() {
      _isFabOpen = !_isFabOpen;
    });
  }

  void _setFilter(String filter) {
    setState(() {
      _currentFilter = filter;
    });
    Navigator.of(context).pop(); // Tutup drawer setelah filter dipilih
  }

  Stream<QuerySnapshot> _fetchActivities() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    // Logika untuk mengambil data dari Firestore berdasarkan filter
    if (_currentFilter == 'generate') {
      return FirebaseFirestore.instance
          .collection('qr_codes')
          .where('ownerId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots();
    } else if (_currentFilter == 'scan') {
      return FirebaseFirestore.instance
          .collection('scan_history')
          .where('userId', isEqualTo: user.uid)
          .orderBy('scannedAt', descending: true)
          .snapshots();
    } else {
      // 'all'
      // Menggabungkan stream dari dua koleksi berbeda
      final generatedStream = FirebaseFirestore.instance
          .collection('qr_codes')
          .where('ownerId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(10) // Batasi untuk efisiensi
          .snapshots();

      final scannedStream = FirebaseFirestore.instance
          .collection('scan_history')
          .where('userId', isEqualTo: user.uid)
          .orderBy('scannedAt', descending: true)
          .limit(10) // Batasi untuk efisiensi
          .snapshots();

      return Stream.multi((controller) {
        generatedStream.listen(
          (snapshot) => controller.add(snapshot),
          onDone: () => scannedStream.listen(
            (snapshot) => controller.add(snapshot),
            onDone: () => controller.close(),
          ),
        );
      });
    }
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
              leading: const Icon(Icons.history),
              title: const Text('Semua Aktivitas'),
              onTap: () => _setFilter('all'),
              selected: _currentFilter == 'all',
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
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _fetchActivities(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Tidak ada riwayat aktivitas.'));
          }

          final activities = snapshot.data!.docs;

          return ListView.builder(
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final doc = activities[index];
              final data = doc.data() as Map<String, dynamic>;
              final isScan = data.containsKey('scannedData');
              final title = isScan
                  ? 'Dipindai: ${data['scannedData']}'
                  : 'Dibuat: ${data['originalLink']}';
              final subtitle = isScan
                  ? 'Pukul: ${data['scannedAt']?.toDate().toString()}'
                  : 'Dibuat: ${data['createdAt']?.toDate().toString()}';

              return ListTile(
                leading: Icon(isScan ? Icons.qr_code_scanner : Icons.qr_code_2),
                title: Text(title),
                subtitle: Text(subtitle),
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
