import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../public/config.dart';

class DeleteHallPage extends StatelessWidget {
  final dynamic hall;

  const DeleteHallPage({super.key, required this.hall});

  Future<void> _deleteHall(BuildContext context) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/halls/${hall['hall_id']}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message'] ?? "Hall '${hall['name']}' deleted successfully!",
            ),
            backgroundColor: Colors.redAccent,
          ),
        );

        // Go back to the first page
        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to delete hall: ${response.statusCode}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error deleting hall: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECE5D8), // Beige 🏡
      appBar: AppBar(
        backgroundColor: const Color(0xFF5B6547), // Olive Green 🌿
        iconTheme: const IconThemeData(color: Color(0xFFD8C9A9)),
        elevation: 0,
        title: const Text(
          "Delete Hall",
          style: TextStyle(
            color: Color(0xFFD8C9A9), // Muted Tan 🏺
            fontWeight: FontWeight.bold,
          ),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20), // Rounded bottom corners
          ),
        ),
      ),
      body: Center(
        child: Card(
          color: const Color(0xFFD8C9A9), // Muted Tan 🏺
          elevation: 8,
          shadowColor: const Color(0xFF5B6547).withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.delete_forever,
                  size: 80,
                  color: Color(0xFF5B6547),
                ),
                const SizedBox(height: 20),
                Text(
                  "Are you sure you want to delete\n'${hall['name']}'?",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF5B6547),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  children: [
                    // Cancel Button
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5B6547), // Olive Green 🌿
                          foregroundColor: const Color(0xFFD8C9A9), // Muted Tan 🏺
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context, false);
                        },
                        child: const Text(
                          "Cancel",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Delete Button
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB00020), // Strong Red
                          foregroundColor: Color(0xFFD8C9A9),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _deleteHall(context),
                        child: const Text(
                          "Delete",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
