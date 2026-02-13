import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'login_screen.dart';
import 'analytics_screen.dart';

// Uniform Theme
class AppColors {
  static const Color backgroundBlack = Color(0xFF0F1218);
  static const Color surfaceDark = Color(0xFF1C212B);
  static const Color accentBlue = Color(0xFF3D8BFF);
  static const Color accentTeal = Color(0xFF00E5FF);
  static const Color textMain = Colors.white;
  static const Color textMuted = Color(0xFF94A3B8);
}

class ClinicDashboardScreen extends StatefulWidget {
  const ClinicDashboardScreen({super.key});

  @override
  State<ClinicDashboardScreen> createState() => _ClinicDashboardScreenState();
}

class _ClinicDashboardScreenState extends State<ClinicDashboardScreen> {
  final DatabaseReference queueRef = FirebaseDatabase.instance.ref('queue');

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginRegisterScreen()),
      (route) => false,
    );
  }

  Future<void> _servePatient(String key) async {
    await queueRef.child(key).update({'status': 'serving'});
  }

  Future<void> _markDone(String key) async {
    await queueRef.child(key).update({
      'status': 'done',
      'completedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _markSkipped(String key) async {
    await queueRef.child(key).update({'status': 'skipped'});
  }

  @override
  Widget build(BuildContext context) {
    // Logic: Define the start of today to filter out old requests
    final now = DateTime.now();
    final todayStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;

    return Scaffold(
      backgroundColor: AppColors.backgroundBlack,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Mithibai_Clinic',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textMain,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.analytics_outlined,
              color: AppColors.accentTeal,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: _logout,
          ),
        ],
      ),
      body: StreamBuilder<DatabaseEvent>(
        // QUERY: Start from today's timestamp and order by time
        stream: queueRef.orderByChild('time').startAt(todayStart).onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentTeal),
            );
          }

          final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>?;

          if (data == null || data.isEmpty) {
            return _buildEmptyState();
          }

          final patients = data.entries.map((e) {
            final map = Map<String, dynamic>.from(e.value);
            map['key'] = e.key;
            return map;
          }).toList()..sort((a, b) => a['time'].compareTo(b['time']));

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: patients.length,
            itemBuilder: (context, index) {
              final patient = patients[index];
              return _buildPatientCard(patient, patients);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_turned_in_outlined,
            size: 80,
            color: AppColors.surfaceDark,
          ),
          const SizedBox(height: 16),
          const Text(
            "No patients for today yet",
            style: TextStyle(color: AppColors.textMuted, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard(Map patient, List allPatients) {
    final String status = patient['status'] ?? 'waiting';
    final String key = patient['key'];
    final bool isAnyServing = allPatients.any((p) => p['status'] == 'serving');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: status == 'serving'
              ? AppColors.accentTeal.withOpacity(0.5)
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.accentBlue.withOpacity(0.1),
                  child: Text(
                    patient['name']?[0] ?? 'P',
                    style: const TextStyle(
                      color: AppColors.accentBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient['name'] ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "${patient['age'] ?? '-'} yrs • ${patient['gender'] ?? '-'}",
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(status),
              ],
            ),
            const Divider(color: Colors.white10, height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Symptoms: ${patient['symptoms'] ?? 'General checkup'}",
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                    ),
                  ),
                ),
                _buildActions(status, key, isAnyServing),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = AppColors.textMuted;
    if (status == 'serving') color = AppColors.accentTeal;
    if (status == 'done') color = Colors.greenAccent;
    if (status == 'skipped') color = Colors.orangeAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildActions(String status, String key, bool isAnyServing) {
    if (status == 'waiting') {
      return ElevatedButton(
        onPressed: isAnyServing ? null : () => _servePatient(key),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text("Serve"),
      );
    }
    if (status == 'serving') {
      return Row(
        children: [
          IconButton(
            onPressed: () => _markSkipped(key),
            icon: const Icon(
              Icons.skip_next_rounded,
              color: Colors.orangeAccent,
            ),
          ),
          ElevatedButton(
            onPressed: () => _markDone(key),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Done"),
          ),
        ],
      );
    }
    return Icon(
      status == 'done' ? Icons.check_circle : Icons.do_not_disturb_on,
      color: status == 'done' ? Colors.greenAccent : AppColors.textMuted,
    );
  }
}
