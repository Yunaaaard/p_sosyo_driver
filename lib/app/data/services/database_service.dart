import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:p_sosyo_driver/app/core/constants/app_constants.dart';
import 'package:p_sosyo_driver/app/core/utils/app_logger.dart';
import 'package:p_sosyo_driver/app/data/models/delivery_attempt.dart';
import 'package:p_sosyo_driver/app/data/models/delivery_order.dart';
import 'package:p_sosyo_driver/app/data/models/driver.dart';
import 'package:p_sosyo_driver/app/data/models/order_item.dart';
import 'package:p_sosyo_driver/app/data/models/pending_transaction.dart';
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
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    // Clean up any residual mock data 'TINDAHAN NI ALING NENA' or order '1' or legacy transactionID ids
    await _db.delete('delivery_orders', where: "id = '1' OR transaction_id = 'TXN-001' OR store_name LIKE '%ALING NENA%' OR id LIKE 'UV10%'");
    await _db.delete('order_items', where: "delivery_order_id = '1' OR delivery_order_id = 'TXN-001' OR delivery_order_id LIKE 'UV10%'");

    // Ensure required columns exist without triggering native SQLiteLog errors
    await _ensureColumnExists('delivery_orders', 'cust_code', 'TEXT');
    await _ensureColumnExists('delivery_orders', 'store_photo', 'TEXT');
    await _ensureColumnExists('delivery_orders', 'delivered_at', 'TEXT');
    await _ensureColumnExists('delivery_orders', 'payment_reference', 'TEXT');
    await _ensureColumnExists('delivery_orders', 's3_proof_of_delivery_path', 'TEXT');
    await _ensureColumnExists('delivery_orders', 'cancellation_reason', 'TEXT');
    await _ensureColumnExists('delivery_orders', 'customer_phone', 'TEXT');
    await _ensureColumnExists('delivery_orders', 'order_remarks', 'TEXT');
    await _ensureColumnExists('delivery_orders', 'attempt_count', 'INTEGER DEFAULT 0');
    await _ensureColumnExists('delivery_orders', 'last_attempt_reason', 'TEXT');
    await _ensureColumnExists('delivery_orders', 'last_attempt_at', 'TEXT');
    await _ensureColumnExists('delivery_orders', 'out_for_delivery_sms_sent_at', 'TEXT');
    await _ensureColumnExists('delivery_orders', 'is_locked', 'INTEGER DEFAULT 0');
    await _ensureColumnExists('delivery_orders', 'scheduled_delivery_date', 'TEXT');
    await _ensureColumnExists('delivery_orders', 'locked_at', 'TEXT');
    await _ensureColumnExists('delivery_orders', 'route_sequence', 'INTEGER');
    await _ensureColumnExists('delivery_orders', 'payment_method', "TEXT DEFAULT 'Cash'");
    await _ensureColumnExists('delivery_orders', 'is_early_priority', 'INTEGER DEFAULT 0');
    await _ensureColumnExists('delivery_orders', 'delivery_window', "TEXT DEFAULT 'normal'");
    await _ensureColumnExists('delivery_orders', 'sync_status', "TEXT DEFAULT 'synced'");
    await _ensureColumnExists('delivery_orders', 'created_at', 'TEXT');
    await _ensureColumnExists('order_items', 'category', 'TEXT');
    await _ensureColumnExists('order_items', 'adjustment_reason', 'TEXT');
    await _ensureColumnExists('pending_transactions', 'transtat', 'INTEGER DEFAULT 2');
    await _ensureColumnExists('order_items', 'original_qty', 'INTEGER');
    await _ensureColumnExists('receipts', 'customer_name', 'TEXT');
    await _ensureColumnExists('receipts', 's3_proof_of_delivery_path', 'TEXT');
    await _ensureColumnExists('receipts', 'created_at', 'TEXT');

    await _db.execute('''
      CREATE TABLE IF NOT EXISTS delivery_attempts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        delivery_order_id TEXT NOT NULL,
        attempt_number INTEGER NOT NULL,
        reason TEXT NOT NULL,
        remarks TEXT,
        sms_sent INTEGER NOT NULL DEFAULT 0,
        attempted_at TEXT NOT NULL,
        rescheduled_date TEXT,
        created_at TEXT
      )
    ''');
    await _ensureColumnExists('delivery_attempts', 'rescheduled_date', 'TEXT');
    await _ensureColumnExists('delivery_attempts', 'created_at', 'TEXT');

    await _db.execute('''
      CREATE TABLE IF NOT EXISTS pending_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id TEXT NOT NULL,
        store_name TEXT NOT NULL,
        action_type TEXT NOT NULL,
        amount TEXT NOT NULL,
        summary TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        synced_at TEXT,
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      )
    ''');

    // Backfill photos for known sandbox orders if missing
    try {
      await _db.execute('''
        UPDATE delivery_orders
        SET cust_code = 'DG18159',
            store_photo = 'https://filezsystem.sgp1.vultrobjects.com/STOREIMAGE/MNC/SANDBOX01/dg18159_1.jpg'
        WHERE id = 'R92611051' AND (cust_code IS NULL OR cust_code = '')
      ''');
      await _db.execute('''
        UPDATE delivery_orders
        SET cust_code = 'DG423801',
            store_photo = 'https://filezsystem.sgp1.vultrobjects.com/STOREIMAGE/MNC/SANDBOX01/dg423801_1.jpg'
        WHERE id = 'R92611052' AND (cust_code IS NULL OR cust_code = '')
      ''');
    } catch (_) {}

    // Deduplicate any duplicate items in existing databases
    try {
      await _db.execute('''
        DELETE FROM order_items
        WHERE id NOT IN (
          SELECT MIN(id)
          FROM order_items
          GROUP BY delivery_order_id, stock_code
        )
      ''');
    } catch (_) {}

    return this;
  }

  Future<void> _ensureColumnExists(
    String table,
    String column,
    String definition,
  ) async {
    try {
      final info = await _db.rawQuery('PRAGMA table_info($table)');
      final exists = info.any((row) => row['name'] == column);
      if (!exists) {
        await _db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
      }
    } catch (e, stack) {
      logError('Error ensuring column $table.$column exists', e, stack);
    }
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
        cust_code TEXT,
        store_photo TEXT,
        store_name TEXT NOT NULL,
        address TEXT NOT NULL,
        distance TEXT,
        sku_count INTEGER NOT NULL,
        total_amount REAL NOT NULL,
        status TEXT NOT NULL,
        delivery_date TEXT,
        latitude REAL,
        longitude REAL,
        delivered_at TEXT,
        payment_reference TEXT,
        s3_proof_of_delivery_path TEXT,
        cancellation_reason TEXT,
        customer_phone TEXT,
        order_remarks TEXT,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_attempt_reason TEXT,
        last_attempt_at TEXT,
        out_for_delivery_sms_sent_at TEXT,
        is_locked INTEGER NOT NULL DEFAULT 0,
        scheduled_delivery_date TEXT,
        locked_at TEXT,
        route_sequence INTEGER,
        payment_method TEXT NOT NULL DEFAULT 'Cash',
        is_early_priority INTEGER NOT NULL DEFAULT 0,
        delivery_window TEXT NOT NULL DEFAULT 'normal',
        sync_status TEXT NOT NULL DEFAULT 'synced',
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        delivery_order_id TEXT NOT NULL,
        stock_code TEXT,
        title TEXT NOT NULL,
        category TEXT,
        price REAL NOT NULL,
        ordered_qty TEXT NOT NULL,
        total_amount REAL NOT NULL,
        uom TEXT,
        created_at TEXT NOT NULL,
        adjustment_reason TEXT,
        original_qty INTEGER
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
        scanned_at TEXT NOT NULL,
        customer_name TEXT,
        s3_proof_of_delivery_path TEXT,
        created_at TEXT
      )
    ''');

    await _seedData(db);
  }

  Future<void> _seedData(Database db) async {
    await db.insert('drivers', Driver(
      username: 'SBRM007',
      password: '123',
      fullName: 'DRP1 - DRP1',
      pin: '',
    ).toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

    logImportant('DatabaseService: Seeded default driver SBRM007.');
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
    if (oldVersion < 4) {
      await db.delete('delivery_orders', where: "id = '1' OR transaction_id = 'TXN-001' OR store_name LIKE '%ALING NENA%'");
      await db.delete('order_items', where: "delivery_order_id = '1' OR delivery_order_id = 'TXN-001'");
    }
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE delivery_orders ADD COLUMN cust_code TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE delivery_orders ADD COLUMN store_photo TEXT');
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
      await _db.delete('delivery_attempts');
      await _db.delete('drivers');
      await _db.execute('PRAGMA foreign_keys = ON');

      // Re-seed default driver and initial data
      await _seedData(_db);

      // Clear driver session preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(ApiClient.keyDriverCode);
      await prefs.remove('remember_me');

      logImportant('DatabaseService: All tables cleared and reset on logout.');

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
    } catch (e, stack) {
      logError('Error clearing tables on logout', e, stack);
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

  Future<DeliveryOrder?> getDeliveryOrderById(String orderId) async {
    final results = await _db.query(
      'delivery_orders',
      where: 'id = ? OR transaction_id = ?',
      whereArgs: [orderId, orderId],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return DeliveryOrder.fromMap(results.first);
  }

  Future<void> markOrderSynced(String orderId) async {
    await _db.update(
      'delivery_orders',
      {'sync_status': 'synced'},
      where: 'id = ? OR transaction_id = ?',
      whereArgs: [orderId, orderId],
    );
  }

  Future<void> saveDeliveryOrdersBatch(List<DeliveryOrder> orders) async {
    final batch = _db.batch();
    // Preserve completed/cancelled history from previous dates while replacing active manifest
    batch.delete(
      'delivery_orders',
      where: "status = 'Out for Delivery' AND (is_locked IS NULL OR is_locked = 0)",
    );
    for (final order in orders) {
      batch.insert(
        'delivery_orders',
        order.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateDeliveryOrderStatus(
    String orderId,
    String newStatus, {
    String? deliveredAt,
    String? paymentReference,
    String? proofOfDeliveryPath,
    String? cancellationReason,
  }) async {
    final Map<String, Object?> updates = {
      'status': newStatus,
      'sync_status': 'pending',
    };
    if (deliveredAt != null) {
      updates['delivered_at'] = deliveredAt;
    }
    if (paymentReference != null) {
      updates['payment_reference'] = paymentReference;
      if (paymentReference.trim().isNotEmpty) {
        updates['payment_method'] = 'Digital/QR';
      }
    }
    if (proofOfDeliveryPath != null) {
      updates['s3_proof_of_delivery_path'] = proofOfDeliveryPath;
    }
    if (cancellationReason != null) {
      updates['cancellation_reason'] = cancellationReason;
    }
    await _db.update(
      'delivery_orders',
      updates,
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
    if (items.isEmpty) return;
    final orderIds = items.map((e) => e.deliveryOrderId).toSet();
    final batch = _db.batch();
    for (final orderId in orderIds) {
      batch.delete('order_items', where: 'delivery_order_id = ?', whereArgs: [orderId]);
    }
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

  // --- Delivery Attempts & Customer SMS Queries ---

  Future<int> insertDeliveryAttempt(DeliveryAttempt attempt) async {
    return await _db.insert('delivery_attempts', attempt.toMap());
  }

  Future<List<DeliveryAttempt>> getDeliveryAttempts(
      String deliveryOrderId) async {
    final results = await _db.query(
      'delivery_attempts',
      where: 'delivery_order_id = ?',
      whereArgs: [deliveryOrderId],
      orderBy: 'attempt_number ASC, id ASC',
    );
    return results.map((map) => DeliveryAttempt.fromMap(map)).toList();
  }

  Future<List<DeliveryAttempt>> getAllDeliveryAttempts() async {
    final results = await _db.query('delivery_attempts');
    return results.map((map) => DeliveryAttempt.fromMap(map)).toList();
  }

  Future<void> updateOrderAttemptState({
    required String orderId,
    required int attemptCount,
    required String lastAttemptReason,
    required String lastAttemptAt,
    bool? isLocked,
    String? scheduledDeliveryDate,
    String? lockedAt,
  }) async {
    final Map<String, Object?> updates = {
      'attempt_count': attemptCount,
      'last_attempt_reason': lastAttemptReason,
      'last_attempt_at': lastAttemptAt,
      'sync_status': 'pending',
    };
    if (isLocked != null) {
      updates['is_locked'] = isLocked ? 1 : 0;
      if (isLocked) {
        updates['route_sequence'] = null;
      }
    }
    if (scheduledDeliveryDate != null) {
      updates['scheduled_delivery_date'] = scheduledDeliveryDate;
    }
    if (lockedAt != null) {
      updates['locked_at'] = lockedAt;
    }
    await _db.update(
      'delivery_orders',
      updates,
      where: 'id = ? OR transaction_id = ?',
      whereArgs: [orderId, orderId],
    );
  }

  Future<void> updateOrderLockState({
    required String orderId,
    required bool isLocked,
    String? scheduledDeliveryDate,
    String? lockedAt,
    String? lastAttemptReason,
  }) async {
    final Map<String, Object?> updates = {
      'is_locked': isLocked ? 1 : 0,
      'scheduled_delivery_date': isLocked ? scheduledDeliveryDate : null,
      'locked_at': isLocked ? lockedAt : null,
    };
    if (lastAttemptReason != null) {
      updates['last_attempt_reason'] = lastAttemptReason;
    }
    await _db.update(
      'delivery_orders',
      updates,
      where: 'id = ? OR transaction_id = ?',
      whereArgs: [orderId, orderId],
    );
  }

  Future<void> updateOrderCustomerPhone(String orderId, String phone) async {
    await _db.update(
      'delivery_orders',
      {'customer_phone': phone.trim()},
      where: 'id = ? OR transaction_id = ?',
      whereArgs: [orderId, orderId],
    );
  }

  Future<void> markOutForDeliverySmsSent(String orderId, String sentAtIso) async {
    await _db.update(
      'delivery_orders',
      {'out_for_delivery_sms_sent_at': sentAtIso},
      where: 'id = ? OR transaction_id = ?',
      whereArgs: [orderId, orderId],
    );
  }

  Future<void> updateOrderPaymentReference(
    String orderId,
    String paymentReference,
  ) async {
    await _db.update(
      'delivery_orders',
      {'payment_reference': paymentReference.trim()},
      where: 'id = ? OR transaction_id = ?',
      whereArgs: [orderId, orderId],
    );
  }

  Future<void> applyWeeklyRoutePlan(
    List<({String orderId, String deliveryDate, int routeSequence})> assignments,
  ) async {
    if (assignments.isEmpty) return;
    final batch = _db.batch();
    for (final a in assignments) {
      batch.update(
        'delivery_orders',
        {
          'delivery_date': a.deliveryDate,
          'route_sequence': a.routeSequence,
        },
        where: 'id = ? OR transaction_id = ?',
        whereArgs: [a.orderId, a.orderId],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateOrderPaymentMethod(
    String orderId,
    String paymentMethod,
  ) async {
    await _db.update(
      'delivery_orders',
      {'payment_method': paymentMethod},
      where: 'id = ? OR transaction_id = ?',
      whereArgs: [orderId, orderId],
    );
  }

  Future<void> updateOrderDeliveryWindow(
    String orderId,
    String window,
  ) async {
    await _db.update(
      'delivery_orders',
      {
        'delivery_window': window,
        'is_early_priority': window == 'early' ? 1 : 0,
      },
      where: 'id = ? OR transaction_id = ?',
      whereArgs: [orderId, orderId],
    );
  }

  Future<void> updateOrderEarlyPriority(
    String orderId,
    bool isEarlyPriority,
  ) async {
    await _db.update(
      'delivery_orders',
      {'is_early_priority': isEarlyPriority ? 1 : 0},
      where: 'id = ? OR transaction_id = ?',
      whereArgs: [orderId, orderId],
    );
  }

  Future<void> markAllPendingSynced() async {
    await _db.update(
      'delivery_orders',
      {'sync_status': 'synced'},
      where: "sync_status = 'pending'",
    );
  }

  /// Checks whether the device currently has active internet connectivity.
  ///
  /// Uses a short TCP socket probe instead of DNS-only lookup so cached DNS
  /// entries do not falsely report online right after turning off Wi-Fi.
  Future<bool> hasInternetConnectivity() async {
    try {
      final socket = await Socket.connect(
        '8.8.8.8',
        53,
        timeout: const Duration(seconds: 2),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Queues a [PendingTransaction] in SQLite when offline (or marks synced when online).
  /// Returns `true` if queued offline as pending, `false` if already online.
  Future<bool> queueOfflineTransactionIfDisconnected({
    required String orderId,
    required String storeName,
    required String actionType,
    required String amount,
    required String summary,
    Map<String, dynamic>? payload,
  }) async {
    final online = await hasInternetConnectivity();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    if (!online) {
      await _db.insert(
        'pending_transactions',
        PendingTransaction(
          orderId: orderId,
          storeName: storeName,
          actionType: actionType,
          amount: amount,
          summary: summary,
          payloadJson: jsonEncode(payload ?? <String, dynamic>{}),
          status: 'pending',
          transtat: TranStat.pending,
          createdAt: nowIso,
        ).toMap(),
      );
      await _db.update(
        'delivery_orders',
        {'sync_status': 'pending'},
        where: 'id = ? OR transaction_id = ?',
        whereArgs: [orderId, orderId],
      );
      logWarning(
        'Offline detected: queued $actionType transaction for #$orderId ($storeName)',
        tag: 'OFFLINE_QUEUE',
      );
      return true;
    }

    await _db.insert(
      'pending_transactions',
      PendingTransaction(
        orderId: orderId,
        storeName: storeName,
        actionType: actionType,
        amount: amount,
        summary: summary,
        payloadJson: jsonEncode(payload ?? <String, dynamic>{}),
        status: 'synced',
        transtat: TranStat.success,
        createdAt: nowIso,
        syncedAt: nowIso,
      ).toMap(),
    );
    await _db.update(
      'delivery_orders',
      {'sync_status': 'synced'},
      where: 'id = ? OR transaction_id = ?',
      whereArgs: [orderId, orderId],
    );
    return false;
  }

  Future<int> insertTransaction(PendingTransaction txn) async {
    return await _db.insert('pending_transactions', txn.toMap());
  }

  Future<List<PendingTransaction>> getAllTransactions() async {
    final results = await _db.query(
      'pending_transactions',
      orderBy: 'id DESC',
    );
    return results.map((m) => PendingTransaction.fromMap(m)).toList();
  }

  Future<List<PendingTransaction>> getTransactionsByTranStat(int transtat) async {
    final results = await _db.query(
      'pending_transactions',
      where: 'transtat = ?',
      whereArgs: [transtat],
      orderBy: 'id DESC',
    );
    return results.map((m) => PendingTransaction.fromMap(m)).toList();
  }

  Future<List<PendingTransaction>> getPendingTransactions() async {
    final results = await _db.query(
      'pending_transactions',
      where: "transtat IN (?, ?) OR status IN ('pending', 'failed')",
      whereArgs: [TranStat.pending, TranStat.failed],
      orderBy: 'id DESC',
    );
    return results.map((m) => PendingTransaction.fromMap(m)).toList();
  }

  Future<int> getPendingTransactionCount() async {
    final rows = await _db.rawQuery(
      "SELECT COUNT(*) AS cnt FROM pending_transactions WHERE transtat IN (?, ?) OR status IN ('pending', 'failed')",
      [TranStat.pending, TranStat.failed],
    );
    return (rows.first['cnt'] as num?)?.toInt() ?? 0;
  }

  Future<void> updateTransactionStatus(
    int id, {
    required int transtat,
    required String status,
    String? lastError,
    bool incrementRetry = false,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    if (incrementRetry) {
      await _db.rawUpdate(
        'UPDATE pending_transactions SET transtat = ?, status = ?, retry_count = retry_count + 1, last_error = ? WHERE id = ?',
        [transtat, status, lastError, id],
      );
      return;
    }
    await _db.update(
      'pending_transactions',
      {
        'transtat': transtat,
        'status': status,
        if (transtat == TranStat.success) 'synced_at': nowIso,
        if (lastError != null) 'last_error': lastError,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAllPendingTransactionsSynced() async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    await _db.update(
      'pending_transactions',
      {
        'status': 'synced',
        'transtat': TranStat.success,
        'synced_at': nowIso,
      },
      where: "transtat IN (?, ?) OR status IN ('pending', 'failed')",
      whereArgs: [TranStat.pending, TranStat.failed],
    );
    await markAllPendingSynced();
  }

  Future<void> markPendingTransactionError(int id, String error) async {
    await _db.rawUpdate(
      'UPDATE pending_transactions SET retry_count = retry_count + 1, last_error = ?, transtat = ?, status = ? WHERE id = ?',
      [error, TranStat.failed, 'failed', id],
    );
  }

  Future<void> updateOrderItemDeliveryAdjustment({
    required int itemId,
    required String orderId,
    required int newQty,
    required double newItemTotal,
    required String reason,
    required int originalQty,
    required double newOrderTotal,
  }) async {
    await _db.update(
      'order_items',
      {
        'ordered_qty': '$newQty',
        'total_amount': newItemTotal,
        'adjustment_reason': reason,
        'original_qty': originalQty,
      },
      where: 'id = ?',
      whereArgs: [itemId],
    );
    await _db.update(
      'delivery_orders',
      {
        'total_amount': newOrderTotal,
        'sync_status': 'pending',
      },
      where: 'id = ? OR transaction_id = ?',
      whereArgs: [orderId, orderId],
    );
  }

  @override
  void onClose() {
    _db.close();
    super.onClose();
  }
}
