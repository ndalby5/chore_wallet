import 'package:flutter/material.dart';

class WalletCard extends StatelessWidget {
  final String amount;
  final String subtitle;

  const WalletCard({
    super.key,
    required this.amount,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Text(
            "Wallet",
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            amount,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 18),

          Row(
            children: const [

              Text(
                "View Wallet",
                style: TextStyle(
                  color: Color(0xFF6C4DFF),
                  fontWeight: FontWeight.w600,
                ),
              ),

              SizedBox(width: 6),

              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Color(0xFF6C4DFF),
              )

            ],
          )

        ],
      ),
    );
  }
}
