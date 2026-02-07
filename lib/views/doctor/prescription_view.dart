import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/appoinmentModel.dart';
import 'prescription_pdf.dart'; // The separated PDF logic

class PrescriptionView extends StatefulWidget {
  final Appointment patient;
  final VoidCallback onFinish;

  const PrescriptionView({super.key, required this.patient, required this.onFinish});

  @override
  State<PrescriptionView> createState() => _PrescriptionViewState();
}

class _PrescriptionViewState extends State<PrescriptionView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // -- Controllers --
  final _prevReportCtrl = TextEditingController();
  final _newInvestCtrl = TextEditingController();
  final _dietCtrl = TextEditingController();
  final _medNameCtrl = TextEditingController();
  final _medQtyCtrl = TextEditingController();

  DateTime? _nextVisitDate;

  // -- Medicine State --
  final List<Map<String, String>> _medicines = [];
  String _timing = "1-0-1";
  bool _afterFood = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- 1. Patient Header ---
        _buildPatientHeader(),

        // --- 2. Tabs ---
        Container(
          color: const Color(0xFF1E293B),
          child: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF6366F1),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabs: const [
              Tab(text: "CURRENT CONSULTATION", icon: Icon(Icons.edit_note)),
              Tab(text: "PATIENT HISTORY", icon: Icon(Icons.history)),
            ],
          ),
        ),

        // --- 3. Body ---
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildConsultationForm(),
              _buildHistoryView(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPatientHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF6366F1),
            radius: 24,
            child: Text(widget.patient.customerName[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.patient.customerName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(
                children: [
                  _tag(widget.patient.serviceType, Colors.orange),
                  const SizedBox(width: 8),
                  _tag("Token #${widget.patient.tokenNumber}", Colors.green),
                  const SizedBox(width: 8),
                  Text(widget.patient.phoneNumber, style: const TextStyle(color: Colors.white54)),
                ],
              ),
            ],
          ),
          const Spacer(),
          Text(DateFormat('dd MMM yyyy').format(DateTime.now()), style: const TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  // --- TAB 1: CONSULTATION FORM ---
  Widget _buildConsultationForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Previous Reports
          _buildSectionLabel("PREVIOUS INVESTIGATION REPORT SUMMARY"),
          _buildTextArea(_prevReportCtrl, "Enter summary of previous reports if any..."),
          const SizedBox(height: 32),

          // Row 2: Medicines
          _buildSectionLabel("MEDICINES"),
          _buildMedicineAdder(),
          if (_medicines.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildMedicineTable(),
          ],
          const SizedBox(height: 32),

          // Row 3: New Investigations & Diet (Side by Side)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionLabel("ADVICE / NEW INVESTIGATIONS"),
                    _buildTextArea(_newInvestCtrl, "List tests or advice..."),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionLabel("DIET & SPECIAL INSTRUCTIONS"),
                    _buildTextArea(_dietCtrl, "Diet plan, precautions..."),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Row 4: Next Visit & Actions
          Row(
            children: [
              // Next Visit Picker
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel("NEXT VISIT DATE"),
                  InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(const Duration(days: 7)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365))
                      );
                      if(d != null) setState(() => _nextVisitDate = d);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.white54, size: 16),
                          const SizedBox(width: 10),
                          Text(
                            _nextVisitDate == null ? "Select Date" : DateFormat('dd MMM yyyy').format(_nextVisitDate!),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // Action Buttons
              OutlinedButton.icon(
                icon: const Icon(Icons.print),
                label: const Text("PRINT PRESCRIPTION"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                ),
                onPressed: () {
                  PrescriptionPDF.generateAndPrint(
                      patientName: widget.patient.customerName,
                      prevReports: _prevReportCtrl.text,
                      medicines: _medicines,
                      newInvestigations: _newInvestCtrl.text,
                      dietInstructions: _dietCtrl.text,
                      nextVisit: _nextVisitDate
                  );
                },
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle),
                label: const Text("FINISH CONSULTATION"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                ),
                onPressed: widget.onFinish,
              ),
            ],
          )
        ],
      ),
    );
  }

  // --- TAB 2: HISTORY VIEW ---
  Widget _buildHistoryView() {
    // This is a placeholder for the actual history list.
    // In a real app, you would fetch `queue.patientHistory` for this specific phone number.
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_edu, size: 64, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          const Text("No previous records found for this patient.", style: TextStyle(color: Colors.white24)),
        ],
      ),
    );
  }

  // --- UI Helpers ---
  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
    );
  }

  Widget _buildTextArea(TextEditingController ctrl, String hint) {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)),
      child: TextField(
        controller: ctrl,
        maxLines: null,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration.collapsed(hintText: hint, hintStyle: TextStyle(color: Colors.white.withOpacity(0.2))),
      ),
    );
  }

  Widget _buildMedicineAdder() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)),
      child: Row(
        children: [
          Expanded(flex: 3, child: _glassField(_medNameCtrl, "Medicine Name")),
          const SizedBox(width: 8),
          Expanded(flex: 1, child: _glassField(_medQtyCtrl, "Qty")),
          const SizedBox(width: 8),
          _buildDropdown(),
          const SizedBox(width: 8),
          _buildChip(),
          const SizedBox(width: 8),
          IconButton(
            style: IconButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _addMedicine,
          )
        ],
      ),
    );
  }

  void _addMedicine() {
    if (_medNameCtrl.text.isEmpty) return;
    setState(() {
      _medicines.add({
        'name': _medNameCtrl.text,
        'qty': _medQtyCtrl.text,
        'timing': _timing,
        'instruction': _afterFood ? "After Food" : "Before Food"
      });
      _medNameCtrl.clear();
      _medQtyCtrl.clear();
    });
  }

  Widget _buildMedicineTable() {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.white12), borderRadius: BorderRadius.circular(8)),
      width: double.infinity,
      child: DataTable(
        headingRowHeight: 40,
        headingRowColor: WidgetStateProperty.all(Colors.white.withOpacity(0.05)),
        columns: const [
          DataColumn(label: Text("Name", style: TextStyle(color: Colors.white54, fontSize: 12))),
          DataColumn(label: Text("Dosage", style: TextStyle(color: Colors.white54, fontSize: 12))),
          DataColumn(label: Text("Instruction", style: TextStyle(color: Colors.white54, fontSize: 12))),
          DataColumn(label: Text("Qty", style: TextStyle(color: Colors.white54, fontSize: 12))),
          DataColumn(label: Text("", style: TextStyle(color: Colors.white54, fontSize: 12))),
        ],
        rows: _medicines.map((m) {
          return DataRow(cells: [
            DataCell(Text(m['name']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            DataCell(Text(m['timing']!, style: const TextStyle(color: Color(0xFF6366F1)))),
            DataCell(Text(m['instruction']!, style: const TextStyle(color: Colors.white70))),
            DataCell(Text(m['qty']!, style: const TextStyle(color: Colors.white))),
            DataCell(IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.redAccent, size: 16),
              onPressed: () => setState(() => _medicines.remove(m)),
            ))
          ]);
        }).toList(),
      ),
    );
  }

  Widget _glassField(TextEditingController ctrl, String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(4)),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(border: InputBorder.none, hintText: hint, hintStyle: TextStyle(color: Colors.white38, fontSize: 13)),
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(4)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _timing,
          dropdownColor: const Color(0xFF1E293B),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white38),
          items: ["1-0-1", "1-1-1", "1-0-0", "0-0-1", "S-O-S"].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white)))).toList(),
          onChanged: (v) => setState(() => _timing = v!),
        ),
      ),
    );
  }

  Widget _buildChip() {
    return FilterChip(
      label: Text(_afterFood ? "After Food" : "Before Food"),
      selected: _afterFood,
      onSelected: (v) => setState(() => _afterFood = v),
      backgroundColor: Colors.white.withOpacity(0.05),
      selectedColor: const Color(0xFF6366F1).withOpacity(0.2),
      checkmarkColor: const Color(0xFF6366F1),
      labelStyle: TextStyle(color: _afterFood ? Colors.white : Colors.white54, fontSize: 12),
    );
  }
}