import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'pdf_helper.dart';

class SaleHistoryScreen extends StatefulWidget {
  @override
  State<SaleHistoryScreen> createState() => _SaleHistoryScreenState();
}

class _SaleHistoryScreenState extends State<SaleHistoryScreen> {
  final Color screenColor = Color(0xFFE65100);
  List<Map<String, dynamic>> _sales = [];
  String _selectedPeriod = 'today';

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    final prefs = await SharedPreferences.getInstance();
    List<dynamic> allSales = jsonDecode(prefs.getString('sales') ?? '[]');
    List<Map<String, dynamic>> sales =
        allSales.map((e) => Map<String, dynamic>.from(e)).toList();

    String today = DateTime.now().toString().substring(0, 10);
    DateTime today0 = DateTime.now();
    DateTime weekStart = DateTime(today0.year, today0.month, today0.day).subtract(Duration(days: 6));
    DateTime monthStart = DateTime(today0.year, today0.month, today0.day).subtract(Duration(days: 29));

    List<Map<String, dynamic>> filtered = [];
    if (_selectedPeriod == 'today') {
      filtered = sales.where((s) => s['date'] == today).toList();
    } else if (_selectedPeriod == 'weekly') {
      filtered = sales.where((s) => !DateTime.parse(s['date']).isBefore(weekStart)).toList();
    } else {
      filtered = sales.where((s) => !DateTime.parse(s['date']).isBefore(monthStart)).toList();
    }

    setState(() => _sales = filtered.reversed.toList());
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

  Future<void> _deleteSale(int index) async {
    final sale = _sales[index];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Delete Sale?', style: TextStyle(color: Colors.redAccent)),
        content: Text('Delete this sale?\nStock will be restored.',
            style: TextStyle(color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(context);
              final prefs = await SharedPreferences.getInstance();
              List<dynamic> items = jsonDecode(prefs.getString('items') ?? '[]');
              List<Map<String, dynamic>> itemsList =
                  items.map((e) => Map<String, dynamic>.from(e)).toList();
              int itemIdx = itemsList.indexWhere((i) => i['name'] == sale['item_name']);
              if (itemIdx != -1) {
                double qty = (sale['quantity'] as num).toDouble();
                itemsList[itemIdx]['stock'] =
                    (itemsList[itemIdx]['stock'] as num).toDouble() + qty;
                List<dynamic> batches = List.from(itemsList[itemIdx]['batches'] ?? []);
                if (batches.isNotEmpty) {
                  batches.last['quantity'] =
                      (batches.last['quantity'] as num).toDouble() + qty;
                  itemsList[itemIdx]['batches'] = batches;
                }
                await prefs.setString('items', jsonEncode(itemsList));
              }
              List<dynamic> allSales = jsonDecode(prefs.getString('sales') ?? '[]');
              List<Map<String, dynamic>> salesList =
                  allSales.map((e) => Map<String, dynamic>.from(e)).toList();
              salesList.removeWhere((s) =>
                  s['date'] == sale['date'] &&
                  s['item_name'] == sale['item_name'] &&
                  s['quantity'].toString() == sale['quantity'].toString());
              await prefs.setString('sales', jsonEncode(salesList));
              _loadSales();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Sale deleted! Stock restored ✅'),
                    backgroundColor: Colors.orange),
              );
            },
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(int index) {
    final sale = _sales[index];
    final itemController = TextEditingController(text: sale['item_name']);
    final qtyController = TextEditingController(text: sale['quantity'].toString());
    final totalController = TextEditingController(
        text: (sale['total'] as num).toDouble().abs().toStringAsFixed(0));
    final custNameController = TextEditingController(text: sale['customer_name'] ?? '');
    final custPhoneController = TextEditingController(text: sale['customer_phone'] ?? '');
    double salePrice = (sale['total'] as num).toDouble().abs() /
        (sale['quantity'] as num).toDouble();
    double oldQty = (sale['quantity'] as num).toDouble();
    String? qtyErrorText;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Edit Sale — ترمیم', style: TextStyle(color: screenColor)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: itemController,
                style: TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Item Name — آئٹم',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: screenColor)),
                ),
              ),
              SizedBox(height: 8),
              FutureBuilder<double>(
                future: _getCurrentAvailableStock(sale['item_name'], oldQty),
                builder: (context, snapshot) {
                  double maxAllowed = snapshot.data ?? double.infinity;
                  return TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'-'))],
                    style: TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Quantity — مقدار',
                      labelStyle: TextStyle(color: Colors.grey),
                      helperText: snapshot.hasData
                          ? 'Max available: ${maxAllowed.toStringAsFixed(1)} ${sale['unit']}'
                          : 'Total updates automatically',
                      helperStyle: TextStyle(color: Colors.black38, fontSize: 10),
                      errorText: qtyErrorText,
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: screenColor)),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: screenColor)),
                    ),
                    onChanged: (val) {
                      double newQty = double.tryParse(val) ?? 0;
                      setDialogState(() {
                        if (newQty > maxAllowed) {
                          qtyErrorText = 'Exceeds available stock!';
                        } else {
                          qtyErrorText = null;
                          totalController.text = (newQty * salePrice).toStringAsFixed(0);
                        }
                      });
                    },
                  );
                },
              ),
              SizedBox(height: 8),
              TextField(
                controller: totalController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'-'))],
                style: TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Total Amount ₨',
                  labelStyle: TextStyle(color: Colors.grey),
                  helperText: 'Edit independently',
                  helperStyle: TextStyle(color: Colors.black38, fontSize: 10),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: screenColor)),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: screenColor)),
                ),
              ),
              SizedBox(height: 8),
              Text('Sale Price: RS ${salePrice.toStringAsFixed(0)}/${sale['unit']}',
                  style: TextStyle(color: Colors.black45, fontSize: 12)),
              SizedBox(height: 12),
              Text('Customer Details — گاہک', style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              TextField(
                controller: custNameController,
                style: TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Customer Name',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: screenColor)),
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: custPhoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'-'))],
                style: TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Phone Number',
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
                double newQty = double.tryParse(qtyController.text) ?? oldQty;
                double maxAllowed = await _getCurrentAvailableStock(sale['item_name'], oldQty);
                if (newQty > maxAllowed) {
                  setDialogState(() {
                    qtyErrorText = 'Exceeds available stock!';
                  });
                  return;
                }

                double newTotal = double.tryParse(totalController.text) ??
                    (sale['total'] as num).toDouble().abs();
                double qtyDiff = newQty - oldQty;
                final prefs = await SharedPreferences.getInstance();

                if (qtyDiff != 0) {
                  List<dynamic> items = jsonDecode(prefs.getString('items') ?? '[]');
                  List<Map<String, dynamic>> itemsList =
                      items.map((e) => Map<String, dynamic>.from(e)).toList();
                  int itemIdx = itemsList.indexWhere((i) => i['name'] == sale['item_name']);
                  if (itemIdx != -1) {
                    itemsList[itemIdx]['stock'] =
                        (itemsList[itemIdx]['stock'] as num).toDouble() - qtyDiff;
                    List<dynamic> batches = List.from(itemsList[itemIdx]['batches'] ?? []);
                    if (batches.isNotEmpty) {
                      batches.last['quantity'] =
                          (batches.last['quantity'] as num).toDouble() - qtyDiff;
                      itemsList[itemIdx]['batches'] = batches;
                    }
                    await prefs.setString('items', jsonEncode(itemsList));
                  }
                }

                List<dynamic> items = jsonDecode(prefs.getString('items') ?? '[]');
                List<Map<String, dynamic>> itemsList =
                    items.map((e) => Map<String, dynamic>.from(e)).toList();
                Map<String, dynamic>? item = itemsList.firstWhere(
                    (i) => i['name'] == sale['item_name'], orElse: () => {});
                double buyPrice = item.isNotEmpty ? (item['buy_price'] as num).toDouble() : 0;
                double newProfit = newTotal - (newQty * buyPrice);

                List<dynamic> allSales = jsonDecode(prefs.getString('sales') ?? '[]');
                List<Map<String, dynamic>> salesList =
                    allSales.map((e) => Map<String, dynamic>.from(e)).toList();
                for (int i = 0; i < salesList.length; i++) {
                  if (salesList[i]['date'] == sale['date'] &&
                      salesList[i]['item_name'] == sale['item_name'] &&
                      salesList[i]['quantity'].toString() == sale['quantity'].toString()) {
                    salesList[i]['item_name'] = itemController.text;
                    salesList[i]['quantity'] = newQty;
                    salesList[i]['total'] = newTotal;
                    salesList[i]['profit'] = newProfit;
                    salesList[i]['customer_name'] = custNameController.text;
                    salesList[i]['customer_phone'] = custPhoneController.text;
                    break;
                  }
                }
                await prefs.setString('sales', jsonEncode(salesList));
                Navigator.pop(context);
                _loadSales();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Sale updated! Stock adjusted ✅'),
                      backgroundColor: Colors.green),
                );
              },
              child: Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // Current stock + the quantity of THIS sale (since it will be "returned"
  // to stock before the new quantity is deducted) = max quantity allowed.
  Future<double> _getCurrentAvailableStock(String itemName, double thisSaleQty) async {
    final prefs = await SharedPreferences.getInstance();
    List<dynamic> items = jsonDecode(prefs.getString('items') ?? '[]');
    List<Map<String, dynamic>> itemsList =
        items.map((e) => Map<String, dynamic>.from(e)).toList();
    int idx = itemsList.indexWhere((i) => i['name'] == itemName);
    if (idx == -1) return 0;
    double currentStock = (itemsList[idx]['stock'] as num).toDouble();
    return currentStock + thisSaleQty;
  }

  @override
  Widget build(BuildContext context) {
    double totalSale = _sales.fold(0.0, (sum, s) => sum + (s['total'] as num).toDouble().abs());
    double totalProfit = _sales.fold(0.0, (sum, s) => sum + (s['profit'] as num).toDouble().abs());

    return Scaffold(
      backgroundColor: Color(0xFFFBE9E7),
      appBar: AppBar(
        backgroundColor: screenColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Sale History — فروخت کی تاریخ',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              String shopName = prefs.getString('shop_name') ?? 'Shop Manager';
              await PdfHelper.generateSaleHistoryPdf(
                context: context,
                shopName: shopName,
                period: _selectedPeriod,
                periodLabel: _getPeriodLabel(),
                sales: _sales,
                totalSale: totalSale,
                totalProfit: totalProfit,
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
          child: Row(children: [
            _summaryCard('Total Sale', 'RS ${totalSale.toStringAsFixed(0)}', Color(0xFF1565C0)),
            SizedBox(width: 12),
            _summaryCard('Total Profit', 'RS ${totalProfit.toStringAsFixed(0)}', Color(0xFF2E7D32)),
            SizedBox(width: 12),
            _summaryCard('Count', '${_sales.length}', screenColor),
          ]),
        ),
        SizedBox(height: 12),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Sales List', style: TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold)),
            Text('${_sales.length} records', style: TextStyle(color: Colors.black45, fontSize: 12)),
          ]),
        ),
        SizedBox(height: 8),
        Expanded(
          child: _sales.isEmpty
              ? Center(child: Text('No sales found!', style: TextStyle(color: Colors.grey, fontSize: 15)))
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _sales.length,
                  itemBuilder: (context, index) {
                    final sale = _sales[index];
                    String custName = (sale['customer_name'] ?? '').toString();
                    String custPhone = (sale['customer_phone'] ?? '').toString();
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
                              Text(sale['item_name'],
                                  style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
                              Text('${(sale['quantity'] as num).toStringAsFixed(1)} ${sale['unit']} — ${sale['date']}',
                                  style: TextStyle(color: Colors.black45, fontSize: 12)),
                              if (custName.isNotEmpty)
                                Text(
                                  custPhone.isNotEmpty ? '👤 $custName • $custPhone' : '👤 $custName',
                                  style: TextStyle(color: Color(0xFF6A1B9A), fontSize: 11),
                                ),
                              Text('RS ${(sale['total'] as num).toDouble().abs().toStringAsFixed(0)} | Profit: RS ${(sale['profit'] as num).toDouble().abs().toStringAsFixed(0)}',
                                  style: TextStyle(color: Color(0xFF2E7D32), fontSize: 12)),
                            ]),
                          ),
                          Row(children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.orange, size: 20),
                              onPressed: () => _showEditDialog(index),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.redAccent, size: 20),
                              onPressed: () => _deleteSale(index),
                            ),
                          ]),
                        ],
                      ),
                    );
                  }),
        ),
      ]),
    );
  }

  Widget _periodBtn(String label, String value) {
    bool selected = _selectedPeriod == value;
    return Expanded(
      child: GestureDetector(
        onTap: () { setState(() => _selectedPeriod = value); _loadSales(); },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? screenColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label, textAlign: TextAlign.center,
              style: TextStyle(color: selected ? Colors.white : Colors.black54,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
        ),
      ),
    );
  }

  Widget _summaryCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: Colors.black54, fontSize: 11)),
          SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}