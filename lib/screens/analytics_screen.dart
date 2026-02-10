import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

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
      backgroundColor: AppColors.backgroundBlack,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Clinic Insights',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textMain,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.accentTeal),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildToggleSwitch(),
          Expanded(
            child: StreamBuilder(
              stream: ref.onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accentTeal,
                    ),
                  );
                }
                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data?.snapshot.value == null) {
                  return const Center(
                    child: Text(
                      "No data available",
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }

                Map data = snapshot.data!.snapshot.value as Map;
                return _buildDashboardContent(data);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleSwitch() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      height: 55,
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _toggleBtn(
            "Today",
            showToday,
            () => setState(() => showToday = true),
          ),
          _toggleBtn(
            "Monthly",
            !showToday,
            () => setState(() => showToday = false),
          ),
        ],
      ),
    );
  }

  Widget _toggleBtn(String title, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: isActive ? AppColors.darkGradient : null,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isActive ? Colors.white : AppColors.textMuted,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardContent(Map data) {
    int doneCount = 0;
    int skippedCount = 0;
    Map<String, int> symptomCount = {};
    Map<int, int> hourCount = {};
    Map<String, int> dayCount = {};
    Map<String, int> monthCount = {};
    DateTime now = DateTime.now();

    data.forEach((key, value) {
      // Ensure we have a timestamp to work with
      int timestamp =
          value['time'] ?? value['completedAt'] ?? now.millisecondsSinceEpoch;
      DateTime t = DateTime.fromMillisecondsSinceEpoch(timestamp);

      bool isMatch = showToday
          ? (t.day == now.day && t.month == now.month && t.year == now.year)
          : (t.month == now.month && t.year == now.year);

      if (isMatch) {
        // 1. Status Tracking
        if (value['status'] == 'done') doneCount++;
        if (value['status'] == 'skipped') skippedCount++;

        // 2. Symptom Frequency
        String symptom = value['symptoms'] ?? "General";
        symptomCount[symptom] = (symptomCount[symptom] ?? 0) + 1;

        // 3. Peak Time Logic (2-Hour Window)
        int rangeStart = (t.hour ~/ 2) * 2;
        hourCount[rangeStart] = (hourCount[rangeStart] ?? 0) + 1;

        // 4. Busiest Day Logic
        String dayName = DateFormat('EEEE').format(t);
        dayCount[dayName] = (dayCount[dayName] ?? 0) + 1;

        // 5. Monthly Tracking (for year view)
        String monthName = DateFormat('MMMM').format(t);
        monthCount[monthName] = (monthCount[monthName] ?? 0) + 1;
      }
    });

    // Final Statistics Calculations
    String topSymptom = symptomCount.isEmpty
        ? "None"
        : symptomCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    String peakTimeRange = "N/A";
    if (hourCount.isNotEmpty) {
      int startHour = hourCount.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      String startLabel = DateFormat(
        'h a',
      ).format(DateTime(2024, 1, 1, startHour));
      String endLabel = DateFormat(
        'h a',
      ).format(DateTime(2024, 1, 1, startHour + 2));
      peakTimeRange = "$startLabel - $endLabel";
    }
    String busyTitle = showToday ? "Peak Hour" : "Busiest Day";

    String busiestPeriod = "N/A";
    if (showToday) {
      busiestPeriod = peakTimeRange;
    } else {
      busiestPeriod = dayCount.isEmpty
          ? "N/A"
          : dayCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _wideCard(
                "Completed Patients",
                doneCount.toString(),
                Icons.check_circle_outline,
                AppColors.accentTeal,
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  // 1. Skipped Patients
                  _statCard(
                    "Skipped",
                    skippedCount.toString(),
                    Icons.person_off_rounded,
                    Colors.redAccent,
                  ),

                  // 2. Top Case (Most Common Symptom)
                  _statCard(
                    "Top Case",
                    topSymptom,
                    Icons.medical_services_outlined,
                    Colors.purpleAccent,
                  ),

                  // 3. Peak Time (The 2-hour range)
                  _statCard(
                    "Peak Time",
                    peakTimeRange,
                    Icons.access_time_filled,
                    Colors.orangeAccent,
                  ),

                  // 4. Contextual Card: Changes based on Toggle
                  _statCard(
                    showToday ? "Busiest Month" : "Busiest Day",
                    showToday
                        ? (monthCount.isNotEmpty
                              ? monthCount.entries
                                    .reduce((a, b) => a.value > b.value ? a : b)
                                    .key
                              : "N/A")
                        : (dayCount.isNotEmpty
                              ? dayCount.entries
                                    .reduce((a, b) => a.value > b.value ? a : b)
                                    .key
                              : "N/A"),
                    showToday ? Icons.insights_rounded : Icons.calendar_today,
                    AppColors.accentBlue,
                  ),
                ],
              ),

              const SizedBox(height: 16),
              _wideCard(
                showToday ? "Current Status" : "Monthly Trend",
                showToday
                    ? "Live Updates"
                    : DateFormat('MMMM yyyy').format(now),
                Icons.trending_up_rounded,
                Colors.pinkAccent,
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _wideCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.3), color.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
