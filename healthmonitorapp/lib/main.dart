// main.dart
// Health Monitor - Firebase Auth + SharedPreferences + local SQLite (sqflite)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

// You must create this file in your project's lib/ directory
// and configure Firebase using 'flutterfire configure'
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
    // Corrected SQL query structure for better readability and safety
    final orderClause = 'ORDER BY recordedAt DESC';
    final limitClause = 'LIMIT $limit';

    // Use rawQuery for conditional WHERE clause
    final sql = 'SELECT * FROM measurements $where $orderClause $limitClause';
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
    // Only clear our specific keys to avoid clearing other potential data
    await p.remove(keyRole);
    await p.remove(keyLastEmail);
    // You could use p.clear() if you are sure you want to clear EVERYTHING
  }
}

// ------------------------
// Main App
// ------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Ensure DB initialized, no changes needed here
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
        // Using default transitions is generally safer unless specific effect is required
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

  // Dispose controllers
  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
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
        // --- FIX: Ensure role is stored locally on login (already present) ---
        final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: pass,
        );
        final userRole = cred.user?.displayName;
        if (userRole != null &&
            (userRole == 'patient' || userRole == 'doctor')) {
          await Prefs.setRole(userRole);
        } else {
          // Fallback default role for old/uninitialized users
          await Prefs.setRole('patient');
        }
        // ---------------------------------------------------
        await Prefs.setLastEmail(email);
      } else {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: pass,
        );
        // store role both in Firebase user.displayName and locally (already correct for signup)
        await cred.user?.updateDisplayName(_role);
        await Prefs.setRole(_role);
        await Prefs.setLastEmail(email);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message ?? 'Auth error')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
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
                      initialValue: _role,
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
    String? finalRole;

    // 1. Try SharedPreferences
    final pRole = await Prefs.getRole();
    if (pRole != null) {
      finalRole = pRole;
    }

    // 2. If not in prefs, check Firebase user.displayName
    final u = FirebaseAuth.instance.currentUser;
    final fRole = u?.displayName;

    if (finalRole == null && fRole != null) {
      if (fRole == 'patient' || fRole == 'doctor') {
        finalRole = fRole;
        // --- FIX: Save role to Prefs if fetched from Firebase for future fast loads (already present) ---
        await Prefs.setRole(fRole);
        // -----------------------------------------------------------------------------
      }
    }

    // 3. Default to 'patient' if all else fails
    if (finalRole == null) {
      finalRole = 'patient';
    }

    if (mounted) setState(() => _role = finalRole);
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
    // Only set loading state if not already loading
    if (!_loading) setState(() => _loading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      // If user is null, sign out to return to AuthScreen
      await _signOut();
      return;
    }
    final list = await _db.fetchMeasurements(patientId: uid);
    if (mounted) {
      setState(() {
        _measurements = list;
        _loading = false;
      });
    }
  }

  Future<void> _addMeasurement() async {
    // await here ensures dashboard is reloaded when AddMeasurementScreen pops
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddMeasurementScreen(isDoctor: false),
      ),
    );
    // Reload measurements after adding
    await _load();
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    // Clear local user data (role, last email)
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
    if (!_loading) setState(() => _loading = true);
    final list = await _db.fetchMeasurements();
    if (mounted) {
      setState(() {
        _measurements = list;
        _loading = false;
      });
    }
  }

  Future<void> _addForPatient() async {
    // await here ensures dashboard is reloaded when AddMeasurementScreen pops
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddMeasurementScreen(isDoctor: true),
      ),
    );
    // Reload all measurements after adding
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
                              'Patient ID: ${m.patientId} • ${DateFormat.yMMMd().add_jm().format(m.recordedAt.toLocal())}',
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
// Add Measurement Screen (FIXED)
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
  // FIXED: Use a controller for the unit field to manage state reliably
  final _unitCtrl = TextEditingController();
  DateTime _time = DateTime.now();
  bool _saving = false;
  final _patientIdCtrl = TextEditingController();

  // Helper map to set default units based on type
  static const Map<String, String> _defaultUnits = {
    'blood_glucose': 'mg/dL',
    'blood_pressure': 'mmHg',
    'spo2': '%',
    'weight': 'kg',
  };

  @override
  void initState() {
    super.initState();
    // Initialize patient ID for non-doctors
    if (!widget.isDoctor) {
      _patientIdCtrl.text = FirebaseAuth.instance.currentUser?.uid ?? '';
    }
    // Initialize default unit controller text
    _unitCtrl.text = _defaultUnits[_type] ?? 'unit';
  }

  // Dispose controllers
  @override
  void dispose() {
    _valueCtrl.dispose();
    _patientIdCtrl.dispose();
    _unitCtrl.dispose(); // Dispose the new controller
    super.dispose();
  }

  // Method to update unit based on type selection
  void _updateType(String? newType) {
    if (newType == null) return;
    setState(() {
      _type = newType;
      // Automatically set the default unit in the controller for the selected type
      _unitCtrl.text = _defaultUnits[_type] ?? 'unit';

      // Since the unit field uses a controller, we don't need a separate _unit state variable
      // or to call setState just to change the unit, but we keep setState for the _type change.
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isDoctor ? 'Add measurement (Doctor)' : 'Add measurement',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch, // Use stretch for buttons
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
                initialValue: _type,
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
                onChanged: _updateType, // Use the update method
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _valueCtrl,
                decoration: InputDecoration(
                  labelText: 'Value',
                  // Use the unit controller's text as a suffix/hint
                  suffixText: _unitCtrl.text,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (s) {
                  if (s == null || s.isEmpty) return 'Enter a value';
                  if (double.tryParse(s) == null) return 'Invalid number';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              // FIXED: Use controller instead of initialValue/onChanged
              TextFormField(
                controller: _unitCtrl,
                decoration: const InputDecoration(
                  labelText: 'Unit (e.g. mg/dL, mmHg, %)',
                ),
                validator: (s) =>
                    (s == null || s.isEmpty) ? 'Enter a unit' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      // Ensure conversion to local time for display
                      'Recorded: ${DateFormat.yMMMd().add_jm().format(_time.toLocal())}',
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _time.toLocal(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (pickedDate == null) return;
                      if (!mounted) return;

                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(_time.toLocal()),
                      );
                      if (pickedTime == null) return;

                      // Combine picked date and time
                      final newTime = DateTime(
                        pickedDate.year,
                        pickedDate.month,
                        pickedDate.day,
                        pickedTime.hour,
                        pickedTime.minute,
                      );

                      if (mounted) setState(() => _time = newTime);
                    },
                    child: const Text('Change Date/Time'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _saving
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Save Measurement'),
                      onPressed: () async {
                        if (!_formKey.currentState!.validate()) return;

                        setState(() => _saving = true);
                        try {
                          final patientId = _patientIdCtrl.text.trim();
                          final doc = Measurement(
                            patientId: patientId,
                            type: _type,
                            // Ensure parsing is robust for decimal input
                            value: double.parse(
                              _valueCtrl.text.replaceAll(',', '.'),
                            ),
                            unit: _unitCtrl.text
                                .trim(), // Get unit from controller
                            recordedAt: _time.toUtc(), // Store as UTC
                            createdAt: DateTime.now().toUtc(),
                          );
                          await DBHelper().insertMeasurement(doc);
                          // Show success message before popping (guarded by mounted)
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Measurement saved successfully!',
                                ),
                              ),
                            );
                            Navigator.pop(context);
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error saving: $e')),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
