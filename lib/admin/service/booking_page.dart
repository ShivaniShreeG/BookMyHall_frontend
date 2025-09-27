import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../public/config.dart';
import '../../utils/alternate_phone formatter.dart';
import 'package:flutter/services.dart';

class BookingPage extends StatefulWidget {
  final DateTime selectedDate;
  const BookingPage({super.key, required this.selectedDate});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
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

  // Event Type
  String? selectedEventType;
  final List<String> eventTypes = [
    "Marriage",
    "Engagement",
    "Reception",
    "Meeting",
    "Other"
  ];

  bool _loading = false;
  List<Map<String, DateTime>> bookedRanges = [];
  List<DateTime> fullyBookedDates = [];

  // Theme Colors
  final Color oliveGreen = const Color(0xFF5B6547);
  final Color tan = const Color(0xFFD8C9A9);
  final Color beigeBackground = const Color(0xFFECE6D1);

  @override
  void initState() {
    super.initState();
    _setDefaultAllotment();
    _loadRent();
    _loadBookedRanges();
  }

  void _setDefaultAllotment() {
    final fromDefault = DateTime(widget.selectedDate.year,
        widget.selectedDate.month, widget.selectedDate.day - 1, 17, 0);
    final toDefault = DateTime(widget.selectedDate.year,
        widget.selectedDate.month, widget.selectedDate.day, 17, 0);

    fromController.text = DateFormat('yyyy-MM-dd hh:mm a').format(fromDefault);
    toController.text = DateFormat('yyyy-MM-dd hh:mm a').format(toDefault);
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

  Future<void> _pickFrom() async {
    final current = DateFormat('yyyy-MM-dd hh:mm a').parse(fromController.text);
    final result = await DateTimeRangePicker.pickSingle(
      context: context,
      selectedDate: widget.selectedDate,
      fullyBookedDates: fullyBookedDates,
      bookedRanges: bookedRanges,
      isFrom: true,
      currentValue: current,
      oliveGreen: oliveGreen,
      tan: tan,
    );
    if (result != null) {
      setState(() {
        fromController.text = DateFormat('yyyy-MM-dd hh:mm a').format(result);
      });
    }
  }

  Future<void> _pickTo() async {
    final current = DateFormat('yyyy-MM-dd hh:mm a').parse(toController.text);
    final result = await DateTimeRangePicker.pickSingle(
      context: context,
      selectedDate: widget.selectedDate,
      fullyBookedDates: fullyBookedDates,
      bookedRanges: bookedRanges,
      isFrom: false,
      currentValue: current,
      oliveGreen: oliveGreen,
      tan: tan,
    );
    if (result != null) {
      setState(() {
        toController.text = DateFormat('yyyy-MM-dd hh:mm a').format(result);
      });
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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt('hallId');
    final userId = prefs.getInt('userId');

    if (hallId == null || userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text("Hall ID or User ID not found"),
            backgroundColor: oliveGreen),
      );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Invalid alternate phone number: $num"),
              backgroundColor: oliveGreen,
            ),
          );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: const Text("Booking created successfully!"),
              backgroundColor: oliveGreen),
        );
        Navigator.pop(context);
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Error: ${error['message']}"),
              backgroundColor: oliveGreen),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: oliveGreen),
      );
    }

    setState(() => _loading = false);
  }

  Future<void> _fetchCustomerDetails(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt('hallId');
    if (hallId == null) return;

    final formattedPhone = phone.startsWith('+91') ? phone : '+91$phone';

    try {
      final res = await http.get(
          Uri.parse('$baseUrl/bookings/$hallId/customer/$formattedPhone'));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        setState(() {
          nameController.text = data['name'] ?? '';
          addressController.text = data['address'] ?? '';
          altPhoneController.text = (data['alternate_phone'] as List<dynamic>?)
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

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('yyyy-MM-dd').format(widget.selectedDate);

    return Scaffold(
      backgroundColor: beigeBackground,
      appBar: AppBar(
        title: const Text(
          "Booking Page",
          style: TextStyle(color: Color(0xFFD8C9A9)),
        ),
        backgroundColor: oliveGreen,
        iconTheme: const IconThemeData(color: Color(0xFFD8C9A9)),
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
              Text(
                "Booking for: $formattedDate",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: oliveGreen,
                ),
              ),
              const SizedBox(height: 20),
              _buildTextField(fromController, "Alloted From", false,
                  readOnly: true, onTap: _pickFrom),
              const SizedBox(height: 10),
              _buildTextField(toController, "Alloted To", false,
                  readOnly: true, onTap: _pickTo),
              const SizedBox(height: 20),
              _buildTextField(
                phoneController,
                "Phone",
                false,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                onChanged: (value) {
                  if (value.length == 10) {
                    _fetchCustomerDetails(value);
                  }
                },
              ),
              const SizedBox(height: 10),
              _buildTextField(nameController, "Name", false),
              const SizedBox(height: 10),
              _buildTextField(addressController, "Address", false),
              const SizedBox(height: 10),
              _buildTextField(
                altPhoneController,
                "Alternate Phone",
                true,
                keyboardType: TextInputType.phone,
                inputFormatters: [AlternatePhoneFormatter()],
              ),
              const SizedBox(height: 10),
              _buildTextField(emailController, "Email", true,
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 10),

              // Event Type Dropdown
              // Event Type Dropdown
              DropdownButtonFormField<String>(
                value: selectedEventType,
                items: eventTypes
                    .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(
                    e,
                    style: TextStyle(color: oliveGreen), // Text color for items
                  ),
                ))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    selectedEventType = val;
                    if (val != "Other") customEventController.text = "";
                  });
                },
                dropdownColor: beigeBackground, // dropdown background
                iconEnabledColor: oliveGreen, // dropdown arrow color
                style: TextStyle(color: oliveGreen), // selected value text
                decoration: InputDecoration(
                  labelText: "Event Type",
                  labelStyle: TextStyle(color: oliveGreen),
                  filled: true,
                  fillColor: tan.withOpacity(0.2),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: oliveGreen),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: oliveGreen),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Event Type is required";
                  }
                  return null;
                },
              ),
              if (selectedEventType == "Other") ...[
                const SizedBox(height: 10),
                _buildTextField(
                    customEventController, "Custom Event Type", false),
              ],

              const SizedBox(height: 10),
              _buildTextField(rentController, "Rent", false,
                  keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              _buildTextField(advanceController, "Advance", false,
                  keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: oliveGreen,
                    foregroundColor: tan,
                  ),
                  onPressed: _submitBooking,
                  child: const Text("Submit Booking"),
                ),
              ),
            ],
          ),
        ),
      ),
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
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: oliveGreen),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: oliveGreen),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: oliveGreen),
        ),
      ),
      style: TextStyle(color: oliveGreen),
      validator: optional
          ? null
          : (value) {
        if (value == null || value.isEmpty) {
          return "$label is required";
        }
        return null;
      },
    );
  }
}

/// DateTime picker with conflict checking
class DateTimeRangePicker {
  static Future<DateTime?> pickSingle({
    required BuildContext context,
    required DateTime selectedDate,
    required List<DateTime> fullyBookedDates,
    required List<Map<String, DateTime>> bookedRanges,
    required bool isFrom,
    DateTime? currentValue,
    required Color oliveGreen,
    required Color tan,
  }) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: currentValue ?? selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: oliveGreen,
            onPrimary: tan,
            surface: tan,
            onSurface: oliveGreen,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: oliveGreen),
          ),
          dialogBackgroundColor: tan,
        ),
        child: child!,
      ),
    );

    if (pickedDate == null) return null;

    final initialTime = currentValue != null
        ? TimeOfDay(hour: currentValue.hour, minute: currentValue.minute)
        : TimeOfDay.now();

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: oliveGreen,
            onPrimary: tan,
            surface: tan,
            onSurface: oliveGreen,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: oliveGreen),
          ),
          timePickerTheme: TimePickerThemeData(
            backgroundColor: tan,
            hourMinuteTextColor: MaterialStateColor.resolveWith(
                    (states) => states.contains(MaterialState.selected)
                    ? tan
                    : oliveGreen),
            hourMinuteShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: oliveGreen),
            ),
            hourMinuteColor: MaterialStateColor.resolveWith(
                    (states) => states.contains(MaterialState.selected)
                    ? oliveGreen
                    : Colors.transparent),
            dayPeriodTextColor: MaterialStateColor.resolveWith(
                    (states) => states.contains(MaterialState.selected)
                    ? tan
                    : oliveGreen),
            dayPeriodShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: oliveGreen),
            ),
            dayPeriodColor: MaterialStateColor.resolveWith(
                    (states) => states.contains(MaterialState.selected)
                    ? oliveGreen
                    : Colors.transparent),
            dialHandColor: oliveGreen,
            dialBackgroundColor: tan,
            entryModeIconColor: oliveGreen,
          ),
        ),
        child: child!,
      ),
    );

    if (pickedTime == null) return null;

    final dt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (fullyBookedDates.any((d) =>
    d.year == dt.year && d.month == dt.month && d.day == dt.day)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This date is fully booked")),
      );
      return null;
    }

    for (var range in bookedRanges) {
      final bookedFrom = range['from']!.toLocal();
      final bookedTo = range['to']!.toLocal();

      final pickedFrom = isFrom ? dt : currentValue ?? dt;
      final pickedTo = isFrom ? currentValue ?? dt : dt;

      if (pickedFrom.isBefore(bookedTo) && pickedTo.isAfter(bookedFrom)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Conflict with existing booking:\n"
                  "${DateFormat('yyyy-MM-dd hh:mm a').format(bookedFrom)} "
                  "to ${DateFormat('yyyy-MM-dd hh:mm a').format(bookedTo)}",
            ),
          ),
        );
        return null;
      }
    }

    return dt;
  }
}
