import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/run_model.dart';
import '../models/user_model.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('runs.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, // Upgraded from version 1
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT,
        createdDate TEXT
      )
    ''');

    // Create a default user immediately since existing runs need to belong somewhere
    await db.execute('''
      INSERT INTO users (id, name, createdDate) 
      VALUES ('default_user', 'The Big Yahu', '${DateTime.now().toIso8601String()}')
    ''');

    await db.execute('''
      CREATE TABLE runs (
        id TEXT PRIMARY KEY,
        name TEXT,
        timestamp TEXT,
        nodeDistances TEXT,
        voltageData TEXT,
        gateTimeOffsets TEXT,
        userId TEXT,
        notes TEXT,
        FOREIGN KEY (userId) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 1. Create the new users table
      await db.execute('''
        CREATE TABLE users (
          id TEXT PRIMARY KEY,
          name TEXT,
          createdDate TEXT
        )
      ''');

      // 2. Insert a default user
      await db.execute('''
        INSERT INTO users (id, name, createdDate) 
        VALUES ('default_user', 'Default Athlete', '${DateTime.now().toIso8601String()}')
      ''');

      // 3. Add new columns to existing runs table for older versions
      // SQLite ALTER TABLE doesn't support multiple columns natively in one statement easily without rebuilding,
      // but simple ADD COLUMN works for one by one.
      await db.execute("ALTER TABLE runs ADD COLUMN nodeDistances TEXT");
      await db.execute("ALTER TABLE runs ADD COLUMN userId TEXT");

      // Update existing records to have a valid user ID
      await db.execute(
        "UPDATE runs SET userId = 'default_user' WHERE userId IS NULL",
      );

      // Assume existing records had 4 equal lengths adding up to 100m (= [25, 25, 25, 25]).
      await db.execute(
        "UPDATE runs SET nodeDistances = '[25.0,25.0,25.0,25.0]' WHERE nodeDistances IS NULL",
      );
    }
  }

  Future<void> saveRun(Run run) async {
    final db = await database;
    await db.insert(
      'runs',
      run.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Run>> getAllRuns() async {
    final db = await database;
    final result = await db.query('runs', orderBy: 'timestamp DESC');
    return result.map((json) => Run.fromMap(json)).toList();
  }

  Future<List<Run>> getRunsByUser(String userId) async {
    final db = await database;
    final result = await db.query(
      'runs',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
    );
    return result.map((json) => Run.fromMap(json)).toList();
  }

  Future<void> saveUser(User user) async {
    final db = await database;
    await db.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<User>> getAllUsers() async {
    final db = await database;
    final result = await db.query('users', orderBy: 'createdDate DESC');
    return result.map((json) => User.fromMap(json)).toList();
  }

  Future<void> deleteUser(String id) async {
    final db = await database;
    await db.delete('users', where: 'id = ?', whereArgs: [id]);
    // Note: Due to foreign constraints (if enforced natively by SQLite PRAGMA),
    // runs will be deleted automatically. Otherwise we delete manually.
    await db.delete('runs', where: 'userId = ?', whereArgs: [id]);
  }

  Future<void> deleteRun(String id) async {
    final db = await database;
    await db.delete('runs', where: 'id = ?', whereArgs: [id]);
  }
}
