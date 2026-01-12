import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'login_screen.dart';
import 'package:tokencare/screens/analytics_screen.dart';

class ClinicDashboardScreen extends StatefulWidget {
  const ClinicDashboardScreen({super.key});

  @override
  State<ClinicDashboardScreen> createState() => _ClinicDashboardScreenState();
}

class _ClinicDashboardScreenState extends State<ClinicDashboardScreen> {
  final DatabaseReference queueRef = FirebaseDatabase.instance.ref('queue');

  // ---------------- LOGOUT ----------------
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginRegisterScreen()),
      (route) => false,
    );
  }

  // SERVE PATIENT
  Future<void> _servePatient(String key) async {
    await queueRef.child(key).update({'status': 'serving'});
  }

  //  MARK DONE
  Future<void> _markDone(String key) async {
    await queueRef.child(key).update({
      'status': 'done',
      'completedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clinic Dashboard'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: queueRef.onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>?;

          if (data == null || data.isEmpty) {
            return const Center(child: Text('No patients in queue'));
          }

          // Convert Map → List for easy sorting by time
          final patients = data.entries.map((e) {
            final map = Map<String, dynamic>.from(e.value);
            map['key'] = e.key;
            return map;
          }).toList()..sort((a, b) => a['time'].compareTo(b['time']));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: patients.length,
            itemBuilder: (context, index) {
              final patient = patients[index];
              final key = patient['key'];
              final status = patient['status'] ?? 'waiting';

              return Card(
                child: ListTile(
                  title: Text(patient['name'] ?? 'No Name'),
                  subtitle: Text(
                    '${patient['age'] ?? '-'} yrs • ${patient['gender'] ?? '-'}\nSymptoms: ${patient['symptoms'] ?? '-'}\nStatus: $status',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (status == 'waiting')
                        ElevatedButton(
                          onPressed: () => _servePatient(key),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                          ),
                          child: const Text('Serve'),
                        ),
                      if (status == 'serving')
                        ElevatedButton(
                          onPressed: () => _markDone(key),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text('Done'),
                        ),
                      if (status == 'done')
                        const Icon(Icons.check, color: Colors.grey),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
