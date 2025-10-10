import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../../public/config.dart';

class CancelDetailsPage extends StatefulWidget {
  final Map<String, dynamic> booking;
  final Map<String, dynamic>? hallDetails;

  const CancelDetailsPage({
    super.key,
    required this.booking,
    this.hallDetails,
  });

  @override
  State<CancelDetailsPage> createState() => _CancelDetailsPageState();
}

class _CancelDetailsPageState extends State<CancelDetailsPage> {
  Map<String, dynamic>? hallDetails;

  final Color primaryColor = const Color(0xFF5B6547);
  final Color cardColor = const Color(0xFFD8C9A9);
  final Color scaffoldBackground = const Color(0xFFECE5D8);

  @override
  void initState() {
    super.initState();
    hallDetails = widget.hallDetails;

    if (hallDetails == null && widget.booking['hall_id'] != null) {
      _fetchHallDetails(widget.booking['hall_id']);
    }
  }

  Future<void> _fetchHallDetails(int hallId) async {
    try {
      final url = Uri.parse('$baseUrl/halls/$hallId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          hallDetails = jsonDecode(response.body);
        });
      }
    } catch (e) {
      print("Error fetching hall details: $e");
    }
  }

  Widget _sectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          title,
          style: TextStyle(
            color: cardColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildHallCard(Map<String, dynamic> hall) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      padding: const EdgeInsets.all(16),
      height: 95,
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (hall['name'] != null) ...[
                  Text(
                    hall['name'].toString().toUpperCase(),
                    style: TextStyle(
                      color: cardColor.withOpacity(0.9),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                ] else
                  const Text(
                    "HALL NAME",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
              border: Border.all(color: primaryColor.withOpacity(0.6), width: 1),
            ),
            child: ClipOval(
              child: hall['logo'] != null
                  ? Image.memory(
                base64Decode(hall['logo']),
                fit: BoxFit.cover,
              )
                  : const Icon(Icons.home_work, color: Colors.white, size: 35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionContainer(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scaffoldBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(title),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _plainRowWithTanValue(BuildContext context, String label, {required String value}) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: screenWidth * 0.35,
            alignment: Alignment.centerLeft,
            child: Text(label,
                style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Container(
            width: screenWidth * 0.38,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              value,
              style: TextStyle(color: primaryColor),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _plainRowIfNotEmpty(BuildContext context, String label, dynamic value) {
    if (value == null) return const SizedBox.shrink();
    if (value is String && value.trim().isEmpty) return const SizedBox.shrink();
    if (value is List && value.isEmpty) return const SizedBox.shrink();

    String displayValue;
    if (value is List) {
      displayValue = value.join(', ');
    } else {
      displayValue = value.toString();
    }

    return _plainRowWithTanValue(context, label, value: displayValue);
  }

  @override
  Widget build(BuildContext context) {
    final billings = widget.booking['billings'] as List<dynamic>? ?? [];
    final cancels = widget.booking['cancels'] as List<dynamic>? ?? [];

    final DateTime? allotedFrom = widget.booking['alloted_from'] != null
        ? DateTime.parse(widget.booking['alloted_from'])
        : null;

    final DateTime? allotedTo = widget.booking['alloted_to'] != null
        ? DateTime.parse(widget.booking['alloted_to'])
        : null;

    final DateTime? functionDate = widget.booking['function_date'] != null
        ? DateTime.parse(widget.booking['function_date'])
        : null;

    return Scaffold(
      backgroundColor: scaffoldBackground,
      appBar: AppBar(
        title: const Text("Cancelled Booking Details"),
        centerTitle: true,
        backgroundColor: primaryColor,
        iconTheme: IconThemeData(color: cardColor),
        titleTextStyle: TextStyle(color: cardColor, fontSize: 23, fontWeight: FontWeight.bold),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (hallDetails != null) ...[
              _buildHallCard(hallDetails!),
              const SizedBox(height: 16),
            ],

            _sectionContainer("Customer & Event Info", [
              _plainRowIfNotEmpty(context, "NAME", widget.booking['customer_name']),
              _plainRowIfNotEmpty(context, "PHONE", widget.booking['phone']),
              _plainRowIfNotEmpty(context, "ADDRESS", widget.booking['address']),
              _plainRowIfNotEmpty(context, "EMAIL", widget.booking['email']),
              _plainRowIfNotEmpty(context, "ALTERNATE PHONE", widget.booking['alternate_phone']),
              _plainRowIfNotEmpty(context, "EVENT", widget.booking['event_type']),
              _plainRowIfNotEmpty(
                  context,
                  "FUNCTION DATE",
                  functionDate != null
                      ? DateFormat('dd-MM-yyyy').format(functionDate)
                      : null),
              _plainRowIfNotEmpty(
                  context,
                  "ALLOTED FROM",
                  allotedFrom != null
                      ? "${DateFormat('dd-MM-yyyy').format(allotedFrom)}\n${DateFormat('hh:mm a').format(allotedFrom)}"
                      : null),
              _plainRowIfNotEmpty(
                  context,
                  "ALLOTED TO",
                  allotedTo != null
                      ? "${DateFormat('dd-MM-yyyy').format(allotedTo)}\n${DateFormat('hh:mm a').format(allotedTo)}"
                      : null),
              _plainRowIfNotEmpty(
                  context, "RENT", widget.booking['rent'] != null ? "₹${widget.booking['rent']}" : null),
            ]),
            if (cancels.isNotEmpty)
              _sectionContainer(
                "Cancellation Details",
                [
                  for (var cancel in cancels.reversed)
                    Column(
                      children: [
                        _plainRowIfNotEmpty(context, "REASON", cancel['reason']),
                        _plainRowIfNotEmpty(context, "TOTAL PAID", cancel['total_paid'] != null ? "₹${cancel['total_paid']}" : null),
                        _plainRowIfNotEmpty(context, "CACELLATION CHARGE", cancel['cancel_charge'] != null ? "₹${cancel['cancel_charge']}" : null),
                        _plainRowIfNotEmpty(context, "REFUND", cancel['refund'] != null ? "₹${cancel['refund']}" : null),
                        const SizedBox(height: 12),
                      ],
                    ),
                ],
              ),

            if (billings.isNotEmpty)
              _sectionContainer(
                "Billings",
                [
                  for (var bill in billings.reversed)
                    if (bill['reason'] != null && bill['reason'] is Map<String, dynamic>)
                      ...((bill['reason'] as Map<String, dynamic>)
                          .entries
                          .toList()
                          .reversed
                          .map((entry) {
                        return _plainRowIfNotEmpty(
                          context,
                          entry.key.toUpperCase(),
                          "₹${entry.value}",
                        );
                      })),
                ],
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}