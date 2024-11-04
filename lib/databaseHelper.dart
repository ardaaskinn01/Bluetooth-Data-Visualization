import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'device.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'devices.db');
    return await openDatabase(
      path,
      onCreate: (db, version) async {
        await db.execute('''
  CREATE TABLE devices6(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uuid TEXT,
    name TEXT,
    temperature REAL,
    isConnected INTEGER,
    temperatureHistory TEXT,  
    bluetoothDevice TEXT
  )
  ''');
      },
      version: 6,
    );
  }

  Future<void> insertDevice(Device device) async {
    final db = await database;
    await db.insert(
      'devices6',
      device.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> deviceExists(String name) async {
    final db = await database;
    final result = await db.query(
      'devices6',
      where: 'name = ?',
      whereArgs: [name],
    );
    return result.isNotEmpty;
  }

  Future<void> insertDeviceName(String uuid, String name) async {
    final db = await database;
    await db.update(
      'devices6',
      {'name': name},
      where: 'uuid = ?', // Use UUID to update the specific device
      whereArgs: [uuid],
    );
  }

  Future<String?> getDeviceName(String uuid) async {
    final db = await database;
    final result = await db.query(
      'devices6',
      columns: ['name'],
      where: 'uuid = ?', // Use UUID to query a specific device
      whereArgs: [uuid],
    );
    return result.isNotEmpty ? result.first['name'] as String : null;
  }

  Future<List<Device>> getDevices() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('devices6');
    return List.generate(maps.length, (i) {
      return Device.fromJson(maps[i]);
    });
  }

  Future<void> deleteDevice(String uuid) async {
    final db = await database;
    await db.delete(
      'devices6',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }
}
