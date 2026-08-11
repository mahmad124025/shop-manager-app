import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/material.dart';

class PdfHelper {

  // ── DATE HELPERS ──
  static String _formatDate(DateTime date) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  static String _formatDateString(String isoDate) {
    try {
      DateTime d = DateTime.parse(isoDate);
      return _formatDate(d);
    } catch (e) {
      return isoDate;
    }
  }

  static String _formatPeriodLabel(String periodLabel) {
    if (periodLabel.contains(' to ')) {
      List<String> parts = periodLabel.split(' to ');
      if (parts.length == 2) {
        try {
          DateTime from = DateTime.parse(parts[0].trim());
          DateTime to = DateTime.parse(parts[1].trim());
          return '${_formatDate(from)} to ${_formatDate(to)}';
        } catch (e) {
          return periodLabel;
        }
      }
    }
    return _formatDateString(periodLabel);
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return '${s[0].toUpperCase()}${s.substring(1)}';
  }

  // ── CUSTOMER BILL (single item, legacy) ──
  static Future<void> generateCustomerBill({
    required BuildContext context,
    required String shopName,
    required String shopNameUrdu,
    required String customerName,
    required String customerPhone,
    required String itemName,
    required double quantity,
    required String unit,
    required double salePrice,
    required double totalAmount,
  }) async {
    final pdf = pw.Document();
    String date = _formatDate(DateTime.now());
    String invoiceNo = DateTime.now().millisecondsSinceEpoch.toString().substring(7);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: pw.EdgeInsets.all(24),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _shopHeader(shopName, shopNameUrdu),
              pw.SizedBox(height: 16),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Invoice #$invoiceNo',
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Text('Date: $date',
                  style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black)),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text('Customer Details',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Row(children: [
                pw.Text('Name: ', style: pw.TextStyle(color: PdfColors.grey700, fontSize: 11)),
                pw.Text(customerName.isEmpty ? 'Walk-in Customer' : customerName,
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              ]),
              if (customerPhone.isNotEmpty)
                pw.Row(children: [
                  pw.Text('Phone: ', style: pw.TextStyle(color: PdfColors.grey700, fontSize: 11)),
                  pw.Text(customerPhone, style: pw.TextStyle(fontSize: 11)),
                ]),
              pw.SizedBox(height: 12),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text('Purchase Details',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: pw.FlexColumnWidth(3),
                  1: pw.FlexColumnWidth(2),
                  2: pw.FlexColumnWidth(2),
                  3: pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('0A1628')),
                    children: [
                      _cell('Item', isHeader: true),
                      _cell('Qty', isHeader: true),
                      _cell('Price/$unit', isHeader: true),
                      _cell('Total', isHeader: true),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _cell(itemName),
                      _cell('$quantity $unit'),
                      _cell('Rs ${salePrice.toStringAsFixed(0)}'),
                      _cell('Rs ${totalAmount.toStringAsFixed(0)}'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Container(
                width: double.infinity,
                padding: pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColor.fromHex('00BCD4')),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Amount:',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Rs ${totalAmount.toStringAsFixed(0)}',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('00BCD4'),
                        )),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text('Thank you!',
                    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text('Shop Manager App',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey)),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // ── MULTI-ITEM CUSTOMER BILL (cart-based sale, one bill for several items) ──
  static Future<void> generateMultiItemBill({
    required BuildContext context,
    required String shopName,
    required String shopNameUrdu,
    required String customerName,
    required String customerPhone,
    required List<Map<String, dynamic>> cartItems, // each: {name, quantity, unit, price, total}
    required double grandTotal,
  }) async {
    final pdf = pw.Document();
    String date = _formatDate(DateTime.now());
    String invoiceNo = DateTime.now().millisecondsSinceEpoch.toString().substring(7);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: pw.EdgeInsets.all(24),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _shopHeader(shopName, shopNameUrdu),
              pw.SizedBox(height: 16),
              pw.Text('Invoice #$invoiceNo',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Text('Date: $date',
                  style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black)),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text('Customer Details',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Row(children: [
                pw.Text('Name: ', style: pw.TextStyle(color: PdfColors.grey700, fontSize: 11)),
                pw.Text(customerName.isEmpty ? 'Walk-in Customer' : customerName,
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              ]),
              if (customerPhone.isNotEmpty)
                pw.Row(children: [
                  pw.Text('Phone: ', style: pw.TextStyle(color: PdfColors.grey700, fontSize: 11)),
                  pw.Text(customerPhone, style: pw.TextStyle(fontSize: 11)),
                ]),
              pw.SizedBox(height: 12),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text('Purchase Details',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: pw.FlexColumnWidth(3),
                  1: pw.FlexColumnWidth(2),
                  2: pw.FlexColumnWidth(2),
                  3: pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('0A1628')),
                    children: [
                      _cell('Item', isHeader: true),
                      _cell('Qty', isHeader: true),
                      _cell('Price', isHeader: true),
                      _cell('Total', isHeader: true),
                    ],
                  ),
                  ...cartItems.map((item) => pw.TableRow(
                    children: [
                      _cell(item['name']),
                      _cell('${item['quantity']} ${item['unit']}'),
                      _cell('Rs ${(item['price'] as num).toStringAsFixed(0)}'),
                      _cell('Rs ${(item['total'] as num).toStringAsFixed(0)}'),
                    ],
                  )),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Container(
                width: double.infinity,
                padding: pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColor.fromHex('00BCD4')),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Grand Total:',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Rs ${grandTotal.toStringAsFixed(0)}',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('00BCD4'),
                        )),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text('Thank you!',
                    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text('Shop Manager App',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey)),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // ── SALE HISTORY PDF (also reused by Item Wise Report with a custom title) ──
  static Future<void> generateSaleHistoryPdf({
    required BuildContext context,
    required String shopName,
    required String period,
    required String periodLabel,
    required List<Map<String, dynamic>> sales,
    required double totalSale,
    required double totalProfit,
    String title = 'Sale History',
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return [
            _shopHeader(shopName, ''),
            pw.SizedBox(height: 12),
            pw.Text('$title - ${_capitalize(period)}',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Period: ${_formatPeriodLabel(periodLabel)}',
                style: pw.TextStyle(
                    fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
            pw.SizedBox(height: 12),
            pw.Row(children: [
              _summaryBox('Total Sale', 'Rs ${totalSale.toStringAsFixed(0)}', PdfColor.fromHex('00BCD4')),
              pw.SizedBox(width: 12),
              _summaryBox('Total Profit', 'Rs ${totalProfit.toStringAsFixed(0)}', PdfColors.green),
              pw.SizedBox(width: 12),
              _summaryBox('Count', '${sales.length}', PdfColors.orange),
            ]),
            pw.SizedBox(height: 16),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(3),
                3: pw.FlexColumnWidth(2),
                4: pw.FlexColumnWidth(2),
                5: pw.FlexColumnWidth(3),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('0A1628')),
                  children: [
                    _cell('Item', isHeader: true),
                    _cell('Qty', isHeader: true),
                    _cell('Date', isHeader: true),
                    _cell('Total', isHeader: true),
                    _cell('Profit', isHeader: true),
                    _cell('Customer', isHeader: true),
                  ],
                ),
                ...sales.map((sale) {
                  String custName = (sale['customer_name'] ?? '').toString();
                  String custPhone = (sale['customer_phone'] ?? '').toString();
                  String custDisplay = custName.isEmpty
                      ? '-'
                      : (custPhone.isNotEmpty ? '$custName ($custPhone)' : custName);
                  return pw.TableRow(
                    children: [
                      _cell(sale['item_name'] ?? ''),
                      _cell('${sale['quantity']} ${sale['unit']}'),
                      _cell(_formatDateString(sale['date'] ?? '')),
                      _cell('Rs ${(sale['total'] as num).toDouble().abs().toStringAsFixed(0)}'),
                      _cell('Rs ${(sale['profit'] as num).toDouble().abs().toStringAsFixed(0)}'),
                      _cell(custDisplay),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 16),
            _footer(),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // ── CUSTOMER TRANSACTIONS PDF ──
  static Future<void> generateCustomerTransactionsPdf({
    required BuildContext context,
    required String shopName,
    required Map<String, dynamic> customer,
    required List<Map<String, dynamic>> transactions,
    required double balance,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return [
            _shopHeader(shopName, ''),
            pw.SizedBox(height: 12),
            pw.Text('Customer Transactions',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Text('Customer: ${customer['name']}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            if (customer['phone'] != null && customer['phone'].toString().isNotEmpty)
              pw.Text('Phone: ${customer['phone']}',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            pw.Text(
                'Balance: Rs ${balance.abs().toStringAsFixed(0)} ${balance > 0 ? '(Credit Due)' : balance < 0 ? '(Advance)' : '(Settled)'}',
                style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: balance > 0 ? PdfColors.red : PdfColors.green)),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: pw.FlexColumnWidth(2),
                1: pw.FlexColumnWidth(3),
                2: pw.FlexColumnWidth(2),
                3: pw.FlexColumnWidth(3),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('0A1628')),
                  children: [
                    _cell('Type', isHeader: true),
                    _cell('Note', isHeader: true),
                    _cell('Amount', isHeader: true),
                    _cell('Date', isHeader: true),
                  ],
                ),
                ...transactions.map((txn) => pw.TableRow(
                  children: [
                    _cell(txn['type'] == 'debit' ? 'Credit Given' : 'Payment'),
                    _cell(txn['note'] ?? ''),
                    _cell('Rs ${(txn['amount'] as num).toStringAsFixed(0)}'),
                    _cell(_formatDateString(txn['date'] ?? '')),
                  ],
                )),
              ],
            ),
            pw.SizedBox(height: 16),
            _footer(),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // ── SUPPLIER TRANSACTIONS PDF ──
  static Future<void> generateSupplierTransactionsPdf({
    required BuildContext context,
    required String shopName,
    required Map<String, dynamic> supplier,
    required List transactions,
    required double balance,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return [
            _shopHeader(shopName, ''),
            pw.SizedBox(height: 12),
            pw.Text('Supplier Transactions',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Text('Supplier: ${supplier['name']}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            if (supplier['phone'] != null && supplier['phone'].toString().isNotEmpty)
              pw.Text('Phone: ${supplier['phone']}',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            pw.Text(
                'Balance: Rs ${balance.abs().toStringAsFixed(0)} ${balance > 0 ? '(Payment Due)' : balance < 0 ? '(Advance)' : '(Settled)'}',
                style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: balance > 0 ? PdfColors.red : PdfColors.green)),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: pw.FlexColumnWidth(2),
                1: pw.FlexColumnWidth(3),
                2: pw.FlexColumnWidth(2),
                3: pw.FlexColumnWidth(3),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('0A1628')),
                  children: [
                    _cell('Type', isHeader: true),
                    _cell('Description', isHeader: true),
                    _cell('Amount', isHeader: true),
                    _cell('Date', isHeader: true),
                  ],
                ),
                ...transactions.map((txn) => pw.TableRow(
                  children: [
                    _cell(txn['type'] == 'purchase' ? 'Purchase' : 'Payment'),
                    _cell(txn['description'] ?? ''),
                    _cell('Rs ${(txn['amount'] as num).toStringAsFixed(0)}'),
                    _cell(_formatDateString(txn['date'] ?? '')),
                  ],
                )),
              ],
            ),
            pw.SizedBox(height: 16),
            _footer(),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // ── EXPENSE PDF ──
  static Future<void> generateExpensePdf({
    required BuildContext context,
    required String shopName,
    required String period,
    required String periodLabel,
    required List<Map<String, dynamic>> expenses,
    required double totalExpenses,
    required Map<String, double> categoryTotals,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return [
            _shopHeader(shopName, ''),
            pw.SizedBox(height: 12),
            pw.Text('Expense Report - ${_capitalize(period)}',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Period: ${_formatPeriodLabel(periodLabel)}',
                style: pw.TextStyle(
                    fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.red),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Expenses:',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Rs ${totalExpenses.toStringAsFixed(0)}',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text('By Category:', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            ...categoryTotals.entries.map((entry) => pw.Padding(
                  padding: pw.EdgeInsets.only(bottom: 4),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(entry.key, style: pw.TextStyle(fontSize: 11)),
                      pw.Text('Rs ${entry.value.toStringAsFixed(0)}',
                          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
                    ],
                  ),
                )),
            pw.SizedBox(height: 16),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: pw.FlexColumnWidth(2),
                1: pw.FlexColumnWidth(3),
                2: pw.FlexColumnWidth(2),
                3: pw.FlexColumnWidth(3),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('0A1628')),
                  children: [
                    _cell('Category', isHeader: true),
                    _cell('Note', isHeader: true),
                    _cell('Amount', isHeader: true),
                    _cell('Date', isHeader: true),
                  ],
                ),
                ...expenses.map((expense) => pw.TableRow(
                  children: [
                    _cell(expense['category'] ?? ''),
                    _cell(expense['note'] ?? ''),
                    _cell('Rs ${(expense['amount'] as num).toStringAsFixed(0)}'),
                    _cell(_formatDateString(expense['date'] ?? '')),
                  ],
                )),
              ],
            ),
            pw.SizedBox(height: 16),
            _footer(),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // ── ANNUAL REPORT PDF ──
  static Future<void> generateAnnualReportPdf({
    required BuildContext context,
    required String shopName,
    required String year,
    required List<Map<String, dynamic>> monthRecords,
    required double yearSale,
    required double yearProfit,
    required double yearExpenses,
    required double yearNet,
    required List<Map<String, dynamic>> itemReports,
    String? bestItem,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return [
            _shopHeader(shopName, ''),
            pw.SizedBox(height: 12),
            pw.Text('Annual Report - Year $year',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Row(children: [
              _summaryBox('Total Sale', 'Rs ${yearSale.toStringAsFixed(0)}', PdfColor.fromHex('00BCD4')),
              pw.SizedBox(width: 8),
              _summaryBox('Total Profit', 'Rs ${yearProfit.toStringAsFixed(0)}', PdfColors.green),
            ]),
            pw.SizedBox(height: 8),
            pw.Row(children: [
              _summaryBox('Total Expenses', 'Rs ${yearExpenses.toStringAsFixed(0)}', PdfColors.red),
              pw.SizedBox(width: 8),
              _summaryBox('Net Profit', 'Rs ${yearNet.toStringAsFixed(0)}',
                  yearNet >= 0 ? PdfColors.green : PdfColors.red),
            ]),
            pw.SizedBox(height: 16),
            pw.Text('Monthly Breakdown:', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(2),
                3: pw.FlexColumnWidth(2),
                4: pw.FlexColumnWidth(2),
                5: pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('0A1628')),
                  children: [
                    _cell('Month', isHeader: true),
                    _cell('Sale', isHeader: true),
                    _cell('Profit', isHeader: true),
                    _cell('Expense', isHeader: true),
                    _cell('Net', isHeader: true),
                    _cell('Best Item', isHeader: true),
                  ],
                ),
                ...monthRecords.map((record) {
                  double net = (record['net_profit'] as num).toDouble();
                  return pw.TableRow(
                    children: [
                      _cell(record['period'] ?? ''),
                      _cell('Rs ${(record['total_sale'] as num).toStringAsFixed(0)}'),
                      _cell('Rs ${(record['total_profit'] as num).toStringAsFixed(0)}'),
                      _cell('Rs ${(record['total_expenses'] as num).toStringAsFixed(0)}'),
                      _cell('Rs ${net.toStringAsFixed(0)}'),
                      _cell(record['best_selling'] ?? 'N/A'),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 16),
            _footer(),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // ── ITEM WISE REPORT PDF (overview across all items, not used by per-item detail screen) ──
  static Future<void> generateItemWiseReport({
    required BuildContext context,
    required String shopName,
    required String period,
    required String periodLabel,
    required List<Map<String, dynamic>> itemReports,
    required Map<String, dynamic>? bestSelling,
    required double totalSale,
    required double totalProfit,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return [
            _shopHeader(shopName, ''),
            pw.SizedBox(height: 12),
            pw.Text('Item Sale - ${_capitalize(period)}',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Period: ${_formatPeriodLabel(periodLabel)}',
                style: pw.TextStyle(
                    fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
            pw.SizedBox(height: 12),
            pw.Row(children: [
              _summaryBox('Total Sale', 'Rs ${totalSale.toStringAsFixed(0)}', PdfColor.fromHex('00BCD4')),
              pw.SizedBox(width: 12),
              _summaryBox('Total Profit', 'Rs ${totalProfit.toStringAsFixed(0)}', PdfColors.green),
            ]),
            pw.SizedBox(height: 16),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(2),
                3: pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('0A1628')),
                  children: [
                    _cell('Item', isHeader: true),
                    _cell('Qty Sold', isHeader: true),
                    _cell('Total Sale', isHeader: true),
                    _cell('Total Profit', isHeader: true),
                  ],
                ),
                ...itemReports.map((item) => pw.TableRow(
                  children: [
                    _cell(item['name']),
                    _cell('${(item['quantity'] as double).toStringAsFixed(1)} ${item['unit']}'),
                    _cell('Rs ${(item['total_sale'] as double).toStringAsFixed(0)}'),
                    _cell('Rs ${(item['total_profit'] as double).toStringAsFixed(0)}'),
                  ],
                )),
              ],
            ),
            pw.SizedBox(height: 16),
            _footer(),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // ── HELPERS ──
  static pw.Widget _shopHeader(String shopName, String shopNameUrdu) {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('0A1628'),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            shopName.isEmpty ? 'Shop Manager' : shopName,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('00BCD4'),
            ),
            textAlign: pw.TextAlign.center,
          ),
          if (shopNameUrdu.isNotEmpty)
            pw.Text(
              shopNameUrdu,
              style: pw.TextStyle(fontSize: 14, color: PdfColors.white),
              textAlign: pw.TextAlign.center,
            ),
        ],
      ),
    );
  }

  static pw.Widget _summaryBox(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: color),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.Text(value,
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _cell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.black,
        ),
      ),
    );
  }

  static pw.Widget _footer() {
    return pw.Column(children: [
      pw.Divider(),
      pw.SizedBox(height: 4),
      pw.Center(
        child: pw.Text('Generated by Shop Manager App',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      ),
    ]);
  }
}