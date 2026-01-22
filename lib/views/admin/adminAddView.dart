import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../controllers/queueController.dart';

class AdminAddView extends StatefulWidget {
  const AdminAddView({super.key});

  @override
  State<AdminAddView> createState() => _AdminAddViewState();
}

class _AdminAddViewState extends State<AdminAddView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _serviceController = TextEditingController(text: 'Haircut');
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 12, minute: 0);
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _submitWalkIn() async {
    if (_nameController.text.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      // Use the ADMIN specific method (No Geo Check, Auto ID)
      await Provider.of<QueueController>(context, listen: false).adminAddWalkIn(
        _nameController.text,
        _phoneController.text,
        _serviceController.text,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitFutureBooking() async {
    if (_nameController.text.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final bookingDateTime = DateTime(
          _selectedDate.year, _selectedDate.month, _selectedDate.day,
          _selectedTime.hour, _selectedTime.minute
      );

      // Use the ADMIN specific method
      await Provider.of<QueueController>(context, listen: false).adminBookAppointment(
        _nameController.text,
        _phoneController.text,
        _serviceController.text,
        bookingDateTime,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(days: 1)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365))
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _selectedTime);
    if (picked != null) setState(() => _selectedTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("New Appointment", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16)),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]),
              labelColor: const Color(0xFF2E3192),
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              dividerColor: Colors.transparent,
              tabs: const [Tab(text: "Walk-In"), Tab(text: "Future Booking")],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
              controller: _tabController,
              children: [
                _buildForm(isFuture: false, btnLabel: "Join Queue Now", btnIcon: Icons.flash_on),
                _buildForm(isFuture: true, btnLabel: "Schedule Booking", btnIcon: Icons.calendar_today),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm({required bool isFuture, required String btnLabel, required IconData btnIcon}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Full Name", prefixIcon: Icon(Icons.person_outline))),
          const SizedBox(height: 16),
          TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Phone Number", prefixIcon: Icon(Icons.phone_outlined))),
          const SizedBox(height: 24),
          TextField(controller: _serviceController, decoration: const InputDecoration(labelText: "Service Type", prefixIcon: Icon(Icons.cut_outlined))),

          if (isFuture) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _dateTimeCard(DateFormat('MMM d').format(_selectedDate), Icons.calendar_today, _pickDate)),
                const SizedBox(width: 12),
                Expanded(child: _dateTimeCard(_selectedTime.format(context), Icons.access_time, _pickTime)),
              ],
            ),
          ],
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: isFuture ? _submitFutureBooking : _submitWalkIn,
            icon: Icon(btnIcon),
            label: Text(btnLabel),
          ),
        ],
      ),
    );
  }

  Widget _dateTimeCard(String text, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(color: const Color(0xFFF4F7FC), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.withOpacity(0.2))),
        child: Row(children: [Icon(icon, color: const Color(0xFF2E3192), size: 20), const SizedBox(width: 12), Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
      ),
    );
  }
}