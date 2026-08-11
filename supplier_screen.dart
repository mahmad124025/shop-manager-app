import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'pdf_helper.dart';

class SupplierScreen extends StatefulWidget {
  @override
  State<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends State<SupplierScreen> {
  final Color screenColor = Color(0xFF00695C);
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _filteredSuppliers = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('suppliers');
    if (data == null) {
      setState(() {
        _suppliers = [];
        _filteredSuppliers = [];
      });
      return;
    }
    List<dynamic> decoded = jsonDecode(data);
    List<Map<String, dynamic>> suppliers =
        decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    setState(() {
      _suppliers = suppliers;
      _filteredSuppliers = suppliers;
    });
  }

  Future<void> _saveSuppliers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('suppliers', jsonEncode(_suppliers));
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
      _filteredSuppliers = _suppliers
          .where((s) => s['name']
              .toString()
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();
    });
  }

  void _showAddSupplierDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Add Supplier — سپلائر',
            style: TextStyle(color: screenColor)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Supplier Name — نام',
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
              labelText: 'Phone Number — فون',
              labelStyle: TextStyle(color: Colors.grey),
              prefixIcon: Icon(Icons.phone, color: screenColor, size: 20),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: screenColor.withOpacity(0.5))),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: screenColor)),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: screenColor),
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              _suppliers.add({
                'id': DateTime.now().millisecondsSinceEpoch,
                'name': nameController.text,
                'phone': phoneController.text,
                'balance': 0.0,
                'purchases': [],
                'transactions': [],
              });
              await _saveSuppliers();
              Navigator.pop(context);
              _loadSuppliers();
            },
            child: Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditSupplierDialog(int index) {
    final supplier = _suppliers[index];
    final nameController = TextEditingController(text: supplier['name']);
    final phoneController =
        TextEditingController(text: supplier['phone'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Edit Supplier — ترمیم',
            style: TextStyle(color: screenColor)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Supplier Name — نام',
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
              labelText: 'Phone Number — فون',
              labelStyle: TextStyle(color: Colors.grey),
              prefixIcon: Icon(Icons.phone, color: screenColor, size: 20),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: screenColor.withOpacity(0.5))),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: screenColor)),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: screenColor),
            onPressed: () async {
              _suppliers[index] = {
                ..._suppliers[index],
                'name': nameController.text,
                'phone': phoneController.text,
              };
              await _saveSuppliers();
              Navigator.pop(context);
              _loadSuppliers();
            },
            child: Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteSupplier(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Delete Supplier?',
            style: TextStyle(color: Colors.redAccent)),
        content: Text('Delete ${_suppliers[index]['name']}?',
            style: TextStyle(color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              _suppliers.removeAt(index);
              await _saveSuppliers();
              Navigator.pop(context);
              _loadSuppliers();
            },
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openSupplierDetail(Map<String, dynamic> supplier) {
    int realIndex =
        _suppliers.indexWhere((s) => s['id'] == supplier['id']);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupplierDetailScreen(
          supplier: supplier,
          onUpdate: (updated) async {
            if (realIndex != -1) {
              _suppliers[realIndex] = updated;
              await _saveSuppliers();
              _loadSuppliers();
            }
          },
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {bool isNumber = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters: isNumber
            ? [FilteringTextInputFormatter.deny(RegExp(r'-'))]
            : null,
        style: TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey),
          enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: screenColor)),
          focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: screenColor)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFE0F2F1),
      appBar: AppBar(
        backgroundColor: screenColor,
        title: Text('Suppliers — سپلائر',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(50),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: _onSearch,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search suppliers...',
                hintStyle: TextStyle(color: Colors.white60),
                prefixIcon: Icon(Icons.search, color: Colors.white),
                filled: true,
                fillColor: Colors.white24,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _filteredSuppliers.isEmpty
          ? Center(
              child: Text(
                  _searchQuery.isEmpty
                      ? 'No suppliers yet!\nTap + to add'
                      : 'No suppliers found!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16)))
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _filteredSuppliers.length,
              itemBuilder: (context, index) {
                final supplier = _filteredSuppliers[index];
                double balance = (supplier['balance'] as num).toDouble();
                List purchases = supplier['purchases'] ?? [];
                double totalPurchase = purchases.fold(0.0,
                    (sum, p) => sum + (p['total_amount'] as num).toDouble());
                int realIndex = _suppliers
                    .indexWhere((s) => s['id'] == supplier['id']);
                String name = supplier['name'] ?? '';
                String phone = (supplier['phone'] ?? '').toString();

                return GestureDetector(
                  onTap: () => _openSupplierDetail(supplier),
                  child: Container(
                    margin: EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: screenColor.withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 4)
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                Text(name,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black87)),
                                Text(
                                  phone.isNotEmpty ? '👤 $name • $phone' : '👤 $name',
                                  style: TextStyle(
                                      color: screenColor,
                                      fontSize: 12),
                                ),
                              ]),
                            ),
                            Row(children: [
                              GestureDetector(
                                onTap: () =>
                                    _showEditSupplierDialog(realIndex),
                                child: Icon(Icons.edit,
                                    color: Colors.orange, size: 20),
                              ),
                              SizedBox(width: 12),
                              GestureDetector(
                                onTap: () => _deleteSupplier(realIndex),
                                child: Icon(Icons.delete,
                                    color: Colors.redAccent, size: 20),
                              ),
                            ]),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                              Text(
                                balance > 0
                                    ? 'Payment Due — ادائیگی'
                                    : balance < 0
                                        ? 'Advance Paid'
                                        : 'Settled ✅',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.black45),
                              ),
                              if (purchases.isNotEmpty)
                                Text(
                                    'Total: RS ${totalPurchase.toStringAsFixed(0)} | ${purchases.length} orders',
                                    style: TextStyle(
                                        color: screenColor,
                                        fontSize: 12)),
                            ]),
                            Text(
                              '₨ ${balance.abs().toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: balance > 0
                                    ? Colors.redAccent
                                    : balance < 0
                                        ? Color(0xFF2E7D32)
                                        : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
      floatingActionButton: FloatingActionButton(
        backgroundColor: screenColor,
        child: Icon(Icons.add, color: Colors.white),
        onPressed: _showAddSupplierDialog,
      ),
    );
  }
}

// ── SUPPLIER DETAIL ──
class SupplierDetailScreen extends StatefulWidget {
  final Map<String, dynamic> supplier;
  final Function(Map<String, dynamic>) onUpdate;

  const SupplierDetailScreen(
      {Key? key, required this.supplier, required this.onUpdate})
      : super(key: key);

  @override
  State<SupplierDetailScreen> createState() =>
      _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  final Color screenColor = Color(0xFF00695C);
  late Map<String, dynamic> _supplier;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _supplier = Map<String, dynamic>.from(widget.supplier);
  }

  void _recalculateBalance() {
    List transactions = List.from(_supplier['transactions'] ?? []);
    double balance = 0;
    for (var t in transactions) {
      if (t['type'] == 'purchase') {
        balance += (t['amount'] as num).toDouble();
      } else {
        balance -= (t['amount'] as num).toDouble();
      }
    }
    _supplier['balance'] = balance;
  }

  void _showAddPurchaseDialog() {
    final itemController = TextEditingController();
    final qtyController = TextEditingController();
    final priceController = TextEditingController();
    final unitController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Add Purchase — خریداری',
            style: TextStyle(color: screenColor)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _field(itemController, 'Item Name — آئٹم'),
            _field(unitController, 'Unit — یونٹ (kg, L, pcs)'),
            _field(qtyController, 'Quantity — مقدار', isNumber: true),
            _field(priceController, 'Price per unit ₨', isNumber: true),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: screenColor),
            onPressed: () async {
              if (itemController.text.isEmpty ||
                  qtyController.text.isEmpty ||
                  priceController.text.isEmpty) return;

              double qty = double.parse(qtyController.text);
              double price = double.parse(priceController.text);
              double total = qty * price;
              int purchaseId = DateTime.now().millisecondsSinceEpoch;

              List purchases = List.from(_supplier['purchases'] ?? []);
              purchases.add({
                'id': purchaseId,
                'item_name': itemController.text,
                'unit': unitController.text,
                'quantity': qty,
                'price_per_unit': price,
                'total_amount': total,
                'date': DateTime.now().toString().substring(0, 10),
              });

              List txns = List.from(_supplier['transactions'] ?? []);
              txns.add({
                'id': purchaseId,
                'type': 'purchase',
                'description':
                    '${itemController.text} ${qty}${unitController.text}',
                'amount': total,
                'date': DateTime.now().toString().substring(0, 10),
              });

              _supplier['purchases'] = purchases;
              _supplier['transactions'] = txns;
              _recalculateBalance();
              setState(() {});
              widget.onUpdate(_supplier);
              Navigator.pop(context);
            },
            child: Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditPurchaseDialog(int index) {
    List purchases = List.from(_supplier['purchases'] ?? []);
    final p = purchases[index];
    final itemController = TextEditingController(text: p['item_name']);
    final qtyController =
        TextEditingController(text: p['quantity'].toString());
    final priceController =
        TextEditingController(text: p['price_per_unit'].toString());
    final unitController =
        TextEditingController(text: p['unit'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Edit Purchase — ترمیم',
            style: TextStyle(color: screenColor)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _field(itemController, 'Item Name — آئٹم'),
            _field(unitController, 'Unit — یونٹ'),
            _field(qtyController, 'Quantity — مقدار', isNumber: true),
            _field(priceController, 'Price per unit ₨', isNumber: true),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: screenColor),
            onPressed: () {
              double qty = double.parse(qtyController.text);
              double price = double.parse(priceController.text);
              double newTotal = qty * price;

              purchases[index] = {
                ...purchases[index],
                'item_name': itemController.text,
                'unit': unitController.text,
                'quantity': qty,
                'price_per_unit': price,
                'total_amount': newTotal,
              };

              List txns = List.from(_supplier['transactions'] ?? []);
              int txnIdx =
                  txns.indexWhere((t) => t['id'] == p['id']);
              if (txnIdx != -1) {
                txns[txnIdx] = {
                  ...txns[txnIdx],
                  'description':
                      '${itemController.text} $qty${unitController.text}',
                  'amount': newTotal,
                };
              }

              _supplier['purchases'] = purchases;
              _supplier['transactions'] = txns;
              _recalculateBalance();
              setState(() {});
              widget.onUpdate(_supplier);
              Navigator.pop(context);
            },
            child: Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deletePurchase(int index) {
    List purchases = List.from(_supplier['purchases'] ?? []);
    final p = purchases[index];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Delete Purchase?',
            style: TextStyle(color: Colors.redAccent)),
        content: Text('Delete ${p['item_name']} purchase?',
            style: TextStyle(color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              purchases.removeAt(index);
              List txns = List.from(_supplier['transactions'] ?? []);
              txns.removeWhere((t) => t['id'] == p['id']);
              _supplier['purchases'] = purchases;
              _supplier['transactions'] = txns;
              _recalculateBalance();
              setState(() {});
              widget.onUpdate(_supplier);
              Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddPaymentDialog() {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Add Payment — ادائیگی',
            style: TextStyle(color: Color(0xFF2E7D32))),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _field(amountController, 'Payment Amount ₨', isNumber: true),
          _field(noteController, 'Note — نوٹ (Optional)'),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2E7D32)),
            onPressed: () {
              if (amountController.text.isEmpty) return;
              double amount = double.parse(amountController.text);
              int payId = DateTime.now().millisecondsSinceEpoch;

              List txns = List.from(_supplier['transactions'] ?? []);
              txns.add({
                'id': payId,
                'type': 'payment',
                'description': noteController.text,
                'amount': amount,
                'date': DateTime.now().toString().substring(0, 10),
              });

              _supplier['transactions'] = txns;
              _recalculateBalance();
              setState(() {});
              widget.onUpdate(_supplier);
              Navigator.pop(context);
            },
            child: Text('Pay', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteTransaction(int index) {
    List txns = List.from(_supplier['transactions'] ?? []);
    final t = txns[txns.length - 1 - index];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Delete Transaction?',
            style: TextStyle(color: Colors.redAccent)),
        content: Text('Delete this transaction?',
            style: TextStyle(color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              if (t['type'] == 'purchase') {
                List purchases =
                    List.from(_supplier['purchases'] ?? []);
                purchases.removeWhere((p) => p['id'] == t['id']);
                _supplier['purchases'] = purchases;
              }
              txns.removeWhere((tx) => tx['id'] == t['id']);
              _supplier['transactions'] = txns;
              _recalculateBalance();
              setState(() {});
              widget.onUpdate(_supplier);
              Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {bool isNumber = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c,
        keyboardType:
            isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters: isNumber
            ? [FilteringTextInputFormatter.deny(RegExp(r'-'))]
            : null,
        style: TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey),
          enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: screenColor)),
          focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: screenColor)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double balance = (_supplier['balance'] as num).toDouble();
    List purchases = _supplier['purchases'] ?? [];
    List transactions = _supplier['transactions'] ?? [];

    return Scaffold(
      backgroundColor: Color(0xFFE0F2F1),
      appBar: AppBar(
        backgroundColor: screenColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_supplier['name'],
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold)),
          if (_supplier['phone'] != null &&
              _supplier['phone'].toString().isNotEmpty)
            Text(_supplier['phone'],
                style: TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              String shopName = prefs.getString('shop_name') ?? '';
              await PdfHelper.generateSupplierTransactionsPdf(
                context: context,
                shopName: shopName,
                supplier: _supplier,
                transactions: transactions,
                balance: balance,
              );
            },
          ),
        ],
      ),
      body: Column(children: [
        Container(
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: balance > 0
                  ? Colors.redAccent.withOpacity(0.5)
                  : Color(0xFF2E7D32).withOpacity(0.5),
            ),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_supplier['name'],
                    style: TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                if (_supplier['phone'] != null &&
                    _supplier['phone'].toString().isNotEmpty)
                  Text(_supplier['phone'],
                      style:
                          TextStyle(color: Colors.black45, fontSize: 13)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('₨ ${balance.abs().toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: balance > 0
                          ? Colors.redAccent
                          : Color(0xFF2E7D32),
                    )),
                Text(
                  balance > 0
                      ? 'Payment Due'
                      : balance < 0
                          ? 'Advance'
                          : 'Settled ✅',
                  style: TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ]),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: screenColor,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                icon: Icon(Icons.add_shopping_cart,
                    color: Colors.white, size: 18),
                label: Text('Add Purchase\nخریداری',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 12)),
                onPressed: _showAddPurchaseDialog,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF2E7D32),
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                icon:
                    Icon(Icons.payment, color: Colors.white, size: 18),
                label: Text('Add Payment\nادائیگی',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 12)),
                onPressed: _showAddPaymentDialog,
              ),
            ),
          ]),
        ),
        SizedBox(height: 12),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16),
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: screenColor.withOpacity(0.3)),
          ),
          child: Row(children: [
            _tabBtn('Purchases (${purchases.length})', 0),
            _tabBtn('Transactions (${transactions.length})', 1),
          ]),
        ),
        SizedBox(height: 8),
        Expanded(
          child: _selectedTab == 0
              ? _buildPurchasesList(purchases)
              : _buildTransactionsList(transactions),
        ),
      ]),
    );
  }

  Widget _buildPurchasesList(List purchases) {
    if (purchases.isEmpty) {
      return Center(
          child: Text('No purchases yet!',
              style: TextStyle(color: Colors.grey, fontSize: 15)));
    }
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: purchases.length,
      itemBuilder: (context, index) {
        final p = purchases[purchases.length - 1 - index];
        int realIndex = purchases.length - 1 - index;
        return Container(
          margin: EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: screenColor.withOpacity(0.2)),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 3)],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(p['item_name'],
                      style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold)),
                  Text(
                      '${(p['quantity'] as num).toStringAsFixed(1)} ${p['unit']} @ RS ${(p['price_per_unit'] as num).toStringAsFixed(0)}/${p['unit']}',
                      style:
                          TextStyle(color: Colors.black45, fontSize: 12)),
                  Text(p['date'] ?? '',
                      style:
                          TextStyle(color: Colors.black38, fontSize: 11)),
                ]),
              ),
              Column(children: [
                Text(
                    'RS ${(p['total_amount'] as num).toStringAsFixed(0)}',
                    style: TextStyle(
                        color: screenColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                Row(children: [
                  IconButton(
                    icon: Icon(Icons.edit,
                        color: Colors.orange, size: 18),
                    onPressed: () => _showEditPurchaseDialog(realIndex),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete,
                        color: Colors.redAccent, size: 18),
                    onPressed: () => _deletePurchase(realIndex),
                  ),
                ]),
              ]),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransactionsList(List transactions) {
    if (transactions.isEmpty) {
      return Center(
          child: Text('No transactions yet!',
              style: TextStyle(color: Colors.grey, fontSize: 15)));
    }
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final t = transactions[transactions.length - 1 - index];
        bool isPurchase = t['type'] == 'purchase';
        return Container(
          margin: EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isPurchase
                  ? Colors.redAccent.withOpacity(0.3)
                  : Color(0xFF2E7D32).withOpacity(0.3),
            ),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 3)],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(
                  isPurchase
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  color: isPurchase
                      ? Colors.redAccent
                      : Color(0xFF2E7D32),
                  size: 18,
                ),
                SizedBox(width: 8),
                Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(isPurchase ? 'Purchase' : 'Payment',
                      style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold)),
                  Text(t['description'] ?? '',
                      style:
                          TextStyle(color: Colors.black45, fontSize: 11)),
                  Text(t['date'] ?? '',
                      style:
                          TextStyle(color: Colors.black38, fontSize: 11)),
                ]),
              ]),
              Row(children: [
                Text(
                  '${isPurchase ? '+' : '-'} RS ${(t['amount'] as num).toStringAsFixed(0)}',
                  style: TextStyle(
                    color: isPurchase
                        ? Colors.redAccent
                        : Color(0xFF2E7D32),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete,
                      color: Colors.redAccent, size: 18),
                  onPressed: () => _deleteTransaction(index),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }

  Widget _tabBtn(String label, int index) {
    bool selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? screenColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white : Colors.black54,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              )),
        ),
      ),
    );
  }
}