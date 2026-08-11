import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'whatsapp_helper.dart';
import 'pdf_helper.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Map<String, dynamic> customer;
  const CustomerDetailScreen({Key? key, required this.customer}) : super(key: key);

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final Color screenColor = Color(0xFF6A1B9A);
  late Map<String, dynamic> _customer;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _customer = Map<String, dynamic>.from(widget.customer);
    _loadTransactions();
  }

  void _loadTransactions() {
    try {
      var txns = _customer['transactions'];
      if (txns == null) {
        _transactions = [];
      } else if (txns is List) {
        _transactions = txns.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        _transactions = [];
      }
    } catch (e) {
      _transactions = [];
    }
    setState(() {});
  }

  void _showEditCustomerDialog() {
    final nameController = TextEditingController(text: _customer['name']);
    final phoneController = TextEditingController(text: _customer['phone'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Edit Customer — ترمیم', style: TextStyle(color: screenColor)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _field(nameController, 'Customer Name — نام'),
          _field(phoneController, 'Phone Number — فون', isPhone: true),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: screenColor),
            onPressed: () async {
              Map<String, dynamic> updated = {
                ..._customer,
                'name': nameController.text,
                'phone': phoneController.text,
              };
              await _db.updateCustomer(_customer['id'], updated);
              setState(() => _customer = updated);
              Navigator.pop(context);
            },
            child: Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddTransactionDialog() {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String type = 'debit';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('${_customer['name']} — لین دین',
              style: TextStyle(color: screenColor)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setDialogState(() => type = 'debit'),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: type == 'debit' ? Colors.red.withOpacity(0.1) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: type == 'debit' ? Colors.redAccent : Colors.grey.shade300),
                    ),
                    child: Column(children: [
                      Icon(Icons.arrow_upward, color: Colors.redAccent),
                      Text('Gave Credit', style: TextStyle(fontSize: 12, color: Colors.black87)),
                      Text('اُدھار دیا', style: TextStyle(fontSize: 11, color: Colors.black45)),
                    ]),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setDialogState(() => type = 'credit'),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: type == 'credit' ? Colors.green.withOpacity(0.1) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: type == 'credit' ? Color(0xFF2E7D32) : Colors.grey.shade300),
                    ),
                    child: Column(children: [
                      Icon(Icons.arrow_downward, color: Color(0xFF2E7D32)),
                      Text('Received', style: TextStyle(fontSize: 12, color: Colors.black87)),
                      Text('وصول کیا', style: TextStyle(fontSize: 11, color: Colors.black45)),
                    ]),
                  ),
                ),
              ),
            ]),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: screenColor),
              onPressed: () async {
                if (amountController.text.isEmpty) return;
                double amount = double.parse(amountController.text);
                double currentBalance = (_customer['balance'] as num).toDouble();
                double newBalance = type == 'debit' ? currentBalance + amount : currentBalance - amount;

                List<Map<String, dynamic>> txns = List.from(_transactions);
                txns.add({
                  'id': DateTime.now().millisecondsSinceEpoch,
                  'type': type,
                  'amount': amount,
                  'note': noteController.text,
                  'date': DateTime.now().toString().substring(0, 10),
                });

                Map<String, dynamic> updated = {
                  ..._customer,
                  'balance': newBalance,
                  'transactions': txns,
                };

                await _db.updateCustomer(_customer['id'], updated);
                setState(() {
                  _customer = updated;
                  _transactions = txns;
                });
                Navigator.pop(context);
              },
              child: Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTransactionDialog(int index) {
    final txn = _transactions[index];
    final amountController = TextEditingController(text: txn['amount'].toString());
    final noteController = TextEditingController(text: txn['note'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Edit Transaction — ترمیم', style: TextStyle(color: screenColor)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: screenColor),
            onPressed: () async {
              double oldAmount = (txn['amount'] as num).toDouble();
              double newAmount = double.parse(amountController.text);
              double diff = newAmount - oldAmount;

              List<Map<String, dynamic>> txns = List.from(_transactions);
              txns[index] = {...txns[index], 'amount': newAmount, 'note': noteController.text};

              double currentBalance = (_customer['balance'] as num).toDouble();
              double newBalance = txn['type'] == 'debit'
                  ? currentBalance + diff
                  : currentBalance - diff;

              Map<String, dynamic> updated = {
                ..._customer,
                'balance': newBalance,
                'transactions': txns,
              };

              await _db.updateCustomer(_customer['id'], updated);
              setState(() {
                _customer = updated;
                _transactions = txns;
              });
              Navigator.pop(context);
            },
            child: Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTransaction(int index) async {
    final txn = _transactions[index];
    double amount = (txn['amount'] as num).toDouble();
    double currentBalance = (_customer['balance'] as num).toDouble();
    double newBalance = txn['type'] == 'debit'
        ? currentBalance - amount
        : currentBalance + amount;

    List<Map<String, dynamic>> txns = List.from(_transactions);
    txns.removeAt(index);

    Map<String, dynamic> updated = {
      ..._customer,
      'balance': newBalance,
      'transactions': txns,
    };

    await _db.updateCustomer(_customer['id'], updated);
    setState(() {
      _customer = updated;
      _transactions = txns;
    });
  }

  Widget _field(TextEditingController c, String label, {bool isPhone = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c,
        keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
        inputFormatters: isPhone
            ? [FilteringTextInputFormatter.deny(RegExp(r'-'))]
            : null,
        style: TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey),
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: screenColor)),
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: screenColor)),
        ),
      ),
    );
  }

  // Balance field allows a leading minus (customer can have negative/advance balance)
  Widget _fieldAllowNegative(TextEditingController c, String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c,
        keyboardType: TextInputType.numberWithOptions(signed: true),
        style: TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey),
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: screenColor)),
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: screenColor)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double balance = (_customer['balance'] as num).toDouble();

    return Scaffold(
      backgroundColor: Color(0xFFF3E5F5),
      appBar: AppBar(
        backgroundColor: screenColor,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_customer['name'],
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            if (_customer['phone'] != null && _customer['phone'].toString().isNotEmpty)
              Text(_customer['phone'],
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.message, color: Colors.white),
            onPressed: () {
              double bal = (_customer['balance'] as num).toDouble();
              if (bal > 0) {
                WhatsAppHelper.sendReminder(
                  phone: _customer['phone'] ?? '',
                  name: _customer['name'],
                  balance: bal,
                  context: context,
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('No credit due!'), backgroundColor: Colors.orange),
                );
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              String shopName = prefs.getString('shop_name') ?? '';
              await PdfHelper.generateCustomerTransactionsPdf(
                context: context,
                shopName: shopName,
                customer: _customer,
                transactions: _transactions,
                balance: balance,
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.edit, color: Colors.white),
            onPressed: _showEditCustomerDialog,
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
                  : balance < 0
                      ? Color(0xFF2E7D32).withOpacity(0.5)
                      : Colors.grey.withOpacity(0.4),
            ),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_customer['name'],
                    style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                if (_customer['phone'] != null && _customer['phone'].toString().isNotEmpty)
                  Text(_customer['phone'],
                      style: TextStyle(color: Colors.black45, fontSize: 13)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('₨ ${balance.abs().toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: balance > 0 ? Colors.redAccent : balance < 0 ? Color(0xFF2E7D32) : Colors.grey,
                    )),
                Text(
                  balance > 0 ? 'Credit Due — اُدھار' : balance < 0 ? 'Advance Paid' : 'Settled ✅',
                  style: TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ]),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Transaction History',
                  style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
              Text('${_transactions.length} records',
                  style: TextStyle(color: Colors.black45, fontSize: 12)),
            ],
          ),
        ),
        SizedBox(height: 8),
        Expanded(
          child: _transactions.isEmpty
              ? Center(child: Text('No transactions yet!',
                  style: TextStyle(color: Colors.grey, fontSize: 15)))
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) {
                    final txn = _transactions[_transactions.length - 1 - index];
                    final realIndex = _transactions.length - 1 - index;
                    bool isDebit = txn['type'] == 'debit';
                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDebit
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
                              isDebit ? Icons.arrow_upward : Icons.arrow_downward,
                              color: isDebit ? Colors.redAccent : Color(0xFF2E7D32),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(
                                isDebit ? 'Credit Given — اُدھار دیا' : 'Payment Received — وصول',
                                style: TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              if (txn['note'] != null && txn['note'].toString().isNotEmpty)
                                Text(txn['note'], style: TextStyle(color: Colors.black45, fontSize: 11)),
                              Text(txn['date'] ?? '', style: TextStyle(color: Colors.black38, fontSize: 11)),
                            ]),
                          ]),
                          Row(children: [
                            Text(
                              '${isDebit ? '+' : '-'} RS ${(txn['amount'] as num).toStringAsFixed(0)}',
                              style: TextStyle(
                                color: isDebit ? Colors.redAccent : Color(0xFF2E7D32),
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 4),
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.orange, size: 18),
                              onPressed: () => _showEditTransactionDialog(realIndex),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.redAccent, size: 18),
                              onPressed: () => showDialog(
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
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _deleteTransaction(realIndex);
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: screenColor,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text('Add Transaction', style: TextStyle(color: Colors.white)),
        onPressed: _showAddTransactionDialog,
      ),
    );
  }
}