import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../controllers/queueController.dart';
import '../../models/appoinmentModel.dart';

class DoctorDesktopView extends StatefulWidget {
  const DoctorDesktopView({super.key});

  @override
  State<DoctorDesktopView> createState() => _DoctorDesktopViewState();
}

class _DoctorDesktopViewState extends State<DoctorDesktopView> {
  // Form Controllers
  final _dietCtrl = TextEditingController();
  final _investigationCtrl = TextEditingController();

  // Medicine List State
  final List<Map<String, String>> _medicines = [];

  // Temporary Medicine Input
  final _medNameCtrl = TextEditingController();
  final _medQtyCtrl = TextEditingController();
  String _timing = "1-0-1";
  bool _afterFood = true;

  @override
  Widget build(BuildContext context) {
    final queue = Provider.of<QueueController>(context);
    // Find the first patient with 'active' status
    final activePatient = queue.activeQueue.isNotEmpty ? queue.activeQueue.first : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Deep Slate Background
      appBar: AppBar(
        title: const Text("Consultation Desk", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (activePatient != null)
            Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(20)),
              child: Center(child: Text("ACTIVE: ${activePatient.customerName.toUpperCase()}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
            )
        ],
      ),
      body: Row(
        children: [
          // LEFT PANEL: Waiting List
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text("WAITING ROOM", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: queue.waitingList.length,
                      itemBuilder: (ctx, i) {
                        final p = queue.waitingList[i];
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                                backgroundColor: const Color(0xFF6366F1).withOpacity(0.2),
                                child: Text("${p.tokenNumber}", style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold))
                            ),
                            title: Text(p.customerName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            subtitle: Text(p.serviceType, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                            trailing: IconButton(
                              icon: const Icon(Icons.play_circle_filled_rounded, color: Color(0xFF10B981)),
                              onPressed: () => queue.updateStatus(p.id, AppointmentStatus.active),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // RIGHT PANEL: Prescription Pad
          Expanded(
            flex: 5,
            child: activePatient == null
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.medical_services_outlined, size: 64, color: Colors.white.withOpacity(0.1)),
                  const SizedBox(height: 16),
                  Text("No Active Patient", style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("Select a patient from the waiting list to begin.", style: TextStyle(color: Colors.white.withOpacity(0.1))),
                ],
              ),
            )
                : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient Info Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2))
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(activePatient.customerName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text(activePatient.serviceType, style: TextStyle(color: Colors.white.withOpacity(0.6))),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text("#${activePatient.tokenNumber}", style: const TextStyle(color: Color(0xFF6366F1), fontSize: 24, fontWeight: FontWeight.w900)),
                            Text(DateFormat('MMM dd, yyyy').format(DateTime.now()), style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Inputs
                  _buildSectionTitle("MEDICINES"),
                  _buildMedicineInputRow(),
                  const SizedBox(height: 16),
                  if (_medicines.isNotEmpty) _buildMedicineTable(),

                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(child: _buildTextArea("INVESTIGATIONS", _investigationCtrl)),
                      const SizedBox(width: 24),
                      Expanded(child: _buildTextArea("DIET & INSTRUCTIONS", _dietCtrl)),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.print_rounded, color: Colors.white70),
                        label: const Text("PRINT PRESCRIPTION", style: TextStyle(color: Colors.white)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        ),
                        onPressed: () => _printPrescription(activePatient),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text("FINISH & NEXT", style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          queue.updateStatus(activePatient.id, AppointmentStatus.completed);
                          _clearForm();
                        },
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Helpers ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
    );
  }

  Widget _buildMedicineInputRow() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Row(
        children: [
          Expanded(flex: 3, child: _glassInput(_medNameCtrl, "Medicine Name")),
          const SizedBox(width: 8),
          Expanded(child: _glassInput(_medQtyCtrl, "Qty")),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _timing,
                dropdownColor: const Color(0xFF1E293B),
                icon: const Icon(Icons.access_time_rounded, color: Colors.white38, size: 16),
                items: ["1-0-1", "1-1-1", "1-0-0", "0-0-1", "0-1-0", "S-O-S"].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white)))).toList(),
                onChanged: (v) => setState(() => _timing = v!),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(_afterFood ? "After Food" : "Before Food"),
            labelStyle: TextStyle(color: _afterFood ? Colors.white : Colors.white70, fontSize: 12),
            selected: _afterFood,
            onSelected: (v) => setState(() => _afterFood = v),
            backgroundColor: Colors.white.withOpacity(0.05),
            selectedColor: const Color(0xFF6366F1).withOpacity(0.2),
            checkmarkColor: const Color(0xFF6366F1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          const SizedBox(width: 8),
          IconButton(
            style: IconButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            onPressed: () {
              if (_medNameCtrl.text.isEmpty) return;
              setState(() {
                _medicines.add({
                  'name': _medNameCtrl.text,
                  'qty': _medQtyCtrl.text,
                  'timing': _timing,
                  'instruction': _afterFood ? "After Food" : "Empty Stomach"
                });
                _medNameCtrl.clear();
                _medQtyCtrl.clear();
              });
            },
          )
        ],
      ),
    );
  }

  Widget _glassInput(TextEditingController ctrl, String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(border: InputBorder.none, hintText: hint, hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13)),
      ),
    );
  }

  Widget _buildMedicineTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(border: Border.all(color: Colors.white12), borderRadius: BorderRadius.circular(16)),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(Colors.white.withOpacity(0.05)),
        columns: const [
          DataColumn(label: Text("Medicine", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold))),
          DataColumn(label: Text("Instruction", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold))),
          DataColumn(label: Text("Timing", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold))),
          DataColumn(label: Text("Qty", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold))),
          DataColumn(label: Text("Action", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold))),
        ],
        rows: _medicines.map((m) {
          return DataRow(cells: [
            DataCell(Text(m['name']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
            DataCell(Text(m['instruction']!, style: const TextStyle(color: Colors.white70))),
            DataCell(Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(m['timing']!, style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 12)),
            )),
            DataCell(Text(m['qty']!, style: const TextStyle(color: Colors.white))),
            DataCell(IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFF43F5E), size: 18),
                onPressed: () => setState(() => _medicines.remove(m))
            )),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildTextArea(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(label),
        Container(
          height: 120,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
          child: TextField(
            controller: ctrl,
            maxLines: null,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration.collapsed(hintText: "Enter clinical notes...", hintStyle: TextStyle(color: Colors.white.withOpacity(0.2))),
          ),
        ),
      ],
    );
  }

  void _clearForm() {
    _dietCtrl.clear();
    _investigationCtrl.clear();
    setState(() => _medicines.clear());
  }

  // --- PRINTING LOGIC ---
  Future<void> _printPrescription(Appointment appt) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // 1. Header
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text("Dr. Sankar Debroy", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                            pw.Text("MS (Ortho), Reg No. 1040 (TSMC)", style: const pw.TextStyle(fontSize: 10)),
                            pw.Text("Assoc Professor, Dept. of Orthopaedics", style: const pw.TextStyle(fontSize: 10)),
                            pw.Text("Agartala Government Medical College", style: const pw.TextStyle(fontSize: 10)),
                          ]
                      ),
                      pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text("CLINIC COPY", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                            pw.SizedBox(height: 4),
                            pw.Text("Contact: 9233812929", style: const pw.TextStyle(fontSize: 10)),
                            pw.Text("Sunday Closed", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          ]
                      ),
                    ]
                ),
                pw.Divider(thickness: 1, color: PdfColors.grey300),
                pw.SizedBox(height: 10),

                // 2. Patient Details
                pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(4)),
                    child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text("Patient: ${appt.customerName}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}", style: const pw.TextStyle(fontSize: 12)),
                        ]
                    )
                ),
                pw.SizedBox(height: 20),

                // 3. Body
                pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Left Column: Vitals/Inv
                      pw.Expanded(
                          flex: 1,
                          child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                if (_investigationCtrl.text.isNotEmpty) ...[
                                  pw.Text("INVESTIGATIONS", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                  pw.SizedBox(height: 4),
                                  pw.Text(_investigationCtrl.text, style: const pw.TextStyle(fontSize: 10)),
                                  pw.SizedBox(height: 20),
                                ],
                                pw.Text("VITALS", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                pw.SizedBox(height: 4),
                                _pdfCheckbox("BP: _____"),
                                _pdfCheckbox("Weight: _____"),
                                _pdfCheckbox("Pulse: _____"),
                              ]
                          )
                      ),
                      pw.SizedBox(width: 20),
                      // Right Column: Rx
                      pw.Expanded(
                          flex: 2,
                          child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text("RX (MEDICINES)", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                                pw.SizedBox(height: 10),
                                pw.Table.fromTextArray(
                                  headers: ['Medicine', 'Timing', 'Qty'],
                                  data: _medicines.map((m) => [m['name'], "${m['timing']} (${m['instruction']})", m['qty']]).toList(),
                                  headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                                  headerDecoration: const pw.BoxDecoration(color: PdfColors.black),
                                  cellStyle: const pw.TextStyle(fontSize: 10),
                                  cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.center, 2: pw.Alignment.center},
                                  border: null,
                                ),
                                pw.SizedBox(height: 20),
                                if (_dietCtrl.text.isNotEmpty) ...[
                                  pw.Text("INSTRUCTIONS", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                  pw.SizedBox(height: 4),
                                  pw.Text(_dietCtrl.text, style: const pw.TextStyle(fontSize: 10)),
                                ]
                              ]
                          )
                      )
                    ]
                ),

                pw.Spacer(),

                // 4. Footer
                pw.Divider(color: PdfColors.grey300),
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text("Generated by AppointmentQueue", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                      pw.Text("Signature", style: const pw.TextStyle(fontSize: 10)),
                    ]
                ),
              ]
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => doc.save());
  }

  pw.Widget _pdfCheckbox(String label) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
    );
  }
}