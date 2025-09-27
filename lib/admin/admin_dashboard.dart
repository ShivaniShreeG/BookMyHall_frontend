import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../public/config.dart';
import 'service/calendar_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, dynamic>? selectedHall;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHall();
  }

  Future<void> _loadHall() async {
    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt('hallId');
    if (hallId != null) {
      await fetchHallDetails(hallId);
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> fetchHallDetails(int hallId) async {
    try {
      final url = Uri.parse('$baseUrl/halls/$hallId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          selectedHall = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFECE5D8),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: Color(0xFF5B6547)),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (selectedHall != null)
              Align(
                alignment: Alignment.center,
                child: _buildHallCard(selectedHall!),
              ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.center,
              child: _buildBookingServiceCard(screenWidth),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔹 Hall Details Card
  Widget _buildHallCard(Map<String, dynamic> hall) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: const Color(0xFFD8C9A9),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: const Color(0xFF5B6547),
              backgroundImage: hall['logo'] != null
                  ? MemoryImage(base64Decode(hall['logo']))
                  : null,
              child: hall['logo'] == null
                  ? const Icon(Icons.home_work, size: 35, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hall['name'] ?? 'No Name',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5B6547),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hall['address'] ?? 'No Address',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF5B6547),
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingServiceCard(double screenWidth) {
    final buttonWidth = 65.0; // Fixed button width

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 10,
      color: const Color(0xFFD8C9A9),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Flexible height
          children: [
            // Centered title + dropdown
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Booking Service",
                  style: TextStyle(
                    color: Color(0xFF5B6547),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 10),
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
                _buildActionButton(
                  icon: Icons.event_available,
                  label: "Book",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CalendarPage(mode: CalendarMode.book),
                      ),
                    );
                  },
                  width: buttonWidth,
                ),
                _buildActionButton(
                  icon: Icons.cancel,
                  label: "Cancel",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CalendarPage(mode: CalendarMode.cancel),
                      ),
                    );
                  },
                  width: buttonWidth,
                ),
                _buildActionButton(
                  icon: Icons.edit_calendar,
                  label: "Update",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CalendarPage(mode: CalendarMode.update),
                      ),
                    );
                  },
                  width: buttonWidth,
                ),
                _buildActionButton(
                  icon: Icons.history,
                  label: "History",
                  onTap: () {},
                  width: buttonWidth,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required double width,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: width,
            height: width,
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
