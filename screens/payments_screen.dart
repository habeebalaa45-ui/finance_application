// lib/screens/payments_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/invoice.dart';
import 'add_invoice_screen.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  List<Invoice> _invoices = [];
  List<Invoice> _filteredInvoices = [];
  final DatabaseHelper _db = DatabaseHelper();
  bool _isLoading = true;

  // متغيرات البحث والفلترة
  final TextEditingController _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    final invoices = await _db.getInvoices();
    setState(() {
      _invoices = invoices;
      _filteredInvoices = invoices;
      _isLoading = false;
    });
  }

  void _filterInvoices(String query) {
    setState(() {
      if (query.isEmpty && _startDate == null && _endDate == null) {
        _filteredInvoices = _invoices;
      } else {
        _filteredInvoices = _invoices.where((invoice) {
          bool matchesSearch = query.isEmpty ||
              invoice.items.any((item) =>
                  item.name.toLowerCase().contains(query.toLowerCase()));

          bool matchesDate = true;
          if (_startDate != null && _endDate != null) {
            final invoiceDate = DateTime.parse(invoice.date);
            matchesDate = invoiceDate.isAfter(_startDate!) &&
                invoiceDate.isBefore(_endDate!.add(const Duration(days: 1)));
          } else if (_startDate != null) {
            matchesDate = DateTime.parse(invoice.date).isAfter(_startDate!);
          } else if (_endDate != null) {
            matchesDate = DateTime.parse(invoice.date).isBefore(_endDate!);
          }

          return matchesSearch && matchesDate;
        }).toList();
      }
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _filterInvoices(_searchController.text);
    }
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _startDate = null;
      _endDate = null;
      _filteredInvoices = _invoices;
    });
  }

  Future<void> _deleteInvoice(int id, String date) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف فاتورة'),
        content: Text('هل أنت متأكد من حذف فاتورة تاريخ $date؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _db.deleteInvoice(id);
      await _loadInvoices();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الفاتورة بنجاح')),
        );
      }
    }
  }

  String _getArabicDate(String date) {
    try {
      final parsedDate = DateTime.parse(date);
      return DateFormat('yyyy/MM/dd - hh:mm a', 'ar').format(parsedDate);
    } catch (e) {
      return date;
    }
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.orange.shade50,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'بحث عن منتج...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _filterInvoices('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: _filterInvoices,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.filter_alt,
                  color: (_startDate != null || _endDate != null)
                      ? Colors.orange
                      : Colors.grey,
                ),
                onPressed: _selectDateRange,
                tooltip: 'فلترة حسب التاريخ',
              ),
              if (_startDate != null ||
                  _endDate != null ||
                  _searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear_all),
                  onPressed: _clearFilters,
                  tooltip: 'مسح الفلترة',
                ),
            ],
          ),
          if (_startDate != null && _endDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.date_range, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'من ${DateFormat('dd/MM/yyyy').format(_startDate!)} إلى ${DateFormat('dd/MM/yyyy').format(_endDate!)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المدفوعات (الفواتير)'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredInvoices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 80,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد فواتير',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchController.text.isNotEmpty ||
                                      _startDate != null
                                  ? 'لا توجد نتائج مطابقة للبحث'
                                  : 'اضغط على زر + لإضافة فاتورة جديدة',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadInvoices,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _filteredInvoices.length,
                          itemBuilder: (context, index) {
                            final invoice = _filteredInvoices[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: InkWell(
                                onTap: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          AddInvoiceScreen(invoice: invoice),
                                    ),
                                  );
                                  if (result == true) {
                                    await _loadInvoices();
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.receipt,
                                              color: Colors.orange.shade700,
                                              size: 24),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'فاتورة - ${_getArabicDate(invoice.date)}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () => _deleteInvoice(
                                                invoice.id!, invoice.date),
                                            constraints: const BoxConstraints(),
                                            padding: EdgeInsets.zero,
                                            splashRadius: 20,
                                          ),
                                        ],
                                      ),
                                      const Divider(),
                                      const SizedBox(height: 4),
                                      // عرض الأقلام
                                      ...invoice.items.take(3).map((item) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 2),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 3,
                                                child: Text(
                                                  item.name,
                                                  style: const TextStyle(
                                                      fontSize: 14),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Text(
                                                  '${item.quantity} × ${NumberFormat.currency(symbol: 'ل.س', decimalDigits: 0).format(item.price)}',
                                                  style: const TextStyle(
                                                      fontSize: 12),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Text(
                                                  NumberFormat.currency(
                                                          symbol: 'ل.س',
                                                          decimalDigits: 0)
                                                      .format(item.total),
                                                  style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w500),
                                                  textAlign: TextAlign.end,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                      if (invoice.items.length > 3)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                            '... و ${invoice.items.length - 3} منتجات أخرى',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                      const Divider(),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          if (invoice.imagePath != null)
                                            Row(
                                              children: [
                                                Icon(Icons.image,
                                                    size: 16,
                                                    color:
                                                        Colors.grey.shade600),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'مرفق صورة',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          const Spacer(),
                                          Text(
                                            'الإجمالي:',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            NumberFormat.currency(
                                                    symbol: 'ل.س',
                                                    decimalDigits: 0)
                                                .format(invoice.totalAmount),
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddInvoiceScreen()),
          );
          if (result == true) {
            await _loadInvoices();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('فاتورة جديدة'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}
