import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'pdf_helper.dart';

class ExpenseScreen extends StatefulWidget {
  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final Color screenColor = Color(0xFFF57F17);

  List<Map<String, dynamic>> _expenses = [];
  double _totalExpenses = 0;
  String _selectedPeriod = 'today';
  Map<String, double> _categoryTotals = {};

  final List<Map<String, String>> _categories = [
    {'en': 'Rent', 'ur': 'کرایہ', 'icon': '🏠'},
    {'en': 'Electricity', 'ur': 'بجلی', 'icon': '⚡'},
    {'en': 'Staff Salary', 'ur': 'تنخواہ', 'icon': '👤'},
    {'en': 'Petrol', 'ur': 'پیٹرول', 'icon': '⛽'},
    {'en': 'Transport Rent', 'ur': 'گاڑی کرایہ', 'icon': '🚗'},
    {'en': 'Other', 'ur': 'دیگر', 'icon': '📦'},
  ];

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  String _getPeriodLabel() {
    if (_selectedPeriod == 'today') {
      return DateTime.now().toString().substring(0, 10);
    } else if (_selectedPeriod == 'weekly') {
      String from = DateTime.now().subtract(Duration(days: 6)).toString().substring(0, 10);
      return '$from to ${DateTime.now().toString().substring(0, 10)}';
    } else {
      String from = DateTime.now().subtract(Duration(days: 29)).toString().substring(0, 10);
      return '$from to ${DateTime.now().toString().substring(0, 10)}';
    }
  }

  Future<void> _loadExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('expenses');
    if (data == null) {
      setState(() { _expenses = []; _totalExpenses = 0; _categoryTotals = {}; });
      return;
    }

    List<dynamic> decoded = jsonDecode(data);
    List<Map<String, dynamic>> allExpenses =
        decoded.map((e) => Map<String, dynamic>.from(e)).toList();

    String today = DateTime.now().toString().substring(0, 10);
    DateTime today0 = DateTime.now();
    DateTime weekStart = DateTime(today0.year, today0.month, today0.day).subtract(Duration(days: 6));
    DateTime monthStart = DateTime(today0.year, today0.month, today0.day).subtract(Duration(days: 29));

    List<Map<String, dynamic>> filtered = allExpenses;
    if (_selectedPeriod == 'today') {
      filtered = allExpenses.where((e) => e['date'] == today).toList();
    } else if (_selectedPeriod == 'weekly') {
      filtered = allExpenses.where((e) => !DateTime.parse(e['date']).isBefore(weekStart)).toList();
    } else if (_selectedPeriod == 'monthly') {
      filtered = allExpenses.where((e) => !DateTime.parse(e['date']).isBefore(monthStart)).toList();
    }

    double total = filtered.fold(0.0, (sum, e) => sum + (e['amount'] as num).toDouble());

    Map<String, double> catTotals = {};
    for (var e in filtered) {
      String cat = e['category'] ?? 'Other';
      catTotals[cat] = (catTotals[cat] ?? 0) + (e['amount'] as num).toDouble();
    }

    setState(() {
      _expenses = filtered.reversed.toList();
      _totalExpenses = total;
      _categoryTotals = catTotals;
    });
  }

  Future<void> _saveAllExpenses(List<Map<String, dynamic>> expenses) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('expenses', jsonEncode(expenses));
  }

  Future<List<Map<String, dynamic>>> _getAllExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('expenses');
    if (data == null) return [];
    List<dynamic> decoded = jsonDecode(data);
    return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> _addExpense(Map<String, dynamic> expense) async {
    List<Map<String, dynamic>> allExpenses = await _getAllExpenses();
    expense['id'] = DateTime.now().millisecondsSinceEpoch;
    allExpenses.add(expense);
    await _saveAllExpenses(allExpenses);
    _loadExpenses();
  }

  Future<void> _deleteExpense(Map<String, dynamic> expense) async {
    List<Map<String, dynamic>> allExpenses = await _getAllExpenses();
    allExpenses.removeWhere((e) => e['id'] == expense['id']);
    await _saveAllExpenses(allExpenses);
    _loadExpenses();
  }

  void _showEditDialog(Map<String, dynamic> expense) {
    final amountController = TextEditingController(text: expense['amount'].toString());
    final noteController = TextEditingController(text: expense['note'] ?? '');
    String selectedCategory = expense['category'] ?? 'Other';
    String selectedCategoryUr = expense['category_ur'] ?? 'دیگر';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Edit Expense — ترمیم', style: TextStyle(color: screenColor)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Category — قسم', style: TextStyle(color: Colors.black54, fontSize: 12)),
              SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _categories.map((cat) {
                  bool isSelected = selectedCategory == cat['en'];
                  return GestureDetector(
                    onTap: () => setDialogState(() {
                      selectedCategory = cat['en']!;
                      selectedCategoryUr = cat['ur']!;
                    }),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? screenColor.withOpacity(0.15) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isSelected ? screenColor : Colors.grey.shade300),
                      ),
                      child: Text('${cat['icon']} ${cat['en']}',
                          style: TextStyle(
                              color: isSelected ? screenColor : Colors.black54, fontSize: 11)),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'-'))],
                style: TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Amount — رقم ₨',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: screenColor)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: screenColor)),
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: noteController,
                style: TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Note — نوٹ',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: screenColor)),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: screenColor),
              onPressed: () async {
                List<Map<String, dynamic>> allExpenses = await _getAllExpenses();
                int idx = allExpenses.indexWhere((e) => e['id'] == expense['id']);
                if (idx != -1) {
                  allExpenses[idx]['category'] = selectedCategory;
                  allExpenses[idx]['category_ur'] = selectedCategoryUr;
                  allExpenses[idx]['amount'] = double.parse(amountController.text);
                  allExpenses[idx]['note'] = noteController.text;
                }
                await _saveAllExpenses(allExpenses);
                Navigator.pop(context);
                _loadExpenses();
              },
              child: Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddExpenseDialog() {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String? selectedCategory;
    String selectedCategoryUr = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Add Expense — خرچہ', style: TextStyle(color: screenColor)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Category — قسم', style: TextStyle(color: Colors.black54, fontSize: 12)),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((cat) {
                  bool isSelected = selectedCategory == cat['en'];
                  return GestureDetector(
                    onTap: () => setDialogState(() {
                      selectedCategory = cat['en'];
                      selectedCategoryUr = cat['ur']!;
                    }),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? screenColor.withOpacity(0.15) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isSelected ? screenColor : Colors.grey.shade300),
                      ),
                      child: Text('${cat['icon']} ${cat['en']}\n${cat['ur']}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: isSelected ? screenColor : Colors.black54, fontSize: 11)),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'-'))],
                style: TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Amount — رقم ₨',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: screenColor)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: screenColor)),
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: noteController,
                style: TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Note — نوٹ (Optional)',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: screenColor)),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: screenColor),
              onPressed: () async {
                if (selectedCategory == null || amountController.text.isEmpty) return;
                await _addExpense({
                  'category': selectedCategory,
                  'category_ur': selectedCategoryUr,
                  'amount': double.parse(amountController.text),
                  'note': noteController.text,
                  'date': DateTime.now().toString().substring(0, 10),
                });
                Navigator.pop(context);
              },
              child: Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  String _getCategoryIcon(String category) {
    return _categories.firstWhere(
        (c) => c['en'] == category, orElse: () => {'icon': '📦'})['icon']!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFF8E1),
      appBar: AppBar(
        backgroundColor: screenColor,
        title: Text('Expenses — اخراجات',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              String shopName = prefs.getString('shop_name') ?? '';
              await PdfHelper.generateExpensePdf(
                context: context,
                shopName: shopName,
                period: _selectedPeriod,
                periodLabel: _getPeriodLabel(),
                expenses: _expenses,
                totalExpenses: _totalExpenses,
                categoryTotals: _categoryTotals,
              );
            },
          ),
        ],
      ),
      body: Column(children: [
        Container(
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: screenColor.withOpacity(0.3)),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: Row(children: [
            _periodBtn('Today', 'today'),
            _periodBtn('Weekly', 'weekly'),
            _periodBtn('Monthly', 'monthly'),
          ]),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Total Expenses',
                      style: TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold)),
                  Text('کل اخراجات', style: TextStyle(color: Colors.black45, fontSize: 12)),
                ]),
                Text('₨ ${_totalExpenses.toStringAsFixed(0)}',
                    style: TextStyle(color: Colors.redAccent, fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        SizedBox(height: 12),
        if (_categoryTotals.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: screenColor.withOpacity(0.3)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('By Category — قسم کے مطابق',
                    style: TextStyle(color: screenColor, fontSize: 13, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                ..._categoryTotals.entries.map((entry) {
                  String icon = _getCategoryIcon(entry.key);
                  double percent = _totalExpenses > 0 ? (entry.value / _totalExpenses * 100) : 0;
                  return Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          Text('$icon ', style: TextStyle(fontSize: 14)),
                          Text(entry.key, style: TextStyle(color: Colors.black87, fontSize: 13)),
                        ]),
                        Row(children: [
                          Text('${percent.toStringAsFixed(0)}%',
                              style: TextStyle(color: Colors.black45, fontSize: 11)),
                          SizedBox(width: 8),
                          Text('RS ${entry.value.toStringAsFixed(0)}',
                              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                        ]),
                      ],
                    ),
                  );
                }).toList(),
              ]),
            ),
          ),
        SizedBox(height: 8),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Expense History — تاریخ',
                  style: TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold)),
              Text('${_expenses.length} records',
                  style: TextStyle(color: Colors.black45, fontSize: 12)),
            ],
          ),
        ),
        SizedBox(height: 8),
        Expanded(
          child: _expenses.isEmpty
              ? Center(child: Text('No expenses!\nTap + to add',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16)))
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _expenses.length,
                  itemBuilder: (context, index) {
                    final expense = _expenses[index];
                    String icon = _getCategoryIcon(expense['category'] ?? '');
                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 3)],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('$icon ${expense['category']}',
                                  style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                              Text(expense['category_ur'] ?? '',
                                  style: TextStyle(color: Colors.black45, fontSize: 11)),
                              if (expense['note'] != null && expense['note'].toString().isNotEmpty)
                                Text(expense['note'],
                                    style: TextStyle(color: Colors.black45, fontSize: 11)),
                              Text(expense['date'] ?? '',
                                  style: TextStyle(color: Colors.black38, fontSize: 11)),
                            ]),
                          ),
                          Row(children: [
                            Text('₨ ${(expense['amount'] as num).toStringAsFixed(0)}',
                                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                            SizedBox(width: 4),
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.orange, size: 18),
                              onPressed: () => _showEditDialog(expense),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.redAccent, size: 18),
                              onPressed: () => showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: Colors.white,
                                  title: Text('Delete Expense?',
                                      style: TextStyle(color: Colors.redAccent)),
                                  content: Text('Delete this expense?',
                                      style: TextStyle(color: Colors.black87)),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text('Cancel', style: TextStyle(color: Colors.grey)),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _deleteExpense(expense);
                                      },
                                      child: Text('Delete', style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    );
                  }),
        ),
      ]),
      floatingActionButton: FloatingActionButton(
        backgroundColor: screenColor,
        child: Icon(Icons.add, color: Colors.white),
        onPressed: _showAddExpenseDialog,
      ),
    );
  }

  Widget _periodBtn(String label, String value) {
    bool selected = _selectedPeriod == value;
    return Expanded(
      child: GestureDetector(
        onTap: () { setState(() => _selectedPeriod = value); _loadExpenses(); },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? screenColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label, textAlign: TextAlign.center,
              style: TextStyle(
                  color: selected ? Colors.white : Colors.black54,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
        ),
      ),
    );
  }
}