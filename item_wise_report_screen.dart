import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'pdf_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── ITEM LIST (choose item to see report) ──
class ItemWiseReportScreen extends StatefulWidget {
  @override
  State<ItemWiseReportScreen> createState() => _ItemWiseReportScreenState();
}

class _ItemWiseReportScreenState extends State<ItemWiseReportScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final Color screenColor = Color(0xFF2E7D32);
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredItems = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final items = await _db.getItems();
    setState(() {
      _items = items;
      _filteredItems = items;
    });
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
      _filteredItems = _items
          .where((item) => item['name']
              .toString()
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFE8F5E9),
      appBar: AppBar(
        backgroundColor: screenColor,
        title: Text('Item Wise Report — آئٹم رپورٹ',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(50),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: _onSearch,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search items...',
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
      body: _filteredItems.isEmpty
          ? Center(
              child: Text(
                  _searchQuery.isEmpty
                      ? 'No items yet!\nAdd items from Inventory'
                      : 'No items found!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16)))
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ItemWiseDetailScreen(item: item)),
                  ),
                  child: Container(
                    margin: EdgeInsets.only(bottom: 10),
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: screenColor.withOpacity(0.3)),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                              '${item['name']}${item['name_urdu'] != '' ? ' — ${item['name_urdu']}' : ''}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.black87)),
                        ),
                        Icon(Icons.arrow_forward_ios, color: screenColor, size: 16),
                      ],
                    ),
                  ),
                );
              }),
    );
  }
}

// ── ITEM DETAIL REPORT (Today/Weekly/Monthly) ──
class ItemWiseDetailScreen extends StatefulWidget {
  final Map<String, dynamic> item;
  const ItemWiseDetailScreen({Key? key, required this.item}) : super(key: key);

  @override
  State<ItemWiseDetailScreen> createState() => _ItemWiseDetailScreenState();
}

class _ItemWiseDetailScreenState extends State<ItemWiseDetailScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final Color screenColor = Color(0xFF2E7D32);
  String _selectedPeriod = 'today';
  List<Map<String, dynamic>> _sales = [];
  double _totalQty = 0;
  double _totalAmount = 0;
  double _totalProfit = 0;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    List<Map<String, dynamic>> allSales = [];
    if (_selectedPeriod == 'today') allSales = await _db.getTodaySales();
    if (_selectedPeriod == 'weekly') allSales = await _db.getWeeklySales();
    if (_selectedPeriod == 'monthly') allSales = await _db.getMonthlySales();

    List<Map<String, dynamic>> itemSales = allSales
        .where((s) => s['item_name'] == widget.item['name'])
        .toList();

    double totalQty = itemSales.fold(0.0, (sum, s) => sum + (s['quantity'] as num).toDouble());
    double totalAmount = itemSales.fold(0.0, (sum, s) => sum + (s['total'] as num).toDouble().abs());
    double totalProfit = itemSales.fold(0.0, (sum, s) => sum + (s['profit'] as num).toDouble().abs());

    setState(() {
      _sales = itemSales;
      _totalQty = totalQty;
      _totalAmount = totalAmount;
      _totalProfit = totalProfit;
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFE8F5E9),
      appBar: AppBar(
        backgroundColor: screenColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${widget.item['name']} — Report',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: _sales.isEmpty
                ? null
                : () async {
                    final prefs = await SharedPreferences.getInstance();
                    String shopName = prefs.getString('shop_name') ?? 'Shop Manager';
                    await PdfHelper.generateSaleHistoryPdf(
                      context: context,
                      shopName: shopName,
                      period: _selectedPeriod,
                      periodLabel: _getPeriodLabel(),
                      sales: _sales,
                      totalSale: _totalAmount,
                      totalProfit: _totalProfit,
                      title: 'Item Sale',
                    );
                  },
          ),
        ],
      ),
      body: Column(children: [
        // Period Selector
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

        // Summary Cards
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _card('Total Qty\nکل مقدار',
                '${_totalQty.toStringAsFixed(1)} ${widget.item['unit']}',
                Color(0xFF1565C0)),
            SizedBox(width: 8),
            _card('Total Sale\nکل فروخت',
                'Rs ${_totalAmount.toStringAsFixed(0)}',
                Color(0xFFE65100)),
            SizedBox(width: 8),
            _card('Total Profit\nکل منافع',
                'Rs ${_totalProfit.toStringAsFixed(0)}',
                Color(0xFF2E7D32)),
          ]),
        ),

        SizedBox(height: 16),

        // Sales List Header
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sale History — فروخت کی تاریخ',
                  style: TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
              Text('${_sales.length} records',
                  style: TextStyle(color: Colors.black45, fontSize: 12)),
            ],
          ),
        ),

        SizedBox(height: 8),

        // Sales List
        Expanded(
          child: _sales.isEmpty
              ? Center(
                  child: Text('No sales in this period!',
                      style: TextStyle(color: Colors.grey, fontSize: 15)))
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _sales.length,
                  itemBuilder: (context, index) {
                    final sale = _sales[_sales.length - 1 - index];
                    String custName = (sale['customer_name'] ?? '').toString();
                    String custPhone = (sale['customer_phone'] ?? '').toString();
                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: screenColor.withOpacity(0.2)),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 3)],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      '${(sale['quantity'] as num).toStringAsFixed(1)} ${sale['unit']}',
                                      style: TextStyle(
                                          color: Colors.black87,
                                          fontWeight: FontWeight.bold)),
                                  Text(sale['date'] ?? '',
                                      style: TextStyle(
                                          color: Colors.black45, fontSize: 12)),
                                  if (custName.isNotEmpty)
                                    Text(
                                      custPhone.isNotEmpty ? '👤 $custName • $custPhone' : '👤 $custName',
                                      style: TextStyle(color: Color(0xFF6A1B9A), fontSize: 11),
                                    ),
                                ]),
                          ),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                    '₨ ${(sale['total'] as num).toDouble().abs().toStringAsFixed(0)}',
                                    style: TextStyle(
                                        color: Color(0xFFE65100),
                                        fontWeight: FontWeight.bold)),
                                Text(
                                    'Profit: Rs ${(sale['profit'] as num).toDouble().abs().toStringAsFixed(0)}',
                                    style: TextStyle(
                                        color: Color(0xFF2E7D32),
                                        fontSize: 12)),
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
        onTap: () {
          setState(() => _selectedPeriod = value);
          _loadReport();
        },
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
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              )),
        ),
      ),
    );
  }

  Widget _card(String label, String value, Color color) {
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
          Text(label, style: TextStyle(color: Colors.black45, fontSize: 10)),
          SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}