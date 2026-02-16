import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PrescriptionPDF {
  // --- Modern Color Palette & Typography ---
  static const double _baseFontSize = 10;

  // Professional Medical Teal/Cyan
  static final PdfColor primaryColor = PdfColor.fromHex('#007B83');
  static final PdfColor secondaryColor = PdfColor.fromHex('#E0F2F1');
  static final PdfColor textColor = PdfColors.grey800;
  static final PdfColor lightGrey = PdfColors.grey100;
// 0.2 represents 20% opacity
  static final PdfColor primaryTransparent = PdfColor(primaryColor.red, primaryColor.green, primaryColor.blue, 0.2);

  static pw.TextStyle get _headerStyle => pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: primaryColor);
  static pw.TextStyle get _subHeaderStyle => pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600);
  static pw.TextStyle get _bodyStyle => pw.TextStyle(fontSize: _baseFontSize, color: textColor);
  static pw.TextStyle get _boldBodyStyle => pw.TextStyle(fontSize: _baseFontSize, fontWeight: pw.FontWeight.bold, color: textColor);
  static pw.TextStyle get _smallStyle => const pw.TextStyle(fontSize: 9, color: PdfColors.grey600);

  /// Main Generation Function
  static Future<void> generateAndPrint({
    required String patientName,
    required String diagnosis,
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
        margin: const pw.EdgeInsets.all(0), // Margin handled via containers for edge-to-edge design
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // 1. Massive Background Watermark
              pw.Positioned(
                top: 300,
                left: 150,
                child: pw.Opacity(
                  opacity: 0.03,
                  child: pw.Text("Rx", style: pw.TextStyle(fontSize: 400, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                ),
              ),

              // 2. Main Content
              pw.Padding(
                padding: const pw.EdgeInsets.all(40),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    pw.SizedBox(height: 16),
                    _buildPatientCard(patientName),
                    pw.SizedBox(height: 24),

                    // Content Body
                    pw.Expanded(
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Left Panel: Diagnosis, Vitals, Reports
                          _buildLeftPanel(diagnosis, prevReports, newInvestigations),

                          pw.SizedBox(width: 20),
                          // Vertical Divider
                          pw.Container(width: 1, height: double.infinity, color: PdfColors.grey300),
                          pw.SizedBox(width: 20),

                          // Right Panel: Medicines (Rx), Diet
                          _buildRightPanel(medicines, dietInstructions),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 20),
                    _buildFooter(nextVisit),
                  ],
                ),
              ),

              // 3. Top Accent Line
              pw.Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: pw.Container(height: 8, color: primaryColor),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => doc.save(), name: "Prescription_${patientName.replaceAll(' ', '_')}");
  }

  // --- Modular UI Components ---

  static pw.Widget _buildHeader() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("Dr. Shankar Deb Roy", style: _headerStyle),
            pw.SizedBox(height: 4),
            pw.Text("MS (Ortho), Reg No. 1040 (TSMC)", style: _boldBodyStyle),
            pw.Text("Assoc. Professor, Dept. of Orthopaedics", style: _bodyStyle),
            pw.Text("Agartala Govt. Medical College", style: _bodyStyle),
          ],
        ),
        pw.Container(
          padding: const pw.EdgeInsets.only(left: 16),
          decoration: pw.BoxDecoration(
            border: pw.Border(left: pw.BorderSide(color: primaryColor, width: 3)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text("CLINIC DETAILS", style: _subHeaderStyle.copyWith(color: primaryColor)),
              pw.SizedBox(height: 4),
              pw.Text("+91 9233812929", style: _boldBodyStyle),
              pw.Text("Sunday Closed", style: _bodyStyle),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildPatientCard(String name) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: pw.BoxDecoration(
        color: secondaryColor,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color:primaryTransparent),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("PATIENT NAME", style: _smallStyle.copyWith(color: primaryColor)),
              pw.SizedBox(height: 2),
              pw.Text(name.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text("DATE", style: _smallStyle.copyWith(color: primaryColor)),
              pw.SizedBox(height: 2),
              pw.Text(DateFormat('dd MMM yyyy').format(DateTime.now()), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildLeftPanel(String diagnosis, String prevReports, String investigations) {
    return pw.Expanded(
      flex: 3, // Changed flex for better proportion
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (diagnosis.isNotEmpty) _buildSection("CLINICAL DIAGNOSIS", diagnosis),
          if (prevReports.isNotEmpty) _buildSection("PREVIOUS REPORTS", prevReports),

          // Vitals Block
          _buildSectionHeader("VITALS"),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
                color: lightGrey,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.grey300)
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text("BP: ______ mmHg", style: _bodyStyle),
                      pw.Text("Temp: ______ °F", style: _bodyStyle),
                    ]
                ),
                pw.SizedBox(height: 8),
                pw.Text("Weight: ______ kg", style: _bodyStyle),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          if (investigations.isNotEmpty) _buildSection("ADVICE / TESTS", investigations),
        ],
      ),
    );
  }

  static pw.Widget _buildRightPanel(List<Map<String, String>> medicines, String instructions) {
    return pw.Expanded(
      flex: 5, // Gives more room to medicines
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text("Rx", style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold, color: primaryColor, fontStyle: pw.FontStyle.italic)),
                pw.SizedBox(width: 8),
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Text("MEDICATIONS", style: _subHeaderStyle),
                )
              ]
          ),
          pw.SizedBox(height: 12),

          // Structured Medicine List
          ...medicines.asMap().entries.map((entry) {
            int index = entry.key;
            Map<String, String> med = entry.value;
            // Alternating background colors for readability
            final bgColor = index % 2 == 0 ? PdfColors.white : PdfColors.grey50;
            return _buildMedicineRow(med, index + 1, bgColor);
          }),

          pw.SizedBox(height: 30),
          if (instructions.isNotEmpty) _buildSection("INSTRUCTIONS / DIET", instructions),
        ],
      ),
    );
  }

  static pw.Widget _buildMedicineRow(Map<String, String> med, int index, PdfColor bgColor) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: pw.BoxDecoration(
        color: bgColor,
        border: const pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text("$index.", style: _boldBodyStyle.copyWith(color: primaryColor)),
          pw.SizedBox(width: 8),
          pw.Expanded(
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(med['name'] ?? '', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: textColor)),
                    pw.SizedBox(height: 2),
                    pw.Row(
                        children: [
                          pw.Text("Dosage: ", style: _smallStyle),
                          pw.Text(med['timing'] ?? '', style: _smallStyle.copyWith(fontWeight: pw.FontWeight.bold, color: primaryColor)),
                          pw.SizedBox(width: 12),
                          pw.Text("Take: ", style: _smallStyle),
                          pw.Text(med['instruction'] ?? '', style: _smallStyle.copyWith(color: textColor)),
                        ]
                    )
                  ]
              )
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(
              color: primaryTransparent,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text("Qty: ${med['qty'] ?? ''}", style: _smallStyle.copyWith(fontWeight: pw.FontWeight.bold, color: primaryColor)),
          )
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(DateTime? nextVisit) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            // Next Visit Banner
            if (nextVisit != null)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  children: [
                    pw.Text("NEXT VISIT: ", style: _bodyStyle.copyWith(color: PdfColors.white)),
                    pw.Text(
                      DateFormat('dd MMM yyyy').format(nextVisit),
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                    ),
                  ],
                ),
              )
            else
              pw.SizedBox(width: 10), // Placeholder if null

            // Signature Block
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.SizedBox(height: 40), // Space for physical signature
                pw.Container(width: 160, height: 1, color: primaryColor),
                pw.SizedBox(height: 4),
                pw.Text("Dr. Shankar Deb Roy", style: _boldBodyStyle),
                pw.Text("Signature", style: _smallStyle),
              ],
            )
          ],
        ),
        pw.SizedBox(height: 24),

        // Bottom Branding
        pw.Center(
          child: pw.Text("Powered by Rashi", style: _smallStyle.copyWith(color: PdfColors.grey400)),
        ),
      ],
    );
  }

  // --- Helper Methods ---

  static pw.Widget _buildSection(String title, String content) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title),
        pw.Text(content, style: _bodyStyle.copyWith(lineSpacing: 2)),
        pw.SizedBox(height: 20),
      ],
    );
  }

  static pw.Widget _buildSectionHeader(String text) {
    return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Row(
            children: [
              pw.Container(width: 4, height: 12, color: primaryColor),
              pw.SizedBox(width: 6),
              pw.Text(
                text,
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                    letterSpacing: 1.2
                ),
              ),
            ]
        )
    );
  }
}