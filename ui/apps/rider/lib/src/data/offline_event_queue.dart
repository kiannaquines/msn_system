import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

enum QueuedEventType { location, status, cashCollection }

class QueuedEvent {
  const QueuedEvent({
    required this.id,
    required this.deliveryId,
    required this.type,
    required this.payload,
    required this.createdAt,
  });

  final String id;
  final String deliveryId;
  final QueuedEventType type;
  final Map<String, Object?> payload;
  final DateTime createdAt;
}

abstract interface class OfflineEventQueue {
  Future<void> enqueue(QueuedEvent event);
  Future<List<QueuedEvent>> pending();
  Future<void> remove(String id);
  Future<int> count();
}

class SqliteOfflineEventQueue implements OfflineEventQueue {
  Database? _database;

  Future<Database> get _db async {
    if (_database != null) return _database!;
    final directory = await getDatabasesPath();
    _database = await openDatabase(
      p.join(directory, 'mns_rider_queue.db'),
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE queued_events (
          id TEXT PRIMARY KEY,
          delivery_id TEXT NOT NULL,
          type TEXT NOT NULL,
          payload TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      '''),
    );
    return _database!;
  }

  @override
  Future<void> enqueue(QueuedEvent event) async {
    final db = await _db;
    await db.insert(
      'queued_events',
      {
        'id': event.id,
        'delivery_id': event.deliveryId,
        'type': event.type.name,
        'payload': jsonEncode(event.payload),
        'created_at': event.createdAt.toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  @override
  Future<List<QueuedEvent>> pending() async {
    final db = await _db;
    final rows = await db.query('queued_events', orderBy: 'created_at ASC');
    return rows
        .map((row) => QueuedEvent(
              id: row['id']! as String,
              deliveryId: row['delivery_id']! as String,
              type: QueuedEventType.values.byName(row['type']! as String),
              payload: (jsonDecode(row['payload']! as String) as Map)
                  .cast<String, Object?>(),
              createdAt: DateTime.parse(row['created_at']! as String),
            ))
        .toList(growable: false);
  }

  @override
  Future<void> remove(String id) async {
    final db = await _db;
    await db.delete('queued_events', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> count() async {
    final db = await _db;
    final result = await db.rawQuery('SELECT COUNT(*) AS total FROM queued_events');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}

class MemoryOfflineEventQueue implements OfflineEventQueue {
  final List<QueuedEvent> _events = [];

  @override
  Future<void> enqueue(QueuedEvent event) async {
    if (_events.every((existing) => existing.id != event.id)) {
      _events.add(event);
    }
  }

  @override
  Future<List<QueuedEvent>> pending() async => List.unmodifiable(_events);

  @override
  Future<void> remove(String id) async =>
      _events.removeWhere((event) => event.id == id);

  @override
  Future<int> count() async => _events.length;
}
