import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class MonthCycleScreen extends StatefulWidget {
  @override
  State<MonthCycleScreen> createState() => _MonthCycleScreenState();
}

class _MonthCycleScreenState extends State<MonthCycleScreen> {
  final Color screenColor = Color(0xFF546E7A); // matches Settings icon color on home screen
  final Color yearColor = Color(0xFF37474F); // darker grey shade for the Year action
  String _currentMonth = '';
  int _activeYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    DateTime now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    int activeYear = prefs.getInt('active_year') ?? now.year;
    List<int> yearList = (prefs.getStringList('year_list') ?? [])
        .map((e) => int.tryParse(e) ?? now.year)
        .toList();
    if (!yearList.contains(activeYear)) {
      yearList.add(activeYear);
      await prefs.setStringList('year_list', yearList.map((e) => e.toString()).toList());
    }
    await prefs.setInt('active_year', activeYear);

    setState(() {
      _currentMonth = _getMonthName(now.month);
      _activeYear = activeYear;
    });
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April',
      'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  Future<void> _startNewMonth() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Start New Month?',
            style: TextStyle(color: screenColor)),
        content: Text(
          'Current month data will be archived.\n'
          'Sales & expenses will reset.\n'
          'Inventory & customers remain!\n\n'
          'کیا نیا مہینہ شروع کریں؟',
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: screenColor),
            onPressed: () async {
              Navigator.pop(context);
              await _archiveMonth();
            },
            child: Text('Yes, Start New Month',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _startNewYear() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Start New Year?',
            style: TextStyle(color: yearColor)),
        content: Text(
          'Current month data will be archived under $_activeYear.\n'
          'A new Year ${_activeYear + 1} will start.\n'
          'Sales & expenses will reset.\n'
          'Inventory & customers remain!\n\n'
          'کیا نیا سال شروع کریں؟',
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: yearColor),
            onPressed: () async {
              Navigator.pop(context);
              await _archiveMonth(silent: true);
              final prefs = await SharedPreferences.getInstance();
              int newYear = _activeYear + 1;
              await prefs.setInt('active_year', newYear);

              List<int> yearList = (prefs.getStringList('year_list') ?? [])
                  .map((e) => int.tryParse(e) ?? newYear)
                  .toList();
              if (!yearList.contains(newYear)) {
                yearList.add(newYear);
                await prefs.setStringList(
                    'year_list', yearList.map((e) => e.toString()).toList());
              }

              setState(() => _activeYear = newYear);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Year $newYear started! ✅'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text('Yes, Start New Year',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<bool> _archiveMonth({bool silent = false}) async {
    final prefs = await SharedPreferences.getInstance();
    DateTime now = DateTime.now();

    List<dynamic> allSales = jsonDecode(prefs.getString('sales') ?? '[]');
    List<dynamic> expensesRaw = jsonDecode(prefs.getString('expenses') ?? '[]');

    if (allSales.isEmpty && expensesRaw.isEmpty) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nothing to archive — no sales or expenses recorded yet.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return false;
    }

    Map<String, double> itemSales = {};
    double totalSale = 0, totalProfit = 0;

    for (var sale in allSales) {
      String name = sale['item_name'];
      itemSales[name] = (itemSales[name] ?? 0) + (sale['quantity'] as num).toDouble();
      totalSale += (sale['total'] as num).toDouble().abs();
      totalProfit += (sale['profit'] as num).toDouble().abs();
    }

    String? bestItem;
    if (itemSales.isNotEmpty) {
      bestItem = itemSales.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }

    double totalExpenses = expensesRaw.fold(0.0, (sum, e) => sum + (e['amount'] as num).toDouble());

    List<dynamic> history = jsonDecode(prefs.getString('month_history') ?? '[]');
    history.add({
      'period': '${_getMonthName(now.month)} $_activeYear',
      'type': 'month',
      'total_sale': totalSale,
      'total_profit': totalProfit,
      'total_expenses': totalExpenses,
      'net_profit': totalProfit - totalExpenses,
      'best_selling': bestItem ?? 'N/A',
      'date': now.toString().substring(0, 10),
      'sales_data': allSales,
      'month': now.month,
      'year': _activeYear,
    });

    await prefs.setString('month_history', jsonEncode(history));
    await prefs.remove('sales');
    await prefs.remove('expenses');
    await prefs.setString('month_start',
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}');

    if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Month archived! New cycle started ✅'),
          backgroundColor: Colors.green,
        ),
      );
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFECEFF1),
      appBar: AppBar(
        backgroundColor: screenColor,
        title: Text('Month Cycle — ماہانہ',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: screenColor.withOpacity(0.3)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: Column(children: [
                Icon(Icons.calendar_month, color: screenColor, size: 40),
                SizedBox(height: 8),
                Text('Current Period — موجودہ مدت',
                    style: TextStyle(color: Colors.black54, fontSize: 13)),
                Text('$_currentMonth $_activeYear',
                    style: TextStyle(
                        color: Colors.black87,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
              ]),
            ),

            SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: screenColor,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(Icons.calendar_month, color: Colors.white, size: 24),
                label: Column(children: [
                  Text('Start New Month',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  Text('نیا مہینہ شروع کریں',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
                onPressed: _startNewMonth,
              ),
            ),

            SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: yearColor,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(Icons.calendar_today, color: Colors.white, size: 24),
                label: Column(children: [
                  Text('Start New Year',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  Text('نیا سال شروع کریں',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
                onPressed: _startNewYear,
              ),
            ),

            SizedBox(height: 24),

            Text(
              '⚠ This will archive current data and reset sales & expenses.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black45, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}