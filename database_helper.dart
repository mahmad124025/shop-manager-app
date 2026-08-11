import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DatabaseHelper {

  // ── ITEMS ──

  Future<List<Map<String, dynamic>>> getItems() async {
    final prefs = await SharedPreferences.getInstance();
    final String? itemsJson = prefs.getString('items');
    if (itemsJson == null) return [];
    List<dynamic> decoded = jsonDecode(itemsJson);
    return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> addItem(Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> items = await getItems();
    item['id'] = DateTime.now().millisecondsSinceEpoch;
    item['batches'] = [
      {
        'buy_price': item['buy_price'],
        'quantity': item['stock'],
        'date': DateTime.now().toString().substring(0, 10),
      }
    ];
    items.add(item);
    await prefs.setString('items', jsonEncode(items));
  }

  Future<void> deleteItem(int id) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> items = await getItems();
    items.removeWhere((item) => item['id'] == id);
    await prefs.setString('items', jsonEncode(items));
  }

  Future<void> updateItem(int id, Map<String, dynamic> updatedItem) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> items = await getItems();
    int index = items.indexWhere((item) => item['id'] == id);
    if (index != -1) items[index] = updatedItem;
    await prefs.setString('items', jsonEncode(items));
  }

  Future<void> restockItem(int id, double quantity,
      double buyPrice, double sellPrice) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> items = await getItems();
    int index = items.indexWhere((item) => item['id'] == id);
    if (index != -1) {
      List<dynamic> batches =
          List<dynamic>.from(items[index]['batches'] ?? []);
      batches.add({
        'buy_price': buyPrice,
        'quantity': quantity,
        'date': DateTime.now().toString().substring(0, 10),
      });
      items[index]['batches'] = batches;
      items[index]['stock'] =
          (items[index]['stock'] as num).toDouble() + quantity;
      items[index]['buy_price'] = buyPrice;
      items[index]['sell_price'] = sellPrice;
      await prefs.setString('items', jsonEncode(items));
    }
  }

  Future<void> updateBatchPrice(
      int itemId, int batchIndex, double newPrice) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> items = await getItems();
    int index = items.indexWhere((item) => item['id'] == itemId);
    if (index != -1) {
      List<dynamic> batches =
          List<dynamic>.from(items[index]['batches'] ?? []);
      if (batchIndex < batches.length) {
        batches[batchIndex]['buy_price'] = newPrice;
        items[index]['batches'] = batches;
        await prefs.setString('items', jsonEncode(items));
      }
    }
  }

  Future<double> sellItemFIFO(int id, double quantity) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> items = await getItems();
    int index = items.indexWhere((item) => item['id'] == id);
    if (index == -1) return 0;

    List<dynamic> batches =
        List<dynamic>.from(items[index]['batches'] ?? []);
    double totalCost = 0;
    double remaining = quantity;

    for (int i = 0; i < batches.length && remaining > 0; i++) {
      double batchQty = (batches[i]['quantity'] as num).toDouble();
      double batchPrice = (batches[i]['buy_price'] as num).toDouble();

      if (batchQty <= remaining) {
        totalCost += batchQty * batchPrice;
        remaining -= batchQty;
        batches[i]['quantity'] = 0;
      } else {
        totalCost += remaining * batchPrice;
        batches[i]['quantity'] = batchQty - remaining;
        remaining = 0;
      }
    }

    batches.removeWhere((b) => (b['quantity'] as num).toDouble() <= 0);
    items[index]['batches'] = batches;
    items[index]['stock'] =
        (items[index]['stock'] as num).toDouble() - quantity;
    await prefs.setString('items', jsonEncode(items));

    return totalCost;
  }

  Future<List<Map<String, dynamic>>> getLowStockItems(
      {double threshold = 10}) async {
    List<Map<String, dynamic>> items = await getItems();
    return items
        .where((i) => (i['stock'] as num).toDouble() < threshold)
        .toList();
  }

  // ── CUSTOMERS ──

  Future<List<Map<String, dynamic>>> getCustomers() async {
    final prefs = await SharedPreferences.getInstance();
    final String? customersJson = prefs.getString('customers');
    if (customersJson == null) return [];
    List<dynamic> decoded = jsonDecode(customersJson);
    return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> addCustomer(Map<String, dynamic> customer) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> customers = await getCustomers();
    customer['id'] = DateTime.now().millisecondsSinceEpoch;
    customer['transactions'] = [];
    customers.add(customer);
    await prefs.setString('customers', jsonEncode(customers));
  }

  Future<void> deleteCustomer(int id) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> customers = await getCustomers();
    customers.removeWhere((c) => c['id'] == id);
    await prefs.setString('customers', jsonEncode(customers));
  }

  Future<void> updateCustomer(
      int id, Map<String, dynamic> updatedCustomer) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> customers = await getCustomers();
    int index = customers.indexWhere((c) => c['id'] == id);
    if (index != -1) customers[index] = updatedCustomer;
    await prefs.setString('customers', jsonEncode(customers));
  }

  // ── SALES ──

  Future<List<Map<String, dynamic>>> getSales() async {
    final prefs = await SharedPreferences.getInstance();
    final String? salesJson = prefs.getString('sales');
    if (salesJson == null) return [];
    List<dynamic> decoded = jsonDecode(salesJson);
    return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> addSale(Map<String, dynamic> sale) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> sales = await getSales();
    sale['id'] = DateTime.now().millisecondsSinceEpoch;
    sales.add(sale);
    await prefs.setString('sales', jsonEncode(sales));
  }

  Future<List<Map<String, dynamic>>> getTodaySales() async {
    List<Map<String, dynamic>> sales = await getSales();
    String today = DateTime.now().toString().substring(0, 10);
    return sales.where((s) => s['date'] == today).toList();
  }

  // Weekly = exactly last 7 calendar days (including today)
  Future<List<Map<String, dynamic>>> getWeeklySales() async {
    List<Map<String, dynamic>> sales = await getSales();
    DateTime today = DateTime.now();
    DateTime weekStart = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: 6));
    return sales.where((s) {
      DateTime saleDate = DateTime.parse(s['date']);
      return !saleDate.isBefore(weekStart);
    }).toList();
  }

  // Monthly = exactly last 30 calendar days (including today)
  Future<List<Map<String, dynamic>>> getMonthlySales() async {
    List<Map<String, dynamic>> sales = await getSales();
    DateTime today = DateTime.now();
    DateTime monthStart = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: 29));
    return sales.where((s) {
      DateTime saleDate = DateTime.parse(s['date']);
      return !saleDate.isBefore(monthStart);
    }).toList();
  }

  Future<Map<String, dynamic>?> getBestSellingItem(String period) async {
    List<Map<String, dynamic>> sales = [];
    if (period == 'today') sales = await getTodaySales();
    if (period == 'weekly') sales = await getWeeklySales();
    if (period == 'monthly') sales = await getMonthlySales();

    if (sales.isEmpty) return null;

    Map<String, double> itemQty = {};
    for (var sale in sales) {
      String name = sale['item_name'];
      double qty = (sale['quantity'] as num).toDouble();
      itemQty[name] = (itemQty[name] ?? 0) + qty;
    }

    String bestItem =
        itemQty.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    return {
      'name': bestItem,
      'quantity': itemQty[bestItem],
    };
  }

  // ── REPORTS ──

  Future<Map<String, double>> getReport(String period) async {
    List<Map<String, dynamic>> sales = [];
    if (period == 'today') sales = await getTodaySales();
    if (period == 'weekly') sales = await getWeeklySales();
    if (period == 'monthly') sales = await getMonthlySales();

    double totalSale = 0;
    double totalProfit = 0;

    for (var sale in sales) {
      totalSale += (sale['total'] as num).toDouble().abs();
      totalProfit += (sale['profit'] as num).toDouble().abs();
    }

    return {
      'total_sale': totalSale,
      'total_profit': totalProfit,
      'total_transactions': sales.length.toDouble(),
    };
  }

  // ── EXPENSES ──

  Future<List<Map<String, dynamic>>> getExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('expenses');
    if (data == null) return [];
    List<dynamic> decoded = jsonDecode(data);
    return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<double> getTodayExpenses() async {
    List<Map<String, dynamic>> expenses = await getExpenses();
    String today = DateTime.now().toString().substring(0, 10);
    double total = 0.0;
    for (var e in expenses.where((e) => e['date'] == today)) {
      total += (e['amount'] as num).toDouble();
    }
    return total;
  }

  // Weekly = exactly last 7 calendar days (including today)
  Future<double> getWeeklyExpenses() async {
    List<Map<String, dynamic>> expenses = await getExpenses();
    DateTime today = DateTime.now();
    DateTime weekStart = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: 6));
    double total = 0.0;
    for (var e in expenses) {
      DateTime d = DateTime.parse(e['date']);
      if (!d.isBefore(weekStart)) total += (e['amount'] as num).toDouble();
    }
    return total;
  }

  // Monthly = exactly last 30 calendar days (including today)
  Future<double> getMonthlyExpenses() async {
    List<Map<String, dynamic>> expenses = await getExpenses();
    DateTime today = DateTime.now();
    DateTime monthStart = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: 29));
    double total = 0.0;
    for (var e in expenses) {
      DateTime d = DateTime.parse(e['date']);
      if (!d.isBefore(monthStart)) total += (e['amount'] as num).toDouble();
    }
    return total;
  }
}