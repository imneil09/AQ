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

      // Auto-select first clinic if none selected (useful for single-doctor apps)
      if (selectedClinic == null && clinics.isNotEmpty) {
        selectClinic(clinics.first);
      }
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

  // --- ACTIONS: BOOKING & WALK-INS ---

  Future<void> bookAppointment({
    required String name,
    required String phone,
    required String service,
    required DateTime date,
    required String clinicId,
    String? patientId, // Optional: if already known
  }) async {
    final cleanDate = DateTime(date.year, date.month, date.day);

    // --- NEW VALIDATION START ---
    if (selectedClinic != null) {
      // 1. Check for Emergency Closure on this specific date
      bool isEmergencyClosed = selectedClinic!.emergencyClosedDates.any(
        (d) =>
            d.year == cleanDate.year &&
            d.month == cleanDate.month &&
            d.day == cleanDate.day,
      );

      if (isEmergencyClosed) {
        throw Exception("Clinic is closed on this date.");
      }

      // 2. Check Weekly Schedule
      String dayName = DateFormat('EEEE').format(cleanDate);
      final schedule = selectedClinic!.weeklySchedule[dayName];
      if (schedule == null || !schedule.isOpen) {
        throw Exception("Clinic is closed on $dayName.");
      }
    }
    // --- NEW VALIDATION END ---
    try {
      // 1. Create a unique ID for the day (e.g., "2026-02-10") to track counters
      final dateKey = DateFormat('yyyy-MM-dd').format(cleanDate);

      await _db.runTransaction((transaction) async {
        // 2. Reference the Daily Counter Document
        // We lock this document to ensure only one person can increment it at a time
        final counterRef = _db
            .collection('clinics')
            .doc(clinicId)
            .collection('daily_counters')
            .doc(dateKey);

        // 3. READ: Get the current counter value
        final counterSnap = await transaction.get(counterRef);

        int nextToken = 1;
        if (counterSnap.exists) {
          final data = counterSnap.data();
          if (data != null && data.containsKey('lastToken')) {
            nextToken = (data['lastToken'] as int) + 1;
          }
        }

        // 4. Determine Status
        final isToday =
            cleanDate.year == DateTime.now().year &&
            cleanDate.month == DateTime.now().month &&
            cleanDate.day == DateTime.now().day;

        final statusToSave =
            isToday ? AppointmentStatus.waiting : AppointmentStatus.waiting;

        // 5. WRITE: Prepare the new appointment
        // We create a reference explicitly so we can use transaction.set()
        final newApptRef = _db.collection('appointments').doc();

        final newApptData = {
          'clinicId': clinicId,
          'doctorId': selectedClinic?.doctorId ?? '',
          'customerName': name,
          'phoneNumber': phone,
          'serviceType': service,
          'type': 'live',
          'appointmentDate': Timestamp.fromDate(cleanDate),
          'bookingTimestamp':
              FieldValue.serverTimestamp(), // Trusted server time
          'tokenNumber': nextToken,
          'status': statusToSave.name,
          'userId': patientId ?? _auth.currentUser?.uid ?? '',
        };

        // 6. COMMIT: Atomic update of both the Appointment and the Counter
        transaction.set(newApptRef, newApptData);
        transaction.set(counterRef, {
          'lastToken': nextToken,
        }, SetOptions(merge: true));
      });
    } catch (e) {
      debugPrint("Error booking appointment: $e");
      rethrow;
    }
  }

  // *** SHADOW ACCOUNT LOGIC (Walk-In) ***
  Future<void> assistantAddWalkIn(
    String name,
    String phone,
    String service,
  ) async {
    if (selectedClinic == null) return;

    String userId = "";

    // 1. Check if user already exists
    final userSnap =
        await _db
            .collection('users')
            .where('phoneNumber', isEqualTo: phone)
            .limit(1)
            .get();

    if (userSnap.docs.isNotEmpty) {
      // User exists, link to them
      userId = userSnap.docs.first.id;
    } else {
      // 2. Create Shadow Account
      // We use the Phone Number as the Document ID for easy merging later
      userId = phone;
      await _db.collection('users').doc(userId).set({
        'uid': userId,
        'phoneNumber': phone,
        'name': name,
        'role': 'patient',
        'createdAt': FieldValue.serverTimestamp(),
        'isShadowAccount': true, // Flag to identify auto-created accounts
      });
    }

    // 3. Book the appointment
    await bookAppointment(
      name: name,
      phone: phone,
      service: service,
      date: DateTime.now(),
      clinicId: selectedClinic!.id,
      patientId: userId,
    );
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
  // This satisfies the feature requirement: Updates clinic settings AND cancels appointments.
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
    // For patients: retrieve by phoneNumber (handles cases where they switch devices)
    if (user == null || user.phoneNumber == null) return Stream.value([]);

    return _db
        .collection('appointments')
        .where('phoneNumber', isEqualTo: user.phoneNumber)
        .orderBy('appointmentDate', descending: true)
        .snapshots()
        .map((snap) {
          final list =
              snap.docs
                  .map((d) => Appointment.fromMap(d.data(), d.id))
                  .toList();
          if (_historySearchQuery.isEmpty) return list;
          return list
              .where(
                (a) =>
                    a.customerName.toLowerCase().contains(
                      _historySearchQuery,
                    ) ||
                    a.serviceType.toLowerCase().contains(_historySearchQuery),
              )
              .toList();
        });
  }

  Stream<List<Appointment>> get assistantFullHistory {
    if (selectedClinic == null) return Stream.value([]);

    return _db
        .collection('appointments')
        .where('clinicId', isEqualTo: selectedClinic!.id)
        .orderBy('appointmentDate', descending: true)
        .snapshots()
        .map((snap) {
          final list =
              snap.docs
                  .map((d) => Appointment.fromMap(d.data(), d.id))
                  .toList();
          if (_historySearchQuery.isEmpty) return list;
          return list
              .where(
                (a) =>
                    a.customerName.toLowerCase().contains(
                      _historySearchQuery,
                    ) ||
                    a.phoneNumber.contains(_historySearchQuery) ||
                    a.tokenNumber.toString().contains(_historySearchQuery),
              )
              .toList();
        });
  }

  Appointment? get myAppointment {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      // Staff shouldn't see 'myAppointment' logic, only patients
      if (user.email != null && user.email!.isNotEmpty) return null;
      return _todayQueue.firstWhere((a) => a.phoneNumber == user.phoneNumber);
    } catch (e) {
      return null;
    }
  }
}
