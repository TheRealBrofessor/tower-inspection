import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' as sqflite;

class AppDatabase {
  AppDatabase({sqflite.DatabaseFactory? factory, this.databasePath})
    : _factory = factory ?? sqflite.databaseFactory;

  static const currentVersion = 1;

  final sqflite.DatabaseFactory _factory;
  final String? databasePath;
  sqflite.Database? _database;

  Future<sqflite.Database> get database async {
    final existing = _database;
    if (existing != null && existing.isOpen) return existing;

    final resolvedPath =
        databasePath ??
        path.join(await _factory.getDatabasesPath(), 'tower_inspection.db');
    final opened = await _factory.openDatabase(
      resolvedPath,
      options: sqflite.OpenDatabaseOptions(
        version: currentVersion,
        onConfigure: _configure,
        onCreate: (database, version) => _migrate(database, 0, version),
        onUpgrade: _migrate,
        onDowngrade: (database, oldVersion, newVersion) {
          throw StateError(
            'Database downgrade from $oldVersion to $newVersion is unsupported.',
          );
        },
      ),
    );
    _database = opened;
    return opened;
  }

  Future<void> close() async {
    final database = _database;
    _database = null;
    if (database != null && database.isOpen) await database.close();
  }

  Future<void> _configure(sqflite.Database database) async {
    await database.execute('PRAGMA foreign_keys = ON');
    await database.execute('PRAGMA journal_mode = WAL');
  }

  Future<void> _migrate(
    sqflite.Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 1 && newVersion >= 1) {
      await database.execute('''
        CREATE TABLE schema_version (
          version INTEGER PRIMARY KEY,
          applied_at TEXT NOT NULL
        )
      ''');
      await database.execute('''
        CREATE TABLE inspections (
          id TEXT PRIMARY KEY,
          template_version TEXT NOT NULL,
          site_name TEXT NOT NULL DEFAULT '',
          asr TEXT NOT NULL DEFAULT '',
          prepared_for TEXT NOT NULL DEFAULT '',
          inspection_date TEXT NOT NULL DEFAULT '',
          status TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await database.execute('''
        CREATE TABLE item_responses (
          inspection_id TEXT NOT NULL,
          item_id TEXT NOT NULL,
          status TEXT,
          comments TEXT NOT NULL DEFAULT '',
          PRIMARY KEY (inspection_id, item_id),
          FOREIGN KEY (inspection_id) REFERENCES inspections(id)
            ON DELETE CASCADE
        )
      ''');
      await database.execute('''
        CREATE TABLE photo_attachments (
          id TEXT PRIMARY KEY,
          inspection_id TEXT NOT NULL,
          item_id TEXT NOT NULL,
          order_index INTEGER NOT NULL,
          original_path TEXT NOT NULL,
          report_path TEXT NOT NULL,
          captured_at TEXT NOT NULL,
          metadata_json TEXT NOT NULL DEFAULT '{}',
          FOREIGN KEY (inspection_id, item_id)
            REFERENCES item_responses(inspection_id, item_id)
            ON DELETE CASCADE,
          UNIQUE (inspection_id, item_id, order_index)
        )
      ''');
      await database.execute('''
        CREATE TABLE reports (
          id TEXT PRIMARY KEY,
          inspection_id TEXT NOT NULL,
          file_path TEXT NOT NULL,
          created_at TEXT NOT NULL,
          metadata_json TEXT NOT NULL DEFAULT '{}',
          FOREIGN KEY (inspection_id) REFERENCES inspections(id)
            ON DELETE CASCADE
        )
      ''');
      await database.execute('''
        CREATE INDEX item_responses_inspection_idx
        ON item_responses(inspection_id)
      ''');
      await database.execute('''
        CREATE INDEX photo_attachments_item_idx
        ON photo_attachments(inspection_id, item_id, order_index)
      ''');
      await database.execute('''
        CREATE INDEX reports_inspection_idx
        ON reports(inspection_id)
      ''');
      await database.insert('schema_version', {
        'version': 1,
        'applied_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
  }
}
