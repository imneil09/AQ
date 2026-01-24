import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/appoinmentModel.dart';

class QueueController extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Dr. Tudu Clinic (Indranagar) Coordinates
  final double storeLat = 23.8711;
  final double storeLng = 91.3072;
  final double maxJoinRadiusKm = 5.0; // 5km Radius

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
      _allAppointments = snapshot.docs.map((doc) => Appointment.fromMap(doc.data(), doc.id)).toList();
      notifyListeners();
    });
  }

  List<Appointment> get waitingQueue {
    final now = DateTime.now();
    return _allAppointments.where((appt) =>
    appt.bookingTime.year == now.year &&
        appt.bookingTime.month == now.month &&
        appt.bookingTime.day == now.day &&
        appt.status == AppointmentStatus.waiting
    ).toList();
  }

  List<Appointment> get skippedList => _allAppointments.where((a) => a.status == AppointmentStatus.skipped).toList();
  List<Appointment> get activeQueue => _allAppointments.where((a) => a.status == AppointmentStatus.inProgress).toList();

  Appointment? get myAppointment {
    if (currentCustomerId == null) return null;
    try { return _allAppointments.firstWhere((a) => a.id == currentCustomerId); } catch (e) { return null; }
  }

  Future<void> joinQueueNow(String name, String phone, String service) async {
    bool isNearby = await _checkLocation();
    if (!isNearby) throw Exception("Too far from clinic! Please come closer.");
    await _addAppointment(name, phone, service, DateTime.now(), docId: _auth.currentUser?.uid);
  }

  Future<void> bookFutureAppointment(String name, String phone, String service, DateTime date) async {
    await _addAppointment(name, phone, service, date, docId: _auth.currentUser?.uid);
  }

  Future<void> adminAddWalkIn(String name, String phone, String service) async {
    await _addAppointment(name, phone, service, DateTime.now(), docId: null);
  }

  Future<void> adminBookAppointment(String name, String phone, String service, DateTime date) async {
    await _addAppointment(name, phone, service, date, docId: null);
  }

  Future<void> _addAppointment(String name, String phone, String service, DateTime time, {String? docId}) async {
    final newAppt = Appointment(
      id: docId ?? '',
      customerName: name,
      phoneNumber: phone,
      serviceType: service,
      bookingTime: time,
    );
    if (docId != null) {
      await _db.collection('appointments').doc(docId).set(newAppt.toMap());
      currentCustomerId = docId;
    } else {
      await _db.collection('appointments').add(newAppt.toMap());
    }
  }

  Future<void> skipAppointment(String id) async {
    final appt = _allAppointments.firstWhere((e) => e.id == id);
    await _db.collection('appointments').doc(id).update({'status': 'skipped', 'skipCount': appt.skipCount + 1});
  }

  Future<void> recallAppointment(String id) async {
    DateTime newTime = waitingQueue.isNotEmpty
        ? waitingQueue.length > 1 ? waitingQueue[1].bookingTime.add(const Duration(seconds: 1)) : waitingQueue[0].bookingTime.add(const Duration(seconds: 1))
        : DateTime.now();
    await _db.collection('appointments').doc(id).update({'status': 'waiting', 'bookingTime': Timestamp.fromDate(newTime)});
  }

  Future<void> updateStatus(String id, AppointmentStatus newStatus) async {
    await _db.collection('appointments').doc(id).update({'status': newStatus.name});
  }

  Future<bool> _checkLocation() async {
    try {
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      return (Geolocator.distanceBetween(storeLat, storeLng, pos.latitude, pos.longitude) / 1000) <= maxJoinRadiusKm;
    } catch (e) { return false; }
  }

  String getEstimatedWaitTime(Appointment myAppt) {
    int pos = waitingQueue.indexWhere((e) => e.id == myAppt.id);
    return pos == -1 ? "Calculating..." : "${(pos + 1) * 15} mins";
  }
}