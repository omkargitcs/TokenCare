import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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

  // --- LOGIC: DATA CRUNCHING ENGINE ---
  Map<String, dynamic> _analyzeData(Map data) {
    int done = 0;
    int skipped = 0;
    Map<String, int> symptomsMap = {};
    Map<int, int> hoursMap = {};
    Map<int, int> dayOfMonthMap = {};
    DateTime now = DateTime.now();

    data.forEach((key, value) {
      DateTime t = DateTime.fromMillisecondsSinceEpoch(
        value['time'] ?? value['completedAt'] ?? now.millisecondsSinceEpoch,
      );

      // Filtering logic based on Toggle (Today vs Monthly)
      bool isMatch = showToday
          ? (t.day == now.day && t.month == now.month && t.year == now.year)
          : (t.month == now.month && t.year == now.year);

      if (isMatch) {
        if (value['status'] == 'done') done++;
        if (value['status'] == 'skipped') skipped++;

        String s = value['symptoms'] ?? "General";
        symptomsMap[s] = (symptomsMap[s] ?? 0) + 1;
        hoursMap[t.hour] = (hoursMap[t.hour] ?? 0) + 1;
        dayOfMonthMap[t.day] = (dayOfMonthMap[t.day] ?? 0) + 1;
      }
    });

    String topSymptom = symptomsMap.isEmpty
        ? "None"
        : symptomsMap.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    String peakTime = "N/A";
    if (hoursMap.isNotEmpty) {
      int hr = hoursMap.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      peakTime = "${hr % 12 == 0 ? 12 : hr % 12} ${hr >= 12 ? 'PM' : 'AM'}";
    }

    String peakDay = dayOfMonthMap.isEmpty
        ? "N/A"
        : "Day ${dayOfMonthMap.entries.reduce((a, b) => a.value > b.value ? a : b).key}";

    return {
      'done': done,
      'skipped': skipped,
      'total': done + skipped,
      'topSymptom': topSymptom,
      'peakTime': peakTime,
      'peakDay': peakDay,
    };
  }

  // --- EXPORT: EXCEL WITH INSIGHTS ---
  Future<void> _exportExcel(Map data) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Clinic_Report'];
    excel.delete('Sheet1');

    var stats = _analyzeData(data);

    // Header Insights
    sheetObject.appendRow([TextCellValue('CLINIC PERFORMANCE SUMMARY')]);
    sheetObject.appendRow([
      TextCellValue('Total Patients'),
      IntCellValue(stats['total']),
    ]);
    sheetObject.appendRow([
      TextCellValue('Attended'),
      IntCellValue(stats['done']),
    ]);
    sheetObject.appendRow([
      TextCellValue('Skipped'),
      IntCellValue(stats['skipped']),
    ]);
    sheetObject.appendRow([
      TextCellValue('Busiest Day'),
      TextCellValue(stats['peakDay']),
    ]);
    sheetObject.appendRow([
      TextCellValue('Peak Time'),
      TextCellValue(stats['peakTime']),
    ]);
    sheetObject.appendRow([
      TextCellValue('Top Symptom'),
      TextCellValue(stats['topSymptom']),
    ]);
    sheetObject.appendRow([TextCellValue('')]); // Spacer row

    // Table Data
    sheetObject.appendRow([
      TextCellValue('Date'),
      TextCellValue('Time'),
      TextCellValue('Status'),
      TextCellValue('Symptoms'),
    ]);

    data.forEach((key, value) {
      DateTime t = DateTime.fromMillisecondsSinceEpoch(
        value['time'] ?? value['completedAt'] ?? 0,
      );
      sheetObject.appendRow([
        TextCellValue(DateFormat('yyyy-MM-dd').format(t)),
        TextCellValue(DateFormat('hh:mm a').format(t)),
        TextCellValue(value['status']?.toString().toUpperCase() ?? 'N/A'),
        TextCellValue(value['symptoms']?.toString() ?? 'General'),
      ]);
    });

    final directory = await getTemporaryDirectory();
    final filePath = "${directory.path}/Clinic_Insight_Report.xlsx";
    final file = File(filePath);
    await file.writeAsBytes(excel.encode()!);
    await Share.shareXFiles([XFile(filePath)], text: 'Clinic Excel Insights');
  }

  // --- EXPORT: PDF WITH INSIGHTS CARDS ---
  Future<void> _exportPDF(Map data) async {
    final pdf = pw.Document();
    var stats = _analyzeData(data);

    List<List<String>> tableData = [
      ['Date', 'Time', 'Status', 'Symptoms'],
    ];
    data.forEach((key, value) {
      DateTime t = DateTime.fromMillisecondsSinceEpoch(
        value['time'] ?? value['completedAt'] ?? 0,
      );
      tableData.add([
        DateFormat('yyyy-MM-dd').format(t),
        DateFormat('hh:mm a').format(t),
        value['status']?.toString().toUpperCase() ?? 'N/A',
        value['symptoms']?.toString() ?? 'General',
      ]);
    });

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            "Executive Clinic Report",
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            "Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}",
          ),
          pw.Divider(thickness: 2),
          pw.SizedBox(height: 15),

          // Insight Cards Grid
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _pdfStatBox("TOTAL PATIENTS", "${stats['total']}"),
              _pdfStatBox("ATTENDED", "${stats['done']}"),
              _pdfStatBox("SKIPPED", "${stats['skipped']}"),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _pdfStatBox("BUSIEST DAY", stats['peakDay']),
              _pdfStatBox("PEAK HOUR", stats['peakTime']),
              _pdfStatBox("TOP SYMPTOM", stats['topSymptom']),
            ],
          ),

          pw.SizedBox(height: 25),
          pw.Text(
            "Detailed Patient Logs",
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),

          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey900,
            ),
            cellAlignment: pw.Alignment.centerLeft,
            data: tableData,
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  pw.Widget _pdfStatBox(String label, String value) {
    return pw.Container(
      width: 170,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // --- UI BUILDING BLOCKS ---
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
          StreamBuilder(
            stream: ref.onValue,
            builder: (context, snapshot) {
              return PopupMenuButton<String>(
                icon: const Icon(
                  Icons.download_for_offline_outlined,
                  color: AppColors.accentTeal,
                ),
                color: AppColors.surfaceDark,
                onSelected: (value) {
                  if (snapshot.hasData &&
                      snapshot.data!.snapshot.value != null) {
                    Map data = snapshot.data!.snapshot.value as Map;
                    if (value == 'excel') _exportExcel(data);
                    if (value == 'pdf') _exportPDF(data);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'excel',
                    child: Text(
                      "Export Excel (.xlsx)",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'pdf',
                    child: Text(
                      "Export PDF (.pdf)",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              );
            },
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
                if (!snapshot.hasData ||
                    snapshot.data?.snapshot.value == null) {
                  return const Center(
                    child: Text(
                      "No data available",
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }
                return _buildDashboardContent(
                  snapshot.data!.snapshot.value as Map,
                );
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
    var stats = _analyzeData(data);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _wideCard(
                "Completed Patients",
                stats['done'].toString(),
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
                  _statCard(
                    "Skipped",
                    stats['skipped'].toString(),
                    Icons.person_off_rounded,
                    Colors.redAccent,
                  ),
                  _statCard(
                    "Top Case",
                    stats['topSymptom'],
                    Icons.medical_services_outlined,
                    Colors.purpleAccent,
                  ),
                  _statCard(
                    "Peak Time",
                    stats['peakTime'],
                    Icons.access_time_filled,
                    Colors.orangeAccent,
                  ),
                  _statCard(
                    showToday ? "Busiest Day" : "Peak Day",
                    stats['peakDay'],
                    Icons.calendar_today,
                    AppColors.accentBlue,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _wideCard(
                "Total Registry",
                stats['total'].toString(),
                Icons.analytics_outlined,
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
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
          Icon(icon, color: color, size: 40),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                ),
              ),
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
        ],
      ),
    );
  }
}
