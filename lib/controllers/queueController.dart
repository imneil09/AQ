import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../models/appoinmentModel.dart';
import '../models/clinicModel.dart';

class QueueController extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- State Variables ---
  List<Clinic> clinics = [];
  List<Appointment> _todayQueue = [];
  Clinic? selectedClinic;

  // Stream Subscriptions
  StreamSubscription? _clinicSub;
  StreamSubscription? _queueSub;

  // Doctor Status
  bool _isOnBreak = false;

  // Search States
  String _liveSearchQuery = "";
  String _historySearchQuery = "";

  // Getters
  String get liveSearchQuery => _liveSearchQuery;
  String get historySearchQuery => _historySearchQuery;
  bool get isOnBreak => _isOnBreak;
  String get currentUserId => _auth.currentUser?.uid ?? '';
  List<Appointment> get history => _todayQueue; // Full list for metrics

  QueueController() {
    _fetchClinics();
  }

  @override
  void dispose() {
    _clinicSub?.cancel();
    _queueSub?.cancel();
    super.dispose();
  }

  // --- Doctor Actions ---

  void toggleBreak() {
    _isOnBreak = !_isOnBreak;
    notifyListeners();
  }

  Future<void> logout() async {
    await _auth.signOut();
    notifyListeners();
  }

  // --- Search Logic ---
  void updateLiveSearch(String query) {
    _liveSearchQuery = query.trim().toLowerCase();
    notifyListeners();
  }

  void updateHistorySearch(String query) {
    _historySearchQuery = query.trim().toLowerCase();
    notifyListeners();
  }

  // --- Clinic Management ---
  void _fetchClinics() {
    _clinicSub = _db.collection('clinics').snapshots().listen((snapshot) {
      clinics =
          snapshot.docs
              .map((doc) => Clinic.fromMap(doc.data(), doc.id))
              .toList();

      // --- CRITICAL FIX START ---
      // If we have a selected clinic, we MUST refresh it with the new data from the list
      if (selectedClinic != null) {
        try {
          // Find the updated version of the currently selected clinic
          selectedClinic = clinics.firstWhere(
            (c) => c.id == selectedClinic!.id,
          );
        } catch (e) {
          // If the selected clinic was deleted, default to the first one available
          selectedClinic = clinics.isNotEmpty ? clinics.first : null;
        }
      }
      // Initial Auto-select logic
      else if (clinics.isNotEmpty) {
        selectClinic(clinics.first);
      }
      // --- CRITICAL FIX END ---

      notifyListeners();
    });
  }

  void selectClinic(Clinic clinic) {
    selectedClinic = clinic;
    _listenToQueue(clinic.id);
    _runAutoCleanup(); // Run cleanup on startup/selection
    notifyListeners();
  }

  // --- QUEUE LISTENER & ALGORITHM ---

  void _listenToQueue(String clinicId) {
    _queueSub?.cancel();

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    _queueSub = _db
        .collection('appointments')
        .where('clinicId', isEqualTo: clinicId)
        .where('appointmentDate', isEqualTo: Timestamp.fromDate(todayStart))
        .orderBy('tokenNumber')
        .snapshots()
        .listen((snapshot) {
          var rawList =
              snapshot.docs
                  .map((doc) => Appointment.fromMap(doc.data(), doc.id))
                  .toList();

          // Apply the Dynamic Time Estimation Algorithm
          _todayQueue = _calculateEstimatedTimes(rawList);
          notifyListeners();
        });
  }

  // *** CORE ALGORITHM: DYNAMIC TIME ESTIMATION ***
  List<Appointment> _calculateEstimatedTimes(List<Appointment> list) {
    if (selectedClinic == null) return list;

    final dayName = DateFormat('EEEE').format(DateTime.now());
    final schedule = selectedClinic!.weeklySchedule[dayName];

    // If clinic is closed today or schedule missing, return raw list
    if (schedule == null || !schedule.isOpen) return list;

    // 1. Determine Start Time
    final parts = schedule.startTime.split(':');
    final startHour = int.parse(parts[0]);
    final startMin = int.parse(parts[1]);
    final now = DateTime.now();

    // The scheduled start time for today
    DateTime clinicStartTime = DateTime(
      now.year,
      now.month,
      now.day,
      startHour,
      startMin,
    );

    // 2. Real-Time Catch Up:
    // If the doctor is late (Now > StartTime), the queue flows from NOW.
    // If the doctor is early, it flows from the Schedule.
    DateTime rollingTime = now.isAfter(clinicStartTime) ? now : clinicStartTime;

    // 3. Break Mode
    if (_isOnBreak) {
      rollingTime = rollingTime.add(const Duration(minutes: 15));
    }

    // 4. "Skipped" Buffer Factor
    // Logic: If a patient is skipped, we reduce the total wait time (since they are gone),
    // BUT we add a small buffer (2 mins) per skipped patient to prevent erratic jumps
    // and account for the transition/confusion time.
    int skippedCount =
        list.where((a) => a.status == AppointmentStatus.skipped).length;
    int bufferMinutes = skippedCount * 2;
    rollingTime = rollingTime.add(Duration(minutes: bufferMinutes));

    // 5. Calculate Times for Active & Waiting
    return list.map((appt) {
      // Create a fresh object to avoid mutating the original stream data
      // (Manual copyWith since not in model)
      var newAppt = Appointment(
        id: appt.id,
        clinicId: appt.clinicId,
        doctorId: appt.doctorId,
        patientId: appt.patientId, // Fixed naming here
        customerName: appt.customerName,
        phoneNumber: appt.phoneNumber,
        serviceType: appt.serviceType,
        type: appt.type,
        appointmentDate: appt.appointmentDate,
        bookingTimestamp: appt.bookingTimestamp,
        tokenNumber: appt.tokenNumber,
        status: appt.status,
      );

      if (newAppt.status == AppointmentStatus.active) {
        // Active patients are consuming time NOW.
        newAppt.estimatedTime = rollingTime;
        rollingTime = rollingTime.add(
          Duration(minutes: schedule.avgConsultationTimeMinutes),
        );
      } else if (newAppt.status == AppointmentStatus.waiting) {
        // Waiting patients get the rolling time
        newAppt.estimatedTime = rollingTime;
        rollingTime = rollingTime.add(
          Duration(minutes: schedule.avgConsultationTimeMinutes),
        );
      } else {
        // Skipped, Completed, Cancelled have no estimated wait time
        newAppt.estimatedTime = null;
      }

      return newAppt;
    }).toList();
  }

  // --- UI Helpers ---

  List<Appointment> get _searchedQueue {
    if (_liveSearchQuery.isEmpty) return _todayQueue;
    return _todayQueue
        .where(
          (a) =>
              a.customerName.toLowerCase().contains(_liveSearchQuery) ||
              a.phoneNumber.contains(_liveSearchQuery) ||
              a.tokenNumber.toString().contains(_liveSearchQuery),
        )
        .toList();
  }

  List<Appointment> get waitingList =>
      _searchedQueue
          .where((a) => a.status == AppointmentStatus.waiting)
          .toList();
  List<Appointment> get activeQueue =>
      _searchedQueue
          .where((a) => a.status == AppointmentStatus.active)
          .toList();
  List<Appointment> get skippedList =>
      _searchedQueue
          .where((a) => a.status == AppointmentStatus.skipped)
          .toList();

  // --- ACTIONS: BOOKING ---

  Future<void> bookAppointment({
    required String name,
    required String phone,
    required String service,
    required DateTime date,
    required String clinicId,
    required String patientId,
    bool isStaff = false, // Added parameter
  }) async {
    final cleanDate = DateTime(date.year, date.month, date.day);

    // --- VALIDATION START ---
    if (selectedClinic != null) {
      // 1. Check for Emergency Closure on this specific date
      bool isEmergencyClosed = selectedClinic!.emergencyClosedDates.any(
        (d) =>
            d.year == cleanDate.year &&
            d.month == cleanDate.month &&
            d.day == cleanDate.day,
      );

      if (isEmergencyClosed && !isStaff) {
        // Allow staff to override
        throw "Clinic is closed on this date.";
      }

      // 2. Check Weekly Schedule
      String dayName = DateFormat('EEEE').format(cleanDate);
      final schedule = selectedClinic!.weeklySchedule[dayName];
      if ((schedule == null || !schedule.isOpen) && !isStaff) {
        // Allow staff to override
        throw "Clinic is closed on $dayName.";
      }
    }
    // --- VALIDATION END ---

    try {
      // 1. Create a unique ID for the day (e.g., "2026-02-10") to track counters
      final dateKey = DateFormat('yyyy-MM-dd').format(cleanDate);

      // We lock this document to ensure only one person can increment it at a time
      final counterRef = _db
          .collection('clinics')
          .doc(clinicId)
          .collection('daily_counters')
          .doc(dateKey);

      final newApptRef = _db.collection('appointments').doc();

      // RUN SECURE TRANSACTION
      await _db.runTransaction((transaction) async {
        // 3. READ: Get the current counter value
        final counterSnap = await transaction.get(counterRef);

        int nextToken = 1;
        if (counterSnap.exists) {
          final data = counterSnap.data();
          if (data != null && data.containsKey('lastToken')) {
            nextToken = (data['lastToken'] as int) + 1;
          }
        }

        // 4. NEW CHECK: MAXIMUM CAPACITY LIMIT (PATIENTS ONLY)
        // If it's a patient booking from the app, enforce the daily limit.
        // Staff/Assistants bypass this and can "overbook".
        if (!isStaff && selectedClinic != null) {
          String dayName = DateFormat('EEEE').format(cleanDate);
          final schedule = selectedClinic!.weeklySchedule[dayName];
          if (schedule != null && nextToken > schedule.maxAppointmentsPerDay) {
            // Throwing a string here aborts the transaction and sends a clean message to the UI
            throw "Fully booked! Maximum limit of ${schedule.maxAppointmentsPerDay} patients reached for this date.";
          }
        }

        // 5. Determine Status
        final isToday =
            cleanDate.year == DateTime.now().year &&
            cleanDate.month == DateTime.now().month &&
            cleanDate.day == DateTime.now().day;

        // Even if booked for tomorrow, they start as waiting
        final statusToSave = AppointmentStatus.waiting;

        // 6. WRITE: Prepare the new appointment
        final newApptData = {
          'clinicId': clinicId,
          'doctorId': selectedClinic?.doctorId ?? '',
          'patientId': patientId,
          'customerName': name,
          'phoneNumber': phone,
          'serviceType': service,
          'type': isToday ? 'walk-in' : 'prebook',
          'bookedBy': isStaff ? 'desk' : 'app', // Track source
          'appointmentDate': Timestamp.fromDate(cleanDate),
          'bookingTimestamp': FieldValue.serverTimestamp(),
          'tokenNumber': nextToken,
          'status': statusToSave.name,
        };

        // 7. COMMIT: Atomic update of both the Appointment and the Counter
        transaction.set(newApptRef, newApptData);
        transaction.set(counterRef, {
          'lastToken': nextToken,
        }, SetOptions(merge: true));
      });
    } catch (e) {
      debugPrint("Error booking appointment: $e");
      // Rethrow to let the UI catch it and show the SnackBar
      rethrow;
    }
  }

  // --- ACTIONS: QUEUE MANAGEMENT ---

  Future<void> recallPatient(String id) async {
    await _db.collection('appointments').doc(id).update({
      'status': AppointmentStatus.waiting.name,
    });
  }

  Future<void> updateStatus(String id, AppointmentStatus newStatus) async {
    await _db.collection('appointments').doc(id).update({
      'status': newStatus.name,
    });
  }

  // --- ACTIONS: DOCTOR ---

  // 1. Complete Appointment & Save Prescription
  Future<void> completeAppointment({
    required String appointmentId,
    required String patientId,
    required List<String> medicines,
    required String notes,
    required String diagnosis,
  }) async {
    WriteBatch batch = _db.batch();

    // Add Prescription to separate collection
    DocumentReference presRef = _db.collection('prescriptions').doc();
    batch.set(presRef, {
      'appointmentId': appointmentId,
      'patientId': patientId,
      'doctorId': _auth.currentUser?.uid,
      'medicines': medicines,
      'notes': notes,
      'diagnosis': diagnosis,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Update Appointment Status to Completed
    DocumentReference apptRef = _db
        .collection('appointments')
        .doc(appointmentId);
    batch.update(apptRef, {'status': AppointmentStatus.completed.name});

    await batch.commit();
  }

  // 2. Planned Closure / Emergency Close (Future Date)
  Future<void> closeClinicForDate(DateTime date) async {
    if (selectedClinic == null) return;
    final cleanDate = DateTime(date.year, date.month, date.day);

    // Add to closed dates in Clinic
    await _db.collection('clinics').doc(selectedClinic!.id).update({
      'emergencyClosedDates': FieldValue.arrayUnion([
        Timestamp.fromDate(cleanDate),
      ]),
    });

    // Cancel all appointments for that day
    final snap =
        await _db
            .collection('appointments')
            .where('clinicId', isEqualTo: selectedClinic!.id)
            .where('appointmentDate', isEqualTo: Timestamp.fromDate(cleanDate))
            .get();

    WriteBatch batch = _db.batch();
    for (var doc in snap.docs) {
      batch.update(doc.reference, {'status': AppointmentStatus.cancelled.name});
    }
    await batch.commit();
    notifyListeners();
  }

  // 3. Emergency Close (Today / Immediate)
  Future<void> emergencyCloseToday() async {
    if (selectedClinic == null) return;
    WriteBatch batch = _db.batch();

    final activeSnap =
        await _db
            .collection('appointments')
            .where('clinicId', isEqualTo: selectedClinic!.id)
            .where('status', whereIn: ['waiting', 'active', 'skipped'])
            .get();

    for (var doc in activeSnap.docs) {
      batch.update(doc.reference, {'status': AppointmentStatus.cancelled.name});
    }

    await batch.commit();
    notifyListeners();
  }

  // --- CLEANUP ---

  Future<void> _runAutoCleanup() async {
    if (selectedClinic == null) return;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    // Clean up PAST days that were left 'waiting' or 'active'
    final leftovers =
        await _db
            .collection('appointments')
            .where('clinicId', isEqualTo: selectedClinic!.id)
            .where(
              'appointmentDate',
              isLessThan: Timestamp.fromDate(todayStart),
            )
            .where('status', whereIn: ['waiting', 'skipped', 'active'])
            .get();

    if (leftovers.docs.isNotEmpty) {
      WriteBatch batch = _db.batch();
      for (var doc in leftovers.docs) {
        batch.update(doc.reference, {
          'status': AppointmentStatus.cancelled.name,
        });
      }
      await batch.commit();
    }
  }

  // --- HISTORY STREAMS ---

  Stream<List<Appointment>> get patientHistory {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    // 1. Fetch RAW history for the patient (Completed or Cancelled)
    return _db
        .collection('appointments')
        .where('patientId', isEqualTo: user.uid)
        .orderBy('appointmentDate', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((d) => Appointment.fromMap(d.data(), d.id))
                  .toList(),
        );
  }

  Stream<List<Appointment>> get assistantFullHistory {
    if (selectedClinic == null) return Stream.value([]);

    // 1. Fetch RAW history for the clinic
    return _db
        .collection('appointments')
        .where('clinicId', isEqualTo: selectedClinic!.id)
        .orderBy('appointmentDate', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((d) => Appointment.fromMap(d.data(), d.id))
                  .toList(),
        );
  }

  Appointment? get myAppointment {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      // Staff shouldn't see 'myAppointment' logic, only patients
      if (user.email != null && user.email!.isNotEmpty) return null;
      // Fixed: Now accurately matches the verified user's UID against the appointment's patientId
      return _todayQueue.firstWhere((a) => a.patientId == user.uid);
    } catch (e) {
      return null;
    }
  }

  // --- UPCOMING SCHEDULE STREAM ---
  Stream<List<Appointment>> get upcomingSchedule {
    if (selectedClinic == null) return Stream.value([]);

    // We only want appointments starting tomorrow
    final now = DateTime.now();
    final tomorrowStart = DateTime(now.year, now.month, now.day + 1);

    return _db
        .collection('appointments')
        .where('clinicId', isEqualTo: selectedClinic!.id)
        .where(
          'appointmentDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(tomorrowStart),
        )
        .orderBy('appointmentDate', descending: false) // Closest dates first
        .snapshots()
        .map((snap) {
          return snap.docs
              .map((d) => Appointment.fromMap(d.data(), d.id))
              .toList();
        });
  }

  // --- PATIENT: UPCOMING APPOINTMENTS ---
  Stream<List<Appointment>> get myUpcomingAppointments {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    // 1. Fetch all active appointments for this specific patient
    // 2. Filter & Sort locally to avoid needing a complex Firestore Index!
    return _db
        .collection('appointments')
        .where('patientId', isEqualTo: user.uid)
        .where('status', whereIn: ['waiting', 'active', 'skipped'])
        .snapshots()
        .map((snap) {
          var list =
              snap.docs
                  .map((d) => Appointment.fromMap(d.data(), d.id))
                  .toList();

          // Only keep appointments for Today or the Future
          list =
              list
                  .where((a) => !a.appointmentDate.isBefore(todayStart))
                  .toList();

          // Sort them so the closest appointment shows up first
          list.sort((a, b) => a.appointmentDate.compareTo(b.appointmentDate));

          return list;
        });
  }
}
