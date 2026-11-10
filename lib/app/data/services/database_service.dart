import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:p_sosyo_driver/app/data/models/delivery_order.dart';
import 'package:p_sosyo_driver/app/data/models/driver.dart';
import 'package:p_sosyo_driver/app/data/models/order_item.dart';
import 'package:p_sosyo_driver/app/data/models/receipt.dart';
import 'package:p_sosyo_driver/app/data/providers/api_client.dart';
import 'package:p_sosyo_driver/app/routes/app_routes.dart';

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
      CREATE TABLE delivery_orders (
        id TEXT PRIMARY KEY,
        transaction_id TEXT NOT NULL,
        store_name TEXT NOT NULL,
        address TEXT NOT NULL,
        distance TEXT,
        sku_count INTEGER NOT NULL,
        total_amount REAL NOT NULL,
        status TEXT NOT NULL,
        delivery_date TEXT,
        latitude REAL,
        longitude REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        delivery_order_id TEXT NOT NULL,
        stock_code TEXT,
        title TEXT NOT NULL,
        price REAL NOT NULL,
        ordered_qty TEXT NOT NULL,
        total_amount REAL NOT NULL,
        uom TEXT,
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
      password: '123',
      fullName: 'Juan Dela Cruz',
      pin: '123456',
    ).toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

    // Initial mock order for offline testing
    await db.insert('delivery_orders', {
      'id': '1',
      'transaction_id': 'TXN-001',
      'store_name': 'TINDAHAN NI ALING NENA',
      'address': 'Fast Distribution Head Office H. Abellana Canduman, Mandaue City Cebu',
      'distance': '12m away',
      'sku_count': 5,
      'total_amount': 9195.0,
      'status': 'Out for Delivery',
      'delivery_date': DateTime.now().toIso8601String().substring(0, 10),
      'latitude': 10.3642,
      'longitude': 123.7885,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    final defaultItems = [
      OrderItem(
        deliveryOrderId: '1',
        stockCode: 'NES-001',
        title: 'NESCAFE CLASSIC COFFEE REFILL | 170G',
        price: 123.00,
        orderedQty: '23PC',
        totalAmount: 1839.00,
        uom: 'PC',
      ),
      OrderItem(
        deliveryOrderId: '1',
        stockCode: 'BEA-002',
        title: 'BEAR BRAND STERILIZED MILK 200ML',
        price: 123.00,
        orderedQty: '23PC',
        totalAmount: 1839.00,
        uom: 'PC',
      ),
      OrderItem(
        deliveryOrderId: '1',
        stockCode: 'CAP-003',
        title: 'READY-TO-DRINK CAPPUCCINO',
        price: 123.00,
        orderedQty: '23PC',
        totalAmount: 1839.00,
        uom: 'PC',
      ),
      OrderItem(
        deliveryOrderId: '1',
        stockCode: 'SUG-004',
        title: 'SUGARFREE CREAMY WHITE',
        price: 123.00,
        orderedQty: '23PC',
        totalAmount: 1839.00,
        uom: 'PC',
      ),
      OrderItem(
        deliveryOrderId: '1',
        stockCode: 'NES-005',
        title: 'NESCAFÉ® ORIGINAL',
        price: 123.00,
        orderedQty: '23PC',
        totalAmount: 1839.00,
        uom: 'PC',
      ),
    ];

    for (final item in defaultItems) {
      await db.insert('order_items', item.toMap());
    }

    debugPrint('DatabaseService: Seeded default driver and order items.');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE drivers ADD COLUMN is_authenticated INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 3) {
      // Create delivery_orders table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS delivery_orders (
          id TEXT PRIMARY KEY,
          transaction_id TEXT NOT NULL,
          store_name TEXT NOT NULL,
          address TEXT NOT NULL,
          distance TEXT,
          sku_count INTEGER NOT NULL,
          total_amount REAL NOT NULL,
          status TEXT NOT NULL,
          delivery_date TEXT,
          latitude REAL,
          longitude REAL
        )
      ''');

      // Alter order_items table for stock_code & uom if not present
      try {
        await db.execute('ALTER TABLE order_items ADD COLUMN stock_code TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE order_items ADD COLUMN uom TEXT');
      } catch (_) {}
    }
  }

  // --- Driver Queries ---

  Future<Driver?> authenticateDriver(String username, String password) async {
    // 1. Direct match on username and password
    final results = await _db.query(
      'drivers',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
      limit: 1,
    );

    if (results.isNotEmpty) {
      return Driver.fromMap(results.first);
    }

    // 2. Hardcoded password support ('123' or 'password123')
    if (password == '123' || password == 'password123') {
      final byUsername = await getDriverByUsername(username);
      if (byUsername != null) {
        return byUsername;
      }
    }

    return null;
  }

  Future<Driver> insertOrUpdateDriver(Driver driver) async {
    final existing = await getDriverByUsername(driver.username);
    if (existing != null) {
      await _db.update(
        'drivers',
        driver.toMap(),
        where: 'id = ?',
        whereArgs: [existing.id],
      );
      return driver.copyWith(id: existing.id);
    } else {
      final id = await _db.insert(
        'drivers',
        driver.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return driver.copyWith(id: id);
    }
  }

  Future<void> updateDriverPin(String username, String pin) async {
    await _db.update(
      'drivers',
      {'pin': pin},
      where: 'username = ?',
      whereArgs: [username],
    );
  }

  Future<void> logoutAndClearData() async {
    try {
      await _db.execute('PRAGMA foreign_keys = OFF');
      await _db.delete('delivery_orders');
      await _db.delete('order_items');
      await _db.delete('receipts');
      await _db.delete('drivers');
      await _db.execute('PRAGMA foreign_keys = ON');

      // Re-seed default driver and initial data
      await _seedData(_db);

      // Clear driver session preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(ApiClient.keyDriverCode);
      await prefs.remove('remember_me');

      debugPrint('DatabaseService: All tables cleared and reset on logout.');

      Get.snackbar(
        'Logged Out',
        'All local data has been cleared successfully.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEFFFEE),
        colorText: const Color(0xFF10B981),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      debugPrint('Error clearing tables on logout: $e');
    } finally {
      Get.offAllNamed(AppRoutes.login);
    }
  }

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

  // --- Delivery Orders Queries ---

  Future<List<DeliveryOrder>> getAllDeliveryOrders() async {
    final results = await _db.query('delivery_orders');
    return results.map((map) => DeliveryOrder.fromMap(map)).toList();
  }

  Future<void> saveDeliveryOrdersBatch(List<DeliveryOrder> orders) async {
    final batch = _db.batch();
    for (final order in orders) {
      batch.insert(
        'delivery_orders',
        order.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateDeliveryOrderStatus(String orderId, String newStatus) async {
    await _db.update(
      'delivery_orders',
      {'status': newStatus},
      where: 'id = ? OR transaction_id = ?',
      whereArgs: [orderId, orderId],
    );
  }

  // --- Order Items Queries ---

  Future<List<OrderItem>> getOrderItems(String deliveryOrderId) async {
    final results = await _db.query(
      'order_items',
      where: 'delivery_order_id = ?',
      whereArgs: [deliveryOrderId],
    );

    return results.map((map) => OrderItem.fromMap(map)).toList();
  }

  Future<List<OrderItem>> getAllOrderItems() async {
    final results = await _db.query('order_items');
    return results.map((map) => OrderItem.fromMap(map)).toList();
  }

  Future<void> saveOrderItemsBatch(List<OrderItem> items) async {
    final batch = _db.batch();
    for (final item in items) {
      batch.insert(
        'order_items',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<int> insertOrderItem(OrderItem item) async {
    return await _db.insert('order_items', item.toMap());
  }

  Future<int> deleteOrderItems(String deliveryOrderId) async {
    return await _db.delete(
      'order_items',
      where: 'delivery_order_id = ?',
      whereArgs: [deliveryOrderId],
    );
  }

  // --- Receipts Queries ---

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
