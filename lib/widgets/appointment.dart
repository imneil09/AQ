import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/appoinmentModel.dart';
import 'appColors.dart';

class AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final bool isAdmin;
  final VoidCallback? onStatusNext; // Handles: Call Next, Recall, Finish
  final VoidCallback? onSkip;       // Handles: Skip
  final VoidCallback? onCancel;     // Handles: Cancel
  final VoidCallback? onVitalsTap;  // --- NEW: Handles Vitals Popup ---

  const AppointmentCard({
    super.key,
    required this.appointment,
    this.isAdmin = false,
    this.onStatusNext,
    this.onSkip,
    this.onCancel,
    this.onVitalsTap,
  });

  @override
  Widget build(BuildContext context) {
    // --- 1. Determine Status Flags ---
    final bool isDone = appointment.status == AppointmentStatus.completed;
    final bool isCancelled = appointment.status == AppointmentStatus.cancelled;
    final bool isActive = appointment.status == AppointmentStatus.active;
    final bool isSkipped = appointment.status == AppointmentStatus.skipped;
    final bool isWaiting = appointment.status == AppointmentStatus.waiting;

    // --- NEW: Determine Vitals State ---
    final bool hasVitals = appointment.vitals != null && appointment.vitals!.isNotEmpty;

    // --- 2. Determine Theme Color ---
    final Color accentColor = _getAccentColor(appointment.status);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.glassWhite,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: accentColor.withOpacity(isActive ? 0.4 : 0.1),
                width: 1.5,
              ),
              boxShadow: [
                if (isActive)
                  BoxShadow(
                    color: accentColor.withOpacity(0.15),
                    blurRadius: 20,
                    spreadRadius: -5,
                  )
              ],
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- LEFT BRANDING STRIP ---
                  Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: accentColor,
                      boxShadow: [
                        BoxShadow(color: accentColor.withOpacity(0.5), blurRadius: 10)
                      ],
                    ),
                  ),

                  // --- TOKEN NUMBER SECTION ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "TOKEN",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: Colors.white38,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "#${appointment.tokenNumber}",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: accentColor,
                            shadows: [
                              Shadow(color: accentColor.withOpacity(0.3), blurRadius: 12)
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- VERTICAL DIVIDER ---
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 20),
                    color: AppColors.glassBorder,
                  ),

                  // --- INFO & DETAILS SECTION ---
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            appointment.customerName.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Status Badge Logic (Wrapped in Flexible)
                              Flexible(
                                child: _buildStatusText(isSkipped, isActive, isCancelled, isDone, accentColor),
                              ),

                              // Time Logic
                              if (!isSkipped && !isCancelled && !isDone) ...[
                                const SizedBox(width: 6),
                                Text("•", style: TextStyle(color: Colors.white.withOpacity(0.4))),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    isActive
                                        ? "NOW"
                                        : (appointment.estimatedTime != null
                                        ? DateFormat('hh:mm a').format(appointment.estimatedTime!)
                                        : "--:--"),
                                    style: TextStyle(
                                      color: accentColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ]
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            appointment.serviceType,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w600),
                          ),

                          // --- ADMIN QUICK ACTIONS (MOVED HERE) ---
                          if (isAdmin && !isDone && !isCancelled) ...[
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  // --- NEW: 0. VITALS BUTTON ---
                                  if (onVitalsTap != null) ...[
                                    _buildActionButton(
                                      icon: hasVitals ? Icons.monitor_heart : Icons.monitor_heart_outlined,
                                      color: hasVitals ? AppColors.success : Colors.white70,
                                      onTap: onVitalsTap,
                                      tooltip: hasVitals ? "Edit Vitals" : "Add Vitals",
                                    ),
                                    const SizedBox(width: 8),
                                  ],

                                  // 1. CANCEL BUTTON
                                  if (onCancel != null && (isWaiting || isSkipped)) ...[
                                    _buildActionButton(
                                      icon: Icons.close_rounded,
                                      color: AppColors.error,
                                      onTap: onCancel,
                                      tooltip: "Cancel Appointment",
                                    ),
                                    const SizedBox(width: 8),
                                  ],

                                  // 2. SKIP BUTTON
                                  if (onSkip != null && isWaiting) ...[
                                    _buildActionButton(
                                      icon: Icons.u_turn_right_rounded,
                                      color: Colors.amberAccent,
                                      onTap: onSkip,
                                      tooltip: "Skip Patient",
                                    ),
                                    const SizedBox(width: 8),
                                  ],

                                  // 3. MAIN ACTION
                                  if (onStatusNext != null)
                                    _buildActionButton(
                                      icon: isSkipped
                                          ? Icons.restore_rounded
                                          : (isActive
                                          ? Icons.check_rounded
                                          : Icons.play_arrow_rounded),
                                      color: isSkipped
                                          ? Colors.blueAccent
                                          : (isActive ? AppColors.success : AppColors.primary),
                                      isLarge: true,
                                      onTap: onStatusNext,
                                      tooltip: isActive ? "Finish" : "Send to Cabin",
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Helpers ---

  Widget _buildStatusText(bool isSkipped, bool isActive, bool isCancelled, bool isDone, Color color) {
    String text = "WAITING";
    if (isSkipped) text = "SKIPPED";
    else if (isActive) text = "NOW SERVING";
    else if (isCancelled) text = "CANCELLED";
    else if (isDone) text = "COMPLETED";

    return Text(
      text,
      style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 13
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Color _getAccentColor(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.skipped:
        return Colors.amber;
      case AppointmentStatus.active:
        return AppColors.success;
      case AppointmentStatus.cancelled:
        return AppColors.error;
      case AppointmentStatus.completed:
        return Colors.white24;
      default:
        return AppColors.primary;
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    bool isLarge = false,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? "",
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: isLarge ? 48 : 36,
          height: isLarge ? 48 : 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(
              icon,
              color: color,
              size: isLarge ? 24 : 18
          ),
        ),
      ),
    );
  }
}