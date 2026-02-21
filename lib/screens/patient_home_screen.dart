import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AppColors {
  static const Color backgroundBlack = Color(0xFF0F1218);
  static const Color surfaceDark = Color(0xFF1C212B);
  static const Color accentBlue = Color(0xFF3D8BFF);
  static const Color accentTeal = Color(0xFF00E5FF);
  static const Color textMain = Colors.white;
  static const Color textMuted = Color(0xFF94A3B8);

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF1E3A8A), Color(0xFF0D9488)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  bool _profileLoading = true;
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final DatabaseReference ref = FirebaseDatabase.instance.ref();
  final DatabaseReference queueRef = FirebaseDatabase.instance.ref('queue');

  Map<String, dynamic>? profile;
  bool _turnAlertShown = false;

  final List<String> symptomsList = [
    'Fever / बुखार',
    'Cough / खांसी',
    'Headache / सिरदर्द',
    'Stomach Pain / पेट दर्द',
    'Eye Problem / आँखों की समस्या',
    'Skin Issue / त्वचा समस्या',
    'General Checkup / सामान्य जांच',
    'Cold & Flu / सर्दी-जुकाम',
    'Other / अन्य',
  ];

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  void _fetchProfile() {
    if (uid == null) return;
    // Listening to the 'profile' node we created in the new RegisterScreen
    ref.child('users/$uid/profile').onValue.listen((event) {
      if (!mounted) return;
      if (event.snapshot.exists) {
        profile = Map<String, dynamic>.from(event.snapshot.value as Map);
      }
      setState(() => _profileLoading = false);
    });
  }

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
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Are you sure you want to logout? You might lose track of your live queue position.",
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
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
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

  Future<String?> _askSymptoms() async {
    final Set<String> selectedSymptoms = {};
    final otherController = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Select Symptoms',
            style: TextStyle(color: Colors.white),
          ),
          content: Theme(
            data: ThemeData.dark().copyWith(
              unselectedWidgetColor: AppColors.textMuted,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...symptomsList.map(
                    (symptom) => CheckboxListTile(
                      title: Text(
                        symptom,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                        ),
                      ),
                      activeColor: AppColors.accentTeal,
                      value: selectedSymptoms.contains(symptom),
                      onChanged: (checked) {
                        setDialogState(() {
                          if (checked == true) {
                            selectedSymptoms.add(symptom);
                          } else {
                            selectedSymptoms.remove(symptom);
                          }
                        });
                      },
                    ),
                  ),
                  if (selectedSymptoms.contains('Other / अन्य'))
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        controller: otherController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Describe here',
                          labelStyle: TextStyle(color: AppColors.accentTeal),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedSymptoms.isEmpty) return;
                String result = selectedSymptoms.join(', ');
                if (otherController.text.isNotEmpty)
                  result += " (${otherController.text})";
                Navigator.pop(context, result);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBlue,
              ),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _joinQueue() async {
    if (profile == null) return;
    final symptoms = await _askSymptoms();
    if (symptoms == null) return;

    await queueRef.push().set({
      'uid': uid,
      'name': profile!['name'],
      'age': profile!['age'],
      'gender': profile!['gender'],
      'phone': profile!['phone'],
      'symptoms': symptoms,
      'time': DateTime.now().millisecondsSinceEpoch,
      'status': 'waiting',
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
          'TokenCare',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: _showLogoutWarning, // Call the new warning function
          ),
        ],
      ),
      body: _profileLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentTeal),
            )
          : StreamBuilder<DatabaseEvent>(
              stream: queueRef.orderByChild('time').startAt(todayStart).onValue,
              builder: (context, snapshot) {
                // Default Join State if no one is in queue or data is null
                if (!snapshot.hasData ||
                    snapshot.data?.snapshot.value == null) {
                  return _buildJoinState();
                }

                final data = Map<dynamic, dynamic>.from(
                  snapshot.data!.snapshot.value as Map,
                );

                final activePatients =
                    data.entries
                        .map((e) => Map<String, dynamic>.from(e.value as Map))
                        .where(
                          (p) =>
                              (p['status'] == 'waiting' ||
                                  p['status'] == 'serving') &&
                              (p['time'] ?? 0) >= todayStart,
                        ) // Only today's tokens
                        .toList()
                      ..sort((a, b) => a['time'].compareTo(b['time']));

                final myNode = activePatients.firstWhere(
                  (p) => p['uid'] == uid,
                  orElse: () => {},
                );

                if (myNode.isEmpty) return _buildJoinState();

                final String myStatus = myNode['status'];
                final int myPosition =
                    activePatients.indexWhere((p) => p['uid'] == uid) + 1;

                if (myStatus == 'serving' && !_turnAlertShown) {
                  _turnAlertShown = true;
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _showTurnAlert(),
                  );
                } else if (myStatus != 'serving') {
                  _turnAlertShown = false;
                }

                return _buildQueueState(
                  activePatients.length,
                  myStatus,
                  myPosition,
                );
              },
            ),
    );
  }

  Widget _buildJoinState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.medical_services_outlined,
              size: 80,
              color: AppColors.accentTeal,
            ),
            const SizedBox(height: 24),
            Text(
              "Hello, ${profile?['name'] ?? 'Patient'}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "You are not in the queue yet.",
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _joinQueue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "Get My Token",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueState(int total, String status, int position) {
    bool isServing = status == 'serving';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Clinic Status",
                  style: TextStyle(color: AppColors.textMuted),
                ),
                Text(
                  "$total in queue",
                  style: const TextStyle(
                    color: AppColors.accentTeal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
            decoration: BoxDecoration(
              gradient: isServing ? AppColors.darkGradient : null,
              color: isServing ? null : AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(30),
              boxShadow: isServing
                  ? [
                      BoxShadow(
                        color: AppColors.accentTeal.withOpacity(0.3),
                        blurRadius: 20,
                      ),
                    ]
                  : [],
            ),
            child: Column(
              children: [
                Text(
                  isServing ? "YOU ARE NEXT" : "YOUR POSITION",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  isServing ? "GO IN" : "#$position",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 25),
                if (!isServing)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: 1 / (position == 0 ? 1 : position),
                      minHeight: 8,
                      color: AppColors.accentTeal,
                      backgroundColor: Colors.white10,
                    ),
                  ),
              ],
            ),
          ),
          if (position <= 2 && !isServing)
            Padding(
              padding: const EdgeInsets.only(top: 30),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orangeAccent,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Please reach the clinic entrance now.",
                        style: TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showTurnAlert() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text(
          '🎉 It\'s Your Turn!',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Please proceed to the doctor\'s cabin.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Understood',
              style: TextStyle(color: AppColors.accentTeal),
            ),
          ),
        ],
      ),
    );
  }
}
