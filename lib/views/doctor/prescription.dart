import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../controllers/queueController.dart';
import '../../models/appoinmentModel.dart';
import '../../models/prescriptionModel.dart';
import '../../widgets/appColors.dart';
import 'prescriptionPdf.dart';

class PrescriptionView extends StatefulWidget {
  final Appointment patient;
  final VoidCallback onFinish;
  // --- NEW: Draft Support ---
  final Map<String, dynamic>? initialDraft;
  final Function(Map<String, dynamic>)? onDraftChanged;

  const PrescriptionView({
    super.key,
    required this.patient,
    required this.onFinish,
    this.initialDraft,
    this.onDraftChanged,
  });

  @override
  State<PrescriptionView> createState() => _PrescriptionViewState();
}

class _PrescriptionViewState extends State<PrescriptionView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // -- Controllers --
  late TextEditingController _diagnosisCtrl;
  late TextEditingController _prevReportCtrl;
  late TextEditingController _newInvestCtrl;
  late TextEditingController _dietCtrl;

  final _medNameCtrl = TextEditingController();
  final _medQtyCtrl = TextEditingController();

  DateTime? _nextVisitDate;
  bool _isSubmitting = false;

  // -- Medicine State --
  List<Map<String, String>> _medicines = [];
  String _timing = "1-0-1";
  bool _afterFood = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final draft = widget.initialDraft ?? {};

    _diagnosisCtrl = TextEditingController(text: draft['diagnosis'] ?? '');
    _prevReportCtrl = TextEditingController(text: draft['prevReport'] ?? '');
    _newInvestCtrl = TextEditingController(text: draft['newInvest'] ?? '');
    _dietCtrl = TextEditingController(text: draft['diet'] ?? '');

    if (draft['medicines'] != null) {
      _medicines = List<Map<String, String>>.from(
          (draft['medicines'] as List).map((item) => Map<String, String>.from(item))
      );
    }

    if (draft['nextVisit'] != null) {
      _nextVisitDate = DateTime.tryParse(draft['nextVisit']);
    }

    _diagnosisCtrl.addListener(_notifyChange);
    _prevReportCtrl.addListener(_notifyChange);
    _newInvestCtrl.addListener(_notifyChange);
    _dietCtrl.addListener(_notifyChange);
  }

  void _notifyChange() {
    if (widget.onDraftChanged != null) {
      widget.onDraftChanged!({
        'diagnosis': _diagnosisCtrl.text,
        'prevReport': _prevReportCtrl.text,
        'newInvest': _newInvestCtrl.text,
        'diet': _dietCtrl.text,
        'medicines': _medicines,
        'nextVisit': _nextVisitDate?.toIso8601String(),
      });
    }
  }

  @override
  void dispose() {
    _diagnosisCtrl.dispose();
    _prevReportCtrl.dispose();
    _newInvestCtrl.dispose();
    _dietCtrl.dispose();
    _medNameCtrl.dispose();
    _medQtyCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // --- BACKEND ACTION: SUBMIT ---
  Future<void> _submitConsultation() async {
    if (_diagnosisCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter a Diagnosis"), backgroundColor: AppColors.error)
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 1. Format Medicines for Backend (List<String>)
      List<String> formattedMedicines = _medicines.map((m) {
        return "${m['name']} | ${m['timing']} | ${m['instruction']} | Qty: ${m['qty']}";
      }).toList();

      // 2. Combine Notes
      String fullNotes = """
Previous Reports: ${_prevReportCtrl.text}
New Investigations: ${_newInvestCtrl.text}
Diet/Instructions: ${_dietCtrl.text}
Next Visit: ${_nextVisitDate != null ? DateFormat('dd MMM yyyy').format(_nextVisitDate!) : 'Not Scheduled'}
      """.trim();

      // 3. Call Controller (Pass Vitals Here)
      final queue = Provider.of<QueueController>(context, listen: false);
      await queue.completeAppointment(
        appointmentId: widget.patient.id,
        patientId: widget.patient.patientId ?? widget.patient.phoneNumber,
        medicines: formattedMedicines,
        notes: fullNotes,
        diagnosis: _diagnosisCtrl.text,
        vitals: widget.patient.vitals, // <--- SAVES VITALS PERMANENTLY TO DB
      );

      // 4. Trigger Parent Callback
      widget.onFinish();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.error)
      );
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildPatientHeader(),
        Container(
          color: AppColors.surface,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            dividerColor: AppColors.glassBorder,
            tabs: const [
              Tab(text: "CURRENT CONSULTATION", icon: Icon(Icons.edit_note_rounded)),
              Tab(text: "PATIENT HISTORY", icon: Icon(Icons.history_rounded)),
            ],
          ),
        ),
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

  // --- REFACTORED PATIENT HEADER (NOW INCLUDES VITALS BAR) ---
  Widget _buildPatientHeader() {
    final v = widget.patient.vitals;
    final bool hasVitals = v != null && v.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary,
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
                      _tag("Token #${widget.patient.tokenNumber}", AppColors.success),
                      const SizedBox(width: 8),
                      Text(widget.patient.phoneNumber, style: const TextStyle(color: Colors.white54)),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.glassWhite, borderRadius: BorderRadius.circular(8)),
                child: Text(DateFormat('dd MMM yyyy').format(DateTime.now()), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),

          // --- DOCTOR'S VITALS DISPLAY BAR ---
          if (hasVitals) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _vitalItem("BP", v['bp']),
                  _vitalItem("Temp", v['temp']),
                  _vitalItem("Weight", v['weight']),
                  _vitalItem("SpO2", v['spo2']),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _vitalItem(String label, dynamic value) {
    String displayVal = (value == null || value.toString().trim().isEmpty) ? "--" : value.toString();
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(displayVal, style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w900)),
      ],
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
          // Diagnosis Field
          _buildSectionLabel("CLINICAL DIAGNOSIS"),
          TextField(
            controller: _diagnosisCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            decoration: _inputDeco("Ex: Acute Bronchitis").copyWith(
              fillColor: AppColors.primary.withOpacity(0.1),
              prefixIcon: const Icon(Icons.local_hospital_rounded, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 32),

          _buildSectionLabel("PREVIOUS INVESTIGATION REPORT SUMMARY"),
          TextField(
            controller: _prevReportCtrl,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDeco("Enter summary of previous reports if any..."),
          ),
          const SizedBox(height: 32),

          _buildSectionLabel("MEDICINES"),
          _buildMedicineAdder(),
          if (_medicines.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildMedicineTable(),
          ],
          const SizedBox(height: 32),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionLabel("ADVICE / NEW INVESTIGATIONS"),
                    TextField(
                      controller: _newInvestCtrl,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDeco("List tests or advice..."),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionLabel("DIET & SPECIAL INSTRUCTIONS"),
                    TextField(
                      controller: _dietCtrl,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDeco("Diet plan, precautions..."),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          _buildActionFooter(),
        ],
      ),
    );
  }

  Widget _buildActionFooter() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 16,
      spacing: 16,
      children: [
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
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(primary: AppColors.primary, surface: AppColors.surface),
                        ),
                        child: child!,
                      );
                    }
                );
                if (d != null) {
                  setState(() => _nextVisitDate = d);
                  _notifyChange();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.glassWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded, color: Colors.white54, size: 18),
                    const SizedBox(width: 12),
                    Text(
                      _nextVisitDate == null ? "Select Date" : DateFormat('dd MMM yyyy').format(_nextVisitDate!),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // PRINT BUTTON - WIRED TO DIAGNOSIS AND VITALS
              OutlinedButton.icon(
                icon: const Icon(Icons.print_rounded),
                label: const Text("PRINT PRESCRIPTION"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  PrescriptionPDF.generateAndPrint(
                    patientName: widget.patient.customerName,
                    diagnosis: _diagnosisCtrl.text,
                    prevReports: _prevReportCtrl.text,
                    medicines: _medicines,
                    newInvestigations: _newInvestCtrl.text,
                    dietInstructions: _dietCtrl.text,
                    nextVisit: _nextVisitDate,
                    vitals: widget.patient.vitals, // <--- PASSES VITALS TO PDF
                  );
                },
              ),
              const SizedBox(width: 16),

              // FINISH BUTTON
              ElevatedButton.icon(
                icon: _isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded),
                label: Text(_isSubmitting ? "SAVING..." : "FINISH CONSULTATION"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: _isSubmitting ? null : _submitConsultation,
              ),
            ]
        ),
      ],
    );
  }

  // --- TAB 2: HISTORY VIEW (WIRED) ---
  Widget _buildHistoryView() {
    final queryId = widget.patient.patientId ?? widget.patient.phoneNumber;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('prescriptions')
          .where('patientId', isEqualTo: queryId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_edu_rounded, size: 64, color: Colors.white.withOpacity(0.05)),
                const SizedBox(height: 16),
                const Text("No previous records found for this patient.", style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final p = Prescription.fromMap(data, docs[index].id);

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.glassWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('dd MMM yyyy • hh:mm a').format(p.timestamp),
                        style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p.diagnosis.isNotEmpty ? p.diagnosis : "Routine Checkup",
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: p.medicines.take(3).map((m) {
                      final name = m.split('|').first.trim();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text(name, style: const TextStyle(color: AppColors.primary, fontSize: 11)),
                      );
                    }).toList(),
                  ),
                  if (p.medicines.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text("+ ${p.medicines.length - 3} more medicines", style: const TextStyle(color: Colors.white38, fontSize: 10)),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- UI Helpers ---

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.glassWhite,
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.all(16),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(text, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
    );
  }

  Widget _buildMedicineAdder() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AppColors.glassWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.glassBorder)),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _medNameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(border: InputBorder.none, hintText: "  Medicine Name", hintStyle: TextStyle(color: Colors.white38, fontSize: 13)),
            ),
          ),
          Container(width: 1, height: 24, color: Colors.white12),
          Expanded(
            flex: 1,
            child: TextField(
              controller: _medQtyCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(border: InputBorder.none, hintText: "  Qty", hintStyle: TextStyle(color: Colors.white38, fontSize: 13)),
            ),
          ),
          const SizedBox(width: 8),
          _buildDropdown(),
          const SizedBox(width: 8),
          _buildChip(),
          const SizedBox(width: 8),
          IconButton(
            style: IconButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            icon: const Icon(Icons.add_rounded, color: Colors.white),
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

    _notifyChange();
  }

  Widget _buildMedicineTable() {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppColors.glassBorder), borderRadius: BorderRadius.circular(12)),
      width: double.infinity,
      child: DataTable(
        headingRowHeight: 40,
        headingRowColor: WidgetStateProperty.all(AppColors.glassWhite),
        columns: const [
          DataColumn(label: Text("Name", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold))),
          DataColumn(label: Text("Dosage", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold))),
          DataColumn(label: Text("Instruction", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold))),
          DataColumn(label: Text("Qty", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold))),
          DataColumn(label: Text("", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold))),
        ],
        rows: _medicines.map((m) {
          return DataRow(cells: [
            DataCell(Text(m['name']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
            DataCell(Text(m['timing']!, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
            DataCell(Text(m['instruction']!, style: const TextStyle(color: Colors.white70))),
            DataCell(Text(m['qty']!, style: const TextStyle(color: Colors.white))),
            DataCell(IconButton(
              icon: Icon(Icons.remove_circle_outline_rounded, color: AppColors.error.withOpacity(0.8), size: 18),
              onPressed: () {
                setState(() => _medicines.remove(m));
                _notifyChange();
              },
            ))
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _timing,
          dropdownColor: AppColors.surface,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white38),
          items: ["1-0-1", "1-1-1", "1-0-0", "0-0-1", "S-O-S"].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white, fontSize: 13)))).toList(),
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
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide.none),
      labelStyle: TextStyle(color: _afterFood ? Colors.white : Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
    );
  }
}