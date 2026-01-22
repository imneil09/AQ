import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/queueController.dart';
import '../../models/appoinmentModel.dart';
import 'adminAddView.dart';

class AdminHomeView extends StatelessWidget {
  const AdminHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final queueController = Provider.of<QueueController>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: Stack(
        children: [
          // Background Header
          Container(
            height: 200,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1C1E53), Color(0xFF2E3192)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Custom App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Dashboard",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1)),
                          Text("Store Manager",
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 14)),
                        ],
                      ),
                      IconButton(
                        onPressed: () => showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const SkippedListSheet()),
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.history, color: Colors.white),
                        ),
                      )
                    ],
                  ),
                ),

                // Stats Cards (HUD)
                SizedBox(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildStatCard(
                          "Est. Wait",
                          "${queueController.totalWaitTimeMinutes}m",
                          Icons.timer_outlined,
                          Colors.orange),
                      _buildStatCard(
                          "In Queue",
                          "${queueController.waitingQueue.length}",
                          Icons.people_outline,
                          Colors.blue),
                      _buildStatCard(
                          "Skipped",
                          "${queueController.skippedList.length}",
                          Icons.warning_amber_rounded,
                          Colors.red),
                    ],
                  ),
                ),

                // --- KILL SWITCH DASHBOARD ---
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text("Open Queue"),
                          onPressed: () {
                            // Logic to open shop / resume queue
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("Queue is now OPEN")));
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent),
                          icon: const Icon(Icons.pause),
                          label: const Text("Pause Queue"),
                          onPressed: () {
                            // Implement simple boolean flag in Firebase to stop new joins
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                    Text("Queue Paused for Lunch")));
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text("Active Queue",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800])),
                ),
                const SizedBox(height: 10),

                // Active List
                Expanded(
                  child: ListView.builder(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: queueController.waitingQueue.length +
                        queueController.activeQueue.length,
                    itemBuilder: (context, index) {
                      final allActive = [
                        ...queueController.activeQueue,
                        ...queueController.waitingQueue
                      ];
                      final appt = allActive[index];
                      final isInProgress =
                          appt.status == AppointmentStatus.inProgress;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: isInProgress
                              ? Border.all(
                              color: const Color(0xFF2E3192), width: 2)
                              : null,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4)),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: isInProgress
                                  ? const Color(0xFF2E3192)
                                  : const Color(0xFFF4F7FC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                "${index + 1}",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isInProgress
                                        ? Colors.white
                                        : const Color(0xFF2E3192)),
                              ),
                            ),
                          ),
                          title: Text(appt.customerName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                  "${appt.serviceType} • ${appt.phoneNumber}",
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 13)),
                              if (isInProgress)
                                const Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Text("SERVING NOW",
                                      style: TextStyle(
                                          color: Color(0xFF2E3192),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                )
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (appt.status == AppointmentStatus.waiting)
                                IconButton(
                                  icon: const Icon(Icons.skip_next_rounded,
                                      color: Colors.orange),
                                  onPressed: () =>
                                      queueController.skipAppointment(appt.id),
                                ),
                              Container(
                                decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8)),
                                child: IconButton(
                                  icon: const Icon(Icons.check,
                                      color: Colors.green),
                                  onPressed: () {
                                    AppointmentStatus next = appt.status ==
                                        AppointmentStatus.waiting
                                        ? AppointmentStatus.inProgress
                                        : AppointmentStatus.completed;
                                    queueController.updateStatus(
                                        appt.id, next);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2E3192),
        elevation: 10,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Walk-In / Book",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const AdminAddView())),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color accent) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: accent, size: 20),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1D2E))),
          Text(title,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class SkippedListSheet extends StatelessWidget {
  const SkippedListSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<QueueController>(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text("Skipped Customers",
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1D2E))),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: controller.skippedList.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final appt = controller.skippedList[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(appt.customerName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Skipped ${appt.skipCount} times"),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E3192),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        minimumSize: const Size(0, 36)),
                    child: const Text("Recall", style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      controller.recallAppointment(appt.id);
                      Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}