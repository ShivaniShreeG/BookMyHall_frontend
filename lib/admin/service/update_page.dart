import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../public/config.dart';

class UpdateBookingPage extends StatefulWidget {
  final int hallId;
  final int bookingId;
  final int userId;

  const UpdateBookingPage({
    super.key,
    required this.hallId,
    required this.bookingId,
    required this.userId,
  });

  @override
  State<UpdateBookingPage> createState() => _UpdateBookingPageState();
}

class _UpdateBookingPageState extends State<UpdateBookingPage> {
  bool _loading = true;
  Map<String, dynamic>? booking;
  List<Map<String, dynamic>> existingCharges = [];
  List<Map<String, dynamic>> chargesControllers = [];
  List<Map<String, dynamic>> defaultValues = [];

  // Theme Colors
  final Color primaryColor = const Color(0xFF5B6547); // Olive green
  final Color backgroundColor = const Color(0xFFD8C9A9); // Soft beige
  final Color cardColor = const Color(0xFFD8C7A5); // Muted tan
  final Color buttonTextColor = const Color(0xFFD8C7A5); // Muted tan
  final Color textFieldBorderColor = const Color(0xFF5B6547); // Olive for textfields

  @override
  void initState() {
    super.initState();
    _loadDefaultValues().then((_) => _loadBookingAndExistingCharges());
  }

  Future<void> _loadDefaultValues() async {
    try {
      final resDefaults = await http.get(Uri.parse('$baseUrl/default-values/${widget.hallId}'));
      if (resDefaults.statusCode == 200) {
        final List<dynamic> data = jsonDecode(resDefaults.body);
        setState(() {
          defaultValues = data.map((e) => Map<String, dynamic>.from(e)).toList();
        });
      }
    } catch (e) {
      debugPrint("Error loading default values: $e");
    }
  }

  Future<void> _loadBookingAndExistingCharges() async {
    try {
      final resBooking = await http.get(Uri.parse('$baseUrl/bookings/${widget.hallId}/${widget.bookingId}'));

      if (resBooking.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Booking not found")));
        Navigator.pop(context);
        return;
      }

      final dataBooking = jsonDecode(resBooking.body);

      final resCharges = await http.get(Uri.parse('$baseUrl/charges/${widget.hallId}/${widget.bookingId}'));

      if (resCharges.statusCode == 200) {
        final List<dynamic> dataCharges = jsonDecode(resCharges.body);
        existingCharges = dataCharges.map((e) => Map<String, dynamic>.from(e)).toList();
      }

      setState(() {
        booking = dataBooking;
        _loading = false;
        _addChargeField();
      });
    } catch (e) {
      debugPrint("Error loading booking/charges: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      Navigator.pop(context);
    }
  }

  void _addChargeField() {
    setState(() {
      chargesControllers.add({
        'reason': TextEditingController(),
        'amount': TextEditingController(),
        'unit': null,
        'selectedDefault': null,
        'isCustom': false,
      });
    });
  }

  void _removeChargeField(int index) {
    setState(() {
      chargesControllers.removeAt(index);
    });
  }

  Future<void> _submitCharges() async {
    final List<Map<String, dynamic>> charges = chargesControllers.map((c) {
      final reason = (c['reason'] as TextEditingController).text.trim();
      double amount = double.tryParse((c['amount'] as TextEditingController).text) ?? 0;

      if (c['selectedDefault']?['reason'] == 'EB (per unit)') {
        final units = int.tryParse(c['unit']?.text ?? '1') ?? 1;
        amount *= units;
      }

      return {
        'reason': c['selectedDefault']?['reason'] == 'EB (per unit)' ? 'EB (per unit)' : reason,
        'amount': amount
      };
    }).where((c) => (c['reason'] as String).isNotEmpty && (c['amount'] as double) > 0).toList();

    if (charges.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Add at least one valid charge")));
      return;
    }

    setState(() => _loading = true);

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/charges/${widget.hallId}/${widget.bookingId}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': widget.userId, 'charges': charges}),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Charges saved successfully!")));
        Navigator.pop(context, true);
      } else {
        final error = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${error['message'] ?? res.body}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryColor),
        ),
      ),
    );
  }

  Widget _buildChargeField(int index) {
    final controllers = chargesControllers[index];
    bool isEBPerUnit = controllers['selectedDefault']?['reason'] == 'EB (per unit)';

    if (isEBPerUnit && controllers['unit'] == null) {
      controllers['unit'] = TextEditingController(text: '1');
    }

    double total = 0;
    if (isEBPerUnit) {
      double perUnit = double.tryParse(controllers['amount'].text) ?? 0;
      int units = int.tryParse(controllers['unit']?.text ?? '1') ?? 1;
      total = perUnit * units;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cardColor,
      elevation: 1, // reduced elevation to avoid dark shadow
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: controllers['selectedDefault']?['reason'],
              hint: Text("Select or type reason", style: TextStyle(color: primaryColor)),
              items: [
                ...defaultValues
                    .where((d) => !['Rent', 'Peak Hours', 'Cancel'].contains(d['reason']))
                    .map((d) => DropdownMenuItem(
                  value: d['reason'],
                  child: Text(d['reason'], style: TextStyle(color: primaryColor)),
                )),
                DropdownMenuItem(
                  value: "Other",
                  child: Text("Other", style: TextStyle(color: primaryColor)),
                ),
              ],
              onChanged: (selected) {
                setState(() {
                  if (selected == "Other") {
                    controllers['selectedDefault'] = {'reason': 'Other'};
                    controllers['isCustom'] = true;
                    controllers['reason'].text = '';
                    controllers['amount'].text = '';
                  } else {
                    controllers['selectedDefault'] = defaultValues.firstWhere(
                          (d) => d['reason'] == selected,
                      orElse: () => {'reason': selected, 'amount': 0},
                    );
                    controllers['isCustom'] = false;
                    controllers['reason'].text = selected ?? '';
                    controllers['amount'].text =
                        controllers['selectedDefault']?['amount']?.toString() ?? '';
                    if (selected == 'EB (per unit)') {
                      controllers['unit'] ??= TextEditingController(text: '1');
                    }
                  }
                });
              },
              dropdownColor: cardColor,
              decoration: InputDecoration(
                labelText: "Reason",
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(borderSide: BorderSide(color: textFieldBorderColor)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: textFieldBorderColor, width: 2)),
              ),
              style: TextStyle(color: primaryColor),
            ),
            if (controllers['isCustom'] == true)
              const SizedBox(height: 10),
            if (controllers['isCustom'] == true)
              TextField(
                controller: controllers['reason'] as TextEditingController,
                decoration: InputDecoration(
                  labelText: "Custom Reason",
                  filled: true,
                  fillColor: cardColor,
                  border: OutlineInputBorder(borderSide: BorderSide(color: textFieldBorderColor)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: textFieldBorderColor, width: 2)),
                ),
                style: TextStyle(color: primaryColor),
              ),
            const SizedBox(height: 10),
            TextField(
              controller: controllers['amount'] as TextEditingController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: isEBPerUnit ? "Amount per Unit" : "Amount",
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(borderSide: BorderSide(color: textFieldBorderColor)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: textFieldBorderColor, width: 2)),
              ),
              style: TextStyle(color: primaryColor),
              onChanged: (_) => setState(() {}),
            ),
            if (isEBPerUnit) ...[
              const SizedBox(height: 10),
              TextField(
                controller: controllers['unit'],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Units",
                  filled: true,
                  fillColor: cardColor,
                  border: OutlineInputBorder(borderSide: BorderSide(color: textFieldBorderColor)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: textFieldBorderColor, width: 2)),
                ),
                style: TextStyle(color: primaryColor),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 6),
              Text("Total: ₹${total.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(Icons.remove_circle, color: primaryColor),
                onPressed: () => _removeChargeField(index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: primaryColor))),
          Expanded(flex: 5, child: Text(value, style: TextStyle(color: primaryColor, fontSize: 15))),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (var c in chargesControllers) {
      (c['reason'] as TextEditingController).dispose();
      (c['amount'] as TextEditingController).dispose();
      if (c['unit'] != null) (c['unit'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text("Update bookings", style: TextStyle(color: cardColor)),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: cardColor),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : booking == null
          ? Center(child: Text("No booking details found", style: TextStyle(color: primaryColor)))
          : Container(
        color: backgroundColor,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              ...List.generate(chargesControllers.length, _buildChargeField),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _addChargeField,
                      icon: Icon(Icons.add, color: cardColor),
                      label: Text("Add Another Charge", style: TextStyle(color: cardColor)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitCharges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text("Submit Charges", style: TextStyle(fontSize: 18, color: cardColor)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _sectionHeader("Booking Details"),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 1,
                color: cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _infoRow("Booking ID", booking!['booking_id'].toString()),
                      _infoRow("Name", booking!['name']),
                      _infoRow("Phone", booking!['phone']),
                      _infoRow("Function Date", DateFormat('yyyy-MM-dd').format(DateTime.parse(booking!['function_date']))),
                      _infoRow("Event Type", booking!['event_type'] ?? "N/A"),
                      _infoRow(
                        "Alloted From",
                        booking!['alloted_datetime_from'] != null
                            ? DateFormat('yyyy-MM-dd hh:mm a').format(DateTime.parse(booking!['alloted_datetime_from']).toLocal())
                            : "N/A",
                      ),
                      _infoRow(
                        "Alloted To",
                        booking!['alloted_datetime_to'] != null
                            ? DateFormat('yyyy-MM-dd hh:mm a').format(DateTime.parse(booking!['alloted_datetime_to']).toLocal())
                            : "N/A",
                      ),
                      _infoRow("Rent", booking!['rent'].toString()),
                      _infoRow("Advance", booking!['advance'].toString()),
                      _infoRow("Balance", booking!['balance'].toString()),
                    ],
                  ),
                ),
              ),
              if (existingCharges.isNotEmpty) ...[
                _sectionHeader("Existing Charges"),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 1,
                  color: cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: existingCharges.map((c) {
                        final reason = c['reason']?.toString() ?? '';
                        final amount = c['amount'] != null
                            ? double.tryParse(c['amount'].toString())?.toStringAsFixed(2) ?? '0.00'
                            : '0.00';
                        return _infoRow(reason, "₹$amount");
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
