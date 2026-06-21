// lib/models/receipt.dart
class Receipt {
  int? id;
  String title;
  double amount;
  String date;
  String note;

  Receipt({
    this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date,
      'note': note,
    };
  }

  factory Receipt.fromMap(Map<String, dynamic> map) {
    return Receipt(
      id: map['id'],
      title: map['title'],
      amount: map['amount'],
      date: map['date'],
      note: map['note'],
    );
  }
}
