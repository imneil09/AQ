import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/appoinmentModel.dart';

class QueueController extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Configuration
  final double storeLat = 23.8315;
  final double storeLng = 91.2868;
  final double maxJoinRadiusKm = 5.0;

  List<Appointment> _allAppointments = [];
  StreamSubscription? _queueSubscription;
  String? currentCustomerId;

  QueueController() {
    _initRealtimeStream();
    if (_auth.currentUser != null) {
      currentCustomerId = _auth.currentUser!.uid;
    }
  }

  void _initRealtimeStream() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    _queueSubscription = _db.collection('appointments')
        .where('bookingTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .orderBy('bookingTime')
        .snapshots()
        .listen((snapshot) {
      _allAppointments = snapshot.docs.map((doc) {
        return Appointment.fromMap(doc.data(), doc.id);
      }).toList();
      notifyListeners();
    });
  }

  // --- Getters ---
  List<Appointment> get waitingQueue {
    final now = DateTime.now();
    return _allAppointments.where((appt) {
      return isSameDay(appt.bookingTime, now) && appt.status == AppointmentStatus.waiting;
    }).toList();
  }

  List<Appointment> get skippedList => _allAppointments
      .where((appt) => appt.status == AppointmentStatus.skipped)
      .toList();

  List<Appointment> get activeQueue => _allAppointments
      .where((appt) => appt.status == AppointmentStatus.inProgress)
      .toList();

  Appointment? get myAppointment {
    if (currentCustomerId == null) return null;
    try {
      return _allAppointments.firstWhere((a) => a.id == currentCustomerId);
    } catch (e) {
      return null;
    }
  }

  int get totalWaitTimeMinutes {
    int total = 0;
    for (var appt in waitingQueue) {
      total += appt.estimatedDurationMinutes;
    }
    for (var appt in activeQueue) {
      total += (appt.estimatedDurationMinutes ~/ 2);
    }
    return total;
  }

  // --- CUSTOMER Actions (With Geo & Auth Logic) ---

  Future<void> joinQueueNow(String name, String phone, String service) async {
    bool isNearby = await _checkLocation();
    if (!isNearby) {
      throw Exception("You are too far away! Please come closer to the store.");
    }
    String? uid = _auth.currentUser?.uid;
    await _addAppointment(name, phone, service, DateTime.now(), docId: uid);
  }

  Future<void> bookFutureAppointment(String name, String phone, String service, DateTime date) async {
    String? uid = _auth.currentUser?.uid;
    await _addAppointment(name, phone, service, date, docId: uid);
  }

  // --- ADMIN Actions (Bypass Geo & ID) ---

  Future<void> adminAddWalkIn(String name, String phone, String service) async {
    // Pass null for docId so Firestore generates a unique ID
    await _addAppointment(name, phone, service, DateTime.now(), docId: null);
  }

  Future<void> adminBookAppointment(String name, String phone, String service, DateTime date) async {
    await _addAppointment(name, phone, service, date, docId: null);
  }

  // --- Internal Helper ---

  Future<void> _addAppointment(String name, String phone, String service, DateTime time, {String? docId}) async {
    final newAppt = Appointment(
      id: docId ?? '', // If null, ID is assigned by Firestore/ignored here
      customerName: name,
      phoneNumber: phone,
      serviceType: service,
      bookingTime: time,
    );

    if (docId != null) {
      await _db.collection('appointments').doc(docId).set(newAppt.toMap());
      currentCustomerId = docId;
    } else {
      // Auto-ID generation for Admins/Walk-ins
      await _db.collection('appointments').add(newAppt.toMap());
    }
  }

  // --- Status Updates ---

  Future<void> skipAppointment(String id) async {
    final appt = _allAppointments.firstWhere((element) => element.id == id);
    await _db.collection('appointments').doc(id).update({
      'status': AppointmentStatus.skipped.name,
      'skipCount': appt.skipCount + 1,
    });
  }

  Future<void> recallAppointment(String id) async {
    final apptIndex = _allAppointments.indexWhere((element) => element.id == id);
    if (apptIndex == -1) return;

    List<Appointment> currentQueue = waitingQueue;
    DateTime newTime;

    if (currentQueue.length >= 2) {
      newTime = currentQueue[1].bookingTime.add(const Duration(seconds: 1));
    } else if (currentQueue.isNotEmpty) {
      newTime = currentQueue[0].bookingTime.add(const Duration(seconds: 1));
    } else {
      newTime = DateTime.now();
    }

    await _db.collection('appointments').doc(id).update({
      'status': AppointmentStatus.waiting.name,
      'bookingTime': Timestamp.fromDate(newTime),
    });
  }

  Future<void> updateStatus(String id, AppointmentStatus newStatus) async {
    await _db.collection('appointments').doc(id).update({'status': newStatus.name});
  }

  // --- Utilities ---

  Future<bool> _checkLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      double distanceInMeters = Geolocator.distanceBetween(storeLat, storeLng, position.latitude, position.longitude);
      return (distanceInMeters / 1000) <= maxJoinRadiusKm;
    } catch (e) {
      return false;
    }
  }

  bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String getEstimatedWaitTime(Appointment myAppt) {
    int position = waitingQueue.indexWhere((element) => element.id == myAppt.id);
    if (position == -1) return "Calculating...";
    int minutes = (position + 1) * 15;
    return "$minutes mins";
  }

  @override
  void dispose() {
    _queueSubscription?.cancel();
    super.dispose();
  }
}