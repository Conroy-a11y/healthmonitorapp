// main.dart
// Health Monitor - Firebase Auth + SharedPreferences + local SQLite (sqflite)
// Features:
// - Firebase Email/Password auth (signup/login)
// - Role selection on signup (patient | doctor) stored in Firebase user.displayName and locally in SharedPreferences
// - SharedPreferences for small local settings (role, last email)
// - Local SQLite (sqflite) for measurements storage and retrieval
// - Role-based dashboards (patient sees own measurements; doctor sees all measurements and can add for patients)
// - Simple modern UI with cards and clean layout

// PUBSPEC (add these to pubspec.yaml dependencies):
// firebase_core: ^3.0.0
// firebase_auth: ^5.0.0
// shared_preferences: ^2.0.15
// sqflite: ^2.2.8+4
// path: ^1.8.3
// path_provider: ^2.0.15
// intl: any
// cupertino_icons: ^1.0.5

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

// Import your generated Firebase options file
import 'firebase_options.dart';

// ------------------------
// Models
// ------------------------
class Measurement {
  final int? id;
  final String patientId;
  final String type;
  final double value;
  final String unit;
  final DateTime recordedAt;
  final DateTime createdAt;

  Measurement({
    this.id,
    required this.patientId,
    required this.type,
    required this.value,
    required this.unit,
    required this.recordedAt,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'patientId': patientId,
    'type': type,
    'value': value,
    'unit': unit,
    'recordedAt': recordedAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  static Measurement fromMap(Map<String, dynamic> m) => Measurement(
    id: m['id'] as int?,
    patientId: m['patientId'] as String,
    type: m['type'] as String,
    value: (m['value'] as num).toDouble(),
    unit: m['unit'] as String,
    recordedAt: DateTime.parse(m['recordedAt'] as String),
    createdAt: DateTime.parse(m['createdAt'] as String),
  );
}

// ------------------------
// Database helper (sqflite)
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
    final doc = await getApplicationDocumentsDirectory();
    final path = p.join(doc.path, 'health_monitor.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
        CREATE TABLE measurements (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          patientId TEXT NOT NULL,
          type TEXT NOT NULL,
          value REAL NOT NULL,
          unit TEXT NOT NULL,
          recordedAt TEXT NOT NULL,
          createdAt TEXT NOT NULL
        );
      ''');
      },
    );
  }

  Future<int> insertMeasurement(Measurement m) async {
    final database = await db;
    return await database.insert('measurements', m.toMap());
  }

  Future<List<Measurement>> fetchMeasurements({
    String? patientId,
    int limit = 100,
  }) async {
    final database = await db;
    String where = '';
    List<dynamic> args = [];
    if (patientId != null) {
      where = 'WHERE patientId = ?';
      args = [patientId];
    }
    final orderClause = 'ORDER BY recordedAt DESC';
    final sql = 'SELECT * FROM measurements $where $orderClause LIMIT $limit';
    final rows = await database.rawQuery(sql, args);
    return rows.map((r) => Measurement.fromMap(r)).toList();
  }

  Future<int> deleteMeasurement(int id) async {
    final database = await db;
    return await database.delete(
      'measurements',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

// ------------------------
// SharedPreferences helper
// ------------------------
class Prefs {
  static const String keyRole = 'role';
  static const String keyLastEmail = 'lastEmail';

  static Future<void> setRole(String role) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(keyRole, role);
  }

  static Future<String?> getRole() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(keyRole);
  }

  static Future<void> setLastEmail(String email) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(keyLastEmail, email);
  }

  static Future<String?> getLastEmail() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(keyLastEmail);
  }

  static Future<void> clearAll() async {
    final p = await SharedPreferences.getInstance();
    await p.clear();
  }
}

// ------------------------
// Main App
// ------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Ensure DB initialized
  await DBHelper().db;
  runApp(const HealthApp());
}

class HealthApp extends StatelessWidget {
  const HealthApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Health Monitor',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData) return const AuthScreen();
        return const HomeRouter();
      },
    );
  }
}

// ------------------------
// Auth Screen (Login / Register with role)
// ------------------------
class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;
  String _role = 'patient';

  @override
  void initState() {
    super.initState();
    Prefs.getLastEmail().then((e) {
      if (e != null) _emailCtrl.text = e;
    });
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() => _loading = true);
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: pass,
        );
        await Prefs.setLastEmail(email);
      } else {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: pass,
        );
        // store role both in Firebase user.displayName and locally
        await cred.user?.updateDisplayName(_role);
        await Prefs.setRole(_role);
        await Prefs.setLastEmail(email);
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message ?? 'Auth error')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FlutterLogo(size: 72),
                  const SizedBox(height: 12),
                  Text(
                    _isLogin ? 'Welcome Back' : 'Create an Account',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passCtrl,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                  ),
                  if (!_isLogin) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _role,
                      items: const [
                        DropdownMenuItem(
                          value: 'patient',
                          child: Text('Patient'),
                        ),
                        DropdownMenuItem(
                          value: 'doctor',
                          child: Text('Doctor'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _role = v ?? 'patient'),
                      decoration: const InputDecoration(labelText: 'Role'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _loading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 36,
                              vertical: 12,
                            ),
                          ),
                          onPressed: _submit,
                          child: Text(_isLogin ? 'Login' : 'Sign up'),
                        ),
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(
                      _isLogin
                          ? 'Create an account'
                          : 'Already have an account? Login',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------
// HomeRouter - decides dashboard based on role
// ------------------------
class HomeRouter extends StatefulWidget {
  const HomeRouter({Key? key}) : super(key: key);

  @override
  State<HomeRouter> createState() => _HomeRouterState();
}

class _HomeRouterState extends State<HomeRouter> {
  String? _role;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    // Priority: SharedPreferences -> Firebase user.displayName -> default 'patient'
    final pRole = await Prefs.getRole();
    if (pRole != null) {
      setState(() => _role = pRole);
      return;
    }
    final u = FirebaseAuth.instance.currentUser;
    final fRole = u?.displayName;
    if (fRole != null && (fRole == 'patient' || fRole == 'doctor')) {
      await Prefs.setRole(fRole);
      setState(() => _role = fRole);
      return;
    }
    // default
    setState(() => _role = 'patient');
  }

  @override
  Widget build(BuildContext context) {
    if (_role == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_role == 'doctor') return const DoctorDashboard();
    return const PatientDashboard();
  }
}

// ------------------------
// Patient Dashboard
// ------------------------
class PatientDashboard extends StatefulWidget {
  const PatientDashboard({Key? key}) : super(key: key);

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  final _db = DBHelper();
  List<Measurement> _measurements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final list = await _db.fetchMeasurements(patientId: uid);
    setState(() {
      _measurements = list;
      _loading = false;
    });
  }

  Future<void> _addMeasurement() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddMeasurementScreen(isDoctor: false)),
    );
    await _load();
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    await Prefs.clearAll();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Dashboard'),
        actions: [
          IconButton(onPressed: _signOut, icon: const Icon(Icons.logout)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addMeasurement,
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(user?.email ?? 'User'),
                subtitle: const Text('Role: Patient'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Recent measurements',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _measurements.isEmpty
                  ? const Center(
                      child: Text('No measurements yet — tap + to add'),
                    )
                  : ListView.builder(
                      itemCount: _measurements.length,
                      itemBuilder: (context, i) {
                        final m = _measurements[i];
                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            title: Text('${m.type} — ${m.value} ${m.unit}'),
                            subtitle: Text(
                              DateFormat.yMMMd().add_jm().format(
                                m.recordedAt.toLocal(),
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                if (m.id != null) {
                                  await _db.deleteMeasurement(m.id!);
                                  await _load();
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------
// Doctor Dashboard
// ------------------------
class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({Key? key}) : super(key: key);

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  final _db = DBHelper();
  List<Measurement> _measurements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final list = await _db.fetchMeasurements();
    setState(() {
      _measurements = list;
      _loading = false;
    });
  }

  Future<void> _addForPatient() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddMeasurementScreen(isDoctor: true)),
    );
    await _loadAll();
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    await Prefs.clearAll();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Dashboard'),
        actions: [
          IconButton(onPressed: _signOut, icon: const Icon(Icons.logout)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addForPatient,
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.medical_services),
                ),
                title: Text(user?.email ?? 'Doctor'),
                subtitle: const Text('Role: Doctor'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'All measurements (local DB)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _measurements.isEmpty
                  ? const Center(child: Text('No measurements available'))
                  : ListView.builder(
                      itemCount: _measurements.length,
                      itemBuilder: (context, i) {
                        final m = _measurements[i];
                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            title: Text('${m.type} — ${m.value} ${m.unit}'),
                            subtitle: Text(
                              'Patient: ${m.patientId} • ${DateFormat.yMMMd().add_jm().format(m.recordedAt.toLocal())}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                if (m.id != null) {
                                  await _db.deleteMeasurement(m.id!);
                                  await _loadAll();
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------
// Add Measurement Screen
// ------------------------
class AddMeasurementScreen extends StatefulWidget {
  final bool isDoctor;
  const AddMeasurementScreen({Key? key, required this.isDoctor})
    : super(key: key);

  @override
  State<AddMeasurementScreen> createState() => _AddMeasurementScreenState();
}

class _AddMeasurementScreenState extends State<AddMeasurementScreen> {
  final _formKey = GlobalKey<FormState>();
  String _type = 'blood_glucose';
  final _valueCtrl = TextEditingController();
  String _unit = 'mg/dL';
  DateTime _time = DateTime.now();
  bool _saving = false;
  final _patientIdCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (!widget.isDoctor) {
      _patientIdCtrl.text = FirebaseAuth.instance.currentUser?.uid ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isDoctor ? 'Add measurement (doctor)' : 'Add measurement',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (widget.isDoctor) ...[
                TextFormField(
                  controller: _patientIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Patient ID (UID)',
                  ),
                  validator: (s) =>
                      (s == null || s.isEmpty) ? 'Enter patient UID' : null,
                ),
                const SizedBox(height: 8),
              ],
              DropdownButtonFormField<String>(
                value: _type,
                items: const [
                  DropdownMenuItem(
                    value: 'blood_glucose',
                    child: Text('Blood glucose'),
                  ),
                  DropdownMenuItem(
                    value: 'blood_pressure',
                    child: Text('Blood pressure'),
                  ),
                  DropdownMenuItem(value: 'spo2', child: Text('SpO2')),
                  DropdownMenuItem(value: 'weight', child: Text('Weight')),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'blood_glucose'),
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _valueCtrl,
                decoration: const InputDecoration(labelText: 'Value'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (s) =>
                    (s == null || s.isEmpty) ? 'Enter a value' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: _unit,
                onChanged: (v) => _unit = v,
                decoration: const InputDecoration(
                  labelText: 'Unit (e.g. mg/dL, mmHg, %)',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Time: ${DateFormat.yMMMd().add_jm().format(_time.toLocal())}',
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _time,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(_time),
                        );
                        if (t != null) {
                          setState(() {
                            _time = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              t.hour,
                              t.minute,
                            );
                          });
                        }
                      }
                    },
                    child: const Text('Change'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _saving
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () async {
                        if (!_formKey.currentState!.validate()) return;
                        setState(() => _saving = true);
                        try {
                          final patientId = _patientIdCtrl.text.trim();
                          final doc = Measurement(
                            patientId: patientId,
                            type: _type,
                            value: double.parse(_valueCtrl.text),
                            unit: _unit,
                            recordedAt: _time.toUtc(),
                            createdAt: DateTime.now().toUtc(),
                          );
                          await DBHelper().insertMeasurement(doc);
                          Navigator.pop(context);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error saving: $e')),
                          );
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                      child: const Text('Save measurement'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

// End of file
