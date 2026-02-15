import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../services/local_database_service.dart';
import '../../../services/sync_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:excel/excel.dart' hide Border, BorderStyle;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../utils/number_formatter.dart';
import '../../../utils/user_utils.dart'; // Import UserUtils
import '../../../models/family_model.dart'; // Import FamilyModel

class TransaksiScreen extends StatefulWidget {
  final String type; // 'pendapatan' atau 'pengeluaran'

  const TransaksiScreen({Key? key, required this.type}) : super(key: key);

  @override
  State<TransaksiScreen> createState() => _TransaksiScreenState();
}

class _TransaksiScreenState extends State<TransaksiScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? get user => FirebaseAuth.instance.currentUser;

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime(DateTime.now().year, DateTime.now().month + 1, 0, 23, 59, 59);

  bool _isProMember = false;
  String? _currentUserFamilyId;
  List<Map<String, dynamic>> _familyMembers = [];
  String? _selectedMemberUid;
  StreamSubscription<DocumentSnapshot>? _userSubscription;


  @override
  void initState() {
    super.initState();
    _syncData();
    _listenToUserStatus();
  }

  void _listenToUserStatus() {
    if (user == null) return;
    _userSubscription = _firestore.collection('users').doc(user!.uid).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final newIsPro = data['isProMember'] == true;
        final rawFamilyId = data['familyId'] as String?;
        final newFamilyId = (rawFamilyId != null && rawFamilyId.trim().isNotEmpty) ? rawFamilyId.trim() : null;

        if (newIsPro != _isProMember || newFamilyId != _currentUserFamilyId) {
          if (mounted) {
            setState(() {
              _isProMember = newIsPro;
              _currentUserFamilyId = newFamilyId;
            });
          }

          if (_isProMember && _currentUserFamilyId != null) {
            _fetchFamilyMembers();
          }
        } else if (_isProMember && _currentUserFamilyId != null && _familyMembers.isEmpty) {
          _fetchFamilyMembers();
        }
      }
    });
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchFamilyMembers() async {
    try {
      final familyDoc = await _firestore.collection('families').doc(_currentUserFamilyId).get();
      if (familyDoc.exists) {
        List<String> memberUids = [];
        try {
          // Menggunakan FamilyModel untuk parsing data
          final family = FamilyModel.fromMap(familyDoc.id, familyDoc.data()!);
          memberUids = family.memberUids;
        } catch (e) {
          // Fallback manual jika parsing model gagal (misal timestamp null)
          memberUids = List<String>.from(familyDoc.data()?['memberUids'] ?? []);
        }
        
        List<Map<String, dynamic>> members = [];

        for (String uid in memberUids) {
          final userDoc = await _firestore.collection('users').doc(uid).get();
          String name = userDoc.data()?['fullName'] ?? 'Unknown';
          if (name == 'Unknown' || name.isEmpty) {
            name = userDoc.data()?['email'] ?? 'Anggota';
          }
          members.add({'uid': uid, 'name': name});
        }

        if (mounted) {
          setState(() {
            _familyMembers = members;
          });
        }
      }
    } catch (e) {
      print("Error fetching members: $e");
    }
  }

  Future<void> _syncData() async {
    await SyncService.syncAllData();
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: _endDate,
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        // Set ke akhir hari agar transaksi hari tersebut tetap muncul
        _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildDateFilter(),
          _buildFamilyFilter(),
          Expanded(
            child: Builder(
              builder: (context) {
                if (user == null) {
                  return const Center(child: Text('Silakan login kembali'));
                }

                Query collectionRef;
                if (_isProMember && _currentUserFamilyId != null && _currentUserFamilyId!.isNotEmpty) {
                  // Jika Pro, ambil dari koleksi family
                  collectionRef = _firestore
                      .collection('families')
                      .doc(_currentUserFamilyId!)
                      .collection('transaksi');
                } else {
                  // Jika bukan pro, ambil dari koleksi user
                  collectionRef = _firestore
                      .collection('users')
                      .doc(user!.uid)
                      .collection('transaksi');
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: collectionRef
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      print('Error Stream Transaksi: ${snapshot.error}');
                      // Jika error permission atau lainnya, coba tampilkan offline view
                      // atau tampilkan pesan error untuk debugging
                      return _buildOfflineView(); 
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildEmptyView();
                    }

                    // Filter by type
                    final filtered = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;

                      // Filter User (Client Side)
                      if (_isProMember && _selectedMemberUid != null) {
                        if (data['userId'] != _selectedMemberUid) {
                          return false;
                        }
                      }

                      final transactionType = (data['type'] ?? '').toString();
                      final rawTanggal = data['tanggal'];
                      final DateTime tanggal = rawTanggal is Timestamp ? rawTanggal.toDate() : (rawTanggal is DateTime ? rawTanggal : DateTime.now());

                      if (tanggal.isBefore(_startDate) || tanggal.isAfter(_endDate)) {
                        return false;
                      }

                      if (widget.type == 'pendapatan') {
                        return transactionType == 'pendapatan';
                      } else {
                        return transactionType == 'pengeluaran' || transactionType == 'hutang';
                      }
                    }).toList();

                    // Hitung Total Nilai
                    int totalNilai = 0;
                    for (var doc in filtered) {
                      final data = doc.data() as Map<String, dynamic>;
                      final rawNilai = data['nilai'];
                      int nilai = 0;
                      if (rawNilai is num) {
                        nilai = rawNilai.toInt();
                      } else if (rawNilai is String) {
                        nilai = int.tryParse(rawNilai.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                      }
                      totalNilai += nilai;
                    }

                    if (filtered.isEmpty) {
                      return Column(
                        children: [
                          _buildSummaryCard(totalNilai),
                          Expanded(child: _buildEmptyView()),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        _buildSummaryCard(totalNilai),
                        Expanded(child: _buildTransaksiList(filtered)),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showFabMenu,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _exportToExcel() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1. Tentukan koleksi transaksi (Family atau User)
      Query collectionRef;
      if (_isProMember && _currentUserFamilyId != null && _currentUserFamilyId!.isNotEmpty) {
        collectionRef = _firestore.collection('families').doc(_currentUserFamilyId!).collection('transaksi');
      } else {
        collectionRef = _firestore.collection('users').doc(user!.uid).collection('transaksi');
      }

      // 2. Fetch Transactions
      final snapshot = await collectionRef.orderBy('createdAt', descending: true).get();

      // 3. Filter Transactions
      final filtered = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;

        // Filter User (Client Side)
        if (_isProMember && _selectedMemberUid != null) {
          if (data['userId'] != _selectedMemberUid) {
            return false;
          }
        }

        final transactionType = (data['type'] ?? '').toString();
        final rawTanggal = data['tanggal'];
        final DateTime tanggal = rawTanggal is Timestamp ? rawTanggal.toDate() : (rawTanggal is DateTime ? rawTanggal : DateTime.now());

        if (tanggal.isBefore(_startDate) || tanggal.isAfter(_endDate)) {
          return false;
        }

        if (widget.type == 'pendapatan') {
          return transactionType == 'pendapatan';
        } else {
          return transactionType == 'pengeluaran' || transactionType == 'hutang';
        }
      }).toList();

      if (filtered.isEmpty) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada data untuk diexport')),
        );
        return;
      }

      // 4. Collect User IDs involved to fetch their Master Data
      Set<String> userIds = {user!.uid};
      for (var doc in filtered) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['userId'] != null) userIds.add(data['userId']);
      }

      // 5. Fetch Master Data for ALL involved users
      Map<String, Map<String, String>> userBankMap = {};
      Map<String, Map<String, String>> userCategoryMap = {};
      Map<String, Map<String, String>> userSubCategoryMap = {};

      for (String uid in userIds) {
        // Banks
        final banksSnap = await _firestore.collection('users').doc(uid).collection('banks').get();
        userBankMap[uid] = {
          for (var doc in banksSnap.docs) doc.id: (doc.data()['namaBanks'] ?? 'Unknown').toString()
        };
        // Categories
        final catSnap = await _firestore.collection('users').doc(uid).collection('kategori').get();
        userCategoryMap[uid] = {
          for (var doc in catSnap.docs) doc.id: (doc.data()['namaKategori'] ?? '-').toString()
        };
        // SubCategories
        final subCatSnap = await _firestore.collection('users').doc(uid).collection('subkategori').get();
        userSubCategoryMap[uid] = {
          for (var doc in subCatSnap.docs) doc.id: (doc.data()['namaSubKategori'] ?? '-').toString()
        };
      }

      var excel = Excel.createExcel();
      String sheetName = excel.sheets.keys.isNotEmpty ? excel.sheets.keys.first : 'Sheet1';
      Sheet sheet = excel[sheetName];

      // Header
      sheet.appendRow([
        TextCellValue('Tanggal'),
        TextCellValue('Oleh'),
        TextCellValue('Kategori'),
        TextCellValue('Sub Kategori'),
        TextCellValue('Bank'),
        TextCellValue('Catatan'),
        TextCellValue('Nilai'),
        TextCellValue('Tipe')
      ]);

      // Isi Data
      for (var doc in filtered) {
        final data = doc.data() as Map<String, dynamic>;
        final rawTanggal = data['tanggal'];
        final DateTime tanggal = rawTanggal is Timestamp ? rawTanggal.toDate() : (rawTanggal is DateTime ? rawTanggal : DateTime.now());
        
        final txUserId = data['userId'] ?? user!.uid;
        
        // Resolve Names from the correct user's master data
        String bankName = userBankMap[txUserId]?[data['bankId']] ?? 'Unknown';
        String catName = userCategoryMap[txUserId]?[data['kategoriId']] ?? '-';
        String subCatName = userSubCategoryMap[txUserId]?[data['subKategoriId']] ?? '-';
        
        // Resolve User Name
        String inputBy = 'Saya';
        if (txUserId != user!.uid) {
           final foundMember = _familyMembers.firstWhere(
            (element) => element['uid'] == txUserId,
            orElse: () => {'name': 'Anggota'},
          );
          inputBy = foundMember['name'];
        }
        
        final rawNilai = data['nilai'];
        int nilai = 0;
        if (rawNilai is num) {
          nilai = rawNilai.toInt();
        } else if (rawNilai is String) {
          nilai = int.tryParse(rawNilai.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        }
        
        String type = (data['type'] ?? '').toString();

        sheet.appendRow([
          TextCellValue(DateFormat('dd/MM/yyyy').format(tanggal)),
          TextCellValue(inputBy),
          TextCellValue(catName),
          TextCellValue(subCatName),
          TextCellValue(bankName),
          TextCellValue(data['catatan'] ?? ''),
          IntCellValue(nilai),
          TextCellValue(type),
        ]);
      }

      var fileBytes = excel.save();
      if (fileBytes != null) {
        final directory = await getTemporaryDirectory();
        final fileName = 'Laporan_${widget.type}_${DateFormat('ddMMyyyy').format(_startDate)}-${DateFormat('ddMMyyyy').format(_endDate)}.xlsx';
        final file = File('${directory.path}/$fileName');
        
        await file.writeAsBytes(fileBytes);
        
        Navigator.pop(context); // Tutup loading
        await Share.shareXFiles([XFile(file.path)], text: 'Laporan ${widget.type}');
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal export: $e')),
      );
    }
  }

  Widget _buildDateFilter() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color.fromARGB(255, 46, 204, 113).withOpacity(0.1),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _selectStartDate,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color.fromARGB(255, 46, 204, 113).withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Color.fromARGB(255, 46, 204, 113)),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('dd MMM yyyy').format(_startDate),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('-', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: InkWell(
              onTap: _selectEndDate,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color.fromARGB(255, 46, 204, 113).withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Color.fromARGB(255, 46, 204, 113)),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('dd MMM yyyy').format(_endDate),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color.fromARGB(255, 46, 204, 113).withOpacity(0.5)),
            ),
            child: IconButton(
              icon: const Icon(Icons.file_download, color: Color.fromARGB(255, 46, 204, 113)),
              onPressed: _exportToExcel,
              tooltip: 'Export Excel',
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyFilter() {
    if (!_isProMember || _currentUserFamilyId == null || _familyMembers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          const Text('Filter Anggota: ', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButton<String?>(
              isExpanded: true,
              value: _selectedMemberUid,
              hint: const Text('Semua Anggota'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Semua Anggota'),
                ),
                ..._familyMembers.map((member) {
                  return DropdownMenuItem<String?>(
                    value: member['uid'],
                    child: Text(member['name']),
                  );
                }).toList(),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedMemberUid = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(int total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: widget.type == 'pendapatan' ? Colors.green : Colors.red,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total ${widget.type == 'pendapatan' ? 'Pendapatan' : 'Pengeluaran'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(total),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${DateFormat('dd MMM').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showFabMenu() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add_circle, color: Color.fromARGB(255, 46, 204, 113)),
                title: const Text('Tambah Transaksi'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AddTransaksiScreen(type: widget.type),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz, color: Colors.green),
                title: const Text('Pindah Dana'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PindahDanaScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  Widget _buildTransaksiList(List<QueryDocumentSnapshot> transaksi) {
    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: transaksi.length,
      itemBuilder: (context, index) {
        final data = transaksi[index].data() as Map<String, dynamic>;
        final docId = transaksi[index].id;
        final userId = data['userId'];
        final rawBankId = data['bankId'];
        String bankId = '';
        if (rawBankId is String) {
          bankId = rawBankId.trim();
        } else if (rawBankId is DocumentReference) {
          bankId = rawBankId.id;
        }
        final transactionRef = transaksi[index].reference;

        String inputBy = 'Saya';
        if (userId != null && user != null && userId != user!.uid) {
          final foundMember = _familyMembers.firstWhere(
            (element) => element['uid'] == userId,
            orElse: () => {'name': 'Anggota Keluarga'},
          );
          inputBy = foundMember['name'];
        }

        DocumentReference? bankRef;
        final txFamilyId = data['familyId'] as String?;

        if (bankId.isNotEmpty) {
          // Selalu ambil referensi bank dari user pembuat transaksi (Master Data tetap di user)
          final ownerId = (userId ?? user!.uid).toString();
          bankRef = _firestore.collection('users').doc(ownerId).collection('banks').doc(bankId);
        }

        return TransactionItem(
          key: ValueKey(docId),
          data: data,
          docId: docId,
          transactionRef: transactionRef,
          type: widget.type,
          inputBy: inputBy,
          bankRef: bankRef,
        );
      },
    );
  }

  Widget _buildOfflineView() {
    final allTransaksi = LocalDatabaseService.getTransaksi();

    // Filter by type
    final transaksi = allTransaksi.where((t) {
      final transactionType = (t['type'] ?? '').toString();
      final rawTanggal = t['tanggal'];
      final DateTime tanggal = rawTanggal is Timestamp ? rawTanggal.toDate() : (rawTanggal is DateTime ? rawTanggal : DateTime.now());

      if (tanggal.isBefore(_startDate) || tanggal.isAfter(_endDate)) {
        return false;
      }

      if (widget.type == 'pendapatan') {
        return transactionType == 'pendapatan';
      } else {
        return transactionType == 'pengeluaran' || transactionType == 'hutang';
      }
    }).toList();

    // Hitung Total Nilai Offline
    int totalNilai = 0;
    for (var data in transaksi) {
      final rawNilai = data['nilai'];
      int nilai = 0;
      if (rawNilai is num) {
        nilai = rawNilai.toInt();
      } else if (rawNilai is String) {
        nilai = int.tryParse(rawNilai.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      }
      totalNilai += nilai;
    }

    if (transaksi.isEmpty) {
      return Column(
        children: [
          _buildSummaryCard(totalNilai),
          Expanded(child: _buildEmptyView()),
        ],
      );
    }

    return Column(
      children: [
        _buildSummaryCard(totalNilai),
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
            itemCount: transaksi.length,
            itemBuilder: (context, index) {
              final data = transaksi[index];
              
              final rawNilai = data['nilai'];
              int nilai = 0;
              if (rawNilai is num) {
                nilai = rawNilai.toInt();
              } else if (rawNilai is String) {
                nilai = int.tryParse(rawNilai.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
              }

              final catatan = data['catatan'] ?? 'Tanpa catatan';
              final bankId = data['bankId'] ?? '';
              final type = (data['type'] ?? widget.type).toString();

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
                          color: _getTypeColor(type).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getTypeIcon(type),
                          color: _getTypeColor(type),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              catatan,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Bank: $bankId',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatCurrency(nilai),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: _getTypeColor(type),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getTypeIcon(widget.type),
            size: 80,
            color: Colors.grey.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          Text(
            'Belum ada ${widget.type}',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Tap tombol + untuk tambah transaksi',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    if (type == 'hutang') return Icons.money_off;
    return type == 'pendapatan' ? Icons.trending_up : Icons.trending_down;
  }

  Color _getTypeColor(String type) {
    if (type == 'hutang') return Colors.amber;
    return type == 'pendapatan' ? Colors.green : Colors.red;
  }

  String _formatCurrency(int value) {
    return 'Rp ${value.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        )}';
  }
}

class AddTransaksiScreen extends StatefulWidget {
  final String type;

  const AddTransaksiScreen({Key? key, required this.type}) : super(key: key);

  @override
  State<AddTransaksiScreen> createState() => _AddTransaksiScreenState();
}

class _AddTransaksiScreenState extends State<AddTransaksiScreen> {
  DateTime? _selectedDate;
  String? _selectedBank;
  String? _selectedBankName;
  String? _selectedKategori;
  String? _selectedSubKategori;
  String? _selectedSubKategoriName;
  final _catatanController = TextEditingController();
  final _nilaiController = TextEditingController();
  bool _isLoading = false;
  late String _currentType;
  File? _selectedImage;

  bool _isProMember = false;
  String? _currentUserFamilyId;
  // Variabel state untuk pilihan anggota keluarga telah dihapus

  @override
  void initState() {
    super.initState();
    _currentType = widget.type;
    _checkProStatus(); // Simplified initializer
  }

  Future<void> _checkProStatus() async {
    _isProMember = await UserUtils.isCurrentUserProMember();
    final rawFamilyId = await UserUtils.getCurrentUserFamilyId();
    _currentUserFamilyId = (rawFamilyId != null && rawFamilyId.trim().isNotEmpty) ? rawFamilyId.trim() : null;
    if (mounted) {
      setState(() {});
    }
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? get user => FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    _catatanController.dispose();
    _nilaiController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeri'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final XFile? image = await picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 50,
                    maxWidth: 1024,
                    maxHeight: 1024,
                  );
                  if (image != null) {
                    setState(() => _selectedImage = File(image.path));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Kamera'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final XFile? image = await picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 50,
                    maxWidth: 1024,
                    maxHeight: 1024,
                  );
                  if (image != null) {
                    setState(() => _selectedImage = File(image.path));
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showBankSearch() {
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return SafeArea(
              child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.7,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Pilih Bank',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Cari bank...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (value) {
                        setStateSheet(() {
                          searchQuery = value.toLowerCase();
                        });
                      },
                    ),
                    const SizedBox(height: 15),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: (_isProMember && _currentUserFamilyId != null)
                            ? _firestore
                                .collection('families')
                                .doc(_currentUserFamilyId!)
                                .collection('banks')
                                .orderBy('namaBanks')
                                .snapshots()
                            : _firestore
                                .collection('users')
                                .doc(user!.uid)
                                .collection('banks')
                                .orderBy('namaBanks')
                                .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return const Center(
                                child: Text('Tidak ada data bank'));
                          }

                          final docs = snapshot.data!.docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final name = (data['namaBanks'] ?? '')
                                .toString()
                                .toLowerCase();
                            return name.contains(searchQuery);
                          }).toList();

                          if (docs.isEmpty) {
                            return const Center(
                                child: Text('Tidak ditemukan'));
                          }

                          return ListView.builder(
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final data =
                                  docs[index].data() as Map<String, dynamic>;
                              final name =
                                  data['namaBanks'] ?? 'Unknown';
                              final id = docs[index].id;

                              return ListTile(
                                title: Text(name),
                                onTap: () {
                                  setState(() {
                                    _selectedBank = id;
                                    _selectedBankName = name;
                                  });
                                  Navigator.pop(context);
                                },
                                trailing: _selectedBank == id
                                    ? const Icon(Icons.check,
                                        color: Colors.green)
                                    : null,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSubKategoriSearch() {
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return SafeArea(
              child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.7,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Pilih Sub Kategori',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Cari sub kategori...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (value) {
                        setStateSheet(() {
                          searchQuery = value.toLowerCase();
                        });
                      },
                    ),
                    const SizedBox(height: 15),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: (_isProMember && _currentUserFamilyId != null)
                            ? _firestore
                                .collection('families')
                                .doc(_currentUserFamilyId!)
                                .collection('subkategori')
                                .orderBy('namaSubKategori')
                                .snapshots()
                            : _firestore
                                .collection('users')
                                .doc(user!.uid)
                                .collection('subkategori')
                                .orderBy('namaSubKategori')
                                .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return const Center(
                                child: Text('Tidak ada data sub kategori'));
                          }

                          final docs = snapshot.data!.docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final name = (data['namaSubKategori'] ?? '')
                                .toString()
                                .toLowerCase();
                            return name.contains(searchQuery);
                          }).toList();

                          if (docs.isEmpty) {
                            return const Center(
                                child: Text('Tidak ditemukan'));
                          }

                          return ListView.builder(
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final data =
                                  docs[index].data() as Map<String, dynamic>;
                              final name =
                                  data['namaSubKategori'] ?? 'Unknown';
                              final id = docs[index].id;

                              return ListTile(
                                title: Text(name),
                                onTap: () {
                                  setState(() {
                                    _selectedSubKategori = id;
                                    _selectedSubKategoriName = name;
                                  });
                                  Navigator.pop(context);
                                },
                                trailing: _selectedSubKategori == id
                                    ? const Icon(Icons.check,
                                        color: Colors.green)
                                    : null,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Transaksi'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pilihan Jenis Transaksi (Hanya muncul di tab Pengeluaran)
              if (widget.type == 'pengeluaran') ...[
                const Text(
                  'Jenis Transaksi',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Pengeluaran'),
                        value: 'pengeluaran',
                        groupValue: _currentType,
                        onChanged: (value) => setState(() => _currentType = value!),
                        contentPadding: EdgeInsets.zero,
                        activeColor: Colors.red,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Hutang'),
                        value: 'hutang',
                        groupValue: _currentType,
                        onChanged: (value) => setState(() => _currentType = value!),
                        contentPadding: EdgeInsets.zero,
                        activeColor: Colors.amber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              // Tanggal
              const Text(
                'Pilih Tanggal',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Color.fromARGB(255, 46, 204, 113)),
                      const SizedBox(width: 12),
                      Text(
                        _selectedDate != null
                            ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                            : 'Pilih Tanggal',
                        style: TextStyle(
                          fontSize: 14,
                          color: _selectedDate != null
                              ? Colors.black
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Bank (dari database)
              const Text(
                'Pilih Bank',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _showBankSearch,
                child: InputDecorator(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.account_balance),
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 16),
                  ),
                  child: Text(
                    _selectedBankName ?? 'Pilih Bank',
                    style: TextStyle(
                      fontSize: 16,
                      color: _selectedBankName != null
                          ? Colors.black
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Pilihan Anggota Keluarga (Hanya muncul jika Pro dan ada familyId)
              // Widget ini dihapus sesuai permintaan

              // Kategori (dari database)
              if (widget.type != 'pengeluaran' && widget.type != 'pendapatan') ...[
              const Text(
                'Pilih Kategori',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream: (_isProMember && _currentUserFamilyId != null)
                    ? _firestore.collection('families').doc(_currentUserFamilyId!).collection('kategori').snapshots()
                    : _firestore.collection('users').doc(user!.uid).collection('kategori').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }

                  final kategori = snapshot.data!.docs;
                  return DropdownButtonFormField<String>(
                    value: _selectedKategori,
                    hint: const Text('Pilih Kategori'),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.category),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: kategori
                        .map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final katId = doc.id;
                          final katName = data['namaKategori'] ?? 'Unknown';
                          return DropdownMenuItem(
                            value: katId,
                            child: Text(katName),
                          );
                        })
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedKategori = value);
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
              ],

              // Sub Kategori (dari database)
              const Text(
                'Pilih Sub Kategori',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _showSubKategoriSearch,
                child: InputDecorator(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.label),
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 16),
                  ),
                  child: Text(
                    _selectedSubKategoriName ?? 'Pilih Sub Kategori',
                    style: TextStyle(
                      fontSize: 16,
                      color: _selectedSubKategoriName != null
                          ? Colors.black
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Catatan
              const Text(
                'Catatan',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _catatanController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Masukkan catatan transaksi',
                  prefixIcon: const Icon(Icons.notes),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Nilai
              const Text(
                'Nilai Transaksi',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nilaiController,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyInputFormatter()],
                decoration: InputDecoration(
                  hintText: 'Masukkan nominal',
                  prefixIcon: const Icon(Icons.money),
                  // prefixText: 'Rp ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Upload Foto Struk
              const Text(
                'Upload Foto Struk (Optional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color.fromARGB(255, 46, 204, 113).withOpacity(0.5),
                      style: BorderStyle.solid,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    image: _selectedImage != null
                        ? DecorationImage(
                            image: FileImage(_selectedImage!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _selectedImage == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: 50,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 10),
                            const Text('Tap untuk ambil/pilih foto'),
                          ],
                        )
                      : Stack(
                          children: [
                            Positioned(
                              right: 10,
                              top: 10,
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedImage = null),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 30),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitTransaksi,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: const Color.fromARGB(255, 46, 204, 113),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Simpan Transaksi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text('Batal'),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Future<void> _submitTransaksi() async {
    if (_selectedDate == null ||
        _selectedBank == null ||
        (widget.type != 'pengeluaran' && widget.type != 'pendapatan' && _selectedKategori == null) ||
        _selectedSubKategori == null ||
        _nilaiController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lengkapi semua field yang diperlukan')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = this.user;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final nilai = int.parse(_nilaiController.text.replaceAll('.', ''));

      String? fotoStrukUrl;
      if (_selectedImage != null) {
        try {
          // Simpan gambar secara lokal di folder dokumen aplikasi
          final appDir = await getApplicationDocumentsDirectory();
          final fileName = 'struk_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final savedImage = await _selectedImage!.copy('${appDir.path}/$fileName');
          fotoStrukUrl = savedImage.path;
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gagal upload foto: $e')),
            );
            setState(() => _isLoading = false);
          }
          return;
        }
      }

      // Jika tipe pengeluaran atau pendapatan, otomatis set kategori
      if (widget.type == 'pengeluaran' || widget.type == 'pendapatan') {
        String categoryName;
        if (widget.type == 'pendapatan') {
          categoryName = 'Pendapatan';
        } else {
          categoryName = _currentType == 'hutang' ? 'Hutang' : 'Pengeluaran';
        }
        
        // Cari kategori yang sesuai di database agar nyambung dengan Data Master
        final CollectionReference categoryCollection = (_isProMember && _currentUserFamilyId != null)
            ? _firestore.collection('families').doc(_currentUserFamilyId!).collection('kategori')
            : _firestore.collection('users').doc(user.uid).collection('kategori');

        final categoryQuery = await categoryCollection
            .where('namaKategori', isEqualTo: categoryName)
            .limit(1)
            .get();

        if (categoryQuery.docs.isNotEmpty) {
          _selectedKategori = categoryQuery.docs.first.id;
        } else {
          // Buat kategori baru di Data Master jika belum ada
          final newCatRef = await categoryCollection.add({
            'idKategori': 'KATEGORI${DateTime.now().millisecondsSinceEpoch}',
            'namaKategori': categoryName,
            'createdAt': FieldValue.serverTimestamp(),
          });
          _selectedKategori = newCatRef.id;
        }
      }

      CollectionReference transaksiCollection;
      String? transaksiFamilyId;

      if (_isProMember && _currentUserFamilyId != null && _currentUserFamilyId!.isNotEmpty) {
        transaksiCollection = _firestore.collection('families').doc(_currentUserFamilyId!).collection('transaksi');
        transaksiFamilyId = _currentUserFamilyId;
      } else {
        transaksiCollection = _firestore.collection('users').doc(user.uid).collection('transaksi');
      }

      await transaksiCollection.add({
        'tanggal': _selectedDate,
        'bankId': _selectedBank,
        'kategoriId': _selectedKategori,
        'subKategoriId': _selectedSubKategori,
        'catatan': _catatanController.text,
        'nilai': nilai,
        'type': _currentType,
        'fotoStruk': fotoStrukUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'userId': user.uid, // Set the correct userId, lgsg dari user yg login
        if (transaksiFamilyId != null) 'familyId': transaksiFamilyId, // Add familyId if available
      });

      // Sync data ke local storage
      await SyncService.syncAllData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaksi berhasil disimpan'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class PindahDanaScreen extends StatefulWidget {
  const PindahDanaScreen({Key? key}) : super(key: key);

  @override
  State<PindahDanaScreen> createState() => _PindahDanaScreenState();
}

class _PindahDanaScreenState extends State<PindahDanaScreen> {
  String? _bankSebelum;
  String? _bankSebelumName;
  String? _bankSesudah;
  String? _bankSesudahName;
  bool _isProMember = false;
  String? _currentUserFamilyId;
  final _nilaiController = TextEditingController();
  bool _isLoading = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? get user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _checkProStatus();
  }

  Future<void> _checkProStatus() async {
    _isProMember = await UserUtils.isCurrentUserProMember();
    final rawFamilyId = await UserUtils.getCurrentUserFamilyId();
    _currentUserFamilyId = (rawFamilyId != null && rawFamilyId.trim().isNotEmpty) ? rawFamilyId.trim() : null;
  }

  @override
  void dispose() {
    _nilaiController.dispose();
    super.dispose();
  }

  void _showBankSearch(String bankType) {
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return SafeArea(
              child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.7,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pilih Bank ${bankType == 'sebelum' ? 'Sumber' : 'Tujuan'}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Cari bank...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (value) {
                        setStateSheet(() {
                          searchQuery = value.toLowerCase();
                        });
                      },
                    ),
                    const SizedBox(height: 15),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: (_isProMember && _currentUserFamilyId != null)
                            ? _firestore
                                .collection('families')
                                .doc(_currentUserFamilyId!)
                                .collection('banks')
                                .orderBy('namaBanks')
                                .snapshots()
                            : _firestore
                                .collection('users')
                                .doc(user!.uid)
                                .collection('banks')
                            .orderBy('namaBanks')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return const Center(
                                child: Text('Tidak ada data bank'));
                          }

                          final docs = snapshot.data!.docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final name = (data['namaBanks'] ?? '')
                                .toString()
                                .toLowerCase();
                            return name.contains(searchQuery);
                          }).toList();

                          if (docs.isEmpty) {
                            return const Center(
                                child: Text('Tidak ditemukan'));
                          }

                          return ListView.builder(
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final data =
                                  docs[index].data() as Map<String, dynamic>;
                              final name =
                                  data['namaBanks'] ?? 'Unknown';
                              final id = docs[index].id;

                              return ListTile(
                                title: Text(name),
                                onTap: () {
                                  setState(() {
                                    if (bankType == 'sebelum') {
                                      _bankSebelum = id;
                                      _bankSebelumName = name;
                                    } else {
                                      _bankSesudah = id;
                                      _bankSesudahName = name;
                                    }
                                  });
                                  Navigator.pop(context);
                                },
                                trailing: (bankType == 'sebelum' ? _bankSebelum : _bankSesudah) == id
                                    ? const Icon(Icons.check,
                                        color: Colors.green)
                                    : null,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pindah Dana'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bank Sebelum (dari)
              const Text(
                'Dari Bank',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _showBankSearch('sebelum'),
                child: InputDecorator(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.account_balance),
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 16),
                  ),
                  child: Text(
                    _bankSebelumName ?? 'Pilih Bank Sumber',
                    style: TextStyle(
                      fontSize: 16,
                      color: _bankSebelumName != null
                          ? Colors.black
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Bank Sesudah (ke)
              const Text(
                'Ke Bank',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _showBankSearch('sesudah'),
                child: InputDecorator(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.account_balance),
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 16),
                  ),
                  child: Text(
                    _bankSesudahName ?? 'Pilih Bank Tujuan',
                    style: TextStyle(
                      fontSize: 16,
                      color: _bankSesudahName != null
                          ? Colors.black
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Nilai
              const Text(
                'Nilai Pindah Dana',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nilaiController,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyInputFormatter()],
                decoration: InputDecoration(
                  hintText: 'Masukkan nominal',
                  prefixIcon: const Icon(Icons.money),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitPindahDana,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: Colors.green,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Pindah Dana',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text('Batal'),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Future<void> _submitPindahDana() async {
    if (_bankSebelum == null ||
        _bankSesudah == null ||
        _nilaiController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lengkapi semua field yang diperlukan'),
        ),
      );
      return;
    }

    if (_bankSebelum == _bankSesudah) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bank sumber dan tujuan tidak boleh sama'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final nilai = int.parse(_nilaiController.text.replaceAll('.', ''));
      final now = DateTime.now();
      final user = this.user;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // --- New Logic: Create 2 Transactions ---

      // 1. Get bank names for notes
      final CollectionReference bankCollection = (_isProMember && _currentUserFamilyId != null)
          ? _firestore.collection('families').doc(_currentUserFamilyId!).collection('banks')
          : _firestore.collection('users').doc(user.uid).collection('banks');

      final bankSebelumDoc = await bankCollection.doc(_bankSebelum).get();
      final bankSesudahDoc = await bankCollection.doc(_bankSesudah).get();
      final bankSebelumName = (bankSebelumDoc.data() as Map<String, dynamic>?)?['namaBanks'] ?? 'Unknown';
      final bankSesudahName = (bankSesudahDoc.data() as Map<String, dynamic>?)?['namaBanks'] ?? 'Unknown';

      // 2. Get or create Category & Sub-category IDs
      Future<String> getKategoriId(String namaKategori) async {
        final CollectionReference col = (_isProMember && _currentUserFamilyId != null)
            ? _firestore.collection('families').doc(_currentUserFamilyId!).collection('kategori')
            : _firestore.collection('users').doc(user.uid).collection('kategori');

        final query = await col
            .where('namaKategori', isEqualTo: namaKategori)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          return query.docs.first.id;
        } else {
          final newDoc = await col.add({
            'namaKategori': namaKategori,
            'createdAt': FieldValue.serverTimestamp(),
          });
          return newDoc.id;
        }
      }
      
      Future<String> getSubKategoriId(String namaSubKategori) async {
         final CollectionReference col = (_isProMember && _currentUserFamilyId != null)
            ? _firestore.collection('families').doc(_currentUserFamilyId!).collection('subkategori')
            : _firestore.collection('users').doc(user.uid).collection('subkategori');

         final query = await col
            .where('namaSubKategori', isEqualTo: namaSubKategori)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          return query.docs.first.id;
        } else {
          final newDoc = await col.add({
            'namaSubKategori': namaSubKategori,
            'createdAt': FieldValue.serverTimestamp(),
          });
          return newDoc.id;
        }
      }

      final kategoriPengeluaranId = await getKategoriId('Pengeluaran');
      final kategoriPendapatanId = await getKategoriId('Pendapatan');
      final subKategoriId = await getSubKategoriId('Pindah Dana');

      // Tentukan koleksi tujuan (Family atau User)
      CollectionReference transaksiCollection;
      String? transaksiFamilyId;

      if (_isProMember && _currentUserFamilyId != null && _currentUserFamilyId!.isNotEmpty) {
        transaksiCollection = _firestore.collection('families').doc(_currentUserFamilyId!).collection('transaksi');
        transaksiFamilyId = _currentUserFamilyId;
      } else {
        transaksiCollection = _firestore.collection('users').doc(user.uid).collection('transaksi');
      }

      // 3. Create expense transaction from source bank
      await transaksiCollection.add({
        'type': 'pengeluaran',
        'nilai': nilai,
        'catatan': 'Pindah dana ke $bankSesudahName',
        'bankId': _bankSebelum,
        'tanggal': now,
        'kategoriId': kategoriPengeluaranId,
        'subKategoriId': subKategoriId,
        'userId': user.uid, // Penting: simpan userId agar list bisa resolve bank
        if (transaksiFamilyId != null) 'familyId': transaksiFamilyId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 4. Create income transaction to destination bank
      await transaksiCollection.add({
        'type': 'pendapatan',
        'nilai': nilai,
        'catatan': 'Pindah dana dari $bankSebelumName',
        'bankId': _bankSesudah,
        'tanggal': now,
        'kategoriId': kategoriPendapatanId,
        'subKategoriId': subKategoriId,
        'userId': user.uid,
        if (transaksiFamilyId != null) 'familyId': transaksiFamilyId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // --- End of New Logic ---

      // Sync data
      await SyncService.syncAllData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pindah dana berhasil'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saat pindah dana: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class TransaksiDetailScreen extends StatefulWidget {
  final String transaksiId;
  final DocumentReference transactionRef;
  final Map<String, dynamic> data;
  final String bankName;
  final String type;

  const TransaksiDetailScreen({
    Key? key,
    required this.transaksiId,
    required this.transactionRef,
    required this.data,
    required this.bankName,
    required this.type,
  }) : super(key: key);

  @override
  State<TransaksiDetailScreen> createState() => _TransaksiDetailScreenState();
}

class _TransaksiDetailScreenState extends State<TransaksiDetailScreen> {
  late TextEditingController _catatanController;
  late TextEditingController _nilaiController;
  bool _isEditing = false;
  bool _isLoading = false;
  late String _currentType;
  String? _selectedSubKategori;
  String? _selectedSubKategoriName;
  String? _selectedBank;
  String? _selectedBankName;

  bool _isProMember = false;
  String? _currentUserFamilyId;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? get user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _catatanController = TextEditingController(text: widget.data['catatan'] ?? '');
    
    final rawNilai = widget.data['nilai'];
    int initialNilai = 0;
    if (rawNilai is num) {
      initialNilai = rawNilai.toInt();
    } else if (rawNilai is String) {
      initialNilai = int.tryParse(rawNilai.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }

    final formattedNilai = NumberFormat('#,##0', 'id_ID').format(initialNilai);
    _nilaiController = TextEditingController(text: formattedNilai);
    
    _currentType = (widget.data['type'] ?? widget.type).toString();
    _selectedBank = widget.data['bankId'];
    _selectedBankName = widget.bankName;
    _selectedSubKategori = widget.data['subKategoriId'];
    if (_selectedSubKategori != null) {
      _fetchSubKategoriName();
    }
    _checkProStatus();
  }

  Future<void> _checkProStatus() async {
    _isProMember = await UserUtils.isCurrentUserProMember();
    final rawFamilyId = await UserUtils.getCurrentUserFamilyId();
    _currentUserFamilyId = (rawFamilyId != null && rawFamilyId.trim().isNotEmpty) ? rawFamilyId.trim() : null;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _fetchSubKategoriName() async {
    try {
      final CollectionReference col = (_isProMember && _currentUserFamilyId != null)
          ? _firestore.collection('families').doc(_currentUserFamilyId!).collection('subkategori')
          : _firestore.collection('users').doc(user!.uid).collection('subkategori');

      final doc = await col
          .doc(_selectedSubKategori)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _selectedSubKategoriName = (doc.data() as Map<String, dynamic>?)?['namaSubKategori'];
        });
      }
    } catch (e) {
      print('Error fetching sub kategori: $e');
    }
  }

  @override
  void dispose() {
    _catatanController.dispose();
    _nilaiController.dispose();
    super.dispose();
  }

  void _showBankSearch() {
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return SafeArea(
              child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.7,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Pilih Bank',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Cari bank...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (value) {
                        setStateSheet(() {
                          searchQuery = value.toLowerCase();
                        });
                      },
                    ),
                    const SizedBox(height: 15),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: (_isProMember && _currentUserFamilyId != null)
                            ? _firestore
                                .collection('families')
                                .doc(_currentUserFamilyId!)
                                .collection('banks')
                                .orderBy('namaBanks')
                                .snapshots()
                            : _firestore
                                .collection('users')
                                .doc(user!.uid)
                                .collection('banks')
                            .orderBy('namaBanks')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return const Center(
                                child: Text('Tidak ada data bank'));
                          }

                          final docs = snapshot.data!.docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final name = (data['namaBanks'] ?? '')
                                .toString()
                                .toLowerCase();
                            return name.contains(searchQuery);
                          }).toList();

                          if (docs.isEmpty) {
                            return const Center(
                                child: Text('Tidak ditemukan'));
                          }

                          return ListView.builder(
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final data =
                                  docs[index].data() as Map<String, dynamic>;
                              final name =
                                  data['namaBanks'] ?? 'Unknown';
                              final id = docs[index].id;

                              return ListTile(
                                title: Text(name),
                                onTap: () {
                                  setState(() {
                                    _selectedBank = id;
                                    _selectedBankName = name;
                                  });
                                  Navigator.pop(context);
                                },
                                trailing: _selectedBank == id
                                    ? const Icon(Icons.check,
                                        color: Colors.green)
                                    : null,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSubKategoriSearch() {
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return SafeArea(
              child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.7,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Pilih Sub Kategori',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Cari sub kategori...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (value) {
                        setStateSheet(() {
                          searchQuery = value.toLowerCase();
                        });
                      },
                    ),
                    const SizedBox(height: 15),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: (_isProMember && _currentUserFamilyId != null)
                            ? _firestore
                                .collection('families')
                                .doc(_currentUserFamilyId!)
                                .collection('subkategori')
                                .orderBy('namaSubKategori')
                                .snapshots()
                            : _firestore
                                .collection('users')
                                .doc(user!.uid)
                                .collection('subkategori')
                                .orderBy('namaSubKategori')
                                .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return const Center(
                                child: Text('Tidak ada data sub kategori'));
                          }

                          final docs = snapshot.data!.docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final name = (data['namaSubKategori'] ?? '')
                                .toString()
                                .toLowerCase();
                            return name.contains(searchQuery);
                          }).toList();

                          if (docs.isEmpty) {
                            return const Center(
                                child: Text('Tidak ditemukan'));
                          }

                          return ListView.builder(
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final data =
                                  docs[index].data() as Map<String, dynamic>;
                              final name =
                                  data['namaSubKategori'] ?? 'Unknown';
                              final id = docs[index].id;

                              return ListTile(
                                title: Text(name),
                                onTap: () {
                                  setState(() {
                                    _selectedSubKategori = id;
                                    _selectedSubKategoriName = name;
                                  });
                                  Navigator.pop(context);
                                },
                                trailing: _selectedSubKategori == id
                                    ? const Icon(Icons.check,
                                        color: Colors.green)
                                    : null,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _updateTransaksi() async {
    if (_nilaiController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nilai tidak boleh kosong')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final nilai = int.parse(_nilaiController.text.replaceAll('.', ''));

      await widget.transactionRef.update({
        'catatan': _catatanController.text,
        'nilai': nilai,
        'type': _currentType,
        'subKategoriId': _selectedSubKategori,
        'bankId': _selectedBank,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaksi berhasil diperbarui'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _isEditing = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteTransaksi() async {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Transaksi'),
        content: const Text('Apakah Anda yakin ingin menghapus transaksi ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              setState(() => _isLoading = true);

              try {
                // Hapus foto struk dari Storage jika ada
                final String? fotoStruk = widget.data['fotoStruk'];
                if (fotoStruk != null && fotoStruk.isNotEmpty) {
                  try {
                    // Cek apakah ini URL online (legacy) atau path lokal
                    if (fotoStruk.startsWith('http')) {
                      await FirebaseStorage.instance.refFromURL(fotoStruk).delete();
                    } else {
                      final file = File(fotoStruk);
                      if (await file.exists()) {
                        await file.delete();
                      }
                    }
                  } catch (e) {
                    // Abaikan error jika file tidak ditemukan (mungkin sudah terhapus)
                  }
                }

                await widget.transactionRef.delete();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Transaksi berhasil dihapus'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.pop(context);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tanggal = (widget.data['tanggal'] as dynamic)?.toDate() ?? DateTime.now();
    final nilai = widget.data['nilai'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Transaksi'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            onPressed: () {
              setState(() => _isEditing = !_isEditing);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteTransaksi,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tanggal
              const Text(
                'Tanggal',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  DateFormat('dd MMMM yyyy').format(tanggal),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 20),

              // Bank
              const Text(
                'Bank',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              if (_isEditing)
                InkWell(
                  onTap: _showBankSearch,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.account_balance),
                      suffixIcon: const Icon(Icons.arrow_drop_down),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16),
                    ),
                    child: Text(
                      _selectedBankName ?? 'Pilih Bank',
                      style: TextStyle(
                        fontSize: 16,
                        color: _selectedBankName != null
                            ? Colors.black
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _selectedBankName ?? widget.bankName,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              const SizedBox(height: 20),

              // Sub Kategori
              const Text(
                'Sub Kategori',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              if (_isEditing)
                InkWell(
                  onTap: _showSubKategoriSearch,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.label),
                      suffixIcon: const Icon(Icons.arrow_drop_down),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16),
                    ),
                    child: Text(
                      _selectedSubKategoriName ?? 'Pilih Sub Kategori',
                      style: TextStyle(
                        fontSize: 16,
                        color: _selectedSubKategoriName != null
                            ? Colors.black
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _selectedSubKategoriName ?? 'Tidak ada sub kategori',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              const SizedBox(height: 20),

              // Pilihan Jenis Transaksi saat Edit (Hanya jika di tab Pengeluaran)
              if (_isEditing && widget.type == 'pengeluaran') ...[
                const Text(
                  'Jenis Transaksi',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Pengeluaran'),
                        value: 'pengeluaran',
                        groupValue: _currentType,
                        onChanged: (value) => setState(() => _currentType = value!),
                        contentPadding: EdgeInsets.zero,
                        activeColor: Colors.red,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Hutang'),
                        value: 'hutang',
                        groupValue: _currentType,
                        onChanged: (value) => setState(() => _currentType = value!),
                        contentPadding: EdgeInsets.zero,
                        activeColor: Colors.amber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              // Catatan
              const Text(
                'Catatan',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _catatanController,
                enabled: _isEditing,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Masukkan catatan transaksi',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Nilai
              const Text(
                'Nilai',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nilaiController,
                enabled: _isEditing,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyInputFormatter()],
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Tampilkan Foto Struk jika ada
              if (widget.data['fotoStruk'] != null) ...[
                const Text(
                  'Foto Struk',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => Dialog(
                        child: widget.data['fotoStruk'].startsWith('http')
                            ? Image.network(widget.data['fotoStruk'])
                            : Image.file(File(widget.data['fotoStruk'])),
                      ),
                    );
                  },
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                      image: DecorationImage(
                        image: widget.data['fotoStruk'].startsWith('http')
                            ? NetworkImage(widget.data['fotoStruk'])
                            : FileImage(File(widget.data['fotoStruk'])) as ImageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              if (_isEditing)
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updateTransaksi,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          backgroundColor: const Color.fromARGB(255, 46, 204, 113),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Simpan Perubahan',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() => _isEditing = false);
                          _catatanController.text =
                              widget.data['catatan'] ?? '';
                          final rawNilai = widget.data['nilai'];
                          int initialNilai = 0;
                          if (rawNilai is num) {
                            initialNilai = rawNilai.toInt();
                          } else if (rawNilai is String) {
                            initialNilai = int.tryParse(rawNilai.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                          }
                          final formattedNilai = NumberFormat('#,##0', 'id_ID').format(initialNilai);
                          _nilaiController.text = formattedNilai;
                          _currentType = (widget.data['type'] ?? widget.type).toString();
                          _selectedSubKategori = widget.data['subKategoriId'];
                          _selectedBank = widget.data['bankId'];
                          _selectedBankName = widget.bankName;
                          _fetchSubKategoriName();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: const Text('Batal'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class TransactionItem extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;
  final DocumentReference transactionRef;
  final String type;
  final String inputBy;
  final DocumentReference? bankRef;

  const TransactionItem({
    Key? key,
    required this.data,
    required this.docId,
    required this.transactionRef,
    required this.type,
    required this.inputBy,
    required this.bankRef,
  }) : super(key: key);

  @override
  State<TransactionItem> createState() => _TransactionItemState();
}

class _TransactionItemState extends State<TransactionItem> {
  Future<DocumentSnapshot>? _bankFuture;

  @override
  void initState() {
    super.initState();
    if (widget.bankRef != null) {
      _bankFuture = widget.bankRef!.get();
    }
  }

  @override
  void didUpdateWidget(TransactionItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bankRef != widget.bankRef) {
      if (widget.bankRef != null) {
        _bankFuture = widget.bankRef!.get();
      } else {
        _bankFuture = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawTanggal = widget.data['tanggal'];
    final DateTime tanggal = rawTanggal is Timestamp ? rawTanggal.toDate() : (rawTanggal is DateTime ? rawTanggal : DateTime.now());
    
    final rawNilai = widget.data['nilai'];
    int nilai = 0;
    if (rawNilai is num) {
      nilai = rawNilai.toInt();
    } else if (rawNilai is String) {
      nilai = int.tryParse(rawNilai.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }

    final catatan = (widget.data['catatan'] ?? 'Tanpa catatan').toString();
    final type = (widget.data['type'] ?? widget.type).toString();

    if (_bankFuture == null) {
      return _buildCard(context, 'Unknown', catatan, tanggal, nilai, type);
    }

    return FutureBuilder<DocumentSnapshot>(
      future: _bankFuture,
      builder: (context, bankSnapshot) {
        String bankName = 'Unknown';
        if (bankSnapshot.hasData && bankSnapshot.data!.exists) {
          final bankData = bankSnapshot.data!.data() as Map<String, dynamic>;
          bankName = bankData['namaBanks'] ?? 'Unknown';
        }

        return _buildCard(context, bankName, catatan, tanggal, nilai, type);
      },
    );
  }

  Widget _buildCard(BuildContext context, String bankName, String catatan, DateTime tanggal, int nilai, String type) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TransaksiDetailScreen(
              transaksiId: widget.docId,
              transactionRef: widget.transactionRef,
              data: widget.data,
              bankName: bankName,
              type: widget.type,
            ),
          ),
        );
      },
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getTypeColor(type).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getTypeIcon(type),
                  color: _getTypeColor(type),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      catatan,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bank: $bankName',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd MMM yyyy').format(tanggal),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Oleh: ${widget.inputBy}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatCurrency(nilai),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: _getTypeColor(type),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    if (type == 'hutang') return Icons.money_off;
    return type == 'pendapatan' ? Icons.trending_up : Icons.trending_down;
  }

  Color _getTypeColor(String type) {
    if (type == 'hutang') return Colors.amber;
    return type == 'pendapatan' ? Colors.green : Colors.red;
  }

  String _formatCurrency(int value) {
    return 'Rp ${value.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        )}';
  }
}
