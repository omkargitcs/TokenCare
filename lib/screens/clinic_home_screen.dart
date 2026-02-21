import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'login_screen.dart'; // Ensure this file exists
import 'analytics_screen.dart'; // Ensure this file exists

// --- THEME COLORS ---
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

  // --- LOGOUT LOGIC WITH WARNING ---
  void _showLogoutWarning() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "Confirm Logout",
            style: TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            "Does the clinic really want to logout? You will need to sign in again to manage the queue.",
            style: TextStyle(color: AppColors.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancel",
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(context); // Close dialog
                _logout();
              },
              child: const Text(
                "Logout",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginRegisterScreen()),
      (route) => false,
    );
  }

  // --- DATABASE ACTIONS ---
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
    await queueRef.child(key).update({
      'status': 'skipped',
      'completedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  @override
  Widget build(BuildContext context) {
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
            onPressed: _showLogoutWarning, // Triggers warning
          ),
        ],
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: queueRef.orderByChild('time').startAt(todayStart).onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentTeal),
            );
          }

          final data = snapshot.data?.snapshot.value as Map<dynamic, dynamic>?;

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
              return _buildPatientCard(patients[index], patients);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_turned_in_outlined,
            size: 80,
            color: AppColors.surfaceDark,
          ),
          SizedBox(height: 16),
          Text(
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
                _buildActions(status, key, isAnyServing, allPatients),
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

  Widget _buildActions(
    String status,
    String key,
    bool isAnyServing,
    List allPatients,
  ) {
    final waitingList = allPatients
        .where((p) => p['status'] == 'waiting')
        .toList();
    final bool isNextInLine =
        waitingList.isNotEmpty && waitingList.first['key'] == key;

    if (status == 'waiting') {
      return ElevatedButton(
        onPressed: (isAnyServing || !isNextInLine)
            ? null
            : () => _servePatient(key),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentBlue,
          disabledBackgroundColor: Colors.grey.withOpacity(0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          "Serve",
          style: TextStyle(
            color: (isAnyServing || !isNextInLine)
                ? AppColors.textMuted
                : Colors.white,
          ),
        ),
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
