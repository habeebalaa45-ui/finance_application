// lib/screens/add_invoice_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../database/database_helper.dart';
import '../models/invoice.dart';
import '../services/pdf_export_service.dart';

class AddInvoiceScreen extends StatefulWidget {
  final Invoice? invoice;
  const AddInvoiceScreen({super.key, this.invoice});

  @override
  State<AddInvoiceScreen> createState() => _AddInvoiceScreenState();
}

class _AddInvoiceScreenState extends State<AddInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseHelper _db = DatabaseHelper();

  List<InvoiceItem> _items = [];
  DateTime _selectedDate = DateTime.now();
  String? _imagePath;
  final ImagePicker _picker = ImagePicker();

  // متغيرات لإضافة قلم جديد
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _itemPriceController = TextEditingController();
  final TextEditingController _itemQuantityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.invoice != null) {
      _items = List.from(widget.invoice!.items);
      _selectedDate = DateTime.parse(widget.invoice!.date);
      _imagePath = widget.invoice!.imagePath;
    }
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _itemPriceController.dispose();
    _itemQuantityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _imagePath = image.path;
      });
    }
  }

  void _addItem() {
    if (_itemNameController.text.trim().isEmpty ||
        _itemPriceController.text.trim().isEmpty ||
        _itemQuantityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى ملء جميع حقول المنتج')),
      );
      return;
    }

    final price = double.tryParse(_itemPriceController.text);
    final quantity = int.tryParse(_itemQuantityController.text);

    if (price == null || quantity == null || price <= 0 || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('السعر والعدد يجب أن يكونا أرقاماً صحيحة')),
      );
      return;
    }

    setState(() {
      _items.add(InvoiceItem(
        name: _itemNameController.text.trim(),
        price: price,
        quantity: quantity,
      ));
    });

    _itemNameController.clear();
    _itemPriceController.clear();
    _itemQuantityController.clear();
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _editItem(int index) {
    final item = _items[index];
    _itemNameController.text = item.name;
    _itemPriceController.text = item.price.toString();
    _itemQuantityController.text = item.quantity.toString();

    _items.removeAt(index);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('قم بتعديل البيانات ثم اضغط إضافة المنتج')),
    );
  }

  Future<void> _saveInvoice() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب إضافة منتج واحد على الأقل')),
      );
      return;
    }

    final invoice = Invoice(
      id: widget.invoice?.id,
      date: _selectedDate.toIso8601String(),
      imagePath: _imagePath,
      items: _items,
    );

    if (widget.invoice == null) {
      await _db.insertInvoice(invoice);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إضافة الفاتورة بنجاح')),
      );
    } else {
      await _db.updateInvoice(invoice);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تعديل الفاتورة بنجاح')),
      );
    }

    Navigator.pop(context, true);
  }

  Future<void> _exportToPdf() async {
    if (widget.invoice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('احفظ الفاتورة أولاً ثم قم بتصديرها')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final pdfService = PdfExportService();
      await pdfService.exportInvoiceToPdf(widget.invoice!);
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء PDF ومشاركته بنجاح')),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في إنشاء PDF: $e')),
      );
    }
  }

  double get _totalAmount {
    return _items.fold(0, (sum, item) => sum + item.total);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.invoice == null ? 'فاتورة جديدة' : 'تعديل فاتورة'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          if (widget.invoice != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _exportToPdf,
              tooltip: 'تصدير PDF',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // اختيار التاريخ
                    ListTile(
                      leading: const Icon(Icons.calendar_today,
                          color: Colors.orange),
                      title: const Text('تاريخ الفاتورة'),
                      subtitle: Text(DateFormat('yyyy/MM/dd - HH:mm', 'ar')
                          .format(_selectedDate)),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(_selectedDate),
                          );
                          if (time != null) {
                            setState(() {
                              _selectedDate = DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          }
                        }
                      },
                    ),

                    // إرفاق صورة
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading:
                                const Icon(Icons.image, color: Colors.orange),
                            title: const Text('إرفاق صورة الفاتورة'),
                            trailing: IconButton(
                              icon: const Icon(Icons.camera_alt),
                              onPressed: _pickImage,
                            ),
                          ),
                          if (_imagePath != null)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      File(_imagePath!),
                                      height: 150,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: CircleAvatar(
                                      backgroundColor: Colors.black54,
                                      child: IconButton(
                                        icon: const Icon(Icons.close,
                                            color: Colors.white, size: 16),
                                        onPressed: () =>
                                            setState(() => _imagePath = null),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // قسم إضافة المنتجات
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'إضافة منتج جديد',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _itemNameController,
                              decoration: const InputDecoration(
                                labelText: 'اسم المنتج',
                                border: OutlineInputBorder(),
                                prefixIcon:
                                    Icon(Icons.production_quantity_limits),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _itemPriceController,
                                    decoration: const InputDecoration(
                                      labelText: 'السعر',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.attach_money),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: _itemQuantityController,
                                    decoration: const InputDecoration(
                                      labelText: 'العدد',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.numbers),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _addItem,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    shape: const CircleBorder(),
                                    padding: const EdgeInsets.all(12),
                                  ),
                                  child: const Icon(Icons.add,
                                      color: Colors.white),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // قائمة المنتجات المضافة
                    const Text(
                      'قائمة المنتجات',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    if (_items.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'لا توجد منتجات مضافة بعد',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.orange.shade100,
                                child: Text('${index + 1}'),
                              ),
                              title: Text(item.name),
                              subtitle: Text(
                                '${item.quantity} × ${NumberFormat.currency(symbol: 'ل.س', decimalDigits: 0).format(item.price)} = ${NumberFormat.currency(symbol: 'ل.س', decimalDigits: 0).format(item.total)}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue),
                                    onPressed: () => _editItem(index),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () => _removeItem(index),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            // الإجمالي وزر الحفظ
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('الإجمالي الكلي',
                          style: TextStyle(color: Colors.grey)),
                      Text(
                        NumberFormat.currency(symbol: 'ل.س', decimalDigits: 0)
                            .format(_totalAmount),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _saveInvoice,
                    icon: const Icon(Icons.save),
                    label: const Text('حفظ الفاتورة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
