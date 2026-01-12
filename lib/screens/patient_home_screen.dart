import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:tokencare/screens/login_screen.dart';
import '../theme.dart';
import 'first_time_registration.dart';

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
  String status = 'not_in_queue';

  bool _turnAlertShown = false;

  final List<String> symptomsList = [
    'Fever / बुखार',
    'Cough / खांसी',
    'Headache / सिरदर्द',
    'Stomach Pain / पेट दर्द',
    'Eye Problem / आंखों की समस्या',
    'Skin Issue / त्वचा समस्या',
    'General Checkup / सामान्य जांच',
    'Back Pain / पीठ दर्द',
    'Cold & Flu / सर्दी-जुकाम',
    'Blood Pressure / ब्लड प्रेशर',
    'Diabetes Check / डायबिटीज जांच',
    'Other / अन्य (describe below)',
  ];

  Future<bool> _alreadyInQueue() async {
    final snapshot = await queueRef.get();

    if (!snapshot.exists) return false;

    final data = snapshot.value as Map<dynamic, dynamic>;

    for (final entry in data.values) {
      if (entry['uid'] == uid &&
          (entry['status'] == 'waiting' || entry['status'] == 'serving')) {
        return true;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _checkProfile();
  }

  // ---------------- PROFILE ----------------
  void _checkProfile() {
    if (uid == null) return;

    ref.child('users/$uid/profile').onValue.listen((event) {
      if (!mounted) return;

      if (event.snapshot.exists) {
        profile = Map<String, dynamic>.from(event.snapshot.value as Map);
      } else {
        profile = null;
      }

      setState(() {
        _profileLoading = false;
      });
    });
  }

  void _saveProfile(Map<String, dynamic> profileData) {
    if (uid == null) return;
    ref.child('users/$uid/profile').set(profileData);
    setState(() {
      profile = profileData;
      status = 'not_in_queue';
    });
  }

  // ---------------- JOIN QUEUE ----------------
  Future<String?> _askSymptoms() async {
    final Set<String> selectedSymptoms = {};
    final otherController = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Select Symptoms'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...symptomsList.map(
                  (symptom) => CheckboxListTile(
                    title: Text(symptom),
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
                if (selectedSymptoms.contains('Other / अन्य (describe below)'))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextField(
                      controller: otherController,
                      decoration: const InputDecoration(
                        labelText: 'Describe other symptoms',
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedSymptoms.isEmpty) return;

                final List<String> finalSymptoms = [];

                for (final s in selectedSymptoms) {
                  if (s.startsWith('Other') &&
                      otherController.text.trim().isNotEmpty) {
                    finalSymptoms.add('Other: ${otherController.text.trim()}');
                  } else if (!s.startsWith('Other')) {
                    finalSymptoms.add(s);
                  }
                }

                Navigator.pop(context, finalSymptoms.join(', '));
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _joinQueue() async {
    if (uid == null || profile == null) return;

    final exists = await _alreadyInQueue();
    if (exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already have an active token'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final symptoms = await _askSymptoms();
    if (symptoms == null) return;

    setState(() => status = 'token_requested');

    await queueRef.push().set({
      'uid': uid,
      'name': profile!['name'],
      'age': profile!['age'],
      'gender': profile!['gender'],
      'symptoms': symptoms,
      'time': DateTime.now().millisecondsSinceEpoch,
      'status': 'waiting',
    });
  }

  void _showTurnAlert() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Your Turn'),
        content: const Text(
          'Please proceed to the clinic. The doctor is ready to see you.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Visit', style: titleTextStyle),
        backgroundColor: tealColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginRegisterScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: _profileLoading
          ? const Center(child: CircularProgressIndicator())
          : profile == null
          ? FirstTimeRegistration(onProfileSaved: _saveProfile)
          : StreamBuilder<DatabaseEvent>(
              stream: queueRef.onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final queueData =
                    snapshot.data!.snapshot.value as Map<dynamic, dynamic>? ??
                    {};

                // Convert Map -> List with keys
                final patientsList = queueData.entries.map((e) {
                  final map = Map<String, dynamic>.from(e.value);
                  map['key'] = e.key;
                  return map;
                }).toList();

                // Sort by time
                patientsList.sort((a, b) => a['time'].compareTo(b['time']));

                // Waiting patients
                final waitingPatients = patientsList
                    .where((p) => p['status'] == 'waiting')
                    .toList();

                // Find my node
                final myNode = patientsList.firstWhere(
                  (p) => p['uid'] == uid,
                  orElse: () => {},
                );

                int? myPosition;
                String? myStatus;

                if (myNode.isNotEmpty) {
                  myStatus = myNode['status'];
                  if (myStatus == 'waiting') {
                    myPosition =
                        waitingPatients.indexWhere((p) => p['uid'] == uid) + 1;
                  }
                }
                if (myStatus == 'serving' && !_turnAlertShown) {
                  _turnAlertShown = true;

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _showTurnAlert();
                  });
                }
                if (myStatus != 'serving') {
                  _turnAlertShown = false;
                }

                return _mainContent(
                  waitingPatients.length,
                  myPosition,
                  myStatus,
                );
              },
            ),
    );
  }

  Widget _mainContent(int waitingCount, int? myPosition, String? myStatus) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Queue count card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'Patients in Queue',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  Text(waitingCount.toString(), style: largeNumberStyle),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Not in queue / request sent
          if (status == 'not_in_queue') _notInQueueCard(),
          if (status == 'token_requested') _tokenRequestedCard(),

          // My position or "Your Turn"
          if (myStatus == 'waiting' && myPosition != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Card(
                color: Colors.yellow[100],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Your position in queue: $myPosition',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          if (myStatus == 'serving')
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Card(
                color: Colors.green[100],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '🎉 It\'s your turn!',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------- CARDS ----------------
  Widget _notInQueueCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.queue, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Not in queue', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _joinQueue,
            style: ElevatedButton.styleFrom(
              backgroundColor: tealColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              'Join Queue',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _tokenRequestedCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: const [
          Icon(Icons.hourglass_top, size: 64, color: Colors.orange),
          SizedBox(height: 16),
          Text(
            'Request Sent',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Please wait for clinic approval',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    ),
  );
}
