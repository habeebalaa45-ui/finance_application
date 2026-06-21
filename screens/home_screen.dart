// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import 'payments_screen.dart';
import 'receipts_screen.dart';
import 'withdrawals_screen.dart';
import '../services/pdf_export_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double _totalPayments = 0.0;
  double _totalReceipts = 0.0;
  double _totalWithdrawals = 0.0;
  double _balance = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFinancialData();
  }

  Future<void> _loadFinancialData() async {
    setState(() => _isLoading = true);
    final db = DatabaseHelper();

    final invoices = await db.getInvoices();
    final receipts = await db.getReceipts();
    final withdrawals = await db.getWithdrawals();

    setState(() {
      _totalPayments = invoices.fold(0, (sum, inv) => sum + inv.totalAmount);
      _totalReceipts = receipts.fold(0, (sum, rec) => sum + rec.amount);
      _totalWithdrawals = withdrawals.fold(0, (sum, wd) => sum + wd.amount);
      _balance = _totalReceipts - _totalPayments - _totalWithdrawals;
      _isLoading = false;
    });
  }

  Future<void> _exportFullReport() async {
    final endDate = DateTime.now();
    final startDate = DateTime(endDate.year, endDate.month, 1);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final pdfService = PdfExportService();
      await pdfService.exportFullReport(startDate, endDate);
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء التقرير الشامل ومشاركته')),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'الميزانية الشخصية',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportFullReport,
            tooltip: 'تقرير شهري PDF',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadFinancialData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // بطاقة الرصيد الرئيسية
                      Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _balance >= 0
                                    ? Colors.teal.shade700
                                    : Colors.red.shade700,
                                _balance >= 0
                                    ? Colors.teal.shade400
                                    : Colors.red.shade400,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'الرصيد الحالي',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                NumberFormat.currency(
                                  symbol: 'ل.س',
                                  decimalDigits: 0,
                                ).format(_balance),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // بطاقات الإحصائيات السريعة
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              title: 'إجمالي المدفوعات',
                              amount: _totalPayments,
                              color: Colors.orange,
                              icon: Icons.shopping_cart,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              title: 'إجمالي المقبوضات',
                              amount: _totalReceipts,
                              color: Colors.green,
                              icon: Icons.attach_money,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      _buildStatCard(
                        title: 'إجمالي المسحوبات',
                        amount: _totalWithdrawals,
                        color: Colors.purple,
                        icon: Icons.person_remove,
                      ),

                      const SizedBox(height: 32),

                      // أزرار التنقل
                      const Text(
                        'الإجراءات السريعة',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.right,
                      ),

                      const SizedBox(height: 16),

                      _buildNavButton(
                        title: 'المدفوعات (فواتير)',
                        icon: Icons.receipt,
                        color: Colors.orange,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PaymentsScreen(),
                            ),
                          );
                          _loadFinancialData();
                        },
                      ),

                      const SizedBox(height: 12),

                      _buildNavButton(
                        title: 'المقبوضات',
                        icon: Icons.money,
                        color: Colors.green,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ReceiptsScreen(),
                            ),
                          );
                          _loadFinancialData();
                        },
                      ),

                      const SizedBox(height: 12),

                      _buildNavButton(
                        title: 'المسحوبات',
                        icon: Icons.remove_circle,
                        color: Colors.purple,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const WithdrawalsScreen(),
                            ),
                          );
                          _loadFinancialData();
                        },
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required double amount,
    required MaterialColor color,
    required IconData icon,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color.shade700),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              NumberFormat.currency(
                symbol: 'ل.س',
                decimalDigits: 0,
              ).format(amount),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required String title,
    required IconData icon,
    required MaterialColor color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 28),
        label: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.shade700,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 3,
        ),
      ),
    );
  }
}
