import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final DatabaseReference ref = FirebaseDatabase.instance.ref('queue');
  bool showToday = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() => showToday = true),
                  child: const Text('Today'),
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() => showToday = false),
                  child: const Text('Monthly'),
                ),
              ),
            ],
          ),

          Expanded(
            child: StreamBuilder(
              stream: ref.onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                Map<dynamic, dynamic> data =
                    (snapshot.data!.snapshot.value ?? {})
                        as Map<dynamic, dynamic>;

                return showToday
                    ? todayAnalytics(data)
                    : monthlyAnalytics(data);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- TODAY ----------------
  Widget todayAnalytics(Map data) {
    int totalToday = 0;
    Map<int, int> hourCount = {};

    DateTime now = DateTime.now();

    data.forEach((key, value) {
      if (value['status'] == 'done') {
        DateTime t = DateTime.fromMillisecondsSinceEpoch(value['completedAt']);

        if (t.year == now.year && t.month == now.month && t.day == now.day) {
          totalToday++;

          int hour = t.hour;
          if (hourCount.containsKey(hour)) {
            hourCount[hour] = hourCount[hour]! + 1;
          } else {
            hourCount[hour] = 1;
          }
        }
      }
    });

    int peakHour = -1;
    int max = 0;
    hourCount.forEach((h, c) {
      if (c > max) {
        max = c;
        peakHour = h;
      }
    });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        simpleCard('Patients Today', totalToday.toString()),
        if (peakHour != -1)
          simpleCard('Peak Hour', '$peakHour:00 - ${peakHour + 1}:00'),
      ],
    );
  }

  // ---------------- MONTHLY ----------------
  Widget monthlyAnalytics(Map data) {
    int totalMonth = 0;
    Map<int, int> dayCount = {};
    Map<String, int> symptomCount = {};

    DateTime now = DateTime.now();

    data.forEach((key, value) {
      if (value['status'] == 'done') {
        DateTime t = DateTime.fromMillisecondsSinceEpoch(value['completedAt']);

        if (t.year == now.year && t.month == now.month) {
          totalMonth++;

          int day = t.day;
          if (dayCount.containsKey(day)) {
            dayCount[day] = dayCount[day]! + 1;
          } else {
            dayCount[day] = 1;
          }

          String symptom = value['symptoms'] ?? 'Unknown';
          if (symptomCount.containsKey(symptom)) {
            symptomCount[symptom] = symptomCount[symptom]! + 1;
          } else {
            symptomCount[symptom] = 1;
          }
        }
      }
    });

    int busyDay = -1;
    int busyCount = 0;
    dayCount.forEach((d, c) {
      if (c > busyCount) {
        busyCount = c;
        busyDay = d;
      }
    });

    String commonSymptom = '';
    int maxSymptom = 0;
    symptomCount.forEach((s, c) {
      if (c > maxSymptom) {
        maxSymptom = c;
        commonSymptom = s;
      }
    });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        simpleCard('Patients This Month', totalMonth.toString()),
        if (busyDay != -1)
          simpleCard('Busiest Day', 'Day $busyDay ($busyCount patients)'),
        if (commonSymptom.isNotEmpty)
          simpleCard('Most Common Symptom', commonSymptom),
      ],
    );
  }

  // ---------------- UI CARD ----------------
  Widget simpleCard(String title, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(title, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
