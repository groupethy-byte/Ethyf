import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_styled_toast/flutter_styled_toast.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../services/local_database_service.dart';
import '../../../services/sync_service.dart';

class SaldoAwalScreen extends StatefulWidget {
  const SaldoAwalScreen({Key? key}) : super(key: key);

  @override
  State<SaldoAwalScreen> createState() => _SaldoAwalScreenState();
}

class _SaldoAwalScreenState extends State<SaldoAwalScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final user = FirebaseAuth.instance.currentUser;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _setupConnectivityListener();
    _initialSync();
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      if (result != ConnectivityResult.none) {
        // Connected to internet, sync data
        _syncData();
      }
    });
  }

  Future<void> _initialSync() async {
    await SyncService.syncAllData();
  }

  Future<void> _syncData() async {
    await SyncService.syncAllData();
    setState(() {});
    if (mounted) {
      showToast(
        'Data tersinkronkan',
        context: context,
        backgroundColor: Colors.green,
      );
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saldo Awal'),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Try online first, fallback to local
    return FutureBuilder<bool>(
      future: SyncService.isOnline(),
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? false;

        if (isOnline) {
          return StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('users')
                .doc(user?.uid)
                .collection('banks')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _buildOfflineView();
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyView();
              }

              final banks = snapshot.data!.docs;
              return _buildBanksList(banks);
            },
          );
        } else {
          return _buildOfflineView();
        }
      },
    );
  }

  Widget _buildOfflineView() {
    final localBanks = LocalDatabaseService.getBanks();

    if (localBanks.isEmpty) {
      return _buildEmptyView();
    }

    return Column(
      children: [
        Container(
          color: Colors.orange.withOpacity(0.1),
          padding: const EdgeInsets.all(12),
          child: const Row(
            children: [
              Icon(Icons.cloud_off, color: Colors.orange),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Mode Offline - Data lokal',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: localBanks.length,
            itemBuilder: (context, index) {
              final bank = localBanks[index];
              return _buildBankCard(bank);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBanksList(List<QueryDocumentSnapshot> banks) {
    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: banks.length,
      itemBuilder: (context, index) {
        final bank = banks[index].data() as Map<String, dynamic>;
        final bankId = banks[index].id;
        final saldoAwal = bank['saldoAwal'] ?? 0;
        final bankName = bank['namaBanks'] ?? 'Unknown';

        return FutureBuilder<int>(
          future: _calculateSaldoSementara(bankId),
          builder: (context, saldoSnapshot) {
            int saldoSementara = saldoAwal;
            if (saldoSnapshot.hasData) {
              saldoSementara = saldoSnapshot.data ?? saldoAwal;
            }

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 46, 204, 113).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.account_balance,
                        color: Color.fromARGB(255, 46, 204, 113),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bankName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Saldo Awal: ${_formatCurrencyToRupiah(saldoAwal)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Saldo Sementara: ${_formatCurrencyToRupiah(saldoSementara)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: saldoSementara >= saldoAwal
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        _showEditSaldoDialog(context, bankId, bankName, saldoAwal);
                      },
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        backgroundColor: const Color.fromARGB(255, 46, 204, 113),
                        foregroundColor: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<int> _calculateSaldoSementara(String bankId) async {
    try {
      // Ambil saldo awal
      final bankDoc = await _firestore
          .collection('users')
          .doc(user?.uid)
          .collection('banks')
          .doc(bankId)
          .get();

      if (!bankDoc.exists) return 0;

      // Ambil data sebagai Map untuk menghindari error jika field tidak ada
      final Object? rawData = bankDoc.data();
      int saldoAwal = 0;
      if (rawData is Map<String, dynamic>) {
        saldoAwal = (rawData['saldoAwal'] as num?)?.toInt() ?? 0;
      }

      // Ambil semua transaksi untuk bank ini
      final transaksiSnapshot = await _firestore
          .collection('users')
          .doc(user?.uid)
          .collection('transaksi')
          .where('bankId', isEqualTo: bankId)
          .get();

      int totalPendapatan = 0;
      int totalPengeluaran = 0;

      for (var doc in transaksiSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final type = data['type'] ?? '';
        final nilai = (data['nilai'] as num?)?.toInt() ?? 0;

        if (type == 'pendapatan') {
          totalPendapatan += nilai;
        } else if (type == 'pengeluaran' || type == 'hutang') {
          totalPengeluaran += nilai;
        }
      }

      int saldoSementara = saldoAwal + totalPendapatan - totalPengeluaran;
      return saldoSementara;
    } catch (e) {
      print('Error calculating saldo sementara: $e');
      return 0;
    }
  }

  Widget _buildBankCard(Map<String, dynamic> bank) {
    final saldoAwal = bank['saldoAwal'] ?? 0;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(
              Icons.account_balance,
              color: Color.fromARGB(255, 46, 204, 113),
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bank['namaBanks'] ?? 'Unknown',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${bank['idBank'] ?? 'N/A'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatCurrencyToRupiah(saldoAwal),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankCardWithEdit(
      String bankId, Map<String, dynamic> bank, int saldoAwal) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(
              Icons.account_balance,
              color: Color.fromARGB(255, 46, 204, 113),
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bank['namaBanks'] ?? 'Unknown',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${bank['idBank'] ?? 'N/A'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatCurrencyToRupiah(saldoAwal),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                _showEditSaldoDialog(context, bankId, bank['namaBanks'], saldoAwal);
              },
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Edit'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                backgroundColor: const Color.fromARGB(255, 46, 204, 113),
                foregroundColor: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet,
            size: 80,
            color: Colors.grey.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          const Text(
            'Belum ada data bank',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Tambahkan bank terlebih dahulu di Data Master',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditSaldoDialog(
    BuildContext context,
    String bankId,
    String bankName,
    int currentSaldo,
  ) {
    final saldoController = TextEditingController(text: currentSaldo.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Saldo Awal - $bankName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Masukkan saldo awal untuk bank ini',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: saldoController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Masukkan nominal saldo',
                labelText: 'Saldo Awal',
                prefixIcon: const Icon(Icons.money),
                prefixText: 'Rp ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              _updateSaldoAwal(bankId, saldoController.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 46, 204, 113),
              foregroundColor: Colors.black87,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateSaldoAwal(String bankId, String saldoText) async {
    try {
      if (saldoText.isEmpty) {
        showToast(
          'Saldo tidak boleh kosong',
          context: context,
        );
        return;
      }

      final saldo = int.parse(saldoText.replaceAll('.', ''));

      await _firestore
          .collection('users')
          .doc(user?.uid)
          .collection('banks')
          .doc(bankId)
          .update({
        'saldoAwal': saldo,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        showToast(
          'Saldo awal berhasil diperbarui',
          context: context,
          backgroundColor: Colors.green,
        );
      }
    } catch (e) {
      if (mounted) {
        showToast(
          'Error: $e',
          context: context,
          backgroundColor: Colors.red,
        );
      }
    }
  }

  String _formatCurrencyToRupiah(int value) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(value);
  }
}
