import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:p_sosyo_driver/app/data/models/driver.dart';
import 'package:p_sosyo_driver/app/data/models/order_item.dart';
import 'package:p_sosyo_driver/app/data/models/receipt.dart';

class DatabaseService extends GetxService {
  static DatabaseService get to => Get.find<DatabaseService>();

  late final Database _db;

  Future<DatabaseService> init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'psosyo_driver.db');

    _db = await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    return this;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE drivers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        full_name TEXT NOT NULL,
        pin TEXT NOT NULL,
        remember_me INTEGER NOT NULL DEFAULT 0,
        is_authenticated INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        delivery_order_id TEXT NOT NULL,
        title TEXT NOT NULL,
        price REAL NOT NULL,
        ordered_qty TEXT NOT NULL,
        total_amount REAL NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE receipts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        delivery_order_id TEXT NOT NULL,
        reference_number TEXT NOT NULL,
        total_amount REAL NOT NULL,
        sender TEXT NOT NULL,
        receiver TEXT NOT NULL,
        date TEXT NOT NULL,
        scanned_at TEXT NOT NULL
      )
    ''');

    await _seedData(db);
  }

  Future<void> _seedData(Database db) async {
    await db.insert('drivers', Driver(
      username: 'SMB0012',
      password: 'password123',
      fullName: 'Juan Dela Cruz',
      pin: '123456',
    ).toMap());
    await _seedOrderItems(db);
    debugPrint('DatabaseService: Seeded default driver and order items.');
  }

  Future<void> _seedOrderItems(Database db) async {
    final defaultItems = [
      OrderItem(
        deliveryOrderId: '1',
        title: 'NESCAFE CLASSIC COFFEE REFILL | 170G',
        price: 189.75,
        orderedQty: '15PC',
      ),
      OrderItem(
        deliveryOrderId: '1',
        title: 'BEAR BRAND STERILIZED MILK 200ML',
        price: 42.50,
        orderedQty: '36PC',
      ),
      OrderItem(
        deliveryOrderId: '1',
        title: 'READY-TO-DRINK CAPPUCCINO',
        price: 55.00,
        orderedQty: '24PC',
      ),
      OrderItem(
        deliveryOrderId: '1',
        title: 'SUGARFREE CREAMY WHITE',
        price: 78.25,
        orderedQty: '18PC',
      ),
      OrderItem(
        deliveryOrderId: '1',
        title: 'NESCAFÉ® ORIGINAL',
        price: 134.50,
        orderedQty: '12PC',
      ),
    ];

    for (final item in defaultItems) {
      await db.insert('order_items', item.toMap());
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE drivers ADD COLUMN is_authenticated INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 3) {
      // Re-seed order items with corrected data
      await db.delete('order_items');
      await _seedOrderItems(db);
      debugPrint('DatabaseService: Re-seeded order items for v3 upgrade.');
    }
  }

  Future<Driver?> authenticateDriver(String username, String password) async {
    final results = await _db.query(
      'drivers',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
      limit: 1,
    );

    if (results.isNotEmpty) {
      return Driver.fromMap(results.first);
    }
    return null;
  }

  /// Get a driver by username.
  Future<Driver?> getDriverByUsername(String username) async {
    final results = await _db.query(
      'drivers',
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );

    if (results.isNotEmpty) {
      return Driver.fromMap(results.first);
    }
    return null;
  }

  Future<void> updateRememberMe(int driverId, bool rememberMe) async {
    await _db.update(
      'drivers',
      {'remember_me': rememberMe ? 1 : 0},
      where: 'id = ?',
      whereArgs: [driverId],
    );
  }

  Future<void> clearAuthenticatedDrivers() async {
    await _db.update(
      'drivers',
      {'is_authenticated': 0},
    );
  }

  Future<void> setAuthenticatedDriver(int driverId) async {
    await clearAuthenticatedDrivers();
    await _db.update(
      'drivers',
      {'is_authenticated': 1},
      where: 'id = ?',
      whereArgs: [driverId],
    );
  }

  Future<Driver?> getRememberedDriver() async {
    final results = await _db.query(
      'drivers',
      where: 'remember_me = 1',
      limit: 1,
    );

    if (results.isNotEmpty) {
      return Driver.fromMap(results.first);
    }
    return null;
  }

  Future<Driver?> getAuthenticatedDriver() async {
    final results = await _db.query(
      'drivers',
      where: 'is_authenticated = 1',
      limit: 1,
    );

    if (results.isNotEmpty) {
      return Driver.fromMap(results.first);
    }
    return null;
  }

  Future<bool> verifyPin(String username, String pin) async {
    final results = await _db.query(
      'drivers',
      where: 'username = ? AND pin = ?',
      whereArgs: [username, pin],
      limit: 1,
    );

    return results.isNotEmpty;
  }

  Future<List<OrderItem>> getOrderItems(String deliveryOrderId) async {
    final results = await _db.query(
      'order_items',
      where: 'delivery_order_id = ?',
      whereArgs: [deliveryOrderId],
    );

    return results.map((map) => OrderItem.fromMap(map)).toList();
  }

  /// Get all order items.
  Future<List<OrderItem>> getAllOrderItems() async {
    final results = await _db.query('order_items');
    return results.map((map) => OrderItem.fromMap(map)).toList();
  }

  /// Insert a new order item.
  Future<int> insertOrderItem(OrderItem item) async {
    return await _db.insert('order_items', item.toMap());
  }

  /// Delete all order items for a delivery order.
  Future<int> deleteOrderItems(String deliveryOrderId) async {
    return await _db.delete(
      'order_items',
      where: 'delivery_order_id = ?',
      whereArgs: [deliveryOrderId],
    );
  }

  /// Returns true if the given reference number already exists in the receipts table.
  Future<bool> isReferenceNumberUsed(String referenceNumber) async {
    final results = await _db.query(
      'receipts',
      columns: ['id'],
      where: 'reference_number = ?',
      whereArgs: [referenceNumber],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  Future<int> insertReceipt(Receipt receipt) async {
    return await _db.insert('receipts', receipt.toMap());
  }

  Future<List<Receipt>> getReceipts(String deliveryOrderId) async {
    final results = await _db.query(
      'receipts',
      where: 'delivery_order_id = ?',
      whereArgs: [deliveryOrderId],
    );

    return results.map((map) => Receipt.fromMap(map)).toList();
  }

  Future<List<Receipt>> getAllReceipts() async {
    final results = await _db.query('receipts');
    return results.map((map) => Receipt.fromMap(map)).toList();
  }

  @override
  void onClose() {
    _db.close();
    super.onClose();
  }
}
