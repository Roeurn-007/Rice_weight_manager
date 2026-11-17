import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/harvest.dart';
import '../models/weight_entry.dart';
import '../models/weight_group.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('rice_weight_manager.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute("ALTER TABLE harvest_records ADD COLUMN currency TEXT DEFAULT 'KHR';");
          } catch (_) {}
        }
      },
      onOpen: (db) async {
        // Ensure currency column exists even if database was opened previously without migration
        try {
          await db.execute("ALTER TABLE harvest_records ADD COLUMN currency TEXT DEFAULT 'KHR';");
        } catch (_) {}
        // Ensure app_settings table exists
        try {
          await db.execute("CREATE TABLE IF NOT EXISTS app_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);");
        } catch (_) {}
        // Performance indexes: Ensure instantaneous queries even with thousands of harvests & millions of sacks
        try {
          await db.execute("CREATE INDEX IF NOT EXISTS idx_weight_groups_harvest_id ON weight_groups(harvest_id);");
          await db.execute("CREATE INDEX IF NOT EXISTS idx_weight_entries_group_id ON weight_entries(group_id);");
          await db.execute("CREATE INDEX IF NOT EXISTS idx_harvest_records_status ON harvest_records(status);");
        } catch (_) {}
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE harvest_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        harvest_date TEXT NOT NULL,
        rice_field_count INTEGER,
        notes TEXT,
        status TEXT NOT NULL,
        price_per_kg REAL,
        currency TEXT DEFAULT 'KHR',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE weight_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        harvest_id INTEGER NOT NULL,
        group_number INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (harvest_id) REFERENCES harvest_records (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE weight_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        group_id INTEGER NOT NULL,
        weight REAL NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (group_id) REFERENCES weight_groups (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_weight_groups_harvest_id ON weight_groups(harvest_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_weight_entries_group_id ON weight_entries(group_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_harvest_records_status ON harvest_records(status);');
  }

  // -------------------------------------------------------------
  // App Settings
  // -------------------------------------------------------------

  Future<void> saveSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final results = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (results.isNotEmpty) {
      return results.first['value'] as String?;
    }
    return null;
  }

  // -------------------------------------------------------------
  // Harvest CRUD
  // -------------------------------------------------------------

  Future<int> insertHarvest(Harvest harvest) async {
    final db = await database;
    final id = await db.insert('harvest_records', harvest.toMap());
    return id;
  }

  Future<int> updateHarvest(Harvest harvest) async {
    final db = await database;
    return await db.update(
      'harvest_records',
      harvest.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [harvest.id],
    );
  }

  Future<int> deleteHarvest(int harvestId) async {
    final db = await database;
    return await db.delete(
      'harvest_records',
      where: 'id = ?',
      whereArgs: [harvestId],
    );
  }

  Future<Harvest?> getHarvest(int id) async {
    final db = await database;
    final results = await db.query(
      'harvest_records',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isNotEmpty) {
      return Harvest.fromMap(results.first);
    }
    return null;
  }

  Future<List<Harvest>> getAllHarvests({
    String? searchQuery,
    String? statusFilter, // 'all', 'in_progress', 'completed'
  }) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    List<String> conditions = [];
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      conditions.add('name LIKE ?');
      whereArgs.add('%${searchQuery.trim()}%');
    }

    if (statusFilter != null && statusFilter != 'all') {
      conditions.add('status = ?');
      whereArgs.add(statusFilter);
    }

    if (conditions.isNotEmpty) {
      whereClause = conditions.join(' AND ');
    }

    final result = await db.query(
      'harvest_records',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'id DESC',
    );

    return result.map((map) => Harvest.fromMap(map)).toList();
  }

  Future<void> updateHarvestStatus(int harvestId, String status) async {
    final db = await database;
    await db.update(
      'harvest_records',
      {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [harvestId],
    );
  }

  Future<void> updateHarvestPrice(int harvestId, double? pricePerKg, {String currency = 'KHR'}) async {
    final db = await database;
    await db.update(
      'harvest_records',
      {
        'price_per_kg': pricePerKg,
        'currency': currency,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [harvestId],
    );
  }

  // -------------------------------------------------------------
  // Weight Groups & Entries Operations
  // -------------------------------------------------------------

  /// Get all groups for a harvest, with each group containing its entries in order
  Future<List<WeightGroup>> getGroupsWithEntries(int harvestId) async {
    final db = await database;

    final groupMaps = await db.query(
      'weight_groups',
      where: 'harvest_id = ?',
      whereArgs: [harvestId],
      orderBy: 'group_number ASC',
    );

    List<WeightGroup> groups = [];
    for (var gMap in groupMaps) {
      final groupId = gMap['id'] as int;
      final entryMaps = await db.query(
        'weight_entries',
        where: 'group_id = ?',
        whereArgs: [groupId],
        orderBy: 'id ASC',
      );

      final entries = entryMaps.map((e) => WeightEntry.fromMap(e)).toList();
      groups.add(WeightGroup.fromMap(gMap, entries: entries));
    }

    return groups;
  }

  /// Adds a weight entry following the 5-entry group rule:
  /// - Finds the latest group.
  /// - If no group exists or latest has >= 5 entries, automatically creates group N+1.
  /// - Saves to SQLite immediately.
  Future<WeightEntry> addWeightEntry(int harvestId, double weight) async {
    final db = await database;

    final groups = await getGroupsWithEntries(harvestId);

    int targetGroupId;
    if (groups.isEmpty) {
      // Create Group 1
      targetGroupId = await db.insert('weight_groups', {
        'harvest_id': harvestId,
        'group_number': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
    } else {
      final latestGroup = groups.last;
      if (latestGroup.entries.length >= 5) {
        // Create new group
        targetGroupId = await db.insert('weight_groups', {
          'harvest_id': harvestId,
          'group_number': latestGroup.groupNumber + 1,
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        targetGroupId = latestGroup.id!;
      }
    }

    final entryId = await db.insert('weight_entries', {
      'group_id': targetGroupId,
      'weight': weight,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    // Touch harvest updated_at
    await db.update(
      'harvest_records',
      {'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [harvestId],
    );

    return WeightEntry(
      id: entryId,
      groupId: targetGroupId,
      weight: weight,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> updateWeightEntry(int entryId, double newWeight, int harvestId) async {
    final db = await database;
    await db.update(
      'weight_entries',
      {
        'weight': newWeight,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [entryId],
    );

    await db.update(
      'harvest_records',
      {'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [harvestId],
    );
  }

  Future<void> deleteWeightEntry(int entryId, int groupId, int harvestId) async {
    final db = await database;
    await db.delete(
      'weight_entries',
      where: 'id = ?',
      whereArgs: [entryId],
    );

    // If the group is now empty, check if we should delete the empty group
    final remainingInGroup = await db.query(
      'weight_entries',
      where: 'group_id = ?',
      whereArgs: [groupId],
    );

    if (remainingInGroup.isEmpty) {
      await db.delete('weight_groups', where: 'id = ?', whereArgs: [groupId]);
      // Re-number remaining groups to keep sequential group numbers
      final remainingGroups = await db.query(
        'weight_groups',
        where: 'harvest_id = ?',
        whereArgs: [harvestId],
        orderBy: 'group_number ASC',
      );
      for (int i = 0; i < remainingGroups.length; i++) {
        final gId = remainingGroups[i]['id'] as int;
        await db.update(
          'weight_groups',
          {'group_number': i + 1},
          where: 'id = ?',
          whereArgs: [gId],
        );
      }
    }

    await db.update(
      'harvest_records',
      {'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [harvestId],
    );
  }

  /// Deletes an entire weight group and all its entries, then re-numbers
  /// subsequent groups to maintain sequential 1, 2, 3... group numbering.
  Future<void> deleteWeightGroup(int groupId, int harvestId) async {
    final db = await database;
    // 1. Delete all weight entries belonging to this group
    await db.delete(
      'weight_entries',
      where: 'group_id = ?',
      whereArgs: [groupId],
    );

    // 2. Delete the group record
    await db.delete(
      'weight_groups',
      where: 'id = ?',
      whereArgs: [groupId],
    );

    // 3. Re-number remaining groups sequentially
    final remainingGroups = await db.query(
      'weight_groups',
      where: 'harvest_id = ?',
      whereArgs: [harvestId],
      orderBy: 'group_number ASC',
    );
    for (int i = 0; i < remainingGroups.length; i++) {
      final gId = remainingGroups[i]['id'] as int;
      await db.update(
        'weight_groups',
        {'group_number': i + 1},
        where: 'id = ?',
        whereArgs: [gId],
      );
    }

    // 4. Update harvest timestamp
    await db.update(
      'harvest_records',
      {'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [harvestId],
    );
  }

  // -------------------------------------------------------------
  // Calculations & Summaries
  // -------------------------------------------------------------

  /// Calculates total weight directly from all individual weight entries
  /// strictly avoiding double-counting group subtotals.
  Future<double> getTotalWeightForHarvest(int harvestId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT SUM(we.weight) as total_weight
      FROM weight_entries we
      INNER JOIN weight_groups wg ON we.group_id = wg.id
      WHERE wg.harvest_id = ?
    ''', [harvestId]);

    if (result.isNotEmpty && result.first['total_weight'] != null) {
      return (result.first['total_weight'] as num).toDouble();
    }
    return 0.0;
  }

  /// Get home screen dashboard counts
  Future<Map<String, dynamic>> getDashboardCounts() async {
    final db = await database;
    final totalResult = await db.rawQuery('SELECT COUNT(*) as count FROM harvest_records');
    final inProgressResult = await db.rawQuery(
      "SELECT COUNT(*) as count FROM harvest_records WHERE status = 'in_progress'",
    );
    final completedResult = await db.rawQuery(
      "SELECT COUNT(*) as count FROM harvest_records WHERE status = 'completed'",
    );

    return {
      'total': Sqflite.firstIntValue(totalResult) ?? 0,
      'in_progress': Sqflite.firstIntValue(inProgressResult) ?? 0,
      'completed': Sqflite.firstIntValue(completedResult) ?? 0,
    };
  }

  /// Get distinct weights usually used by the user.
  /// Prioritizes weights used in the current harvest, then across all harvests.
  Future<List<double>> getFrequentWeights({int? harvestId}) async {
    final db = await database;
    final List<double> result = [];

    // 1. Get most recent / frequent weights from current harvest if available
    if (harvestId != null) {
      final currentRows = await db.rawQuery('''
        SELECT we.weight, COUNT(*) as cnt, MAX(we.id) as max_id
        FROM weight_entries we
        INNER JOIN weight_groups wg ON we.group_id = wg.id
        WHERE wg.harvest_id = ?
        GROUP BY we.weight
        ORDER BY max_id DESC, cnt DESC
        LIMIT 6
      ''', [harvestId]);

      for (var row in currentRows) {
        if (row['weight'] != null) {
          final w = (row['weight'] as num).toDouble();
          if (!result.contains(w)) {
            result.add(w);
          }
        }
      }
    }

    // 2. If fewer than 5 weights found, supplement from other harvests
    if (result.length < 5) {
      final allRows = await db.rawQuery('''
        SELECT weight, COUNT(*) as cnt, MAX(id) as max_id
        FROM weight_entries
        GROUP BY weight
        ORDER BY max_id DESC, cnt DESC
        LIMIT 6
      ''');

      for (var row in allRows) {
        if (row['weight'] != null) {
          final w = (row['weight'] as num).toDouble();
          if (!result.contains(w)) {
            result.add(w);
            if (result.length >= 6) break;
          }
        }
      }
    }

    // 3. Fallback defaults if database has no weights recorded yet
    final defaultFallbacks = [50.0, 51.0, 52.0, 49.0, 48.0];
    for (var def in defaultFallbacks) {
      if (result.length >= 5) break;
      if (!result.contains(def)) {
        result.add(def);
      }
    }

    return result;
  }
}
