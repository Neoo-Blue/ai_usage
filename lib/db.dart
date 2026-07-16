import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

// Raw sqflite store. Schema is identical to the Drift design we signed off;
// this cut avoids code generation so the APK builds without a build_runner step.
class Db {
  Db._();
  static final Db instance = Db._();
  Database? _db;

  Future<Database> get _database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, 'ai_usage.db'),
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE accounts(
            id TEXT PRIMARY KEY,
            provider TEXT NOT NULL,
            kind TEXT NOT NULL,
            label TEXT NOT NULL,
            remote_user_id TEXT,
            plan_name TEXT,
            status TEXT NOT NULL,
            last_sync_at TEXT,
            created_at TEXT NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE metric_snapshots(
            account_id TEXT NOT NULL,
            metric_type TEXT NOT NULL,
            num_value REAL,
            text_value TEXT,
            unit TEXT,
            captured_at TEXT NOT NULL,
            PRIMARY KEY(account_id, metric_type)
          )''');
        await db.execute('''
          CREATE TABLE provider_health(
            provider TEXT PRIMARY KEY,
            consecutive_failures INTEGER NOT NULL DEFAULT 0,
            open_until TEXT,
            last_error TEXT,
            updated_at TEXT NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE widget_configs(
            id TEXT PRIMARY KEY,
            account_id TEXT,
            theme TEXT NOT NULL,
            metric_types TEXT NOT NULL,
            size TEXT NOT NULL DEFAULT 'medium',
            created_at TEXT NOT NULL
          )''');
      },
    );
  }

  // Accounts
  Future<void> insertAccount(Account a) async {
    final db = await _database;
    await db.insert('accounts', a.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Account>> allAccounts() async {
    final db = await _database;
    final rows = await db.query('accounts', orderBy: 'created_at DESC');
    return rows.map(Account.fromMap).toList();
  }

  Future<Account?> accountById(String id) async {
    final db = await _database;
    final rows = await db.query('accounts', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Account.fromMap(rows.first);
  }

  Future<Account?> findByRemote(ProviderId provider, String remoteUserId) async {
    final db = await _database;
    final rows = await db.query('accounts',
        where: 'provider = ? AND remote_user_id = ?',
        whereArgs: [provider.name, remoteUserId],
        limit: 1);
    return rows.isEmpty ? null : Account.fromMap(rows.first);
  }

  Future<void> deleteAccount(String id) async {
    final db = await _database;
    await db.delete('metric_snapshots', where: 'account_id = ?', whereArgs: [id]);
    await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setStatus(String id, AccountStatus status) async {
    final db = await _database;
    await db.update('accounts', {'status': status.name}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setSynced(String id) async {
    final db = await _database;
    await db.update(
      'accounts',
      {'status': AccountStatus.active.name, 'last_sync_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Metrics
  Future<void> upsertMetric(MetricRow m) async {
    final db = await _database;
    await db.insert(
      'metric_snapshots',
      {
        'account_id': m.accountId,
        'metric_type': m.metricType,
        'num_value': m.numValue,
        'text_value': m.textValue,
        'unit': m.unit,
        'captured_at': m.capturedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MetricRow>> metricsFor(String accountId) async {
    final db = await _database;
    final rows = await db.query('metric_snapshots', where: 'account_id = ?', whereArgs: [accountId]);
    return rows.map(MetricRow.fromMap).toList();
  }

  // Circuit breaker state
  Future<Map<String, Object?>?> healthFor(ProviderId provider) async {
    final db = await _database;
    final rows =
        await db.query('provider_health', where: 'provider = ?', whereArgs: [provider.name], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> writeHealth(ProviderId provider,
      {required int failures, DateTime? openUntil, String? lastError}) async {
    final db = await _database;
    await db.insert(
      'provider_health',
      {
        'provider': provider.name,
        'consecutive_failures': failures,
        'open_until': openUntil?.toIso8601String(),
        'last_error': lastError,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
