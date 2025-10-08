import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'pdf/cancel_pdf_generator.dart';
import '../../utils/hall_header.dart';
import '../../public/config.dart';

class CancelBookingPage extends StatefulWidget {
  final int hallId;
  final int bookingId;
  final int userId;

  const CancelBookingPage({
    super.key,
    required this.hallId,
    required this.bookingId,
    required this.userId,
  });

  @override
  State<CancelBookingPage> createState() => _CancelBookingPageState();
}

class _CancelBookingPageState extends State<CancelBookingPage> {
  bool _loading = true;
  bool _canceled = false;
  bool _showPdfButton = false; // Controls visibility of PDF button
  Map<String, dynamic>? booking;
  Map<String, dynamic>? _cancelData;
  Map<String, dynamic>? _hallDetails;

  final TextEditingController reasonController = TextEditingController();
  final TextEditingController percentController = TextEditingController();
  final TextEditingController chargeController = TextEditingController();

  final Color primaryColor = const Color(0xFF5B6547);
  final Color tanColor = const Color(0xFFD8C9A9);
  final Color scaffoldBackground = const Color(0xFFECE5D8);

  double billingTotal = 0;
  bool _updatingPercent = false;
  bool _updatingCharge = false;

  @override
  void initState() {
    super.initState();
    _loadBookingDetails();
    percentController.addListener(_onPercentChanged);
    chargeController.addListener(_onChargeChanged);
  }

  void _onPercentChanged() {
    if (_updatingPercent || billingTotal == 0 || _canceled) return;
    double? percent = double.tryParse(percentController.text);
    if (percent == null) return;
    if (percent > 100) percent = 100;

    _updatingCharge = true;
    double charge = billingTotal * percent / 100;
    if (charge > billingTotal) charge = billingTotal;
    chargeController.text = charge.toStringAsFixed(2);
    _updatingCharge = false;
  }

  void _onChargeChanged() {
    if (_updatingCharge || billingTotal == 0 || _canceled) return;
    double charge = double.tryParse(chargeController.text) ?? 0;
    if (charge > billingTotal) charge = billingTotal;

    _updatingPercent = true;
    percentController.text = ((charge / billingTotal) * 100).toStringAsFixed(2);
    _updatingPercent = false;
  }
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: tanColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }


  Future<void> _loadBookingDetails() async {
    try {
      // Fetch booking and billing
      final res = await http.get(Uri.parse('$baseUrl/cancels/${widget.hallId}/${widget.bookingId}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          booking = data;
          if (booking!['billings'] != null && (booking!['billings'] as List).isNotEmpty) {
            billingTotal = (booking!['billings'][0]['total'] ?? 0).toDouble();
          }
        });

        // Fetch default cancellation percent
        final defaultRes = await http.get(Uri.parse('$baseUrl/default-values/${widget.hallId}'));
        if (defaultRes.statusCode == 200) {
          final defaults = jsonDecode(defaultRes.body) as List<dynamic>;
          final cancelDefault = defaults.firstWhere(
                (d) => d['reason'].toString().toLowerCase() == 'cancel',
            orElse: () => null,
          );
          if (cancelDefault != null) {
            final defaultPercent = double.tryParse(cancelDefault['amount'].toString()) ?? 0;
            percentController.text = defaultPercent.clamp(0, 100).toStringAsFixed(
                defaultPercent % 1 == 0 ? 0 : 2);
            double defaultCharge = (billingTotal * defaultPercent / 100);
            if (defaultCharge > billingTotal) defaultCharge = billingTotal;
            chargeController.text = defaultCharge.toStringAsFixed(defaultCharge % 1 == 0 ? 0 : 2);
          }
        }
      }

      // Fetch hall details for header
      final hallRes = await http.get(Uri.parse('$baseUrl/halls/${widget.hallId}'));
      if (hallRes.statusCode == 200) {
        setState(() {
          _hallDetails = jsonDecode(hallRes.body);
        });
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _confirmCancel() async {
    if (reasonController.text.isEmpty) {
      _showSnackBar("Please enter a reason");
      return;
    }

    setState(() => _loading = true);
    try {
      double cancelCharge = double.tryParse(chargeController.text) ?? 0;
      if (cancelCharge > billingTotal) cancelCharge = billingTotal;

      final payload = {
        "hall_id": widget.hallId,
        "booking_id": widget.bookingId,
        "user_id": widget.userId,
        "reason": reasonController.text,
        "cancel_charge": cancelCharge,
      };

      final res = await http.post(
        Uri.parse('$baseUrl/cancels'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (res.statusCode == 201 || res.statusCode == 200) {
        final data = jsonDecode(res.body);

        setState(() {
          _cancelData = data;  // store cancel data
          _canceled = true;
        });

        _showSnackBar("Booking cancelled successfully!");

        // Navigate to PDF page immediately after cancellation
      }
    } finally {
      setState(() => _loading = false);
    }
  }


  Widget _sectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical:10,horizontal:8),
      // padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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
            color: tanColor,
            fontWeight: FontWeight.bold,
            fontSize: 16, // increased font size
          ),
        ),
      ),
    );
  }

  Widget _plainRowWithTanValue(String label, {Widget? child, String? value}) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Container(
            width: screenWidth * 0.35, // 35% for label
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Value container
          Container(
            width: screenWidth * 0.42, // 42% for value/child
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: tanColor,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center, // Center content horizontally
            child: child ??
                Text(
                  value ?? "—",
                  style: TextStyle(color: primaryColor),
                  textAlign: TextAlign.center, // Center text
                ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final readOnly = _canceled;

    return WillPopScope(
        onWillPop: () async {
          Navigator.pop(context, true); // send refresh signal
          return false; // prevent default pop (we already did it)
        },child:Scaffold(
      backgroundColor: scaffoldBackground,
      appBar: AppBar(
        title: const Text("Cancel Booking"),
        centerTitle: true,
        backgroundColor: primaryColor,
        iconTheme: IconThemeData(color: tanColor),
        titleTextStyle: TextStyle(color: tanColor, fontSize: 23, fontWeight: FontWeight.bold),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : booking == null
          ? const Center(child: Text("No booking details found"))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hall header
            if (_hallDetails != null)
              HallHeader(hallDetails: _hallDetails!, oliveGreen: primaryColor, tan: tanColor),
            const SizedBox(height: 10),

            // Header

            _sectionContainer(_canceled ? "CANCELLATION DETAILS" : "BOOKING DETAILS",

            [
            // Booking info
            _plainRowWithTanValue("NAME", value:booking!['name']),
            _plainRowWithTanValue("PHONE", value:booking!['phone']),
            _plainRowWithTanValue(
              "FUNCTION DATE",value:
              DateFormat('dd-MM-yyyy').format(DateTime.parse(booking!['function_date']).toLocal()),
            ),
            _plainRowWithTanValue("EVENT TYPE", value:booking!['event_type'] ?? "N/A"),
              _plainRowWithTanValue(
                "ALLOTED FROM",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      booking!['alloted_datetime_from'] != null
                          ? DateFormat('dd-MM-yyyy').format(DateTime.parse(booking!['alloted_datetime_from']))
                          : "N/A",
                      style: TextStyle(color: primaryColor),
                    ),
                    Text(
                      booking!['alloted_datetime_from'] != null
                          ? DateFormat('hh:mm a').format(DateTime.parse(booking!['alloted_datetime_from']))
                          : "",
                      style: TextStyle(color: primaryColor),
                    ),
                  ],
                ),
              ),

              _plainRowWithTanValue(
                "ALLOTED TO",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,

                  children: [
                    Text(
                      booking!['alloted_datetime_to'] != null
                          ? DateFormat('dd-MM-yyyy').format(DateTime.parse(booking!['alloted_datetime_to']))
                          : "N/A",
                      style: TextStyle(color: primaryColor),
                    ),
                    Text(
                      booking!['alloted_datetime_to'] != null
                          ? DateFormat('hh:mm a').format(DateTime.parse(booking!['alloted_datetime_to']))
                          : "",
                      style: TextStyle(color: primaryColor),
                    ),
                  ],
                ),
              ),

              _plainRowWithTanValue("RENT", value:booking!['rent'].toString()),
            _plainRowWithTanValue(
              _canceled ? "CANCEL CHARGE" : "TOTAL AMOUNT PAID",
              value:_canceled ? (_cancelData?['cancel_charge'] ?? chargeController.text) : billingTotal.toStringAsFixed(2),
            ),
            if (_canceled)
              _plainRowWithTanValue("REASON", value:_cancelData?['reason'] ?? reasonController.text),
],
        ),

            if (!_canceled) ...[
              const SizedBox(height: 25),

              _sectionContainer("CANCELLATION DETAILS",
              [
              _plainRowWithTanValue(
                "CANCELLATION REASON",
                child: TextField(
                  controller: reasonController,
                  maxLines: 3,
                  readOnly: readOnly,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: "Enter cancellation reason",
                    hintStyle: TextStyle(color: primaryColor.withOpacity(0.7)),
                  ),
                  style: TextStyle(color: primaryColor),
                ),
              ),

// Cancel %
              _plainRowWithTanValue(
                "CANCEL %",
                child: TextField(
                  controller: percentController,
                  readOnly: readOnly,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(border: InputBorder.none),
                  style: TextStyle(color: primaryColor),
                ),
              ),

// Cancel Charge
              _plainRowWithTanValue(
                "CANCEL CHARGE",
                child: TextField(
                  controller: chargeController,
                  readOnly: readOnly,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      border: InputBorder.none,
                  ),
                  style: TextStyle(color: primaryColor),

                ),
              ),
              ],),


              const SizedBox(height: 25),
              const SizedBox(height: 24),

              // Cancel button (disabled after cancellation)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _cancelData != null ? null : _confirmCancel,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text("Cancel Booking"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: tanColor,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),

              const SizedBox(height: 38),


    ],
            if (_canceled && booking != null && _hallDetails != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CancelPdfPage(
                                bookingData: booking!,
                                hallDetails: _hallDetails!,
                                cancelData: _cancelData ?? {},
                                oliveGreen: primaryColor,
                                tan: tanColor,
                                beigeBackground: scaffoldBackground, // Add this
                              ),
                            ),
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text("Generate & View PDF"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: tanColor,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            const SizedBox(height: 24,)

        ],),
      ),
    ),
    );
  }
  Widget _sectionContainer(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: scaffoldBackground, // same as page background
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: primaryColor, // only olive green border
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(title), // existing header function
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }


}
