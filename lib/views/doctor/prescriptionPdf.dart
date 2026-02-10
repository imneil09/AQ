import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PrescriptionPDF {
  // --- Constants & Styles ---
  static const double _baseFontSize = 10;

  static pw.TextStyle get _headerStyle => pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold);
  static pw.TextStyle get _subHeaderStyle => pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold);
  static pw.TextStyle get _bodyStyle => const pw.TextStyle(fontSize: _baseFontSize);
  static pw.TextStyle get _boldBodyStyle => pw.TextStyle(fontSize: _baseFontSize, fontWeight: pw.FontWeight.bold);
  static pw.TextStyle get _smallStyle => const pw.TextStyle(fontSize: 9, color: PdfColors.grey700);

  /// Main Generation Function
  static Future<void> generateAndPrint({
    required String patientName,
    required String diagnosis, // <--- ADDED: Backend Field
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
              _buildHeader(),
              pw.Divider(thickness: 2),
              _buildPatientInfo(patientName),
              pw.Divider(),
              pw.SizedBox(height: 20),

              // Content Body
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Left Panel: Diagnosis, Vitals, Reports
                    _buildLeftPanel(diagnosis, prevReports, newInvestigations),

                    pw.SizedBox(width: 20),
                    // Vertical Divider
                    pw.Container(width: 1, height: 400, color: PdfColors.grey300),
                    pw.SizedBox(width: 20),

                    // Right Panel: Medicines (Rx), Diet
                    _buildRightPanel(medicines, dietInstructions),
                  ],
                ),
              ),

              pw.Spacer(),
              _buildFooter(nextVisit),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => doc.save());
  }

  // --- Modular UI Components ---

  static pw.Widget _buildHeader() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("Dr. Shankar Deb Roy", style: _headerStyle),
            pw.Text("MS (Ortho), Reg No. 1040 (TSMC)", style: _bodyStyle),
            pw.Text("Assoc. Professor, Dept. of Orthopaedics", style: _bodyStyle),
            pw.Text("Agartala Govt. Medical College", style: _bodyStyle),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text("Ph: +91 9233812929", style: _bodyStyle),
            pw.Text("Sunday Closed", style: _boldBodyStyle),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildPatientInfo(String name) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text("Patient: $name", style: _boldBodyStyle),
          pw.Text("Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}", style: _bodyStyle),
        ],
      ),
    );
  }

  static pw.Widget _buildLeftPanel(String diagnosis, String prevReports, String investigations) {
    return pw.Expanded(
      flex: 1,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ADDED: Diagnosis Section
          if (diagnosis.isNotEmpty) _buildSection("CLINICAL DIAGNOSIS", diagnosis),

          if (prevReports.isNotEmpty) _buildSection("PREV. REPORTS", prevReports),

          _buildSectionHeader("VITALS"),
          pw.Text("BP: ______  Weight: ______", style: _bodyStyle),
          pw.SizedBox(height: 20),

          if (investigations.isNotEmpty) _buildSection("ADVICE / TESTS", investigations),
        ],
      ),
    );
  }

  static pw.Widget _buildRightPanel(List<Map<String, String>> medicines, String instructions) {
    return pw.Expanded(
      flex: 2,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text("Rx", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, fontStyle: pw.FontStyle.italic)),
          pw.SizedBox(height: 10),

          ...medicines.map(_buildMedicineRow),

          pw.SizedBox(height: 30),
          if (instructions.isNotEmpty) _buildSection("INSTRUCTIONS / DIET", instructions),
        ],
      ),
    );
  }

  static pw.Widget _buildMedicineRow(Map<String, String> med) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Text(med['name'] ?? '', style: _boldBodyStyle)),
          pw.SizedBox(width: 8),
          pw.Text(med['timing'] ?? '', style: _bodyStyle),
          pw.SizedBox(width: 8),
          pw.Text("(${med['instruction'] ?? ''})", style: _smallStyle),
          pw.SizedBox(width: 8),
          pw.Text("Qty: ${med['qty'] ?? ''}", style: _bodyStyle),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(DateTime? nextVisit) {
    return pw.Column(
      children: [
        if (nextVisit != null)
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(border: pw.Border.all()),
            child: pw.Center(
              child: pw.Text(
                "NEXT VISIT DATE: ${DateFormat('dd MMM yyyy').format(nextVisit)}",
                style: _boldBodyStyle,
              ),
            ),
          ),
        pw.SizedBox(height: 20),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text("Powered by Universal Clinic", style: _smallStyle),
            pw.Column(
              children: [
                pw.SizedBox(height: 20), // Space for signing
                pw.Container(width: 150, height: 1, color: PdfColors.black),
                pw.Text("(Signature)", style: _bodyStyle),
              ],
            )
          ],
        )
      ],
    );
  }

  // --- Helper Methods ---

  static pw.Widget _buildSection(String title, String content) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title),
        pw.Text(content, style: _bodyStyle),
        pw.SizedBox(height: 15),
      ],
    );
  }

  static pw.Widget _buildSectionHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          decoration: pw.TextDecoration.underline,
        ),
      ),
    );
  }
}