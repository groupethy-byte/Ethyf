import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../utils/user_utils.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final user = FirebaseAuth.instance.currentUser;

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();
  String _filterType = 'all'; // all, pendapatan, pengeluaran, hutang
  String _selectedPeriod = 'Bulan'; // Default period

  // Chart State
  String _chartType = 'income_expense'; // income_expense, subcategory, bank
  int _touchedIndex = -1;
  late Future<Map<String, dynamic>> _statsFuture;

  bool _isProMember = false;
  String? _currentUserFamilyId;
  List<Map<String, String>> _familyMembers = [];
  String? _selectedMemberUid;

  @override
  void initState() {
    super.initState();
    _onPeriodSelected(_selectedPeriod);
    _initialize();
  }

  Future<void> _initialize() async {
    _isProMember = await UserUtils.isCurrentUserProMember();
    _currentUserFamilyId = await UserUtils.getCurrentUserFamilyId();
    if (_isProMember && _currentUserFamilyId != null) {
      _familyMembers = await UserUtils.getFamilyMembers(_currentUserFamilyId!);
    }
    if (mounted) {
      setState(() {
        _statsFuture = _calculateStatistics();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        child: Column(
          children: [
            // Filter Section
            _buildFilterSection(),
            _buildFamilyFilter(),
            // Statistics Section
            _buildStatisticsSection(),
            const SizedBox(height: 20),
          ],
        ),
    );
  }

  void _onPeriodSelected(String period) {
    if (period == 'Periode') {
      setState(() {
        _selectedPeriod = period;
      });
      _selectDateRange();
      return;
    }

    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (period) {
      case 'Hari':
        start = DateTime(now.year, now.month, now.day);
        break;
      case 'Minggu':
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        break;
      case 'Bulan':
        start = DateTime(now.year, now.month, 1);
        break;
      case 'Tahun':
        start = DateTime(now.year, 1, 1);
        break;
      default:
        // This should not happen with the current setup, but it makes the analyzer happy
        throw Exception('Invalid period: $period');
    }

    setState(() {
      _selectedPeriod = period;
      _startDate = start;
      _endDate = end;
      _statsFuture = _calculateStatistics();
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      helpText: 'Pilih Rentang Tanggal',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
        _selectedPeriod = 'Periode'; // Ensure this is set
        _statsFuture = _calculateStatistics();
      });
    }
  }

  Widget _buildPeriodFilter() {
    final periods = ['Hari', 'Minggu', 'Bulan', 'Tahun', 'Periode'];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: periods.map((period) {
          final isSelected = _selectedPeriod == period;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
              label: Text(period),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  _onPeriodSelected(period);
                }
              },
              selectedColor: const Color.fromARGB(255, 46, 204, 113),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isSelected ? const Color.fromARGB(255, 46, 204, 113) : Colors.grey.shade300),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      color: const Color.fromARGB(255, 46, 204, 113).withOpacity(0.1),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           _buildPeriodFilter(),
          const SizedBox(height: 10),
          if (_selectedPeriod == 'Periode')
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectDateRange,
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
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text('-', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: InkWell(
                    onTap: _selectDateRange,
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
              ],
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
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
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
                    child: Text(member['name'] ?? 'Anggota'),
                  );
                }).toList(),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedMemberUid = value;
                  _statsFuture = _calculateStatistics();
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filterType == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterType = value;
          _statsFuture = _calculateStatistics();
        });
      },
      selectedColor: const Color.fromARGB(255, 46, 204, 113),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
        fontSize: 12,
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.connectionState == ConnectionState.done && !snapshot.hasData) {
          return const Center(child: Text('Tidak ada data untuk rentang ini.'));
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: Text('Tidak ada data'));
        }

        final stats = snapshot.data!;
        final totalPendapatan = stats['totalPendapatan'] as int;
        final totalPengeluaran = stats['totalPengeluaran'] as int;
        final totalHutang = stats['totalHutang'] as int;
        final totalSaldoAwal = stats['totalSaldoAwal'] as int? ?? 0;
        final saldoBersih = totalPendapatan - totalPengeluaran - totalHutang;
        final totalKekayaan = totalSaldoAwal + saldoBersih;

        return Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            children: [
              // Chart Section
              _buildChartCard(stats),
              const SizedBox(height: 20),
              // Main Statistics
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Pendapatan',
                      amount: totalPendapatan,
                      color: Colors.green,
                      icon: Icons.trending_up,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Pengeluaran',
                      amount: totalPengeluaran,
                      color: Colors.red,
                      icon: Icons.trending_down,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Hutang',
                      amount: totalHutang,
                      color: Colors.orange,
                      icon: Icons.warning,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Saldo Bersih',
                      amount: saldoBersih,
                      color: saldoBersih >= 0 ? const Color.fromARGB(255, 46, 204, 113) : Colors.red,
                      icon: Icons.account_balance_wallet,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Detailed Statistics
              _buildDetailedStats(stats),
              const SizedBox(height: 20),
              // Finance Section (Data Keuangan)
              _buildFinanceSection(totalSaldoAwal, totalKekayaan),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChartCard(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Analisis',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              DropdownButton<String>(
                value: _chartType,
                items: const [
                  DropdownMenuItem(
                      value: 'income_expense',
                      child: Text('Pemasukan vs Pengeluaran', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(
                      value: 'subcategory',
                      child: Text('Per Sub Kategori', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(
                      value: 'bank',
                      child: Text('Per Bank', style: TextStyle(fontSize: 12))),
                ],
                onChanged: (v) => setState(() => _chartType = v!),
                underline: Container(),
                isDense: true,
              )
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: _getChartSections(stats),
                centerSpaceRadius: 40,
                sectionsSpace: 2,
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        _touchedIndex = -1;
                        return;
                      }
                      _touchedIndex =
                          pieTouchResponse.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildChartLegend(stats),
          _buildChartDataTable(stats),
        ],
      ),
    );
  }

  List<PieChartSectionData> _getChartSections(Map<String, dynamic> stats) {
    final List<PieChartSectionData> sections = [];
    
    if (_chartType == 'income_expense') {
      final income = (stats['totalPendapatan'] as int).toDouble();
      final expense = (stats['totalPengeluaran'] as int).toDouble();
      
      final total = income + expense;
      if (total == 0) return [PieChartSectionData(value: 1, color: Colors.grey.shade200, title: 'No data', radius: 50)];

      if (income > 0) {
        final isTouched = _touchedIndex == 0;
        sections.add(PieChartSectionData(
          color: Colors.green,
          value: income,
          title: _formatChartValue(income.toInt()),
          radius: isTouched ? 60 : 50,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ));
      }
      if (expense > 0) {
        final isTouched = _touchedIndex == (income > 0 ? 1 : 0);
        sections.add(PieChartSectionData(
          color: Colors.red,
          value: expense,
          title: _formatChartValue(expense.toInt()),
          radius: isTouched ? 60 : 50,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ));
      }
    } else {
      final Map<String, int> data = _chartType == 'subcategory' 
          ? stats['subCategoryStats'] 
          : stats['bankStats'];
      
      int i = 0;
      final total = data.values.fold(0, (sum, item) => sum + item);
      if (total == 0) return [PieChartSectionData(value: 1, color: Colors.grey.shade200, title: '', radius: 50)];

      
      data.forEach((key, value) {
        final isTouched = _touchedIndex == i;
        
        sections.add(PieChartSectionData(
          color: Colors.primaries[i % Colors.primaries.length],
          value: value.toDouble(),
          title: _formatChartValue(value),
          radius: isTouched ? 60 : 50,
          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
        ));
        i++;
      });
    }
    
    return sections.isEmpty 
        ? [PieChartSectionData(value: 1, color: Colors.grey.shade200, title: '', radius: 50)] 
        : sections;
  }

  Widget _buildChartLegend(Map<String, dynamic> stats) {
    if (_chartType == 'income_expense') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem(Colors.green, 'Pendapatan'),
          const SizedBox(width: 15),
          _buildLegendItem(Colors.red, 'Pengeluaran'),
        ],
      );
    }

    final Map<String, int> data = _chartType == 'subcategory' 
        ? stats['subCategoryStats'] 
        : stats['bankStats'];

    if (data.isEmpty) return const Text('Tidak ada data');

    return Wrap(
      spacing: 10,
      runSpacing: 5,
      alignment: WrapAlignment.center,
      children: List.generate(data.length, (index) {
        final key = data.keys.elementAt(index);
        return _buildLegendItem(
          Colors.primaries[index % Colors.primaries.length],
          key,
        );
      }),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required int amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _formatCurrency(amount),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedStats(Map<String, dynamic> stats) {
    final transactionCount = stats['transactionCount'] as int;
    final avgTransaction = stats['avgTransaction'] as int;
    final maxTransaction = stats['maxTransaction'] as int;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detail Statistik',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatRow('Total Transaksi', '$transactionCount'),
          const SizedBox(height: 8),
          _buildStatRow('Rata-rata', _formatCurrency(avgTransaction)),
          const SizedBox(height: 8),
          _buildStatRow('Transaksi Terbesar', _formatCurrency(maxTransaction)),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildFinanceSection(int totalSaldoAwal, int totalKekayaan) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Data Keuangan',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatRow('Total Saldo Awal', _formatCurrency(totalSaldoAwal)),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Kekayaan',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Text(
                _formatCurrency(totalKekayaan),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartDataTable(Map<String, dynamic> stats) {
    if (_chartType == 'income_expense') {
      return const SizedBox.shrink(); // Don't show table for this type
    }

    final Map<String, int> data = _chartType == 'subcategory' 
        ? stats['subCategoryStats'] 
        : stats['bankStats'];

    if (data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 20.0),
        child: const Center(child: Text('Tidak ada data untuk ditampilkan di tabel.', style: TextStyle(fontSize: 12, color: Colors.grey))),
      );
    }
    
    // Sort data by value in descending order
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));


    return Container(
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DataTable(
        columnSpacing: 20,
        columns: [
          DataColumn(label: Text(_chartType == 'subcategory' ? 'Sub Kategori' : 'Bank', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          DataColumn(label: Text('Nilai', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
        ],
        rows: sortedEntries.map((entry) {
          return DataRow(
            cells: [
              DataCell(Text(entry.key, style: const TextStyle(fontSize: 12))),
              DataCell(Text(_formatCurrency(entry.value), style: const TextStyle(fontSize: 12))),
            ],
          );
        }).toList(),
      ),
    );
  }

  String _formatChartValue(int value) {
    if (value >= 1000000000) {
      double result = value / 1000000000;
      return '${result.toStringAsFixed(result.truncateToDouble() == result ? 0 : 1)}M';
    } else if (value >= 1000000) {
      double result = value / 1000000;
      return '${result.toStringAsFixed(result.truncateToDouble() == result ? 0 : 1)}JT';
    } else if (value >= 1000) {
      double result = value / 1000;
      return '${result.toStringAsFixed(result.truncateToDouble() == result ? 0 : 1)}K';
    }
    return value.toString();
  }

  Future<Map<String, dynamic>> _calculateStatistics() async {
    if (user == null) {
      print("Error: User is not authenticated. Cannot fetch statistics.");
      // Return an empty map, FutureBuilder will show 'No data'.
      return {
        'totalPendapatan': 0,
        'totalPengeluaran': 0,
        'totalHutang': 0,
        'transactionCount': 0,
        'avgTransaction': 0,
        'maxTransaction': 0,
        'subCategoryStats': <String, int>{},
        'bankStats': <String, int>{},
        'totalSaldoAwal': 0,
      };
    }

    try {
      Query collectionRef;
      if (_isProMember && _currentUserFamilyId != null) {
        collectionRef = _firestore.collection('families').doc(_currentUserFamilyId!).collection('transaksi');
      } else {
        collectionRef = _firestore.collection('users').doc(user!.uid).collection('transaksi');
      }

      // Fetch Total Saldo Awal dari semua bank
      int totalSaldoAwal = 0;
      try {
        // 1. Ambil dari Bank Pribadi (Hanya jika filter Semua atau Saya)
        if (_selectedMemberUid == null || _selectedMemberUid == user!.uid) {
          final personalBanks = await _firestore.collection('users').doc(user!.uid).collection('banks').get();
          for (var doc in personalBanks.docs) {
            final data = doc.data() as Map<String, dynamic>;
            totalSaldoAwal += (data['saldoAwal'] as num?)?.toInt() ?? 0;
          }
        }

        // 2. Ambil dari Bank Keluarga (Jika Pro)
        if (_isProMember && _currentUserFamilyId != null) {
          final familyBanks = await _firestore.collection('families').doc(_currentUserFamilyId!).collection('banks').get();
          for (var doc in familyBanks.docs) {
            final data = doc.data() as Map<String, dynamic>;
            
            // Filter Bank Keluarga berdasarkan userId jika ada filter
            if (_selectedMemberUid != null && data['userId'] != null && data['userId'] != _selectedMemberUid) {
              continue;
            }
            totalSaldoAwal += (data['saldoAwal'] as num?)?.toInt() ?? 0;
          }
        }
      } catch (e) {
        print('Error fetching banks for saldo awal: $e');
      }

      final snapshot = await collectionRef
          .where('tanggal', isGreaterThanOrEqualTo: _startDate)
          .where('tanggal', isLessThanOrEqualTo: _endDate)
          .get();

      int totalPendapatan = 0;
      int totalPengeluaran = 0;
      int totalHutang = 0;
      int transactionCount = 0;
      int maxTransaction = 0;
      
      final Map<String, int> subCategoryStats = {};
      final Map<String, int> bankStats = {};
      
      // Fetch names for mapping
      Map<String, String> bankMap = {};
      Map<String, String> subKatMap = {};
      
      try {
        final banksSnapshot = await _firestore.collection('users').doc(user!.uid).collection('banks').get();
        for(var doc in banksSnapshot.docs) bankMap[doc.id] = (doc.data()['namaBanks'] ?? 'Unknown').toString();
        
        final subKatsSnapshot = await _firestore.collection('users').doc(user!.uid).collection('subkategori').get();
        for(var doc in subKatsSnapshot.docs) subKatMap[doc.id] = (doc.data()['namaSubKategori'] ?? 'Unknown').toString();

        if (_isProMember && _currentUserFamilyId != null) {
          final famBanks = await _firestore.collection('families').doc(_currentUserFamilyId!).collection('banks').get();
          for(var doc in famBanks.docs) bankMap[doc.id] = (doc.data()['namaBanks'] ?? 'Unknown').toString();
          final famSubKats = await _firestore.collection('families').doc(_currentUserFamilyId!).collection('subkategori').get();
          for(var doc in famSubKats.docs) subKatMap[doc.id] = (doc.data()['namaSubKategori'] ?? 'Unknown').toString();
        }
      } catch (_) {}

      final List<int> amounts = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Filter User (Client Side)
        if (_isProMember && _selectedMemberUid != null) {
          if (data['userId'] != _selectedMemberUid) {
            continue;
          }
        }

        final tanggal = (data['tanggal'] as dynamic)?.toDate() ?? DateTime.now();
        final type = data['type'] ?? '';
        final nilai = (data['nilai'] as num?)?.toInt() ?? 0;

        // Filter by type
        if (_filterType != 'all' && type != _filterType) {
          continue;
        }

        amounts.add(nilai);
        transactionCount++;
        maxTransaction = nilai > maxTransaction ? nilai : maxTransaction;

        if (type == 'pendapatan') {
          totalPendapatan += nilai;
        } else if (type == 'pengeluaran') {
          totalPengeluaran += nilai;
          
          // Chart Aggregation
          final subId = data['subKategoriId'] as String? ?? '';
          final subName = subId.isNotEmpty ? (subKatMap[subId] ?? 'Lainnya') : 'Tanpa Kategori';
          subCategoryStats[subName] = (subCategoryStats[subName] ?? 0) + nilai;
          
          final bId = data['bankId'] as String? ?? '';
          final bName = bId.isNotEmpty ? (bankMap[bId] ?? 'Unknown') : 'Unknown';
          bankStats[bName] = (bankStats[bName] ?? 0) + nilai;
          
        } else if (type == 'hutang') {
          totalHutang += nilai;
        }
      }

      int avgTransaction = amounts.isEmpty
          ? 0
          : (amounts.reduce((a, b) => a + b) ~/ amounts.length);

      return {
        'totalPendapatan': totalPendapatan,
        'totalPengeluaran': totalPengeluaran,
        'totalHutang': totalHutang,
        'transactionCount': transactionCount,
        'avgTransaction': avgTransaction,
        'maxTransaction': maxTransaction,
        'subCategoryStats': subCategoryStats,
        'bankStats': bankStats,
        'totalSaldoAwal': totalSaldoAwal,
      };
    } catch (e) {
      print('Error calculating statistics: $e');
      // Re-throw the error to be caught by the FutureBuilder
      throw Exception(
          'Gagal memuat statistik. Kemungkinan besar ini adalah masalah indeks Firestore. Silakan periksa konsol debug Anda untuk link pembuatan indeks.');
    }
  }

  String _formatCurrency(int value) {
    return 'Rp ${value.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        )}';
  }
}
