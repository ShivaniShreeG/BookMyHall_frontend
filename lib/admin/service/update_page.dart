import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../public/config.dart';
import '../../utils/hall_header.dart';

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
  Map<String, dynamic>? _hallDetails;
  List<Map<String, dynamic>> existingCharges = [];
  List<Map<String, dynamic>> chargesControllers = [];
  List<Map<String, dynamic>> defaultValues = [];

  // Theme Colors
  final Color primaryColor = const Color(0xFF5B6547); // Olive green
  final Color backgroundColor = const Color(0xFFECE5D8); // Soft beige
  final Color cardColor = const Color(0xFFD8C7A5); // Muted tan
  final Color buttonTextColor = const Color(0xFFD8C7A5); // Muted tan
  final Color textFieldBorderColor = const Color(0xFF5B6547); // Olive for textfields

  @override
  void initState() {
    super.initState();
    _loadDefaultValues().then((_) => _loadBookingAndExistingCharges());
    _loadHallDetails();
  }
  Future<void> _loadHallDetails() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/halls/${widget.hallId}'));
      if (res.statusCode == 200) {
        setState(() {
          _hallDetails = jsonDecode(res.body);
        });
      }
    } catch (e) {
      debugPrint("Error loading hall details: $e");
    }
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

      // For EB per unit, calculate total amount
      if (c['selectedDefault']?['reason'] == 'EB (per unit)') {
        int start = int.tryParse(c['startUnit']?.text ?? '0') ?? 0;
        int end = int.tryParse(c['endUnit']?.text ?? '0') ?? 0;
        int units = (end - start).clamp(0, 99999); // ensure non-negative
        amount = amount * units; // total amount
      }

      return {
        'reason': c['selectedDefault']?['reason'] == 'EB (per unit)' ? 'EB (per unit)' : reason,
        'amount': amount,
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

  // Widget _sectionHeader(String title) {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(vertical: 16.0),
  //     child: Center(
  //       child: Text(
  //         title,
  //         style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryColor),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildChargeField(int index) {
    final controllers = chargesControllers[index];
    bool isEBPerUnit = controllers['selectedDefault']?['reason'] == 'EB (per unit)';

    // Ensure controllers exist
    if (isEBPerUnit) {
      controllers['startUnit'] ??= TextEditingController(text: '0');
      controllers['endUnit'] ??= TextEditingController(text: '0');
    }
    int units =0;
    double total = 0;
    if (isEBPerUnit) {
      double perUnit = double.tryParse(controllers['amount'].text) ?? 0;
      int start = int.tryParse(controllers['startUnit']?.text ?? '0') ?? 0;
      int end = int.tryParse(controllers['endUnit']?.text ?? '0') ?? 0;
      int units = (end - start).clamp(0, 99999);
      total = perUnit * units;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: primaryColor, width: 1),
      ),
      color: backgroundColor,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _plainRowWithTanValue(
              "REASON",
              child: DropdownButtonFormField<String>(
                value: controllers['selectedDefault']?['reason'],
                items: [
                  ...defaultValues
                      .where((d) => !['Rent', 'Peak Hours', 'Cancel'].contains(d['reason']))
                      .map(
                        (d) => DropdownMenuItem(
                      value: d['reason'],
                      child: Text(d['reason'], style: TextStyle(color: primaryColor)),
                    ),
                  ),
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
                        controllers['startUnit'] ??= TextEditingController(text: '0');
                        controllers['endUnit'] ??= TextEditingController(text: '0');
                      }
                    }
                  });
                },
                decoration: const InputDecoration(border: InputBorder.none),
                style: TextStyle(color: primaryColor),
                dropdownColor: cardColor,
              ),
            ),

            if (controllers['isCustom'] == true)
              _plainRowWithTanValue(
                "CUSTOM REASON",
                child: TextField(
                  controller: controllers['reason'],
                  decoration: const InputDecoration(border: InputBorder.none),
                  style: TextStyle(color: primaryColor),
                ),
              ),

            _plainRowWithTanValue(
              isEBPerUnit ? "AMOUNT (per Unit)" : "AMOUNT",
              child: TextField(
                controller: controllers['amount'],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(border: InputBorder.none),
                style: TextStyle(color: primaryColor),
                onChanged: (_) => setState(() {}),
              ),
            ),

            if (isEBPerUnit)
              _plainRowWithTanValue(
                "START UNIT",
                child: TextField(
                  controller: controllers['startUnit'],
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(border: InputBorder.none),
                  style: TextStyle(color: primaryColor),
                  onChanged: (_) => setState(() {}),
                ),
              ),

            if (isEBPerUnit)
              _plainRowWithTanValue(
                "END UNIT",
                child: TextField(
                  controller: controllers['endUnit'],
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(border: InputBorder.none),
                  style: TextStyle(color: primaryColor),
                  onChanged: (_) {
                    int start = int.tryParse(controllers['startUnit']?.text ?? '0') ?? 0;
                    int end = int.tryParse(controllers['endUnit']?.text ?? '0') ?? 0;

                    if (end < start) {
                      _showSnackBar("End unit must be greater than start unit");
                      controllers['endUnit']!.text = start.toString();
                    }
                    setState(() {});
                  },
                ),
              ),
            if (isEBPerUnit)
              _plainRowWithTanValue(
                "CONSUMED UNITS",
                value: units.toString(),
              ),


            if (isEBPerUnit)
              _plainRowWithTanValue(
                "TOTAL",
                value: "₹${total.toStringAsFixed(2)}",
              ),

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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: cardColor,
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
              color: cardColor,
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
  Widget _sectionContainer(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: backgroundColor, // same as page background
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: primaryColor,
          width: 1.5,
        ),
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
        title: Text("Billing", style: TextStyle(color: cardColor)),
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
              // ✅ Show Hall Details Card
              if (_hallDetails != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: HallHeader(
                    hallDetails: _hallDetails!,
                    oliveGreen: primaryColor,
                    tan: cardColor,
                  ),
                ),
              ...List.generate(chargesControllers.length, _buildChargeField),
              // _buildCharges(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Get screen width once for cleaner code
                  Builder(
                    builder: (context) {
                      final screenWidth = MediaQuery.of(context).size.width;

                      final buttonWidth = screenWidth * 0.40; // each button takes 45%
                      final spacing = screenWidth * 0.10; // space between
                      final fontSize = screenWidth * 0.04; // adaptive font size (~16 at 400px)
                      final iconSize = screenWidth * 0.05; // adaptive icon size
                      final verticalPadding = screenWidth * 0.035; // adaptive vertical padding

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SizedBox(
                            width: buttonWidth,
                            child: ElevatedButton.icon(
                              onPressed: _addChargeField,
                              icon: Icon(Icons.add, color: cardColor, size: iconSize),
                              label: Text(
                                "Add Charge",
                                style: TextStyle(
                                  color: cardColor,
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                padding: EdgeInsets.symmetric(vertical: verticalPadding),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: spacing),
                          SizedBox(
                            width: buttonWidth,
                            child: ElevatedButton.icon(
                              onPressed: _submitCharges,
                              icon: Icon(Icons.check_circle, color: cardColor, size: iconSize),
                              label: Text(
                                "Save Charges",
                                style: TextStyle(
                                  fontSize: fontSize,
                                  color: cardColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                padding: EdgeInsets.symmetric(vertical: verticalPadding),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),



              const SizedBox(height: 24),
              if (existingCharges.isNotEmpty)
                _sectionContainer(
                  "EXISTING CHARGES",
                  existingCharges.map((c) {
                    final reason = (c['reason']?.toString() ?? '').toUpperCase(); // convert to uppercase
                    final amount = c['amount'] != null
                        ? double.tryParse(c['amount'].toString())?.toStringAsFixed(2) ?? '0.00'
                        : '0.00';
                    return _plainRowWithTanValue(reason, value: "₹$amount");
                  }).toList(),
                ),
              const SizedBox(height: 24),
              _sectionContainer(
                "BOOKING DETAILS",
                [
                  _plainRowWithTanValue("BOOKING ID", value: booking!['booking_id'].toString()),
                  _plainRowWithTanValue("NAME", value: booking!['name']),
                  _plainRowWithTanValue("PHONE", value: booking!['phone']),
                  _plainRowWithTanValue(
                    "FUNCTION DATE",
                    value: DateFormat('dd-MM-yyyy').format(DateTime.parse(booking!['function_date'])),
                  ),
                  _plainRowWithTanValue("EVENT NAME", value: booking!['event_type'] ?? "N/A"),
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
                  _plainRowWithTanValue("RENT", value: booking!['rent'].toString()),
                  _plainRowWithTanValue("ADVANCE", value: booking!['advance'].toString()),
                  _plainRowWithTanValue("BALANCE", value: booking!['balance'].toString()),
                ],
              ),

              // Existing Charges section

              const SizedBox(height: 25)
            ],
          ),
        ),
      ),
    );
  }
}
