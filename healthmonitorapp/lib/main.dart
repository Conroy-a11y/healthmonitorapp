// main.dart
// SIMPLE MVP – Local SQLite Only (No Firebase, No Login)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

// ------------------------
// Model
// ------------------------
class Measurement {
  final int? id;
  final String type;
  final double value;
  final String unit;
  final DateTime recordedAt;

  Measurement({
    this.id,
    required this.type,
    required this.value,
    required this.unit,
    required this.recordedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type,
    'value': value,
    'unit': unit,
    'recordedAt': recordedAt.toIso8601String(),
  };

  static Measurement fromMap(Map<String, dynamic> m) => Measurement(
    id: m['id'] as int?,
    type: m['type'] as String,
    value: (m['value'] as num).toDouble(),
    unit: m['unit'] as String,
    recordedAt: DateTime.parse(m['recordedAt'] as String),
  );
}

// ------------------------
// Local Database
// ------------------------
class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, "health_mvp.db");

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        db.execute("""
        CREATE TABLE measurements (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL,
          value REAL NOT NULL,
          unit TEXT NOT NULL,
          recordedAt TEXT NOT NULL
        )
      """);
      },
    );
  }

  Future<int> insert(Measurement m) async {
    final database = await db;
    return database.insert("measurements", m.toMap());
  }

  Future<List<Measurement>> fetchAll() async {
    final database = await db;
    final rows = await database.query(
      "measurements",
      orderBy: "recordedAt DESC",
    );
    return rows.map((m) => Measurement.fromMap(m)).toList();
  }

  Future<int> delete(int id) async {
    final database = await db;
    return database.delete("measurements", where: "id = ?", whereArgs: [id]);
  }
}

// ------------------------
// MAIN APP
// ------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DBHelper().db;
  runApp(const HealthMVPApp());
}

class HealthMVPApp extends StatelessWidget {
  const HealthMVPApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Health Monitor MVP",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, primarySwatch: Colors.teal),
      home: const DashboardScreen(),
    );
  }
}

// ------------------------
// Dashboard
// ------------------------
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final db = DBHelper();
  bool loading = true;
  List<Measurement> items = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    items = await db.fetchAll();
    setState(() => loading = false);
  }

  Future<void> add() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddMeasurementScreen()),
    );
    load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Health Monitor MVP")),
      floatingActionButton: FloatingActionButton(
        onPressed: add,
        child: const Icon(Icons.add),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? const Center(child: Text("No measurements yet"))
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, i) {
                final m = items[i];
                return Card(
                  child: ListTile(
                    title: Text(
                      "${m.type.toUpperCase()} — ${m.value} ${m.unit}",
                    ),
                    subtitle: Text(
                      DateFormat.yMMMd().add_jm().format(m.recordedAt),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () async {
                        await db.delete(m.id!);
                        load();
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ------------------------
// Add Measurement
// ------------------------
class AddMeasurementScreen extends StatefulWidget {
  @override
  State<AddMeasurementScreen> createState() => _AddMeasurementScreenState();
}

class _AddMeasurementScreenState extends State<AddMeasurementScreen> {
  String type = "blood_glucose";
  final valueCtrl = TextEditingController();
  final unitCtrl = TextEditingController(text: "mg/dL");
  DateTime time = DateTime.now();

  final _types = {
    "blood_glucose": "mg/dL",
    "blood_pressure": "mmHg",
    "spo2": "%",
    "weight": "kg",
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Measurement")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: type,
              items: _types.keys
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  type = v!;
                  unitCtrl.text = _types[type]!;
                });
              },
              decoration: const InputDecoration(labelText: "Type"),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: valueCtrl,
              decoration: InputDecoration(
                labelText: "Value",
                suffixText: unitCtrl.text,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: unitCtrl,
              decoration: const InputDecoration(labelText: "Unit"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              child: const Text("Save"),
              onPressed: () async {
                final val = double.tryParse(valueCtrl.text);
                if (val == null) return;

                final measurement = Measurement(
                  type: type,
                  value: val,
                  unit: unitCtrl.text,
                  recordedAt: time,
                );

                await DBHelper().insert(measurement);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
