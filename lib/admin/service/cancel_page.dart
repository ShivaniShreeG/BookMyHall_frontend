import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
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
  Map<String, dynamic>? booking;
  Map<String, dynamic>? _cancelData;

  final TextEditingController reasonController = TextEditingController();
  final TextEditingController percentController = TextEditingController();
  final TextEditingController chargeController = TextEditingController();

  final Color primaryColor = const Color(0xFF5B6547);
  final Color backgroundColor = const Color(0xFFD8C9A9);
  final Color scaffoldBackground = const Color(0xFFECE5D8);

  double billingTotal = 0;

  bool _updatingPercent = false;
  bool _updatingCharge = false;
  bool _shownPercentWarning = false;
  bool _shownChargeWarning = false;

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

    if (percent > 100) {
      if (!_shownPercentWarning) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Percentage cannot exceed 100%")),
        );
        _shownPercentWarning = true;
      }
      percent = 100;
    } else {
      _shownPercentWarning = false;
    }

    _updatingCharge = true;
    double charge = billingTotal * percent / 100;
    if (charge > billingTotal) charge = billingTotal;

    percentController.value = percentController.value.copyWith(
      text: percent.toStringAsFixed(percent % 1 == 0 ? 0 : 2),
      selection: TextSelection.fromPosition(
          TextPosition(offset: percentController.text.length)),
    );
    chargeController.value = chargeController.value.copyWith(
      text: charge.toStringAsFixed(charge % 1 == 0 ? 0 : 2),
      selection: TextSelection.fromPosition(
          TextPosition(offset: chargeController.text.length)),
    );
    _updatingCharge = false;
  }

  void _onChargeChanged() {
    if (_updatingCharge || billingTotal == 0 || _canceled) return;
    double charge = double.tryParse(chargeController.text) ?? 0;

    if (charge > billingTotal) {
      if (!_shownChargeWarning) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cancellation charge cannot exceed total")),
        );
        _shownChargeWarning = true;
      }
      charge = billingTotal;
    } else {
      _shownChargeWarning = false;
    }

    _updatingPercent = true;
    chargeController.value = chargeController.value.copyWith(
      text: charge.toStringAsFixed(charge % 1 == 0 ? 0 : 2),
      selection: TextSelection.fromPosition(
          TextPosition(offset: chargeController.text.length)),
    );
    percentController.value = percentController.value.copyWith(
      text: ((charge / billingTotal) * 100).toStringAsFixed(2),
      selection: TextSelection.fromPosition(
          TextPosition(offset: percentController.text.length)),
    );
    _updatingPercent = false;
  }

  Future<void> _loadBookingDetails() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/cancels/${widget.hallId}/${widget.bookingId}'),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          booking = data;
          if (booking!['billings'] != null &&
              (booking!['billings'] as List).isNotEmpty) {
            billingTotal =
                (booking!['billings'][0]['total'] ?? 0).toDouble();
          }
        });

        final defaultRes = await http.get(
          Uri.parse('$baseUrl/default-values/${widget.hallId}'),
        );

        if (defaultRes.statusCode == 200) {
          final defaults = jsonDecode(defaultRes.body) as List<dynamic>;
          final cancelDefault = defaults.firstWhere(
                (d) => d['reason'].toString().toLowerCase() == 'cancel',
            orElse: () => null,
          );

          if (cancelDefault != null) {
            final defaultPercent =
                double.tryParse(cancelDefault['amount'].toString()) ?? 0;

            percentController.text =
                defaultPercent.clamp(0, 100).toStringAsFixed(
                    defaultPercent % 1 == 0 ? 0 : 2);

            double defaultCharge = (billingTotal * defaultPercent / 100);
            if (defaultCharge > billingTotal) defaultCharge = billingTotal;
            chargeController.text =
                defaultCharge.toStringAsFixed(defaultCharge % 1 == 0 ? 0 : 2);
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Booking not found")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Error loading booking details: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
      Navigator.pop(context);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _confirmCancel() async {
    if (reasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a reason")),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text("Confirm Cancellation", style: TextStyle(color: primaryColor)),
        content: Text(
          "Are you sure you want to cancel this booking?",
          style: TextStyle(color: primaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("No", style: TextStyle(color: primaryColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            onPressed: () => Navigator.pop(context, true),
            child: Text("Yes", style: TextStyle(color: backgroundColor)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

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
        _cancelData = jsonDecode(res.body);
        setState(() => _canceled = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Booking cancelled successfully!")),
        );
      } else {
        final error = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${error['message'] ?? res.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _generatePdf() async {
    if (booking == null) return;

    final pdf = pw.Document();
    final billNo = '${widget.hallId}${widget.bookingId}';
    final dateTime = DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Center(
            child: pw.Text(
              "Cancellation Receipt",
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text("Bill No: $billNo"),
          pw.Text("Date: $dateTime"),
          pw.Divider(),
          pw.Text("Booking Details", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text("Name: ${booking!['name']}"),
          pw.Text("Phone: ${booking!['phone']}"),
          pw.Text("Function Date: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(booking!['function_date']))}"),
          pw.Text("Event Type: ${booking!['event_type'] ?? 'N/A'}"),
          pw.Text("Rent: ${booking!['rent']}"),
          pw.Text("Total Amount Paid: ${billingTotal.toStringAsFixed(2)}"),
          pw.Divider(),
          pw.Text("Cancellation Details", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text("Reason: ${_cancelData?['reason'] ?? reasonController.text}"),
          pw.Text("Cancel Charge: ${_cancelData?['cancel_charge'] ?? chargeController.text}"),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  @override
  void dispose() {
    reasonController.dispose();
    percentController.dispose();
    chargeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final readOnly = _canceled;

    return Scaffold(
      backgroundColor: scaffoldBackground,
      appBar: AppBar(
        title: const Text("Cancel Booking"),
        centerTitle: true,
        backgroundColor: primaryColor,
        iconTheme: IconThemeData(color: backgroundColor),
        titleTextStyle: TextStyle(
          color: backgroundColor,
          fontSize: 23,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : booking == null
          ? const Center(child: Text("No booking details found"))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_canceled)
              ElevatedButton(
                onPressed: _generatePdf,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: backgroundColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(
                  "Generate & Print PDF",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            if (_canceled) const SizedBox(height: 16),
            Card(
              color: backgroundColor,
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Text(
                        _canceled ? "Cancellation Details" : "Booking Details",
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: primaryColor),
                      ),
                    ),
                    const SizedBox(height: 10),
                    InfoRow(label: "Name", value: booking!['name'], primaryColor: primaryColor),
                    InfoRow(label: "Phone", value: booking!['phone'], primaryColor: primaryColor),
                    InfoRow(label: "Function Date", value: DateFormat('yyyy-MM-dd').format(DateTime.parse(booking!['function_date'])), primaryColor: primaryColor),
                    InfoRow(label: "Event Type", value: booking!['event_type'] ?? "N/A", primaryColor: primaryColor),
                    InfoRow(label: "Alloted From", value: booking!['alloted_datetime_from'] != null
                        ? DateFormat('yyyy-MM-dd hh:mm a').format(DateTime.parse(booking!['alloted_datetime_from']).toLocal())
                        : "N/A", primaryColor: primaryColor),
                    InfoRow(label: "Alloted To", value: booking!['alloted_datetime_to'] != null
                        ? DateFormat('yyyy-MM-dd hh:mm a').format(DateTime.parse(booking!['alloted_datetime_to']).toLocal())
                        : "N/A", primaryColor: primaryColor),
                    InfoRow(label: "Rent", value: booking!['rent'].toString(), primaryColor: primaryColor),
                    InfoRow(
                      label: _canceled ? "Cancel Charge" : "Total Amount Paid",
                      value: _canceled ? (_cancelData?['cancel_charge'] ?? chargeController.text) : billingTotal.toStringAsFixed(2),
                      primaryColor: primaryColor,
                    ),
                    if (_canceled)
                      InfoRow(
                        label: "Reason",
                        value: _cancelData?['reason'] ?? reasonController.text,
                        primaryColor: primaryColor,
                      ),
                    if (!_canceled) ...[
                      const SizedBox(height: 20),
                      TextField(
                        controller: reasonController,
                        maxLines: 3,
                        readOnly: readOnly,
                        decoration: InputDecoration(
                          labelText: "Cancellation Reason",
                          labelStyle: TextStyle(color: primaryColor),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: primaryColor)
                          ),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: primaryColor)
                          ),
                        ),
                        style: TextStyle(color: primaryColor),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: percentController,
                              readOnly: readOnly,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: "Cancel % (default)",
                                labelStyle: TextStyle(color: primaryColor),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: primaryColor)
                                ),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: primaryColor)
                                ),
                              ),
                              style: TextStyle(color: primaryColor),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: chargeController,
                              readOnly: readOnly,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: "Cancel Charge",
                                labelStyle: TextStyle(color: primaryColor),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: primaryColor)
                                ),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: primaryColor)
                                ),
                              ),
                              style: TextStyle(color: primaryColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),
                      ElevatedButton(
                        onPressed: _confirmCancel,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: backgroundColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text(
                          "Cancel Booking",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color primaryColor;

  const InfoRow({super.key, required this.label, required this.value, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130, // Fixed width for labels for alignment
            child: Text(
              "$label:",
              style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

