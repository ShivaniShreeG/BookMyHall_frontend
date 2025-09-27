import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import '../../public/config.dart';

class DashboardPage extends StatefulWidget {
  final dynamic selectedHall;

  const DashboardPage({super.key, required this.selectedHall});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic>? stats;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchHallStats();
  }

  Future<void> _fetchHallStats() async {
    try {
      final hallId =
          widget.selectedHall['hallId'] ?? widget.selectedHall['hall_id'];
      final response =
      await http.get(Uri.parse("$baseUrl/dashboard/$hallId/stats"));

      if (response.statusCode == 200) {
        setState(() {
          stats = jsonDecode(response.body);
          loading = false;
        });
      } else {
        setState(() {
          error = "Failed to fetch stats: ${response.statusCode}";
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = "Error: $e";
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hall = widget.selectedHall;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF3EAD6),
      appBar: AppBar(
        title: const Text(
          "Dashboard",
          style: TextStyle(
            color: Color(0xFFD8C9A9),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF5B6547),
        iconTheme: const IconThemeData(color: Color(0xFFD8C9A9)),
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20), // Rounded bottom corners
          ),
        ),
      ),
      body: hall == null
          ? const Center(
        child: Text(
          "No hall selected",
          style: TextStyle(fontSize: 16, color: Color(0xFF5B6547)),
        ),
      )
          : loading
          ? const Center(
        child: CircularProgressIndicator(color: Color(0xFF5B6547)),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ✅ Revenue vs Expenses Section (No Card)
            const Text(
              "Revenue vs Expenses",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5B6547),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sections: _getPieSections(),
                  centerSpaceRadius: 0,
                  sectionsSpace: 6,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Legend
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLegend(
                    Colors.green,
                    "Revenue ₹${(stats?['totalRevenue'] ?? 0).toStringAsFixed(2)}",
                  ),
                  const SizedBox(height: 8),
                  _buildLegend(
                    Colors.red,
                    "Expenses ₹${(stats?['totalExpenses'] ?? 0).toStringAsFixed(2)}",
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ✅ 3 Stat Cards
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                    width: (screenWidth - 48) / 3,
                    child: _buildStatCard(
                        label: "Bookings",
                        value:
                        (stats?['totalBookings'] ?? 0).toString())),
                SizedBox(
                    width: (screenWidth - 48) / 3,
                    child: _buildStatCard(
                        label: "Cancelled",
                        value:
                        (stats?['totalCancelled'] ?? 0).toString())),
                SizedBox(
                    width: (screenWidth - 48) / 3,
                    child: _buildStatCard(
                        label: "Users",
                        value:
                        (stats?['totalUsers'] ?? 0).toString())),
              ],
            ),

            const SizedBox(height: 24),

            // ✅ Hall Details Card
            // Inside the Hall Details Card (replace the relevant part)
            Card(
              color: const Color(0xFFD8C9A9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (hall['logo'] != null)
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: MemoryImage(base64Decode(hall['logo'])),
                        backgroundColor: const Color(0xFF5B6547),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      hall['name'] ?? "No Name",
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5B6547),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Hall ID row added here
                    _buildDetailRow(
                        icon: Icons.perm_identity,
                        text: "Hall ID: ${hall['hallId'] ?? hall['hall_id'] ?? 'N/A'}"),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                        icon: Icons.location_on,
                        text: hall['address'] ?? "No Address"),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                        icon: Icons.phone,
                        text: hall['phone'] ?? "No Phone"),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                        icon: Icons.email,
                        text: hall['email'] ?? "No Email"),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF5B6547)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 16, color: Color(0xFF5B6547))),
        ),
      ],
    );
  }

  Widget _buildStatCard({required String label, required String value}) {
    return Card(
      color: const Color(0xFFD8C9A9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: const TextStyle(
                  color: Color(0xFF5B6547),
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                  color: Color(0xFF5B6547),
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
              color: Color(0xFF5B6547), fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  List<PieChartSectionData> _getPieSections() {
    final revenue = (stats?['totalRevenue'] ?? 0).toDouble();
    final expenses = (stats?['totalExpenses'] ?? 0).toDouble();
    final total = revenue + expenses;

    if (total == 0) {
      return [
        PieChartSectionData(
          color: Color(0xFFD8C9A9),
          value: 1,
          title: "No Data",
          radius: 100,
          titleStyle: const TextStyle(
              color: Color(0xFF5B6547), fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ];
    }

    double revenuePercent = (revenue / total) * 100;
    double expensesPercent = (expenses / total) * 100;

    return [
      PieChartSectionData(
        color: Colors.green,
        value: revenue,
        title: "${revenuePercent.toStringAsFixed(1)}%",
        radius: 100,
        titleStyle: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
      ),
      PieChartSectionData(
        color: Colors.red,
        value: expenses,
        title: "${expensesPercent.toStringAsFixed(1)}%",
        radius: 100,
        titleStyle: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    ];
  }
}
