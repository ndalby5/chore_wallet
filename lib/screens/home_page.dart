import 'package:flutter/material.dart';

import '../widgets/task_card.dart';
import '../widgets/wallet_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Good morning, Niamh 👋",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                "You have 3 tasks today.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 28),

              const WalletCard(
                amount: "£6.40",
                subtitle: "Available to collect",
              ),

              const SizedBox(height: 30),

              const Text(
                "My Tasks",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              TaskCard(
                title: "Empty the dishwasher",
                reward: "20p",
                dueText: "Due today",
                icon: Icons.local_dining_outlined,
                onComplete: () {},
              ),

              TaskCard(
                title: "Make your bed",
                reward: "10p",
                dueText: "Due today",
                icon: Icons.bed_outlined,
                onComplete: () {},
              ),

              TaskCard(
                title: "Take the bins out",
                reward: "40p",
                dueText: "Due tomorrow",
                icon: Icons.delete_outline,
                onComplete: () {},
              ),

              const SizedBox(height: 30),

              const Text(
                "Tasks Assigned By Me",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFEAE8F2),
                  ),
                ),
                child: const Center(
                  child: Text(
                    "You haven't assigned any tasks.",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}