import 'dart:convert';
import 'package:flutter/material.dart';

class HallHeader extends StatelessWidget {
  final Map<String, dynamic>? hallDetails;
  final Color oliveGreen;
  final Color tan;

  const HallHeader({
    super.key,
    required this.hallDetails,
    required this.oliveGreen,
    required this.tan,
  });

  @override
  Widget build(BuildContext context) {
    Widget logoWidget = const SizedBox.shrink();
    if (hallDetails?['logo'] != null && hallDetails!['logo'].isNotEmpty) {
      try {
        logoWidget = CircleAvatar(
          radius: 30,
          backgroundColor: tan.withOpacity(0.2),
          backgroundImage: MemoryImage(base64Decode(hallDetails!['logo'])),
        );
      } catch (_) {}
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: oliveGreen,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              hallDetails?['name']?.toUpperCase() ?? "HALL NAME",
              style: TextStyle(
                color: tan,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          logoWidget,
        ],
      ),
    );
  }
}
