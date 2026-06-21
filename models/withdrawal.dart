// lib/models/withdrawal.dart
import 'package:flutter/material.dart';

class Withdrawal {
  int? id;
  String category;
  double amount;
  String date;
  String note;

  Withdrawal({
    this.id,
    required this.category,
    required this.amount,
    required this.date,
    required this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'amount': amount,
      'date': date,
      'note': note,
    };
  }

  factory Withdrawal.fromMap(Map<String, dynamic> map) {
    return Withdrawal(
      id: map['id'],
      category: map['category'],
      amount: map['amount'],
      date: map['date'],
      note: map['note'],
    );
  }
}

// فئة ثابتة لأنواع التصنيفات المتاحة
class WithdrawalCategories {
  static const List<String> categories = [
    'رواتب',
    'مسحوبات شخصية',
    'مصاريف منزلية',
    'فواتير خدمات',
    'علاج وصحة',
    'تعليم',
    'مواصلات',
    'ترفيه',
    'آخر',
  ];

  static IconData getIconForCategory(String category) {
    switch (category) {
      case 'رواتب':
        return Icons.people;
      case 'مسحوبات شخصية':
        return Icons.person;
      case 'مصاريف منزلية':
        return Icons.home;
      case 'فواتير خدمات':
        return Icons.receipt;
      case 'علاج وصحة':
        return Icons.health_and_safety;
      case 'تعليم':
        return Icons.school;
      case 'مواصلات':
        return Icons.directions_car;
      case 'ترفيه':
        return Icons.movie;
      default:
        return Icons.category;
    }
  }

  static Color getColorForCategory(String category) {
    switch (category) {
      case 'رواتب':
        return Colors.blue;
      case 'مسحوبات شخصية':
        return Colors.purple;
      case 'مصاريف منزلية':
        return Colors.teal;
      case 'فواتير خدمات':
        return Colors.orange;
      case 'علاج وصحة':
        return Colors.red;
      case 'تعليم':
        return Colors.indigo;
      case 'مواصلات':
        return Colors.amber;
      case 'ترفيه':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }
}
