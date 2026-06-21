import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/withdrawal.dart';

class AddWithdrawalScreen extends StatefulWidget {
  final Withdrawal? withdrawal;
  const AddWithdrawalScreen({super.key, this.withdrawal});

  @override
  State<AddWithdrawalScreen> createState() => _AddWithdrawalScreenState();
}

class _AddWithdrawalScreenState extends State<AddWithdrawalScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseHelper _db = DatabaseHelper();

  String _selectedCategory = 'مسحوبات شخصية';
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.withdrawal != null) {
      // تعديل مسحوب موجود
      _selectedCategory = widget.withdrawal!.category;
      _amountController.text = widget.withdrawal!.amount.toString();
      _noteController.text = widget.withdrawal!.note;
      _selectedDate = DateTime.parse(widget.withdrawal!.date);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveWithdrawal() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('المبلغ يجب أن يكون رقماً موجباً')),
      );
      return;
    }

    final withdrawal = Withdrawal(
      id: widget.withdrawal?.id,
      category: _selectedCategory,
      amount: amount,
      date: _selectedDate.toIso8601String(),
      note: _noteController.text.trim(),
    );

    if (widget.withdrawal == null) {
      await _db.insertWithdrawal(withdrawal);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إضافة المسحوب بنجاح')));
    } else {
      await _db.updateWithdrawal(withdrawal);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تعديل المسحوب بنجاح')));
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.withdrawal == null ? 'إضافة مسحوب جديد' : 'تعديل مسحوب',
        ),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        centerTitle: true,
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
                    Card(
                      elevation: 2,
                      child: ListTile(
                        leading: const Icon(
                          Icons.calendar_today,
                          color: Colors.purple,
                        ),
                        title: const Text('تاريخ السحب'),
                        subtitle: Text(
                          DateFormat(
                            'yyyy/MM/dd - HH:mm',
                            'ar',
                          ).format(_selectedDate),
                          style: const TextStyle(fontSize: 14),
                        ),
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
                              initialTime: TimeOfDay.fromDateTime(
                                _selectedDate,
                              ),
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
                    ),

                    const SizedBox(height: 16),

                    // بيانات المسحوب
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'بيانات المسحوب',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // اختيار التصنيف
                            DropdownButtonFormField<String>(
                              initialValue: _selectedCategory,
                              decoration: const InputDecoration(
                                labelText: 'التصنيف *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.category),
                              ),
                              items:
                                  WithdrawalCategories.categories.map((
                                    category,
                                  ) {
                                    return DropdownMenuItem(
                                      value: category,
                                      child: Row(
                                        children: [
                                          Icon(
                                            WithdrawalCategories.getIconForCategory(
                                              category,
                                            ),
                                            size: 20,
                                            color:
                                                WithdrawalCategories.getColorForCategory(
                                                  category,
                                                ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(category),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedCategory = value!;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'يرجى اختيار التصنيف';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // حقل المبلغ
                            TextFormField(
                              controller: _amountController,
                              decoration: const InputDecoration(
                                labelText: 'المبلغ *',
                                hintText: 'مثال: 25000',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.money),
                                suffixText: 'ل.س',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'يرجى إدخال المبلغ';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'يرجى إدخال رقم صحيح';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // حقل الملاحظات
                            TextFormField(
                              controller: _noteController,
                              decoration: const InputDecoration(
                                labelText: 'ملاحظات (اختياري)',
                                hintText:
                                    'اذكر سبب السحب أو أي تفاصيل إضافية...',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.note),
                              ),
                              maxLines: 3,
                            ),

                            const SizedBox(height: 16),

                            // نصائح سريعة
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.purple.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.lightbulb,
                                    color: Colors.purple.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'نصيحة: سجل جميع المسحوبات بدقة لمراقبة المصروفات الشخصية',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.purple.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // زر الحفظ
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
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveWithdrawal,
                  icon: const Icon(Icons.save),
                  label: const Text(
                    'حفظ المسحوب',
                    style: TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
