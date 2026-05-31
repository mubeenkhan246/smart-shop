import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/app_models.dart';
import '../utils/formatters.dart';

class InvoiceService {
  Future<Uint8List> buildInvoicePdf({
    required Shop shop,
    required Bill bill,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(18),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              shop.name,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(shop.type),
            if (shop.phone.isNotEmpty) pw.Text(shop.phone),
            pw.SizedBox(height: 10),
            pw.Text('Invoice: ${bill.invoiceNumber}'),
            pw.Text(compactDateFormat.format(bill.createdAt)),
            pw.Divider(),
            ...bill.items.map(
              (item) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Text('${item.product.name} x ${item.quantity}'),
                    ),
                    pw.Text(moneyFormat.format(item.total)),
                  ],
                ),
              ),
            ),
            pw.Divider(),
            _row('Subtotal', moneyFormat.format(bill.subTotal)),
            _row(
              'Discount',
              moneyFormat.format(bill.itemDiscount + bill.totalDiscount),
            ),
            _row('Tax', moneyFormat.format(bill.tax)),
            pw.SizedBox(height: 6),
            _row(
              'Grand total',
              moneyFormat.format(bill.grandTotal),
              bold: true,
            ),
            _row('Paid', moneyFormat.format(bill.paidAmount)),
            _row('Due', moneyFormat.format(bill.dueAmount)),
            pw.SizedBox(height: 14),
            pw.Center(child: pw.Text('Thank you for shopping')),
          ],
        ),
      ),
    );
    return doc.save();
  }

  Future<void> printInvoice({required Shop shop, required Bill bill}) async {
    final bytes = await buildInvoicePdf(shop: shop, bill: bill);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> shareInvoice({required Shop shop, required Bill bill}) async {
    final bytes = await buildInvoicePdf(shop: shop, bill: bill);
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            name: '${bill.invoiceNumber}.pdf',
            mimeType: 'application/pdf',
          ),
        ],
        text: '${shop.name} invoice ${bill.invoiceNumber}',
      ),
    );
  }

  pw.Widget _row(String label, String value, {bool bold = false}) {
    final style = bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null;
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text(value, style: style),
      ],
    );
  }
}
