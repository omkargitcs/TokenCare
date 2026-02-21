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

  // Cleans special characters for PDF generation
  String _cleanText(String? text) {
    if (text == null) return "General";
    return text.replaceAll(RegExp(r'[^\x00-\x7F]+'), '');
  }

  // --- DATA ENGINE: Calculates stats and Average Consultation Time ---
  Map<String, dynamic> _analyzeData(Map data) {
    int done = 0;
    int skipped = 0;
    List<int> durations = [];
    Map<String, int> symptomsMap = {};
    Map<int, int> hoursMap = {};
    Map<int, int> dayOfMonthMap = {};
    DateTime now = DateTime.now();

    data.forEach((key, value) {
      int checkIn = value['time'] ?? 0;
      int finish = value['completedAt'] ?? 0;

      DateTime t = DateTime.fromMillisecondsSinceEpoch(
        checkIn != 0
            ? checkIn
            : (finish != 0 ? finish : now.millisecondsSinceEpoch),
      );

      bool isMatch = showToday
          ? (t.day == now.day && t.month == now.month && t.year == now.year)
          : (t.month == now.month && t.year == now.year);

      if (isMatch) {
        if (value['status'] == 'done') {
          done++;
          if (finish > checkIn && checkIn != 0) {
            durations.add(finish - checkIn);
          }
        }
        if (value['status'] == 'skipped') skipped++;

        String s = value['symptoms'] ?? "General";
        symptomsMap[s] = (symptomsMap[s] ?? 0) + 1;
        hoursMap[t.hour] = (hoursMap[t.hour] ?? 0) + 1;
        dayOfMonthMap[t.day] = (dayOfMonthMap[t.day] ?? 0) + 1;
      }
    });

    double avgMinutes = 0;
    if (durations.isNotEmpty) {
      double avgMs = durations.reduce((a, b) => a + b) / durations.length;
      avgMinutes = avgMs / (1000 * 60);
    }

    String topSymptom = symptomsMap.isEmpty
        ? "None"
        : symptomsMap.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    String peakTime = "N/A";
    if (hoursMap.isNotEmpty) {
      int hr = hoursMap.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      peakTime = "${hr % 12 == 0 ? 12 : hr % 12} ${hr >= 12 ? 'PM' : 'AM'}";
    }

    return {
      'done': done,
      'skipped': skipped,
      'total': done + skipped,
      'avgTime': avgMinutes.toStringAsFixed(1),
      'topSymptom': topSymptom,
      'peakTime': peakTime,
      'peakDay': dayOfMonthMap.isEmpty
          ? "N/A"
          : "Day ${dayOfMonthMap.entries.reduce((a, b) => a.value > b.value ? a : b).key}",
    };
  }

  // --- EXPORT: EXCEL ---
  Future<void> _exportExcel(Map data) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Clinic_Report'];
    excel.delete('Sheet1');
    var stats = _analyzeData(data);

    sheetObject.appendRow([TextCellValue('CLINIC PERFORMANCE SUMMARY')]);
    sheetObject.appendRow([
      TextCellValue('Avg. Consultation (Mins)'),
      TextCellValue(stats['avgTime']),
    ]);
    sheetObject.appendRow([
      TextCellValue('Top Symptom'),
      TextCellValue(stats['topSymptom']),
    ]);
    sheetObject.appendRow([TextCellValue('')]);
    sheetObject.appendRow([
      TextCellValue('Date'),
      TextCellValue('Time'),
      TextCellValue('Status'),
      TextCellValue('Symptoms'),
    ]);

    data.forEach((key, value) {
      DateTime t = DateTime.fromMillisecondsSinceEpoch(value['time'] ?? 0);
      sheetObject.appendRow([
        TextCellValue(DateFormat('yyyy-MM-dd').format(t)),
        TextCellValue(DateFormat('hh:mm a').format(t)),
        TextCellValue(value['status']?.toString().toUpperCase() ?? 'N/A'),
        TextCellValue(value['symptoms']?.toString() ?? 'General'),
      ]);
    });

    final directory = await getTemporaryDirectory();
    final filePath = "${directory.path}/Clinic_Insight_Report.xlsx";
    await File(filePath).writeAsBytes(excel.encode()!);
    await Share.shareXFiles([XFile(filePath)], text: 'Excel Export');
  }

  // --- EXPORT: PDF ---
  Future<void> _exportPDF(Map data) async {
    final pdf = pw.Document();
    var stats = _analyzeData(data);
    List<List<String>> tableData = [
      ['Date', 'Time', 'Status', 'Symptoms'],
    ];

    data.forEach((key, value) {
      DateTime t = DateTime.fromMillisecondsSinceEpoch(value['time'] ?? 0);
      tableData.add([
        DateFormat('yyyy-MM-dd').format(t),
        DateFormat('hh:mm a').format(t),
        value['status']?.toString().toUpperCase() ?? 'N/A',
        _cleanText(value['symptoms']?.toString()),
      ]);
    });

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            "Executive Clinic Report",
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _pdfStatBox("TOTAL PATIENTS", "${stats['total']}"),
              _pdfStatBox("AVG TIME (MINS)", "${stats['avgTime']}"),
              _pdfStatBox("PEAK HOUR", stats['peakTime']),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: tableData[0],
            data: tableData.sublist(1),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey900,
            ),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  pw.Widget _pdfStatBox(String label, String value) {
    return pw.Container(
      width: 160,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Column(
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Clinic Insights',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          StreamBuilder(
            stream: ref.onValue,
            builder: (context, snapshot) {
              return PopupMenuButton<String>(
                icon: const Icon(
                  Icons.download_outlined,
                  color: AppColors.accentTeal,
                ),
                color: AppColors.surfaceDark,
                onSelected: (val) {
                  if (snapshot.hasData &&
                      snapshot.data!.snapshot.value != null) {
                    Map data = snapshot.data!.snapshot.value as Map;
                    val == 'pdf' ? _exportPDF(data) : _exportExcel(data);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'pdf',
                    child: Text(
                      "Export PDF",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'excel',
                    child: Text(
                      "Export Excel",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: StreamBuilder(
        stream: ref.onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentTeal),
            );
          }
          var stats = _analyzeData(snapshot.data!.snapshot.value as Map);
          return Column(
            children: [
              _buildToggleSwitch(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio:
                        1.1, // Fixed: Prevents yellow overflow line
                    children: [
                      _statCard(
                        "Total Patients",
                        stats['total'].toString(),
                        Icons.people,
                        AppColors.accentBlue,
                      ),
                      _statCard(
                        "Avg. Mins",
                        "${stats['avgTime']}m",
                        Icons.timer_outlined,
                        Colors.greenAccent,
                      ),
                      _statCard(
                        "Top Case",
                        stats['topSymptom'],
                        Icons.medical_information,
                        Colors.purpleAccent,
                      ),
                      _statCard(
                        "Peak Time",
                        stats['peakTime'],
                        Icons.bolt,
                        Colors.orangeAccent,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildToggleSwitch() {
    return Container(
      margin: const EdgeInsets.all(20),
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
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

  Widget _toggleBtn(String t, bool active, VoidCallback tap) {
    return Expanded(
      child: GestureDetector(
        onTap: tap,
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: active ? AppColors.accentBlue : null,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            t,
            style: TextStyle(
              color: active ? Colors.white : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCard(String title, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 10),
          FittedBox(
            // Fixed: Shrinks text to fit card, removing yellow line
            fit: BoxFit.scaleDown,
            child: Text(
              val,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
