import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../public/config.dart';
import 'service/calendar_page.dart';
import 'service/upcoming_events.dart';
import 'service/booking_history.dart';
import 'service/cancel_history.dart';

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
    // 📱 MediaQuery scaling factors
    final size = MediaQuery.of(context).size;
    final double screenWidth = size.width;
    final double screenHeight = size.height;
    final double textScale = screenWidth / 375; // iPhone 11 width base
    final double boxScale = screenHeight / 812;

    return Scaffold(
      backgroundColor: const Color(0xFFECE5D8),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: Color(0xFF5B6547)),
      )
          : SingleChildScrollView(
        padding: EdgeInsets.all(20 * textScale),
        child: Column(
          children: [
            if (selectedHall != null)
              Align(
                alignment: Alignment.center,
                child: _buildHallCard(selectedHall!, textScale, boxScale),
              ),
            SizedBox(height: 20 * boxScale),
            Align(
              alignment: Alignment.center,
              child: _buildBookingServiceCard(
                  screenWidth, textScale, boxScale),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔹 Hall Details Card
  Widget _buildHallCard(
      Map<String, dynamic> hall, double textScale, double boxScale) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20 * boxScale)),
      color: const Color(0xFFD8C9A9),
      child: Padding(
        padding: EdgeInsets.all(16 * boxScale),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 40 * boxScale,
              backgroundColor: const Color(0xFF5B6547),
              backgroundImage: hall['logo'] != null
                  ? MemoryImage(base64Decode(hall['logo']))
                  : null,
              child: hall['logo'] == null
                  ? Icon(Icons.home_work,
                  size: 35 * boxScale, color: Colors.white)
                  : null,
            ),
            SizedBox(width: 16 * boxScale),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hall['name'] ?? 'No Name',
                    style: TextStyle(
                      fontSize: 18 * textScale,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF5B6547),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4 * boxScale),
                  Text(
                    hall['address'] ?? 'No Address',
                    style: TextStyle(
                      fontSize: 14 * textScale,
                      color: const Color(0xFF5B6547),
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

  /// 🔹 Booking Service Card (auto adjusts for small screens)
  Widget _buildBookingServiceCard(
      double screenWidth, double textScale, double boxScale) {
    final double buttonWidth =
    screenWidth < 400 ? 75 * boxScale : 90 * boxScale; // responsive button size

    // All booking actions in one list — auto-wrap into rows
    final List<Map<String, dynamic>> actions = [
      {
        "icon": Icons.event_available,
        "label": "Book Hall",
        "onTap": () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CalendarPage(mode: CalendarMode.book),
            ),
          );
        }
      },
      {
        "icon": Icons.cancel,
        "label": "Cancel Booking",
        "onTap": () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CalendarPage(mode: CalendarMode.cancel),
            ),
          );
        }
      },
      {
        "icon": Icons.edit_calendar,
        "label": "Change Date",
        "onTap": () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CalendarPage(mode: CalendarMode.update),
            ),
          );
        }
      },
      {
        "icon": Icons.receipt_long,
        "label": "Billing",
        "onTap": () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CalendarPage(mode: CalendarMode.bill),
            ),
          );
        }},
      {"icon": Icons.search, "label": "Date Availability", "onTap": () {}},
      {"icon": Icons.event_note, "label": "Upcoming Events",
        "onTap": () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UpcomingEventsPage(),
            ),
          );
        }},
      {"icon": Icons.history, "label": "Booking History",
        "onTap": () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BookingHistoryPage(),
            ),
          );
        }},
      {"icon": Icons.cancel_presentation, "label": "Cancel History",
        "onTap": () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CancelHistoryPage(),
            ),
          );
        }},
    ];

    return Card(
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(20 * boxScale)),
      elevation: 10,
      color: const Color(0xFFD8C9A9),
      child: Padding(
        padding: EdgeInsets.all(16 * boxScale),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🔹 Title
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Booking Service",
                  style: TextStyle(
                    color: const Color(0xFF5B6547),
                    fontSize: 20 * textScale,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 10 * textScale),
                GestureDetector(
                  onTap: () {},
                  child: Icon(Icons.arrow_drop_down,
                      color: const Color(0xFF5B6547),
                      size: 26 * boxScale),
                ),
              ],
            ),
            SizedBox(height: 20 * boxScale),

            // 🔹 Auto-wrap Buttons (replaces fixed rows)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 20 * textScale,
              runSpacing: 20 * boxScale,
              children: actions
                  .map((item) => _buildActionButton(
                icon: item['icon'],
                label: item['label'],
                onTap: item['onTap'],
                width: buttonWidth,
                textScale: textScale,
                boxScale: boxScale,
              ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔹 Action button with icon + text
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required double width,
    required double textScale,
    required double boxScale,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: width,
            height: width,
            decoration: BoxDecoration(
              color: const Color(0xFF5B6547),
              borderRadius: BorderRadius.circular(18 * boxScale),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26.withOpacity(0.3),
                  blurRadius: 5 * boxScale,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Icon(icon,
                  size: 32 * textScale, color: const Color(0xFFD8C9A9)),
            ),
          ),
        ),
        SizedBox(height: 6 * boxScale),
        SizedBox(
          width: width,
          height: 36 * boxScale,
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF5B6547),
                fontWeight: FontWeight.bold,
                fontSize: 13 * textScale,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}
