import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';
import '../models/invoice.dart';
import '../models/receipt.dart';
import '../models/withdrawal.dart';

class PdfExportService {
  final DatabaseHelper _db = DatabaseHelper();

  // تصدير فاتورة واحدة
  Future<void> exportInvoiceToPdf(Invoice invoice) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            _buildInvoiceHeader(invoice),
            pw.SizedBox(height: 20),
            _buildInvoiceItemsTable(invoice),
            pw.SizedBox(height: 20),
            _buildInvoiceFooter(invoice),
          ],
        ),
      );

      await _saveAndSharePdf(
        pdf,
        'فاتورة_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.parse(invoice.date))}.pdf',
      );
    } catch (e) {
      print('خطأ في تصدير PDF: $e');
      rethrow;
    }
  }

  // تصدير تقرير شامل
  Future<void> exportFullReport(DateTime startDate, DateTime endDate) async {
    try {
      final invoices = await _db.filterInvoicesByDateRange(startDate, endDate);
      final receipts = await _db.filterReceiptsByDateRange(startDate, endDate);
      final withdrawals = await _db.filterWithdrawalsByDateRange(
        startDate,
        endDate,
      );

      final totalPayments = invoices.fold(
        0.0,
        (sum, inv) => sum + inv.totalAmount,
      );
      final totalReceipts = receipts.fold(0.0, (sum, rec) => sum + rec.amount);
      final totalWithdrawals = withdrawals.fold(
        0.0,
        (sum, wd) => sum + wd.amount,
      );
      final balance = totalReceipts - totalPayments - totalWithdrawals;

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          header: (context) => _buildReportHeader(startDate, endDate),
          build: (context) => [
            _buildSummarySection(
              totalPayments,
              totalReceipts,
              totalWithdrawals,
              balance,
            ),
            pw.SizedBox(height: 20),
            _buildReceiptsSection(receipts),
            pw.SizedBox(height: 20),
            _buildWithdrawalsSection(withdrawals),
            pw.SizedBox(height: 20),
            _buildInvoicesSection(invoices),
          ],
          footer: (context) => _buildFooter(),
        ),
      );

      await _saveAndSharePdf(
        pdf,
        'تقرير_مالي_${DateFormat('yyyyMMdd').format(startDate)}_${DateFormat('yyyyMMdd').format(endDate)}.pdf',
      );
    } catch (e) {
      print('خطأ في تصدير التقرير: $e');
      rethrow;
    }
  }

  pw.Widget _buildInvoiceHeader(Invoice invoice) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(
          child: pw.Text(
            'فاتورة شراء',
            style: const pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Text('رقم الفاتورة: ${invoice.id ?? 'غير محدد'}'),
        pw.Text(
          'التاريخ: ${DateFormat('yyyy/MM/dd - HH:mm').format(DateTime.parse(invoice.date))}',
        ),
        if (invoice.imagePath != null) pw.Text('مرفق صورة: نعم'),
      ],
    );
  }

  pw.Widget _buildInvoiceItemsTable(Invoice invoice) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'المنتجات:',
          style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'المنتج',
                    style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'السعر',
                    style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'العدد',
                    style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'الإجمالي',
                    style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
            ...invoice.items.map(
              (item) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(item.name),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      NumberFormat.currency(
                        symbol: 'ل.س',
                        decimalDigits: 0,
                      ).format(item.price),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      '${item.quantity}',
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      NumberFormat.currency(
                        symbol: 'ل.س',
                        decimalDigits: 0,
                      ).format(item.total),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildInvoiceFooter(Invoice invoice) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.SizedBox(height: 20),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'الإجمالي الكلي:',
                style: const pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              pw.Text(
                NumberFormat.currency(
                  symbol: 'ل.س',
                  decimalDigits: 0,
                ).format(invoice.totalAmount),
                style: const pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildReportHeader(DateTime startDate, DateTime endDate) {
    return pw.Column(
      children: [
        pw.Center(
          child: pw.Text(
            'تقرير مالي شامل',
            style: const pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Center(
          child: pw.Text(
            'من ${DateFormat('yyyy/MM/dd').format(startDate)} إلى ${DateFormat('yyyy/MM/dd').format(endDate)}',
            style: const pw.TextStyle(fontSize: 14),
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Divider(),
      ],
    );
  }

  pw.Widget _buildSummarySection(
    double payments,
    double receipts,
    double withdrawals,
    double balance,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'ملخص الفترة',
            style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18),
          ),
          pw.SizedBox(height: 10),
          _buildSummaryRow(
            'إجمالي المدفوعات:',
            NumberFormat.currency(
              symbol: 'ل.س',
              decimalDigits: 0,
            ).format(payments),
          ),
          _buildSummaryRow(
            'إجمالي المقبوضات:',
            NumberFormat.currency(
              symbol: 'ل.س',
              decimalDigits: 0,
            ).format(receipts),
          ),
          _buildSummaryRow(
            'إجمالي المسحوبات:',
            NumberFormat.currency(
              symbol: 'ل.س',
              decimalDigits: 0,
            ).format(withdrawals),
          ),
          pw.Divider(),
          _buildSummaryRow(
            'الرصيد الحالي:',
            NumberFormat.currency(
              symbol: 'ل.س',
              decimalDigits: 0,
            ).format(balance),
            isBold: true,
            color: balance >= 0 ? PdfColors.green : PdfColors.red,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildReceiptsSection(List<Receipt> receipts) {
    if (receipts.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'المقبوضات',
          style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'الوصف',
                    style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'المبلغ',
                    style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'التاريخ',
                    style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            ),
            ...receipts.map(
              (receipt) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(receipt.title),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      NumberFormat.currency(
                        symbol: 'ل.س',
                        decimalDigits: 0,
                      ).format(receipt.amount),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      DateFormat(
                        'yyyy/MM/dd',
                      ).format(DateTime.parse(receipt.date)),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildWithdrawalsSection(List<Withdrawal> withdrawals) {
    if (withdrawals.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'المسحوبات',
          style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'التصنيف',
                    style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'المبلغ',
                    style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'التاريخ',
                    style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            ),
            ...withdrawals.map(
              (withdrawal) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(withdrawal.category),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      NumberFormat.currency(
                        symbol: 'ل.س',
                        decimalDigits: 0,
                      ).format(withdrawal.amount),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      DateFormat(
                        'yyyy/MM/dd',
                      ).format(DateTime.parse(withdrawal.date)),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildInvoicesSection(List<Invoice> invoices) {
    if (invoices.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'الفواتير',
          style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'عدد المنتجات',
                    style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'الإجمالي',
                    style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'التاريخ',
                    style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            ),
            ...invoices.map(
              (invoice) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('${invoice.items.length} منتج'),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      NumberFormat.currency(
                        symbol: 'ل.س',
                        decimalDigits: 0,
                      ).format(invoice.totalAmount),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      DateFormat(
                        'yyyy/MM/dd',
                      ).format(DateTime.parse(invoice.date)),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Divider(),
        pw.SizedBox(height: 10),
        pw.Center(
          child: pw.Text(
            'تم إنشاء هذا التقرير بواسطة تطبيق إدارة المدفوعات',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
          ),
        ),
      ],
    );
  }

  Future<void> _saveAndSharePdf(pw.Document pdf, String filename) async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)], text: 'مشاركة ملف PDF');
    } catch (e) {
      print('خطأ في حفظ ومشاركة PDF: $e');
      rethrow;
    }
  }

  Future<void> printPdf(pw.Document pdf) async {
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
