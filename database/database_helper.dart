import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../models/invoice.dart';
import '../models/receipt.dart';
import '../models/withdrawal.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'finance_app.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    // جدول الفواتير (مع تخزين JSON للأقلام)
    await db.execute('''
      CREATE TABLE invoices(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        imagePath TEXT,
        items TEXT,
        totalAmount REAL
      )
    ''');

    // جدول المقبوضات
    await db.execute('''
      CREATE TABLE receipts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        amount REAL,
        date TEXT,
        note TEXT
      )
    ''');

    // جدول المسحوبات
    await db.execute('''
      CREATE TABLE withdrawals(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT,
        amount REAL,
        date TEXT,
        note TEXT
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // إضافة أي تحديثات مستقبلية هنا
    }
  }

  // ==================== دوال مساعدة للتحويل بين JSON والأقلام ====================

  String _itemsToJson(List<InvoiceItem> items) {
    List<Map<String, dynamic>> itemsMap =
        items
            .map(
              (item) => {
                'name': item.name,
                'price': item.price,
                'quantity': item.quantity,
                'total': item.total,
              },
            )
            .toList();
    return jsonEncode(itemsMap);
  }

  List<InvoiceItem> _itemsFromJson(String jsonString) {
    if (jsonString.isEmpty) return [];
    try {
      List<dynamic> itemsList = jsonDecode(jsonString);
      return itemsList
          .map(
            (item) => InvoiceItem(
              name: item['name'],
              price: item['price'],
              quantity: item['quantity'],
            ),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ==================== عمليات الفواتير ====================

  Future<int> insertInvoice(Invoice invoice) async {
    Database db = await database;
    Map<String, dynamic> map = {
      'date': invoice.date,
      'imagePath': invoice.imagePath,
      'items': _itemsToJson(invoice.items),
      'totalAmount': invoice.totalAmount,
    };
    return await db.insert('invoices', map);
  }

  Future<List<Invoice>> getInvoices() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'invoices',
      orderBy: 'date DESC',
    );

    return maps
        .map(
          (map) => Invoice(
            id: map['id'],
            date: map['date'],
            imagePath: map['imagePath'],
            items: _itemsFromJson(map['items']),
          ),
        )
        .toList();
  }

  Future<List<Invoice>> searchInvoices(String query) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'invoices',
      where: 'date LIKE ? OR items LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'date DESC',
    );

    return maps
        .map(
          (map) => Invoice(
            id: map['id'],
            date: map['date'],
            imagePath: map['imagePath'],
            items: _itemsFromJson(map['items']),
          ),
        )
        .toList();
  }

  Future<List<Invoice>> filterInvoicesByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'invoices',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'date DESC',
    );

    return maps
        .map(
          (map) => Invoice(
            id: map['id'],
            date: map['date'],
            imagePath: map['imagePath'],
            items: _itemsFromJson(map['items']),
          ),
        )
        .toList();
  }

  Future<int> updateInvoice(Invoice invoice) async {
    Database db = await database;
    Map<String, dynamic> map = {
      'date': invoice.date,
      'imagePath': invoice.imagePath,
      'items': _itemsToJson(invoice.items),
      'totalAmount': invoice.totalAmount,
    };
    return await db.update(
      'invoices',
      map,
      where: 'id = ?',
      whereArgs: [invoice.id],
    );
  }

  Future<int> deleteInvoice(int id) async {
    Database db = await database;
    return await db.delete('invoices', where: 'id = ?', whereArgs: [id]);
  }

  Future<double> getTotalPayments() async {
    Database db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(totalAmount) as total FROM invoices',
    );
    return result.first['total'] as double? ?? 0.0;
  }

  // ==================== عمليات المقبوضات ====================

  Future<int> insertReceipt(Receipt receipt) async {
    Database db = await database;
    return await db.insert('receipts', receipt.toMap());
  }

  Future<List<Receipt>> getReceipts() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'receipts',
      orderBy: 'date DESC',
    );
    return maps.map((map) => Receipt.fromMap(map)).toList();
  }

  Future<List<Receipt>> searchReceipts(String query) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'receipts',
      where: 'title LIKE ? OR note LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'date DESC',
    );
    return maps.map((map) => Receipt.fromMap(map)).toList();
  }

  Future<List<Receipt>> filterReceiptsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'receipts',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'date DESC',
    );
    return maps.map((map) => Receipt.fromMap(map)).toList();
  }

  Future<int> updateReceipt(Receipt receipt) async {
    Database db = await database;
    return await db.update(
      'receipts',
      receipt.toMap(),
      where: 'id = ?',
      whereArgs: [receipt.id],
    );
  }

  Future<int> deleteReceipt(int id) async {
    Database db = await database;
    return await db.delete('receipts', where: 'id = ?', whereArgs: [id]);
  }

  Future<double> getTotalReceipts() async {
    Database db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM receipts',
    );
    return result.first['total'] as double? ?? 0.0;
  }

  // ==================== عمليات المسحوبات ====================

  Future<int> insertWithdrawal(Withdrawal withdrawal) async {
    Database db = await database;
    return await db.insert('withdrawals', withdrawal.toMap());
  }

  Future<List<Withdrawal>> getWithdrawals() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'withdrawals',
      orderBy: 'date DESC',
    );
    return maps.map((map) => Withdrawal.fromMap(map)).toList();
  }

  Future<List<Withdrawal>> searchWithdrawals(String query) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'withdrawals',
      where: 'category LIKE ? OR note LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'date DESC',
    );
    return maps.map((map) => Withdrawal.fromMap(map)).toList();
  }

  Future<List<Withdrawal>> filterWithdrawalsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'withdrawals',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'date DESC',
    );
    return maps.map((map) => Withdrawal.fromMap(map)).toList();
  }

  Future<List<Withdrawal>> filterWithdrawalsByCategory(String category) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'withdrawals',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'date DESC',
    );
    return maps.map((map) => Withdrawal.fromMap(map)).toList();
  }

  Future<int> updateWithdrawal(Withdrawal withdrawal) async {
    Database db = await database;
    return await db.update(
      'withdrawals',
      withdrawal.toMap(),
      where: 'id = ?',
      whereArgs: [withdrawal.id],
    );
  }

  Future<int> deleteWithdrawal(int id) async {
    Database db = await database;
    return await db.delete('withdrawals', where: 'id = ?', whereArgs: [id]);
  }

  Future<double> getTotalWithdrawals() async {
    Database db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM withdrawals',
    );
    return result.first['total'] as double? ?? 0.0;
  }

  // ==================== دوال التقارير والإحصائيات ====================

  Future<Map<String, double>> getCategoryTotals() async {
    Database db = await database;
    final result = await db.rawQuery('''
      SELECT category, SUM(amount) as total 
      FROM withdrawals 
      GROUP BY category
    ''');

    Map<String, double> totals = {};
    for (var row in result) {
      totals[row['category'] as String] = row['total'] as double;
    }
    return totals;
  }

  Future<Map<String, dynamic>> getMonthlyReport(int year, int month) async {
    Database db = await database;
    String startDate = DateTime(year, month, 1).toIso8601String();
    String endDate = DateTime(year, month + 1, 0, 23, 59, 59).toIso8601String();

    final payments = await db.rawQuery(
      'SELECT SUM(totalAmount) as total FROM invoices WHERE date BETWEEN ? AND ?',
      [startDate, endDate],
    );

    final receipts = await db.rawQuery(
      'SELECT SUM(amount) as total FROM receipts WHERE date BETWEEN ? AND ?',
      [startDate, endDate],
    );

    final withdrawals = await db.rawQuery(
      'SELECT SUM(amount) as total FROM withdrawals WHERE date BETWEEN ? AND ?',
      [startDate, endDate],
    );

    return {
      'payments': payments.first['total'] as double? ?? 0.0,
      'receipts': receipts.first['total'] as double? ?? 0.0,
      'withdrawals': withdrawals.first['total'] as double? ?? 0.0,
      'balance':
          (receipts.first['total'] as double? ?? 0.0) -
          (payments.first['total'] as double? ?? 0.0) -
          (withdrawals.first['total'] as double? ?? 0.0),
    };
  }
}
