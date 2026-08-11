import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'pdf_helper.dart';

class AnnualReportsScreen extends StatefulWidget {
  @override
  State<AnnualReportsScreen> createState() => _AnnualReportsScreenState();
}

class _AnnualReportsScreenState extends State<AnnualReportsScreen> {
  final Color screenColor = Color(0xFFC62828); // matches Reports icon color
  Map<String, List<Map<String, dynamic>>> _yearGroups = {};

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    List<dynamic> history =
        jsonDecode(prefs.getString('month_history') ?? '[]');
    List<Map<String, dynamic>> monthHistory =
        history.map((e) => Map<String, dynamic>.from(e)).toList();

    Map<String, List<Map<String, dynamic>>> yearGroups = {};
    for (var record in monthHistory) {
      String year = record['year']?.toString() ?? 'Unknown';
      if (!yearGroups.containsKey(year)) yearGroups[year] = [];
      yearGroups[year]!.add(record);
    }

    // Ensure every year ever "started" shows up, even with zero months yet.
    List<String> yearList = (prefs.getStringList('year_list') ?? []);
    for (var y in yearList) {
      if (!yearGroups.containsKey(y)) yearGroups[y] = [];
    }

    setState(() => _yearGroups = yearGroups);
  }

  List<Map<String, dynamic>> _getItemReports(
      List<Map<String, dynamic>> yearRecords) {
    Map<String, Map<String, dynamic>> itemMap = {};
    for (var record in yearRecords) {
      List salesData = record['sales_data'] ?? [];
      for (var sale in salesData) {
        String name = sale['item_name'];
        if (!itemMap.containsKey(name)) {
          itemMap[name] = {
            'name': name,
            'unit': sale['unit'],
            'quantity': 0.0,
            'total_sale': 0.0,
            'total_profit': 0.0,
          };
        }
        itemMap[name]!['quantity'] =
            itemMap[name]!['quantity'] + (sale['quantity'] as num).toDouble();
        itemMap[name]!['total_sale'] = itemMap[name]!['total_sale'] +
            (sale['total'] as num).toDouble().abs();
        itemMap[name]!['total_profit'] = itemMap[name]!['total_profit'] +
            (sale['profit'] as num).toDouble().abs();
      }
    }
    List<Map<String, dynamic>> reports = itemMap.values.toList();
    reports.sort((a, b) =>
        (b['quantity'] as double).compareTo(a['quantity'] as double));
    return reports;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFCE4EC), // light pink tint matching Reports theme
      appBar: AppBar(
        backgroundColor: screenColor,
        title: Text('Annual Reports — سالانہ رپورٹ',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _yearGroups.isEmpty
          ? Center(
              child: Text(
                'No records yet!\nStart a new month to see reports.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
            )
          : ListView(
              padding: EdgeInsets.all(16),
              children: _yearGroups.entries.map((yearEntry) {
                String year = yearEntry.key;
                List<Map<String, dynamic>> yearRecords = yearEntry.value;

                double yearSale = yearRecords.fold(0.0,
                    (sum, r) => sum + (r['total_sale'] as num).toDouble());
                double yearProfit = yearRecords.fold(0.0,
                    (sum, r) => sum + (r['total_profit'] as num).toDouble());
                double yearExpenses = yearRecords.fold(0.0,
                    (sum, r) => sum + (r['total_expenses'] as num).toDouble());
                double yearNet = yearProfit - yearExpenses;

                List<Map<String, dynamic>> itemReports =
                    _getItemReports(yearRecords);
                String? bestItem =
                    itemReports.isNotEmpty ? itemReports.first['name'] : null;

                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => YearDetailScreen(
                        year: year,
                        yearRecords: yearRecords,
                        yearSale: yearSale,
                        yearProfit: yearProfit,
                        yearExpenses: yearExpenses,
                        yearNet: yearNet,
                        itemReports: itemReports,
                        yearBestItem: bestItem,
                      ),
                    ),
                  ),
                  child: Container(
                    margin: EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: screenColor.withOpacity(0.4)),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 4)
                      ],
                    ),
                    child: Column(children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            Icon(Icons.calendar_today,
                                color: screenColor, size: 22),
                            SizedBox(width: 8),
                            Text('Year $year',
                                style: TextStyle(
                                    color: screenColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18)),
                          ]),
                          Row(children: [
                            Text('${yearRecords.length} months',
                                style: TextStyle(
                                    color: Colors.black45, fontSize: 12)),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios,
                                color: Colors.black38, size: 14),
                          ]),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(children: [
                        _statBox('Total Sale',
                            'Rs ${yearSale.toStringAsFixed(0)}',
                            Color(0xFF1565C0)),
                        SizedBox(width: 8),
                        _statBox('Total Profit',
                            'Rs ${yearProfit.toStringAsFixed(0)}',
                            Color(0xFF2E7D32)),
                      ]),
                      SizedBox(height: 8),
                      Row(children: [
                        _statBox('Expenses',
                            'Rs ${yearExpenses.toStringAsFixed(0)}',
                            Colors.redAccent),
                        SizedBox(width: 8),
                        _statBox(
                            'Net Profit',
                            'Rs ${yearNet.toStringAsFixed(0)}',
                            yearNet >= 0
                                ? Color(0xFF2E7D32)
                                : Colors.redAccent),
                      ]),
                    ]),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: Colors.black45, fontSize: 10)),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}

// ── YEAR DETAIL ──
class YearDetailScreen extends StatelessWidget {
  final String year;
  final List<Map<String, dynamic>> yearRecords;
  final double yearSale;
  final double yearProfit;
  final double yearExpenses;
  final double yearNet;
  final List<Map<String, dynamic>> itemReports;
  final String? yearBestItem;
  final Color screenColor = Color(0xFFC62828);

  YearDetailScreen({
    Key? key,
    required this.year,
    required this.yearRecords,
    required this.yearSale,
    required this.yearProfit,
    required this.yearExpenses,
    required this.yearNet,
    required this.itemReports,
    this.yearBestItem,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFCE4EC),
      appBar: AppBar(
        backgroundColor: screenColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Year $year — Months',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              String shopName =
                  prefs.getString('shop_name') ?? 'Shop Manager';
              await PdfHelper.generateAnnualReportPdf(
                context: context,
                shopName: shopName,
                year: year,
                monthRecords: yearRecords,
                yearSale: yearSale,
                yearProfit: yearProfit,
                yearExpenses: yearExpenses,
                yearNet: yearNet,
                itemReports: itemReports,
                bestItem: yearBestItem,
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: yearRecords.map((record) {
          double net = (record['net_profit'] as num).toDouble();
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MonthReportDetail(record: record),
              ),
            ),
            child: Container(
              margin: EdgeInsets.only(bottom: 10),
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: screenColor.withOpacity(0.3)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(record['period'],
                        style: TextStyle(
                            color: screenColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    Text(
                        'Sale: Rs ${(record['total_sale'] as num).toStringAsFixed(0)}',
                        style:
                            TextStyle(color: Colors.black54, fontSize: 12)),
                    Text(
                        'Net: Rs ${net.toStringAsFixed(0)}',
                        style: TextStyle(
                            color: net >= 0
                                ? Color(0xFF2E7D32)
                                : Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ]),
                  Icon(Icons.arrow_forward_ios,
                      color: Colors.black38, size: 14),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── MONTH REPORT DETAIL ──
class MonthReportDetail extends StatelessWidget {
  final Map<String, dynamic> record;
  final Color screenColor = Color(0xFFC62828);

  MonthReportDetail({Key? key, required this.record}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double netProfit = (record['net_profit'] as num).toDouble();

    return Scaffold(
      backgroundColor: Color(0xFFFCE4EC),
      appBar: AppBar(
        backgroundColor: screenColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(record['period'],
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: screenColor.withOpacity(0.3)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Column(children: [
              Text('Summary — خلاصہ',
                  style: TextStyle(
                      color: screenColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              _row('Total Sale',
                  'Rs ${(record['total_sale'] as num).toStringAsFixed(0)}',
                  Color(0xFF1565C0)),
              _row('Total Profit',
                  'Rs ${(record['total_profit'] as num).toStringAsFixed(0)}',
                  Color(0xFF2E7D32)),
              _row('Total Expenses',
                  'Rs ${(record['total_expenses'] as num).toStringAsFixed(0)}',
                  Colors.redAccent),
              Divider(color: Colors.black12),
              _row('Net Profit', '₨ ${netProfit.toStringAsFixed(0)}',
                  netProfit >= 0 ? Color(0xFF2E7D32) : Colors.redAccent),
              if (record['best_selling'] != null) ...[
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.purpleAccent.withOpacity(0.4)),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('⭐ Best Selling',
                          style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
                      Text(record['best_selling'],
                          style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ]),
          ),
          SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _row(String label, String value, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
        Text(label, style: TextStyle(color: Colors.black54, fontSize: 13)),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
      ]),
    );
  }
}