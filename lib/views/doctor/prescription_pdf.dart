import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PrescriptionPDF {
  static Future<void> generateAndPrint({
    required String patientName,
    required String prevReports,
    required List<Map<String, String>> medicines,
    required String newInvestigations,
    required String dietInstructions,
    required DateTime? nextVisit,
  }) async {
    final doc = pw.Document();

    doc.addPage(
        pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(40),
            build: (pw.Context context) {
              return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // --- HEADER ---
                    pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text("Dr. Shankar Deb Roy", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                                pw.Text("MS (Ortho), Reg No. 1040 (TSMC)"),
                                pw.Text("Assoc. Professor, Dept. of Orthopaedics"),
                                pw.Text("Agartala Govt. Medical College"),
                              ]
                          ),
                          pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              children: [
                                pw.Text("Ph: +91 9233812929"),
                                pw.Text("Sunday Closed", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                              ]
                          )
                        ]
                    ),
                    pw.Divider(thickness: 2),

                    // --- PATIENT INFO ---
                    pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8),
                        child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text("Patient: $patientName", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                              pw.Text("Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}"),
                            ]
                        )
                    ),
                    pw.Divider(),
                    pw.SizedBox(height: 20),

                    // --- BODY ---
                    pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Left Side: History & Investigation
                          pw.Expanded(
                              flex: 1,
                              child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    if (prevReports.isNotEmpty) ...[
                                      _sectionHeader("PREV. REPORTS"),
                                      pw.Text(prevReports, style: const pw.TextStyle(fontSize: 10)),
                                      pw.SizedBox(height: 20),
                                    ],

                                    _sectionHeader("VITALS"),
                                    pw.Text("BP: ______  Weight: ______"),
                                    pw.SizedBox(height: 20),

                                    if (newInvestigations.isNotEmpty) ...[
                                      _sectionHeader("ADVICE / TESTS"),
                                      pw.Text(newInvestigations, style: const pw.TextStyle(fontSize: 10)),
                                    ]
                                  ]
                              )
                          ),
                          pw.SizedBox(width: 20),
                          // Vertical Line
                          pw.Container(width: 1, height: 400, color: PdfColors.grey300),
                          pw.SizedBox(width: 20),

                          // Right Side: Rx
                          pw.Expanded(
                              flex: 2,
                              child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text("Rx", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                                    pw.SizedBox(height: 10),

                                    // Medicine List
                                    ...medicines.map((m) => pw.Padding(
                                        padding: const pw.EdgeInsets.only(bottom: 8),
                                        child: pw.Row(
                                            children: [
                                              pw.Expanded(child: pw.Text(m['name']!, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                                              pw.SizedBox(width: 10),
                                              pw.Text(m['timing']!, style: const pw.TextStyle(fontSize: 10)),
                                              pw.SizedBox(width: 10),
                                              pw.Text("(${m['instruction']})", style: const pw.TextStyle(fontSize: 10)),
                                              pw.SizedBox(width: 10),
                                              pw.Text("Qty: ${m['qty']}", style: const pw.TextStyle(fontSize: 10)),
                                            ]
                                        )
                                    )),

                                    pw.SizedBox(height: 30),
                                    if (dietInstructions.isNotEmpty) ...[
                                      _sectionHeader("INSTRUCTIONS / DIET"),
                                      pw.Text(dietInstructions, style: const pw.TextStyle(fontSize: 10)),
                                    ]
                                  ]
                              )
                          )
                        ]
                    ),

                    pw.Spacer(),

                    // --- FOOTER ---
                    if (nextVisit != null)
                      pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.all(10),
                          decoration: pw.BoxDecoration(border: pw.Border.all()),
                          child: pw.Text("NEXT VISIT DATE: ${DateFormat('dd MMM yyyy').format(nextVisit)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))
                      ),
                    pw.SizedBox(height: 20),
                    pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text("Powered by Universal Clinic"),
                          pw.Text("(Signature)", style: const pw.TextStyle(fontSize: 12)),
                        ]
                    )
                  ]
              );
            }
        )
    );

    await Printing.layoutPdf(onLayout: (format) => doc.save());
  }

  static pw.Widget _sectionHeader(String text) {
    return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Text(text, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline))
    );
  }
}