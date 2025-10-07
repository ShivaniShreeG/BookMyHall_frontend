import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../../public/config.dart';
import '../../utils/alternate_phone formatter.dart';
import 'pdf/booking_pdf_generator.dart';
import '../../utils/date_time_range_picker.dart';
import 'calendar_page.dart';

class BookingPage extends StatefulWidget {
  final DateTime selectedDate;
  const BookingPage({super.key, required this.selectedDate});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController altPhoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController rentController = TextEditingController();
  final TextEditingController advanceController = TextEditingController();
  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();
  final TextEditingController customEventController = TextEditingController();

  String? selectedEventType;
  final List<String> eventTypes = [
    "Marriage",
    "Engagement",
    "Reception",
    "Meeting",
    "Other"
  ];

  bool _loading = false;
  bool _showPdfButton = false;
  Map<String, dynamic>? _lastBooking;
  Map<String, dynamic>? _hallDetails;

  List<Map<String, DateTime>> bookedRanges = [];
  List<DateTime> fullyBookedDates = [];

  final Color oliveGreen = const Color(0xFF5B6547);
  final Color tan = const Color(0xFFD8C9A9);
  final Color beigeBackground = const Color(0xFFECE6D1);

  @override
  void initState() {
    super.initState();
    _setDefaultAllotment();
    _loadRent();
    _loadBookedRanges();
    _fetchHallDetails();
    phoneController.addListener(_onPhoneChanged);
  }

  void _onPhoneChanged() {
    final phone = phoneController.text;
    if (phone.length == 10) {
      _fetchCustomerDetails(phone);
    }
  }

  void _setDefaultAllotment() {
    final fromDefault = DateTime(widget.selectedDate.year,
        widget.selectedDate.month, widget.selectedDate.day - 1, 17, 0);
    final toDefault = DateTime(widget.selectedDate.year,
        widget.selectedDate.month, widget.selectedDate.day, 17, 0);

    fromController.text =
        DateFormat('yyyy-MM-dd hh:mm a').format(fromDefault);
    toController.text = DateFormat('yyyy-MM-dd hh:mm a').format(toDefault);
  }

  Future<void> _fetchHallDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt('hallId');
    if (hallId == null) return;
    try {
      final res = await http.get(Uri.parse('$baseUrl/halls/$hallId'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _hallDetails = data;
        });
      }
      final instrRes =
      await http.get(Uri.parse('$baseUrl/instructions/hall/$hallId'));
      if (instrRes.statusCode == 200) {
        final instrData = jsonDecode(instrRes.body) as List;
        final instructions =
        instrData.map((i) => i['instruction'].toString()).toList();

        setState(() {
          if (_hallDetails != null) {
            _hallDetails!['instructions'] = instructions;
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching hall details or instructions: $e");
    }
  }

  Future<void> _showValidationDialog(String message) async {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: beigeBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: oliveGreen, width: 1.5),
          ),
          title: Text(
            "Invalid Input",
            style: TextStyle(
              color: oliveGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(
              color: oliveGreen,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CalendarPage(mode: CalendarMode.book),
                  ),
                );
              },
              child: Text("OK",
                style: TextStyle(
                  color: tan,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: oliveGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            )
          ],
        );
      },
    );
  }

  Future<void> _loadBookedRanges() async {
    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt('hallId');
    if (hallId == null) return;
    try {
      final res = await http.get(Uri.parse('$baseUrl/bookings/$hallId'));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        final Map<String, int> bookingCount = {};
        List<Map<String, DateTime>> ranges = [];
        for (var b in data) {
          final from = DateTime.parse(b['alloted_datetime_from']);
          final to = DateTime.parse(b['alloted_datetime_to']);
          ranges.add({"from": from, "to": to});
          final dayKey = DateFormat('yyyy-MM-dd').format(from);
          bookingCount[dayKey] = (bookingCount[dayKey] ?? 0) + 1;
        }
        final fullyBooked = bookingCount.entries
            .where((e) => e.value >= 3)
            .map((e) => DateFormat('yyyy-MM-dd').parse(e.key))
            .toList();

        setState(() {
          bookedRanges = ranges;
          fullyBookedDates = fullyBooked;
        });
      }
    } catch (e) {
      debugPrint("Error loading booked ranges: $e");
    }
  }

  Future<void> _loadRent() async {
    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt('hallId');
    if (hallId == null) return;
    final dateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
    try {
      final calRes = await http.get(Uri.parse('$baseUrl/calendar/$hallId'));
      bool isPeakDay = false;
      if (calRes.statusCode == 200) {
        final calData = jsonDecode(calRes.body);
        final dayEntry = calData[dateStr];
        if (dayEntry != null &&
            dayEntry['peakHours'] != null &&
            dayEntry['peakHours'].isNotEmpty) {
          isPeakDay = true;
        }
      }
      final defaultRes =
      await http.get(Uri.parse('$baseUrl/default-values/$hallId'));
      if (defaultRes.statusCode == 200) {
        final defaults = jsonDecode(defaultRes.body);
        Map<String, dynamic>? rentValue;
        if (isPeakDay) {
          rentValue = defaults.firstWhere(
                (d) => d['reason'].toString().toLowerCase() == 'peak hours',
            orElse: () => null,
          );
        } else {
          rentValue = defaults.firstWhere(
                (d) => d['reason'].toString().toLowerCase() == 'rent',
            orElse: () => null,
          );
        }
        if (rentValue != null) {
          rentController.text = rentValue['amount'].toString();
        }
      }
    } catch (e) {
      debugPrint("Error fetching rent: $e");
    }
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) {
      // Find the first invalid field and show dialog
      if (phoneController.text.isEmpty || phoneController.text.length != 10) {
        _showValidationDialog("Please enter a valid 10-digit phone number.");
        return;
      }

      if (nameController.text.isEmpty) {
        _showValidationDialog("Please enter the customer's name.");
        return;
      }

      if (addressController.text.isEmpty) {
        _showValidationDialog("Please enter the address.");
        return;
      }

      if (selectedEventType == null || selectedEventType!.isEmpty) {
        _showValidationDialog("Please select an event type.");
        return;
      }

      if (selectedEventType == "Other" && customEventController.text.isEmpty) {
        _showValidationDialog("Please enter a custom event type.");
        return;
      }

      if (emailController.text.isNotEmpty &&
          !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
              .hasMatch(emailController.text.trim())) {
        _showValidationDialog("Please enter a valid email address.");
        return;
      }

      if (altPhoneController.text.isNotEmpty) {
        final rawNumbers = altPhoneController.text
            .split(RegExp(r'[,\s]+'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        for (var num in rawNumbers) {
          if (num.length != 10 || !RegExp(r'^[0-9]{10}$').hasMatch(num)) {
            _showValidationDialog("Invalid alternate phone number: $num");
            return;
          }
        }
      }
      return; // Stop submission if invalid
    }
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt('hallId');
    final userId = prefs.getInt('userId');
    if (hallId == null || userId == null) {
      _showSnackBar("Hall ID or User ID not found");
      setState(() => _loading = false);
      return;
    }
    final rent = double.tryParse(rentController.text) ?? 0;
    final advance = double.tryParse(advanceController.text) ?? 0;
    final balance = rent - advance;
    List<String> alternatePhones = [];
    if (altPhoneController.text.isNotEmpty) {
      final rawNumbers = altPhoneController.text
          .split(RegExp(r'[,\s]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      for (var num in rawNumbers) {
        if (num.length == 10 && RegExp(r'^[0-9]{10}$').hasMatch(num)) {
          alternatePhones.add('+91$num');
        } else {
          _showSnackBar("Invalid alternate phone number: $num");
          setState(() => _loading = false);
          return;
        }
      }
    }
    final payload = {
      "hall_id": hallId,
      "user_id": userId,
      "function_date": DateFormat('yyyy-MM-dd').format(widget.selectedDate),
      "alloted_datetime_from": fromController.text,
      "alloted_datetime_to": toController.text,
      "name": nameController.text,
      "phone": phoneController.text.length == 10
          ? '+91${phoneController.text}'
          : phoneController.text,
      "address": addressController.text,
      "alternate_phone": alternatePhones,
      "email": emailController.text.isNotEmpty ? emailController.text : null,
      "rent": rent,
      "advance": advance,
      "balance": balance,
      "event_type": selectedEventType == "Other"
          ? customEventController.text
          : selectedEventType,
    };
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/bookings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _showSnackBar("Booking created successfully!");
        setState(() {
          _lastBooking = {
            ...payload,
            "booking_id": data['booking_id'] ?? data['id'],
          };
          _showPdfButton = true;
        });
      } else {
        final error = jsonDecode(response.body);
        _showSnackBar("Error: ${error['message']}");
      }
    } catch (e) {
      _showSnackBar("Error: $e");
    }
    setState(() => _loading = false);
  }
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: tan,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: oliveGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    altPhoneController.dispose();
    emailController.dispose();
    rentController.dispose();
    advanceController.dispose();
    fromController.dispose();
    toController.dispose();
    customEventController.dispose();
    super.dispose();
  }

  Widget _plainRowWithTanValue(String label, Widget valueWidget) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: screenWidth * 0.35, // 35% of screen width
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: beigeBackground,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: oliveGreen,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),

          Container(
            width: screenWidth * 0.50, // 55% of screen width
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tan,
              borderRadius: BorderRadius.circular(6),
            ),
            child: valueWidget,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('dd-MM-yyyy').format(widget.selectedDate);
    return Scaffold(
      backgroundColor: beigeBackground,
      appBar: AppBar(
        backgroundColor: oliveGreen,
        iconTheme: IconThemeData(color: tan),
        title: Text(
          "Booking Page",
          style: TextStyle(color: tan, fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: oliveGreen))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: oliveGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        fit: FlexFit.tight,
                        child: Text(
                          _hallDetails?['name']?.toUpperCase() ?? "HALL NAME",
                          style: TextStyle(
                            color: tan,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          softWrap: true,
                        ),
                      ),
                      if (_hallDetails?['logo'] != null && _hallDetails!['logo'].isNotEmpty)
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: tan.withOpacity(0.2),
                          backgroundImage: MemoryImage(
                            base64Decode(_hallDetails!['logo']),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _sectionHeader("PERSONAL INFORMATION"),
                const SizedBox(height: 8),
                _plainRowWithTanValue(
                  "PHONE",
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    style: TextStyle(
                      color: oliveGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter phone number',
                      hintStyle: TextStyle(color: oliveGreen.withOpacity(0.7)), // same as other fields
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                _plainRowWithTanValue(
                  "NAME",
                  TextFormField(
                    controller: nameController,
                    readOnly: _showPdfButton,
                    style: TextStyle(color: oliveGreen, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: "Enter name",
                      isDense: true,
                      hintStyle: TextStyle(color: oliveGreen.withOpacity(0.7)),
                      contentPadding: EdgeInsets.zero,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "Name is required";
                      }
                      return null;
                    },
                  ),
                ),
                _plainRowWithTanValue(
                  "ADDRESS",
                  TextFormField(
                    controller: addressController,
                    readOnly: _showPdfButton,
                    style: TextStyle(color: oliveGreen, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: "Enter address",
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintStyle: TextStyle(color: oliveGreen.withOpacity(0.7)),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "Address is required";
                      }
                      return null;
                    },
                  ),
                ),
                _plainRowWithTanValue(
                  "ALTERNATE PHONE",
                  TextFormField(
                    controller: altPhoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [AlternatePhoneFormatter()],
                    readOnly: _showPdfButton,
                    style: TextStyle(color: oliveGreen, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: "Enter alternate phones (comma separated)",
                      hintStyle: TextStyle(color: oliveGreen.withOpacity(0.7)),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    validator: (value) {
                      return null;
                    },
                  ),
                ),
                _plainRowWithTanValue(
                  "EMAIL",
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    readOnly: _showPdfButton,
                    style: TextStyle(color: oliveGreen, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: "Enter email (optional)",
                      hintStyle: TextStyle(color: oliveGreen.withOpacity(0.7)),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegex.hasMatch(value.trim())) {
                          return "Enter a valid email address";
                        }
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 18),
                _sectionHeader("BOOKING INFORMATION"),
                const SizedBox(height: 12),
                  _plainRowWithTanValue(
                    "BOOKING DATE",
                    Container(
                      alignment: Alignment.center, // <-- center horizontally & vertically
                      child: Text(
                        formattedDate,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: oliveGreen,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),
                _plainRowWithTanValue(
                  "EVENT TYPE",
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedEventType,
                        isExpanded: true,
                        items: eventTypes
                            .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(
                            e,
                            style: TextStyle(color: oliveGreen, fontSize: 16),
                          ),
                        ))
                            .toList(),
                        onChanged: _showPdfButton
                            ? null
                            : (val) {
                          setState(() {
                            selectedEventType = val;
                            if (val != "Other") customEventController.text = "";
                          });
                        },
                        hint: Text(
                          "Select any event", // <-- shows inside the field before selection
                          style: TextStyle(color: oliveGreen.withOpacity(0.7), fontSize: 14),
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          filled: true,
                          fillColor: tan.withOpacity(0.0),
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        dropdownColor: beigeBackground,
                        validator: (val) {
                          if (val == null || val.isEmpty) return "Please select an event type";
                          return null;
                        },
                      ),
                      if (selectedEventType == "Other")
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: TextFormField(
                            controller: customEventController,
                            style: TextStyle(color: oliveGreen),
                            decoration: InputDecoration(
                              labelText: "Custom Event",
                              filled: true,
                              fillColor: tan.withOpacity(0.12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                _plainRowWithTanValue(
                  "ALLOTED FROM",
                  GestureDetector(
                    onTap: _pickFrom,
                    child: Container(
                      width: double.infinity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center, // center vertically
                        crossAxisAlignment: CrossAxisAlignment.center, // center horizontally
                        children: [
                          Text(
                            DateFormat('dd-MM-yyyy').format(
                              DateFormat('yyyy-MM-dd hh:mm a').parse(fromController.text),
                            ),
                            style: TextStyle(
                              color: oliveGreen,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('hh:mm a').format(
                              DateFormat('yyyy-MM-dd hh:mm a').parse(fromController.text),
                            ),
                            style: TextStyle(
                              color: oliveGreen,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _plainRowWithTanValue(
                  "ALLOTED TO",
                  GestureDetector(
                    onTap: _pickTo,
                    child: Container(
                      width: double.infinity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center, // center vertically
                        crossAxisAlignment: CrossAxisAlignment.center, // center horizontally
                        children: [
                          Text(
                            DateFormat('dd-MM-yyyy').format(
                              DateFormat('yyyy-MM-dd hh:mm a').parse(toController.text),
                            ),
                            style: TextStyle(
                              color: oliveGreen,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('hh:mm a').format(
                              DateFormat('yyyy-MM-dd hh:mm a').parse(toController.text),
                            ),
                            style: TextStyle(
                              color: oliveGreen,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _sectionHeader("PAYMENT DETAILS"),
                const SizedBox(height: 8),
                _plainRowWithTanValue(
                  "RENT",
                  TextFormField(
                    controller: rentController,
                    keyboardType: TextInputType.number,
                    readOnly: _showPdfButton,
                    style: TextStyle(color: oliveGreen, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: "Enter rent amount",
                      hintStyle: TextStyle(color: oliveGreen.withOpacity(0.7)),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "Rent amount is required";
                      } else if (double.tryParse(value.trim()) == null) {
                        return "Enter a valid number";
                      }
                      return null;
                    },
                  ),
                ),
                _plainRowWithTanValue(
                  "ADVANCE",
                  TextFormField(
                    controller: advanceController,
                    keyboardType: TextInputType.number,
                    readOnly: _showPdfButton,
                    style: TextStyle(color: oliveGreen, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: "Enter advance amount",
                      hintStyle: TextStyle(color: oliveGreen.withOpacity(0.7)),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "Advance amount is required";
                      } else if (double.tryParse(value.trim()) == null) {
                        return "Enter a valid number";
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 24),
                if (_showPdfButton && _lastBooking != null && _hallDetails != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookingPdfPage(
                              bookingData: _lastBooking!,
                              hallDetails: _hallDetails!,
                              oliveGreen: oliveGreen,
                              tan: tan,
                              beigeBackground: beigeBackground,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text("Generate & View PDF"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: oliveGreen,
                        foregroundColor: tan,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                if (_showPdfButton) const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showPdfButton ? null : () {
                      print("Submit button pressed: $_showPdfButton"); // 👈 Add here
                      _submitBooking();
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text("Submit Booking"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: oliveGreen,
                      foregroundColor: tan,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 38),
              ],
            ),
          ),
    ),
    );
  }

  Widget _sectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: oliveGreen,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(color: oliveGreen.withOpacity(0.12), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Text(
        title,
        style: TextStyle(color: tan, fontWeight: FontWeight.bold),
      ),
    );
  }
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: oliveGreen, fontWeight: FontWeight.w500),
      filled: true,
      fillColor: tan.withOpacity(0.12),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: oliveGreen.withOpacity(0.6)),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: oliveGreen, width: 1.4),
        borderRadius: BorderRadius.circular(8),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    );
  }
  Widget _buildTextField(
      TextEditingController controller,
      String label,
      bool optional, {
        TextInputType keyboardType = TextInputType.text,
        bool readOnly = false,
        VoidCallback? onTap,
        List<TextInputFormatter>? inputFormatters,
        ValueChanged<String>? onChanged,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        style: TextStyle(color: oliveGreen),
        decoration: _inputDecoration(label),
        validator: optional
            ? null
            : (value) {
          if (value == null || value.isEmpty) return "$label is required";
          return null;
        },
      ),
    );
  }

  Future<void> _fetchCustomerDetails(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt('hallId');
    if (hallId == null) return;

    final formattedPhone = phone.startsWith('+91') ? phone : '+91$phone';

    try {
      final res = await http.get(Uri.parse('$baseUrl/bookings/$hallId/customer/$formattedPhone'));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          nameController.text = data['name'] ?? '';
          addressController.text = data['address'] ?? '';
          altPhoneController.text =
              (data['alternate_phone'] as List<dynamic>?)
                  ?.map((e) => (e as String).replaceFirst('+91', ''))
                  .join(', ') ??
                  '';
          emailController.text = data['email'] ?? '';
        });
      }
    } catch (e) {
      debugPrint("Error fetching customer details: $e");
    }
  }
  Future<void> _pickFrom() async {
    final picked = await DateTimeRangePicker.pickSingle(
      context: context,
      selectedDate: widget.selectedDate,
      fullyBookedDates: fullyBookedDates,
      bookedRanges: bookedRanges,
      isFrom: true,
      currentValue: DateFormat('yyyy-MM-dd hh:mm a').parse(fromController.text),
      oliveGreen: oliveGreen,
      tan: tan,
    );

    if (picked != null) {
      setState(() {
        fromController.text = DateFormat('yyyy-MM-dd hh:mm a').format(picked);
      });
    }
  }

  Future<void> _pickTo() async {
    final picked = await DateTimeRangePicker.pickSingle(
      context: context,
      selectedDate: widget.selectedDate,
      fullyBookedDates: fullyBookedDates,
      bookedRanges: bookedRanges,
      isFrom: false,
      currentValue: DateFormat('yyyy-MM-dd hh:mm a').parse(toController.text),
      oliveGreen: oliveGreen,
      tan: tan,
    );

    if (picked != null) {
      setState(() {
        toController.text = DateFormat('yyyy-MM-dd hh:mm a').format(picked);
      });
    }
  }

}
