class InvoiceItem {
  String name;
  double price;
  int quantity;
  double total;

  InvoiceItem({required this.name, required this.price, required this.quantity})
    : total = price * quantity;

  Map<String, dynamic> toMap() {
    return {'name': name, 'price': price, 'quantity': quantity, 'total': total};
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      name: map['name'],
      price: map['price'],
      quantity: map['quantity'],
    );
  }
}

class Invoice {
  int? id;
  String date;
  String? imagePath;
  List<InvoiceItem> items;
  double totalAmount;

  Invoice({this.id, required this.date, this.imagePath, required this.items})
    : totalAmount = items.fold(0, (sum, item) => sum + item.total);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'imagePath': imagePath,
      'items': items.map((e) => e.toMap()).toList(),
      'totalAmount': totalAmount,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    List<InvoiceItem> itemsList = [];
    if (map['items'] != null) {
      itemsList =
          (map['items'] as List).map((e) => InvoiceItem.fromMap(e)).toList();
    }
    return Invoice(
      id: map['id'],
      date: map['date'],
      imagePath: map['imagePath'],
      items: itemsList,
    );
  }
}
