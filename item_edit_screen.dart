import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'database_helper.dart';

class ItemEditScreen extends StatefulWidget {
  final Map<String, dynamic> item;
  const ItemEditScreen({Key? key, required this.item}) : super(key: key);

  @override
  State<ItemEditScreen> createState() => _ItemEditScreenState();
}

class _ItemEditScreenState extends State<ItemEditScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final Color screenColor = Color(0xFF2E7D32);
  late Map<String, dynamic> _item;
  late TextEditingController _nameController;
  late TextEditingController _nameUrduController;
  late TextEditingController _unitController;
  late TextEditingController _sellPriceController;
  List<dynamic> _batches = [];

  @override
  void initState() {
    super.initState();
    _item = Map<String, dynamic>.from(widget.item);
    _nameController = TextEditingController(text: _item['name']);
    _nameUrduController = TextEditingController(text: _item['name_urdu'] ?? '');
    _unitController = TextEditingController(text: _item['unit']);
    _sellPriceController = TextEditingController(text: _item['sell_price'].toString());

    try {
      var b = _item['batches'];
      if (b is List) {
        _batches = List.from(b);
      } else {
        _batches = [];
      }
    } catch (e) {
      _batches = [];
    }
  }

  Future<void> _saveChanges() async {
    if (_nameController.text.isEmpty) return;

    Map<String, dynamic> updated = {
      ..._item,
      'name': _nameController.text,
      'name_urdu': _nameUrduController.text,
      'unit': _unitController.text,
      'sell_price': double.tryParse(_sellPriceController.text) ?? _item['sell_price'],
      'batches': _batches,
    };

    await _db.updateItem(_item['id'], updated);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Item updated! ✅'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context, true);
  }

  void _showEditBatchDialog(int index) {
    final priceController = TextEditingController(
        text: (_batches[index]['buy_price'] as num).toStringAsFixed(0));
    final qtyController = TextEditingController(
        text: (_batches[index]['quantity'] as num).toStringAsFixed(1));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Edit Batch ${index + 1}', style: TextStyle(color: screenColor)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: priceController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'-'))],
            style: TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              labelText: 'Purchase Price ₨/${_item['unit']}',
              labelStyle: TextStyle(color: Colors.grey),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: screenColor)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: screenColor)),
            ),
          ),
          SizedBox(height: 8),
          TextField(
            controller: qtyController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'-'))],
            style: TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              labelText: 'Quantity — ${_item['unit']}',
              labelStyle: TextStyle(color: Colors.grey),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: screenColor)),
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
            onPressed: () {
              setState(() {
                _batches[index]['buy_price'] =
                    double.tryParse(priceController.text) ?? _batches[index]['buy_price'];
                _batches[index]['quantity'] =
                    double.tryParse(qtyController.text) ?? _batches[index]['quantity'];

                double totalStock = _batches.fold(
                    0.0, (sum, b) => sum + (b['quantity'] as num).toDouble());
                _item['stock'] = totalStock;
              });
              Navigator.pop(context);
            },
            child: Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {bool isNumber = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
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
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: screenColor)),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: screenColor)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFE8F5E9),
      appBar: AppBar(
        backgroundColor: screenColor,
        title: Text('Edit Item — آئٹم ترمیم',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.save, color: Colors.white),
            onPressed: _saveChanges,
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
              Text('Basic Info — بنیادی معلومات',
                  style: TextStyle(color: screenColor, fontSize: 14, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              _field(_nameController, 'Item Name (English)'),
              _field(_nameUrduController, 'اردو نام (Optional)'),
              _field(_unitController, 'Unit (kg, L, pcs)'),
              _field(_sellPriceController, 'Sale Price ₨ (per ${_item['unit']})', isNumber: true),
            ]),
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Stock Batches — اسٹاک',
                    style: TextStyle(color: screenColor, fontSize: 14, fontWeight: FontWeight.bold)),
                Text('Total: ${_item['stock']} ${_item['unit']}',
                    style: TextStyle(color: Color(0xFF2E7D32), fontSize: 12)),
              ]),
              SizedBox(height: 12),
              _batches.isEmpty
                  ? Text('No batches found', style: TextStyle(color: Colors.grey))
                  : Column(
                      children: _batches
                          .asMap()
                          .entries
                          .where((entry) => (entry.value['quantity'] as num).toDouble() > 0)
                          .map((entry) {
                        int i = entry.key;
                        var b = entry.value;
                        return Container(
                          margin: EdgeInsets.only(bottom: 8),
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: screenColor.withOpacity(0.2)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Batch ${i + 1}',
                                    style: TextStyle(color: screenColor, fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('${(b['quantity'] as num).toStringAsFixed(1)} ${_item['unit']}',
                                    style: TextStyle(color: Color(0xFF2E7D32), fontSize: 13)),
                                Text('Purchase: RS ${(b['buy_price'] as num).toStringAsFixed(0)}/${_item['unit']}',
                                    style: TextStyle(color: Colors.black54, fontSize: 12)),
                                if (b['date'] != null)
                                  Text(b['date'], style: TextStyle(color: Colors.black38, fontSize: 11)),
                              ]),
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.orange),
                                onPressed: () => _showEditBatchDialog(i),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ]),
          ),
          SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: screenColor,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _saveChanges,
              child: Text('Save Changes — تبدیلیاں محفوظ کریں',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          SizedBox(height: 20),
        ]),
      ),
    );
  }
}