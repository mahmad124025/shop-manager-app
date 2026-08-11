import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'database_helper.dart';
import 'splash_screen.dart';
import 'reports_screen.dart';
import 'whatsapp_helper.dart';
import 'customer_detail_screen.dart';
import 'pin_lock_screen.dart';
import 'settings_screen.dart';
import 'pdf_helper.dart';
import 'expense_screen.dart';
import 'supplier_screen.dart';
import 'item_edit_screen.dart';
import 'month_cycle_screen.dart';
import 'sale_history_screen.dart';
import 'annual_reports_screen.dart';
import 'item_wise_report_screen.dart';
import 'calculator_overlay.dart';

void main() {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // Keep the native splash visible after Flutter's first frame renders —
  // we'll manually remove it after a delay in SplashScreen.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  runApp(ShopManagerApp());
}

class ShopManagerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shop Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF00BCD4)),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => SplashScreen(),
        '/home': (context) => MainScreen(),
        '/pin': (context) => PinLockScreen(),
      },
      builder: (context, child) {
        return CalculatorOverlay(child: child!);
      },
    );
  }
}

// ── MAIN SCREEN ──
class MainScreen extends StatefulWidget {
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  String _shopName = '';
  String _shopNameUrdu = '';

  double _todaySale = 0;
  double _todayProfit = 0;
  double _todayExpense = 0;
  double _todayNet = 0;
  double _totalCredit = 0;
  double _totalSupplierDue = 0;
  int _lowStock = 0;

  final List<Map<String, dynamic>> menuItems = [
    {'label': 'Inventory', 'urdu': 'انوینٹری', 'icon': Icons.inventory, 'color': Color(0xFF2E7D32), 'screen': InventoryScreen()},
    {'label': 'Sale', 'urdu': 'فروخت', 'icon': Icons.point_of_sale, 'color': Color(0xFFE65100), 'screen': SaleScreen()},
    {'label': 'Customers', 'urdu': 'گاہک', 'icon': Icons.people, 'color': Color(0xFF6A1B9A), 'screen': CustomerScreen()},
    {'label': 'Reports', 'urdu': 'رپورٹ', 'icon': Icons.bar_chart, 'color': Color(0xFFC62828), 'screen': ReportsScreen()},
    {'label': 'Expenses', 'urdu': 'اخراجات', 'icon': Icons.money_off, 'color': Color(0xFFF57F17), 'screen': ExpenseScreen()},
    {'label': 'Suppliers', 'urdu': 'سپلائر', 'icon': Icons.local_shipping, 'color': Color(0xFF00695C), 'screen': SupplierScreen()},
    {'label': 'Item Report', 'urdu': 'آئٹم رپورٹ', 'icon': Icons.analytics, 'color': Color(0xFF2E7D32), 'screen': ItemWiseReportScreen()},
    {'label': 'Annual', 'urdu': 'سالانہ', 'icon': Icons.calendar_month, 'color': Color(0xFFC62828), 'screen': AnnualReportsScreen()},
    {'label': 'Settings', 'urdu': 'ترتیبات', 'icon': Icons.settings, 'color': Color(0xFF546E7A), 'screen': SettingsScreen()},
  ];

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> todaySales = await _db.getTodaySales();
    double todaySale = 0, todayProfit = 0;
    for (var s in todaySales) {
      todaySale += (s['total'] as num).toDouble().abs();
      todayProfit += (s['profit'] as num).toDouble().abs();
    }
    double todayExpense = await _db.getTodayExpenses();

    List<Map<String, dynamic>> customers = await _db.getCustomers();
    double totalCredit = 0;
    for (var c in customers) {
      double bal = (c['balance'] as num).toDouble();
      if (bal > 0) totalCredit += bal;
    }

    double totalSupplierDue = 0;
    final String? supplierData = prefs.getString('suppliers');
    if (supplierData != null) {
      List<dynamic> decoded = jsonDecode(supplierData);
      for (var s in decoded) {
        double bal = (s['balance'] as num).toDouble();
        if (bal > 0) totalSupplierDue += bal;
      }
    }

    List<Map<String, dynamic>> items = await _db.getItems();
    int lowStock = items.where((i) => (i['stock'] as num).toDouble() < 10).length;

    setState(() {
      _shopName = prefs.getString('shop_name') ?? '';
      _shopNameUrdu = prefs.getString('shop_name_urdu') ?? '';
      _todaySale = todaySale;
      _todayProfit = todayProfit;
      _todayExpense = todayExpense;
      _todayNet = todayProfit - todayExpense;
      _totalCredit = totalCredit;
      _totalSupplierDue = totalSupplierDue;
      _lowStock = lowStock;
    });
  }

  String _buildTitle() {
    bool hasEn = _shopName.trim().isNotEmpty;
    bool hasUr = _shopNameUrdu.trim().isNotEmpty;
    if (hasEn && hasUr) return '$_shopName — $_shopNameUrdu';
    if (hasEn) return _shopName;
    if (hasUr) return _shopNameUrdu;
    return 'Shop Manager — دکان منیجر';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(56),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF0A1628), Color(0xFF13324A)],
            ),
            boxShadow: [BoxShadow(color: Color(0xFF00BCD4).withOpacity(0.15), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            toolbarHeight: 56,
            title: Text(_buildTitle(),
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            actions: [
              IconButton(
                icon: Icon(Icons.refresh, color: Color(0xFF00E5FF), size: 22),
                onPressed: _loadSummary,
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Column(
            children: [
              Row(children: [
                _summaryChip('Today Sale', '₨ ${_todaySale.toStringAsFixed(0)}', Color(0xFF1565C0)),
                SizedBox(width: 6),
                _summaryChip('Today Profit', '₨ ${_todayProfit.toStringAsFixed(0)}', Color(0xFF2E7D32)),
                SizedBox(width: 6),
                _summaryChip('Today Expense', '₨ ${_todayExpense.toStringAsFixed(0)}', Colors.redAccent),
                SizedBox(width: 6),
                _summaryChip('Today Net Profit', '₨ ${_todayNet.toStringAsFixed(0)}',
                    _todayNet >= 0 ? Color(0xFF2E7D32) : Colors.redAccent),
              ]),
              SizedBox(height: 6),
              Row(children: [
                _summaryChip('Credit Due', '₨ ${_totalCredit.toStringAsFixed(0)}', Color(0xFF6A1B9A)),
                SizedBox(width: 6),
                _summaryChip('Supplier Due', '₨ ${_totalSupplierDue.toStringAsFixed(0)}', Color(0xFF00695C)),
                SizedBox(width: 6),
                _summaryChip('Low Stock', '$_lowStock Items', Colors.orange),
              ]),
              SizedBox(height: 10),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildBox(context, menuItems[0]),
                          SizedBox(width: 6),
                          _buildBox(context, menuItems[1]),
                          SizedBox(width: 6),
                          _buildBox(context, menuItems[2]),
                        ],
                      ),
                    ),
                    SizedBox(height: 6),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildBox(context, menuItems[3]),
                          SizedBox(width: 6),
                          _buildBox(context, menuItems[4]),
                          SizedBox(width: 6),
                          _buildBox(context, menuItems[5]),
                        ],
                      ),
                    ),
                    SizedBox(height: 6),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildBox(context, menuItems[6]),
                          SizedBox(width: 6),
                          _buildBox(context, menuItems[7]),
                          SizedBox(width: 6),
                          _buildBox(context, menuItems[8]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center),
            SizedBox(height: 2),
            Text(value,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildBox(BuildContext context, Map<String, dynamic> item) {
    final Color color = item['color'] as Color;
    return Expanded(
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => item['screen'] as Widget),
        ).then((_) => _loadSummary()),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: color.withOpacity(0.6), width: 1),
            boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 5, offset: Offset(0, 3))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                child: Icon(item['icon'] as IconData, color: Colors.white, size: 26),
              ),
              SizedBox(height: 6),
              Text(item['label'] as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              Text(item['urdu'] as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── INVENTORY ──
class InventoryScreen extends StatefulWidget {
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final Color screenColor = Color(0xFF2E7D32);
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredItems = [];
  String _searchQuery = '';
  double _totalStockValue = 0;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final items = await _db.getItems();
    double totalValue = 0;
    for (var item in items) {
      double itemValue = 0;
      try {
        var batchesRaw = item['batches'];
        if (batchesRaw != null && batchesRaw is List && batchesRaw.isNotEmpty) {
          for (var b in batchesRaw) {
            double qty = (b['quantity'] as num).toDouble();
            double price = (b['buy_price'] as num).toDouble();
            itemValue += qty * price;
          }
        } else {
          double stock = (item['stock'] as num).toDouble();
          double buyPrice = (item['buy_price'] as num).toDouble();
          itemValue = stock * buyPrice;
        }
      } catch (e) {
        double stock = (item['stock'] as num).toDouble();
        double buyPrice = (item['buy_price'] as num).toDouble();
        itemValue = stock * buyPrice;
      }
      totalValue += itemValue;
    }
    setState(() {
      _items = items;
      _filteredItems = items;
      _totalStockValue = totalValue;
    });
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
      _filteredItems = _items
          .where((item) => item['name'].toString().toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> _scanBarcode() async {
    String? scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => BarcodeScannerScreen()),
    );
    if (scannedCode != null && scannedCode.isNotEmpty) {
      var match = _items.where((i) => i['barcode'] == scannedCode).toList();
      if (match.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Found: ${match.first['name']}'), backgroundColor: Colors.green),
        );
      } else {
        _showAddItemDialogWithBarcode(scannedCode);
      }
    }
  }

  void _showAddItemDialogWithBarcode(String barcode) {
    final nameController = TextEditingController();
    final nameUrduController = TextEditingController();
    final stockController = TextEditingController();
    final unitController = TextEditingController();
    final buyController = TextEditingController();
    final sellController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Add Item — نیا آئٹم', style: TextStyle(color: screenColor)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Barcode: $barcode', style: TextStyle(color: Colors.black54, fontSize: 12)),
            SizedBox(height: 8),
            _field(nameController, 'Item Name (English)'),
            _field(nameUrduController, 'اردو نام (Optional)'),
            _field(stockController, 'Opening Stock', isNumber: true),
            _field(unitController, 'Unit (kg, L, pcs)'),
            _field(buyController, 'Purchase Price ₨ (per unit)', isNumber: true),
            _field(sellController, 'Sale Price ₨ (per unit)', isNumber: true),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: screenColor),
            onPressed: () async {
              if (nameController.text.isEmpty || stockController.text.isEmpty || buyController.text.isEmpty || sellController.text.isEmpty) return;
              await _db.addItem({
                'name': nameController.text,
                'name_urdu': nameUrduController.text,
                'stock': double.parse(stockController.text),
                'unit': unitController.text,
                'buy_price': double.parse(buyController.text),
                'sell_price': double.parse(sellController.text),
                'barcode': barcode,
              });
              Navigator.pop(context);
              _loadItems();
            },
            child: Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog() {
    final nameController = TextEditingController();
    final nameUrduController = TextEditingController();
    final stockController = TextEditingController();
    final unitController = TextEditingController();
    final buyController = TextEditingController();
    final sellController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Add Item — نیا آئٹم', style: TextStyle(color: screenColor)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _field(nameController, 'Item Name (English)'),
            _field(nameUrduController, 'اردو نام (Optional)'),
            _field(stockController, 'Opening Stock', isNumber: true),
            _field(unitController, 'Unit (kg, L, pcs)'),
            _field(buyController, 'Purchase Price ₨ (per unit)', isNumber: true),
            _field(sellController, 'Sale Price ₨ (per unit)', isNumber: true),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: screenColor),
            onPressed: () async {
              if (nameController.text.isEmpty || stockController.text.isEmpty || buyController.text.isEmpty || sellController.text.isEmpty) return;
              await _db.addItem({
                'name': nameController.text,
                'name_urdu': nameUrduController.text,
                'stock': double.parse(stockController.text),
                'unit': unitController.text,
                'buy_price': double.parse(buyController.text),
                'sell_price': double.parse(sellController.text),
              });
              Navigator.pop(context);
              _loadItems();
            },
            child: Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRestockDialog(Map<String, dynamic> item) {
    final qtyController = TextEditingController();
    final priceController = TextEditingController();
    final sellPriceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Restock — ${item['name']}', style: TextStyle(color: screenColor)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _field(qtyController, 'New Stock Quantity', isNumber: true),
          _field(priceController, 'New Purchase Price ₨', isNumber: true),
          _field(sellPriceController, 'New Sale Price ₨', isNumber: true),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: screenColor),
            onPressed: () async {
              await _db.restockItem(item['id'], double.parse(qtyController.text), double.parse(priceController.text), double.parse(sellPriceController.text));
              Navigator.pop(context);
              _loadItems();
            },
            child: Text('Restock', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {bool isNumber = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters: isNumber ? [FilteringTextInputFormatter.deny(RegExp(r'-'))] : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey),
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: screenColor)),
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: screenColor)),
        ),
      ),
    );
  }

  Widget _buildBatchInfo(Map<String, dynamic> item) {
    try {
      var batchesRaw = item['batches'];
      if (batchesRaw == null) {
        return Text('Purchase: ₨${item['buy_price']}/${item['unit']}', style: TextStyle(color: Colors.grey, fontSize: 12));
      }
      List<dynamic> batches = [];
      if (batchesRaw is List) batches = batchesRaw;
      var activeBatches = batches.where((b) => (b['quantity'] as num).toDouble() > 0).toList();
      if (activeBatches.isEmpty || activeBatches.length == 1) {
        return Text('Purchase: ₨${item['buy_price']}/${item['unit']}', style: TextStyle(color: Colors.grey, fontSize: 12));
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📦 Stock Batches:', style: TextStyle(color: Colors.black54, fontSize: 11)),
          ...activeBatches.asMap().entries.map((entry) {
            int i = entry.key + 1;
            var b = entry.value;
            return Text(
              'Batch $i: ${(b['quantity'] as num).toStringAsFixed(1)} ${item['unit']} @ ₨${(b['buy_price'] as num).toStringAsFixed(0)}/${item['unit']}',
              style: TextStyle(color: screenColor, fontSize: 11),
            );
          }).toList(),
        ],
      );
    } catch (e) {
      return Text('Purchase: ₨${item['buy_price']}/${item['unit']}', style: TextStyle(color: Colors.grey, fontSize: 12));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFE8F5E9),
      appBar: AppBar(
        backgroundColor: screenColor,
        title: Text('Inventory — انوینٹری', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.qr_code_scanner, color: Colors.white),
            onPressed: _scanBarcode,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(50),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Search items...',
                hintStyle: TextStyle(color: Colors.white60),
                prefixIcon: Icon(Icons.search, color: Colors.white),
                filled: true,
                fillColor: Colors.white24,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
      body: Column(children: [
        Container(
          margin: EdgeInsets.fromLTRB(16, 16, 16, 8),
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: screenColor.withOpacity(0.4)),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(Icons.inventory_2, color: screenColor, size: 22),
                SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Total Stock Value', style: TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('کل اسٹاک مالیت', style: TextStyle(color: Colors.black45, fontSize: 10)),
                ]),
              ]),
              Text('₨ ${_totalStockValue.toStringAsFixed(0)}', style: TextStyle(color: screenColor, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(
          child: _filteredItems.isEmpty
              ? Center(
                  child: Text(_searchQuery.isEmpty ? 'No items yet!\nTap + to add items' : 'No items found!',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)))
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = _filteredItems[index];
                    bool lowStock = (item['stock'] as num).toDouble() < 10;
                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: lowStock ? Colors.redAccent.withOpacity(0.5) : screenColor.withOpacity(0.3)),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${item['name']}${item['name_urdu'] != '' ? ' — ${item['name_urdu']}' : ''}',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                              SizedBox(height: 4),
                              Text('Stock: ${item['stock']} ${item['unit']}', style: TextStyle(color: lowStock ? Colors.redAccent : screenColor)),
                              Text('Sale: ₨${item['sell_price']}/${item['unit']}', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              SizedBox(height: 4),
                              _buildBatchInfo(item),
                              if (lowStock) Text('⚠ Low Stock!', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
                            ]),
                          ),
                          Column(children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.orange),
                              onPressed: () async {
                                await Navigator.push(context, MaterialPageRoute(builder: (context) => ItemEditScreen(item: item)));
                                _loadItems();
                              },
                            ),
                            IconButton(icon: Icon(Icons.add_circle, color: screenColor), onPressed: () => _showRestockDialog(item)),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: Colors.white,
                                  title: Text('Delete Item?', style: TextStyle(color: Colors.redAccent)),
                                  content: Text('Delete ${item['name']}?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.grey))),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                      onPressed: () async {
                                        await _db.deleteItem(item['id']);
                                        Navigator.pop(context);
                                        _loadItems();
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
        onPressed: _showAddItemDialog,
      ),
    );
  }
}

// ── SALE ──
class SaleScreen extends StatefulWidget {
  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final Color screenColor = Color(0xFFE65100);
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _availableItems = [];
  List<Map<String, dynamic>> _todaySales = [];
  Map<String, dynamic>? _selectedItem;
  final _quantityController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();

  List<Map<String, dynamic>> _cart = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
    _loadTodaySales();
  }

  Future<void> _loadItems() async {
    final items = await _db.getItems();
    setState(() {
      _items = items;
      _availableItems = items.where((i) => (i['stock'] as num).toDouble() > 0).toList();
    });
  }

  Future<void> _loadTodaySales() async {
    final sales = await _db.getTodaySales();
    setState(() => _todaySales = sales.reversed.toList());
  }

  double _remainingStockFor(Map<String, dynamic> item) {
    double stock = (item['stock'] as num).toDouble();
    double alreadyInCart = 0;
    for (var c in _cart) {
      if (c['item']['id'] == item['id']) {
        alreadyInCart += (c['quantity'] as num).toDouble();
      }
    }
    return stock - alreadyInCart;
  }

  void _addToCart() {
    if (_selectedItem == null || _quantityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Select item and quantity first!'), backgroundColor: Colors.orange),
      );
      return;
    }
    double qty = double.tryParse(_quantityController.text) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enter a valid quantity!'), backgroundColor: Colors.orange),
      );
      return;
    }
    double remaining = _remainingStockFor(_selectedItem!);
    if (qty > remaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Not enough stock! Available: ${remaining.toStringAsFixed(1)} ${_selectedItem!['unit']}'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    double sellPrice = (_selectedItem!['sell_price'] as num).toDouble();

    setState(() {
      int existingIdx = _cart.indexWhere((c) => c['item']['id'] == _selectedItem!['id']);
      if (existingIdx != -1) {
        double newQty = (_cart[existingIdx]['quantity'] as num).toDouble() + qty;
        _cart[existingIdx]['quantity'] = newQty;
        _cart[existingIdx]['total'] = newQty * sellPrice;
      } else {
        _cart.add({
          'item': _selectedItem,
          'quantity': qty,
          'sellPrice': sellPrice,
          'total': qty * sellPrice,
        });
      }
      _selectedItem = null;
      _quantityController.clear();
    });
  }

  void _removeFromCart(int index) {
    setState(() => _cart.removeAt(index));
  }

  double get _cartGrandTotal => _cart.fold(0.0, (sum, c) => sum + (c['total'] as num).toDouble());

  Future<void> _recordCartSale() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cart is empty! Add items first.'), backgroundColor: Colors.orange),
      );
      return;
    }

    double totalProfit = 0;
    int billId = DateTime.now().millisecondsSinceEpoch;
    String custName = _customerNameController.text;
    String custPhone = _customerPhoneController.text;

    for (var cartEntry in _cart) {
      Map<String, dynamic> item = cartEntry['item'];
      double qty = (cartEntry['quantity'] as num).toDouble();
      double sellPrice = (cartEntry['sellPrice'] as num).toDouble();

      double actualCost = await _db.sellItemFIFO(item['id'], qty);
      double actualProfit = (qty * sellPrice) - actualCost;
      totalProfit += actualProfit;

      await _db.addSale({
        'item_name': item['name'],
        'quantity': qty,
        'unit': item['unit'],
        'total': qty * sellPrice,
        'profit': actualProfit,
        'date': DateTime.now().toString().substring(0, 10),
        'customer_name': custName,
        'customer_phone': custPhone,
        'bill_id': billId,
      });
    }

    setState(() {
      _cart.clear();
      _customerNameController.clear();
      _customerPhoneController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sale recorded! Total Profit: ₨${totalProfit.toStringAsFixed(0)} ✅'), backgroundColor: Colors.green),
    );
    _loadItems();
    _loadTodaySales();
  }

  Future<void> _generateCartBill() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cart is empty! Add items first.'), backgroundColor: Colors.orange),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    String shopName = prefs.getString('shop_name') ?? '';
    String shopNameUrdu = prefs.getString('shop_name_urdu') ?? '';

    List<Map<String, dynamic>> billItems = _cart.map((c) => {
      'name': c['item']['name'],
      'quantity': c['quantity'],
      'unit': c['item']['unit'],
      'price': c['sellPrice'],
      'total': c['total'],
    }).toList();

    await PdfHelper.generateMultiItemBill(
      context: context,
      shopName: shopName,
      shopNameUrdu: shopNameUrdu,
      customerName: _customerNameController.text,
      customerPhone: _customerPhoneController.text,
      cartItems: billItems,
      grandTotal: _cartGrandTotal,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFBE9E7),
      appBar: AppBar(
        backgroundColor: screenColor,
        title: Text('Sale — فروخت', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.history, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SaleHistoryScreen())).then((_) => _loadTodaySales()),
          ),
        ],
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Add Item to Cart — کارٹ میں شامل کریں', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
              SizedBox(height: 4),
              Text('Out of stock items are hidden — سٹاک ختم آئٹم نہیں دکھائے جاتے',
                  style: TextStyle(fontSize: 10, color: Colors.black45)),
              SizedBox(height: 8),
              _availableItems.isEmpty
                  ? Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Text('No items in stock! Restock from Inventory.', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                    )
                  : DropdownButtonFormField<Map<String, dynamic>>(
                      value: _selectedItem,
                      hint: Text('Choose an item', style: TextStyle(color: Colors.grey)),
                      items: _availableItems.map((item) {
                        double remaining = _remainingStockFor(item);
                        return DropdownMenuItem(
                          value: item,
                          child: Text('${item['name']} (${remaining.toStringAsFixed(1)} ${item['unit']} left)'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedItem = value);
                      },
                    ),
              SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'-'))],
                    decoration: InputDecoration(
                      labelText: 'Quantity — مقدار',
                      labelStyle: TextStyle(color: Colors.grey),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: screenColor)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: screenColor)),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: screenColor,
                    padding: EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                  ),
                  onPressed: _addToCart,
                  child: Icon(Icons.add_shopping_cart, color: Colors.white),
                ),
              ]),
            ]),
          ),

          SizedBox(height: 12),

          if (_cart.isNotEmpty)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: screenColor.withOpacity(0.3)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Cart — کارٹ (${_cart.length} items)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                  Icon(Icons.shopping_cart, color: screenColor, size: 20),
                ]),
                SizedBox(height: 8),
                ...List.generate(_cart.length, (index) {
                  final c = _cart[index];
                  return Container(
                    margin: EdgeInsets.only(bottom: 6),
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: screenColor.withOpacity(0.15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c['item']['name'], style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('${(c['quantity'] as num).toStringAsFixed(1)} ${c['item']['unit']} × ₨${(c['sellPrice'] as num).toStringAsFixed(0)}',
                                style: TextStyle(color: Colors.black45, fontSize: 11)),
                          ]),
                        ),
                        Text('₨${(c['total'] as num).toStringAsFixed(0)}',
                            style: TextStyle(color: screenColor, fontWeight: FontWeight.bold, fontSize: 13)),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.redAccent, size: 18),
                          onPressed: () => _removeFromCart(index),
                        ),
                      ],
                    ),
                  );
                }),
                Divider(),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Grand Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                  Text('₨${_cartGrandTotal.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: screenColor)),
                ]),
              ]),
            ),

          SizedBox(height: 12),

          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: screenColor.withOpacity(0.3)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Customer Details — گاہک کی تفصیل (Optional)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54)),
              SizedBox(height: 8),
              TextField(
                controller: _customerNameController,
                decoration: InputDecoration(
                  labelText: 'Customer Name',
                  labelStyle: TextStyle(color: Colors.grey),
                  prefixIcon: Icon(Icons.person, color: screenColor, size: 20),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: screenColor.withOpacity(0.5))),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: screenColor)),
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _customerPhoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'-'))],
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  labelStyle: TextStyle(color: Colors.grey),
                  prefixIcon: Icon(Icons.phone, color: screenColor, size: 20),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: screenColor.withOpacity(0.5))),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: screenColor)),
                ),
              ),
            ]),
          ),

          SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: screenColor,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _recordCartSale,
              child: Text('Record Sale — فروخت درج کریں', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: screenColor),
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(Icons.receipt, color: screenColor),
              label: Text('Generate Bill — بل بنائیں', style: TextStyle(color: screenColor, fontSize: 15)),
              onPressed: _generateCartBill,
            ),
          ),
          SizedBox(height: 16),
          if (_todaySales.isNotEmpty) ...[
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text("Today's Sales — آج کی فروخت", style: TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold)),
              Text('${_todaySales.length} records', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
            SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _todaySales.length,
              itemBuilder: (context, index) {
                final sale = _todaySales[index];
                String custName = sale['customer_name'] ?? '';
                String custPhone = sale['customer_phone'] ?? '';
                return Container(
                  margin: EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: screenColor.withOpacity(0.2)),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 3)],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(sale['item_name'], style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                          Text('${(sale['quantity'] as num).toStringAsFixed(1)} ${sale['unit']}', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          if (custName.isNotEmpty)
                            Text(
                              custPhone.isNotEmpty ? '👤 $custName • $custPhone' : '👤 $custName',
                              style: TextStyle(color: Color(0xFF6A1B9A), fontSize: 11),
                            ),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('₨ ${(sale['total'] as num).toDouble().abs().toStringAsFixed(0)}', style: TextStyle(color: screenColor, fontWeight: FontWeight.bold)),
                        Text('Profit: ₨${(sale['profit'] as num).toDouble().abs().toStringAsFixed(0)}', style: TextStyle(color: Color(0xFF2E7D32), fontSize: 12)),
                      ]),
                    ],
                  ),
                );
              },
            ),
          ],
        ]),
      ),
    );
  }
}

// ── CUSTOMERS ──
class CustomerScreen extends StatefulWidget {
  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final Color screenColor = Color(0xFF6A1B9A);
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final customers = await _db.getCustomers();
    setState(() {
      _customers = customers;
      _filteredCustomers = customers;
    });
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
      _filteredCustomers = _customers.where((c) => c['name'].toString().toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  void _showAddCustomerDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Add Customer — نیا گاہک', style: TextStyle(color: screenColor)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Customer Name',
              labelStyle: TextStyle(color: Colors.grey),
              prefixIcon: Icon(Icons.person, color: screenColor, size: 20),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: screenColor.withOpacity(0.5))),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: screenColor)),
            ),
          ),
          SizedBox(height: 8),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'-'))],
            decoration: InputDecoration(
              labelText: 'Phone Number',
              labelStyle: TextStyle(color: Colors.grey),
              prefixIcon: Icon(Icons.phone, color: screenColor, size: 20),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: screenColor.withOpacity(0.5))),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: screenColor)),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: screenColor),
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              await _db.addCustomer({'name': nameController.text, 'phone': phoneController.text, 'balance': 0.0, 'transactions': []});
              Navigator.pop(context);
              _loadCustomers();
            },
            child: Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF3E5F5),
      appBar: AppBar(
        backgroundColor: screenColor,
        title: Text('Customers — گاہک', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(50),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: _onSearch,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search customers...',
                hintStyle: TextStyle(color: Colors.white60),
                prefixIcon: Icon(Icons.search, color: Colors.white),
                filled: true,
                fillColor: Colors.white24,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
      ),
      body: _filteredCustomers.isEmpty
          ? Center(child: Text(_searchQuery.isEmpty ? 'No customers yet!\nTap + to add' : 'No customers found!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)))
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _filteredCustomers.length,
              itemBuilder: (context, index) {
                final customer = _filteredCustomers[index];
                double balance = (customer['balance'] as num).toDouble();
                String name = customer['name'] ?? '';
                String phone = (customer['phone'] ?? '').toString();
                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CustomerDetailScreen(customer: customer))).then((_) => _loadCustomers()),
                  child: Container(
                    margin: EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: screenColor.withOpacity(0.3)),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                            Text(
                              phone.isNotEmpty ? '👤 $name • $phone' : '👤 $name',
                              style: TextStyle(color: screenColor, fontSize: 12),
                            ),
                          ]),
                        ),
                        Row(children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('₨ ${balance.abs().toStringAsFixed(0)}',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: balance > 0 ? Colors.redAccent : balance < 0 ? Color(0xFF2E7D32) : Colors.grey)),
                            Text(balance > 0 ? 'Credit Due — اُدھار' : balance < 0 ? 'Advance Paid' : 'Settled ✅', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ]),
                          SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: Colors.white,
                                title: Text('Delete Customer?', style: TextStyle(color: Colors.redAccent)),
                                content: Text('Delete ${customer['name']}?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.grey))),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                    onPressed: () async {
                                      await _db.deleteCustomer(customer['id']);
                                      Navigator.pop(context);
                                      _loadCustomers();
                                    },
                                    child: Text('Delete', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            ),
                            child: Icon(Icons.delete, color: Colors.redAccent, size: 20),
                          ),
                        ]),
                      ],
                    ),
                  ),
                );
              }),
      floatingActionButton: FloatingActionButton(backgroundColor: screenColor, child: Icon(Icons.add, color: Colors.white), onPressed: _showAddCustomerDialog),
    );
  }
}

// ── BARCODE SCANNER ──
class BarcodeScannerScreen extends StatefulWidget {
  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      String? code = barcodes.first.rawValue;
      if (code != null && code.isNotEmpty) {
        _handled = true;
        Navigator.pop(context, code);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Scan Barcode — بارکوڈ اسکین کریں', style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.flash_on, color: Colors.white),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}