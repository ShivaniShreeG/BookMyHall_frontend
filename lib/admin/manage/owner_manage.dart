import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../public/config.dart'; // where baseUrl is defined
import 'create_admin.dart';
import 'default_value_page.dart';
import 'add_peak_hour.dart';
import 'add_instruction_page.dart';

class OwnerPage extends StatefulWidget {
  const OwnerPage({super.key});

  @override
  State<OwnerPage> createState() => _OwnerPageState();
}

class _OwnerPageState extends State<OwnerPage> {
  String? hallName;
  String? hallAddress;
  String? hallLogo;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHallData();
  }

  Future<void> _fetchHallData() async {
    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt("hallId");

    if (hallId == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final url = Uri.parse("$baseUrl/halls/$hallId");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          hallName = data["name"];
          hallAddress = data["address"];
          hallLogo = data["logo"];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFECE5D8),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF5B6547))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFECE5D8),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 🔹 Hall Card
            if (hallName != null) _buildHallCard(),
            const SizedBox(height: 20),
            // 🔹 Manage Card
            _buildManageCard(screenWidth),
          ],
        ),
      ),
    );
  }

  Widget _buildHallCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: const Color(0xFFD8C9A9),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: const Color(0xFF5B6547),
              backgroundImage: (hallLogo != null && hallLogo!.isNotEmpty)
                  ? MemoryImage(base64Decode(hallLogo!))
                  : null,
              child: hallLogo == null || hallLogo!.isEmpty
                  ? const Icon(Icons.store, size: 35, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hallName ?? "Unknown Hall",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5B6547),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hallAddress ?? "No address available",
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF5B6547),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildManageCard(double screenWidth) {
    final buttonSize = 70.0; // square buttons

    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: const Color(0xFFD8C9A9),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Centered title + dropdown
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Manage",
                  style: TextStyle(
                    color: Color(0xFF5B6547),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    // Dropdown action
                  },
                  child: const Icon(
                    Icons.arrow_drop_down,
                    color: Color(0xFF5B6547),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Buttons
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildManageButton(
                  icon: Icons.admin_panel_settings,
                  label: "Admin",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CreateAdminPage()),
                    );
                  },
                  size: buttonSize,
                ),
                _buildManageButton(
                  icon: Icons.access_time,
                  label: "Peak Hours",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PeakHoursPage()),
                    );
                  },
                  size: buttonSize,
                ),
                _buildManageButton(
                  icon: Icons.attach_money,
                  label: "Charges",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DefaultValuesPage()),
                    );
                  },
                  size: buttonSize,
                ),
                _buildManageButton(
                  icon: Icons.rule,
                  label: "Instructions",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const HallInstructionsPage()),
                    );
                  },
                  size: buttonSize,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManageButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required double size,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xFF5B6547),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26.withOpacity(0.3),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Icon(icon, size: 38, color: const Color(0xFFD8C9A9)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF5B6547),
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}
