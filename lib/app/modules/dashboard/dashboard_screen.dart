import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

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

  // Chart State
  String _chartType = 'income_expense'; // income_expense, subcategory, bank
  int _touchedIndex = -1;
  late Future<Map<String, dynamic>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _calculateStatistics();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        child: Column(
          children: [
            // Filter Section
            _buildFilterSection(),
            // Statistics Section
            _buildStatisticsSection(),
            const SizedBox(height: 20),
          ],
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
          const Text(
            'Filter',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          // Date Range Filter
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectStartDate(),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      DateFormat('dd MMM yyyy').format(_startDate),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text('-', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectEndDate(),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      DateFormat('dd MMM yyyy').format(_endDate),
                      style: const TextStyle(fontSize: 12),
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

        if (!snapshot.hasData) {
          return const Center(child: Text('No data'));
        }

        final stats = snapshot.data!;
        final totalPendapatan = stats['totalPendapatan'] as int;
        final totalPengeluaran = stats['totalPengeluaran'] as int;
        final totalHutang = stats['totalHutang'] as int;
        final saldoBersih = totalPendapatan - totalPengeluaran - totalHutang;

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
        ],
      ),
    );
  }

  List<PieChartSectionData> _getChartSections(Map<String, dynamic> stats) {
    final List<PieChartSectionData> sections = [];
    
    if (_chartType == 'income_expense') {
      final income = (stats['totalPendapatan'] as int).toDouble();
      final expense = (stats['totalPengeluaran'] as int).toDouble();
      
      if (income > 0) {
        final isTouched = _touchedIndex == 0;
        sections.add(PieChartSectionData(
          color: Colors.green,
          value: income,
          title: '${((income / (income + expense)) * 100).toStringAsFixed(0)}%',
          radius: isTouched ? 60 : 50,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ));
      }
      if (expense > 0) {
        final isTouched = _touchedIndex == (income > 0 ? 1 : 0);
        sections.add(PieChartSectionData(
          color: Colors.red,
          value: expense,
          title: '${((expense / (income + expense)) * 100).toStringAsFixed(0)}%',
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
      
      data.forEach((key, value) {
        final isTouched = _touchedIndex == i;
        final percentage = total > 0 ? (value / total * 100) : 0;
        
        sections.add(PieChartSectionData(
          color: Colors.primaries[i % Colors.primaries.length],
          value: value.toDouble(),
          title: '${percentage.toStringAsFixed(0)}%',
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

  Future<Map<String, dynamic>> _calculateStatistics() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user?.uid)
          .collection('transaksi')
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
        final banksSnapshot = await _firestore.collection('users').doc(user?.uid).collection('banks').get();
        for(var doc in banksSnapshot.docs) bankMap[doc.id] = (doc.data()['namaBanks'] ?? 'Unknown').toString();
        
        final subKatsSnapshot = await _firestore.collection('users').doc(user?.uid).collection('subkategori').get();
        for(var doc in subKatsSnapshot.docs) subKatMap[doc.id] = (doc.data()['namaSubKategori'] ?? 'Unknown').toString();
      } catch (_) {}

      final List<int> amounts = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final tanggal = (data['tanggal'] as dynamic)?.toDate() ?? DateTime.now();
        final type = data['type'] ?? '';
        final nilai = (data['nilai'] as num?)?.toInt() ?? 0;

        // Filter by date range
        if (tanggal.isBefore(_startDate) || tanggal.isAfter(_endDate)) {
          continue;
        }

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
      };
    } catch (e) {
      print('Error calculating statistics: $e');
      return {
        'totalPendapatan': 0,
        'totalPengeluaran': 0,
        'totalHutang': 0,
        'transactionCount': 0,
        'avgTransaction': 0,
        'maxTransaction': 0,
        'subCategoryStats': <String, int>{},
        'bankStats': <String, int>{},
      };
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: _endDate,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _statsFuture = _calculateStatistics();
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
        _statsFuture = _calculateStatistics();
      });
    }
  }

  String _formatCurrency(int value) {
    return 'Rp ${value.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        )}';
  }
}
