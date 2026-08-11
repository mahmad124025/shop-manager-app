import 'package:flutter/material.dart';
import 'database_helper.dart';

class ReportsScreen extends StatefulWidget {
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final Color screenColor = Color(0xFFC62828);

  // Today
  double _todaySale = 0;
  double _todayProfit = 0;
  double _todayExpense = 0;
  double _todayNet = 0;
  Map<String, dynamic>? _todayBest;

  // Weekly
  double _weeklySale = 0;
  double _weeklyProfit = 0;
  double _weeklyExpense = 0;
  double _weeklyNet = 0;
  Map<String, dynamic>? _weeklyBest;

  // Monthly
  double _monthlySale = 0;
  double _monthlyProfit = 0;
  double _monthlyExpense = 0;
  double _monthlyNet = 0;
  Map<String, dynamic>? _monthlyBest;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    // Today
    List<Map<String, dynamic>> todaySales = await _db.getTodaySales();
    double todaySale = 0, todayProfit = 0;
    for (var s in todaySales) {
      todaySale += (s['total'] as num).toDouble().abs();
      todayProfit += (s['profit'] as num).toDouble().abs();
    }
    double todayExpense = await _db.getTodayExpenses();

    // Weekly
    List<Map<String, dynamic>> weeklySales = await _db.getWeeklySales();
    double weeklySale = 0, weeklyProfit = 0;
    for (var s in weeklySales) {
      weeklySale += (s['total'] as num).toDouble().abs();
      weeklyProfit += (s['profit'] as num).toDouble().abs();
    }
    double weeklyExpense = await _db.getWeeklyExpenses();

    // Monthly
    List<Map<String, dynamic>> monthlySales = await _db.getMonthlySales();
    double monthlySale = 0, monthlyProfit = 0;
    for (var s in monthlySales) {
      monthlySale += (s['total'] as num).toDouble().abs();
      monthlyProfit += (s['profit'] as num).toDouble().abs();
    }
    double monthlyExpense = await _db.getMonthlyExpenses();

    // Best selling
    Map<String, dynamic>? todayBest = await _db.getBestSellingItem('today');
    Map<String, dynamic>? weeklyBest = await _db.getBestSellingItem('weekly');
    Map<String, dynamic>? monthlyBest = await _db.getBestSellingItem('monthly');

    setState(() {
      _todaySale = todaySale;
      _todayProfit = todayProfit;
      _todayExpense = todayExpense;
      _todayNet = todayProfit - todayExpense;
      _todayBest = todayBest;

      _weeklySale = weeklySale;
      _weeklyProfit = weeklyProfit;
      _weeklyExpense = weeklyExpense;
      _weeklyNet = weeklyProfit - weeklyExpense;
      _weeklyBest = weeklyBest;

      _monthlySale = monthlySale;
      _monthlyProfit = monthlyProfit;
      _monthlyExpense = monthlyExpense;
      _monthlyNet = monthlyProfit - monthlyExpense;
      _monthlyBest = monthlyBest;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFCE4EC),
      appBar: AppBar(
        backgroundColor: screenColor,
        title: Text('Reports — رپورٹ',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAll,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(children: [

          // ── TODAY ──
          _sectionHeader('Today — آج'),
          SizedBox(height: 8),
          Row(children: [
            _statCard('Total Sale', 'Rs ${_todaySale.toStringAsFixed(0)}',
                Color(0xFF1565C0)),
            SizedBox(width: 8),
            _statCard('Total Profit', 'Rs ${_todayProfit.toStringAsFixed(0)}',
                Color(0xFF2E7D32)),
          ]),
          SizedBox(height: 8),
          Row(children: [
            _statCard('Expense', 'Rs ${_todayExpense.toStringAsFixed(0)}',
                Colors.redAccent),
            SizedBox(width: 8),
            _statCard('Net Profit', 'Rs ${_todayNet.toStringAsFixed(0)}',
                _todayNet >= 0 ? Color(0xFF2E7D32) : Colors.redAccent),
          ]),
          if (_todayBest != null) ...[
            SizedBox(height: 8),
            _bestSellingCard(_todayBest!),
          ],

          SizedBox(height: 20),

          // ── WEEKLY ──
          _sectionHeader('Weekly — ہفتہ وار'),
          SizedBox(height: 8),
          Row(children: [
            _statCard('Total Sale', 'Rs ${_weeklySale.toStringAsFixed(0)}',
                Color(0xFF1565C0)),
            SizedBox(width: 8),
            _statCard('Total Profit', 'Rs ${_weeklyProfit.toStringAsFixed(0)}',
                Color(0xFF2E7D32)),
          ]),
          SizedBox(height: 8),
          Row(children: [
            _statCard('Expense', 'Rs ${_weeklyExpense.toStringAsFixed(0)}',
                Colors.redAccent),
            SizedBox(width: 8),
            _statCard('Net Profit', 'Rs ${_weeklyNet.toStringAsFixed(0)}',
                _weeklyNet >= 0 ? Color(0xFF2E7D32) : Colors.redAccent),
          ]),
          if (_weeklyBest != null) ...[
            SizedBox(height: 8),
            _bestSellingCard(_weeklyBest!),
          ],

          SizedBox(height: 20),

          // ── MONTHLY ──
          _sectionHeader('Monthly — ماہانہ'),
          SizedBox(height: 8),
          Row(children: [
            _statCard('Total Sale', 'Rs ${_monthlySale.toStringAsFixed(0)}',
                Color(0xFF1565C0)),
            SizedBox(width: 8),
            _statCard('Total Profit', 'Rs ${_monthlyProfit.toStringAsFixed(0)}',
                Color(0xFF2E7D32)),
          ]),
          SizedBox(height: 8),
          Row(children: [
            _statCard('Expense', 'Rs ${_monthlyExpense.toStringAsFixed(0)}',
                Colors.redAccent),
            SizedBox(width: 8),
            _statCard('Net Profit', 'Rs ${_monthlyNet.toStringAsFixed(0)}',
                _monthlyNet >= 0 ? Color(0xFF2E7D32) : Colors.redAccent),
          ]),
          if (_monthlyBest != null) ...[
            SizedBox(height: 8),
            _bestSellingCard(_monthlyBest!),
          ],

          SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: screenColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(title,
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15)),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: Colors.black54, fontSize: 12)),
          SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

 Widget _bestSellingCard(Map<String, dynamic> best) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Icon(Icons.star_rounded, color: Colors.purple, size: 20),
          SizedBox(width: 6),
          Text('Best Selling',
              style: TextStyle(
                  color: Colors.purple,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ]),
        Text(best['name'],
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}