import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../public/config.dart';

class ChangeBookingDatePage extends StatefulWidget {
  final int hallId;
  final int bookingId;

  const ChangeBookingDatePage({
    super.key,
    required this.hallId,
    required this.bookingId,
  });

  @override
  State<ChangeBookingDatePage> createState() => _ChangeBookingDatePageState();
}

class _ChangeBookingDatePageState extends State<ChangeBookingDatePage> {
  bool _loading = true;
  Map<String, dynamic>? booking;

  DateTime? functionDate;
  DateTime? allotedFrom;
  DateTime? allotedTo;

  List<Map<String, DateTime>> otherBookedRanges = [];
  List<DateTime> fullyBookedDates = [];
  List<DateTime> otherFunctionDates = [];

  final Color primaryColor = const Color(0xFF5B6547);
  final Color backgroundColor = const Color(0xFFD8C9A9);
  final Color cardColor = const Color(0xFFD8C7A5);

  @override
  void initState() {
    super.initState();
    _loadBooking();
  }

  Future<void> _loadBooking() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/bookings/${widget.hallId}/${widget.bookingId}'),
      );

      if (res.statusCode == 200) {
        booking = jsonDecode(res.body);

        functionDate = DateTime.parse(booking!['function_date']).toLocal();
        allotedFrom =
            DateTime.parse(booking!['alloted_datetime_from']).toLocal();
        allotedTo = DateTime.parse(booking!['alloted_datetime_to']).toLocal();

        await _loadOtherBookings();

        setState(() => _loading = false);
      } else {
        throw Exception('Booking not found');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading booking: $e")));
      Navigator.pop(context);
    }
  }

  Future<void> _loadOtherBookings() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/bookings/${widget.hallId}'),
      );

      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        Map<String, int> bookingCount = {};
        List<Map<String, DateTime>> ranges = [];
        List<DateTime> funcDates = [];

        for (var b in data) {
          if (b['booking_id'] == widget.bookingId) continue;

          final from = DateTime.parse(b['alloted_datetime_from']).toLocal();
          final to = DateTime.parse(b['alloted_datetime_to']).toLocal();
          final fdate = DateTime.parse(b['function_date']).toLocal();

          ranges.add({"from": from, "to": to});
          funcDates.add(fdate);

          final dayKey = DateFormat('yyyy-MM-dd').format(from);
          bookingCount[dayKey] = (bookingCount[dayKey] ?? 0) + 1;
        }

        final fullyBooked = bookingCount.entries
            .where((e) => e.value >= 3)
            .map((e) => DateFormat('yyyy-MM-dd').parse(e.key))
            .toList();

        otherBookedRanges = ranges;
        fullyBookedDates = fullyBooked;
        otherFunctionDates = funcDates;
      }
    } catch (e) {
      debugPrint("Error loading other bookings: $e");
    }
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    return await ThemedDateTimePicker.pick(
      context: context,
      initialDate: initial ?? DateTime.now(),
      primaryColor: primaryColor,
      backgroundColor: cardColor,
    );
  }

  Future<void> _pickAllotedFrom() async {
    final picked = await _pickDateTime(allotedFrom);
    if (picked != null) setState(() => allotedFrom = picked);
  }

  Future<void> _pickAllotedTo() async {
    final picked = await _pickDateTime(allotedTo);
    if (picked != null) setState(() => allotedTo = picked);
  }

  Future<void> _pickFunctionDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: functionDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: primaryColor,
            onPrimary: backgroundColor,
            surface: cardColor,
            onSurface: primaryColor,
          ),
          dialogBackgroundColor: cardColor,
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      if (fullyBookedDates.any((d) =>
      d.year == picked.year &&
          d.month == picked.month &&
          d.day == picked.day)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("This date is fully booked")),
        );
        return;
      }

      if (otherFunctionDates.any((d) =>
      d.year == picked.year &&
          d.month == picked.month &&
          d.day == picked.day)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("This function date is already booked")),
        );
        return;
      }

      setState(() => functionDate = picked);
    }
  }

  bool _checkConflict(DateTime start, DateTime end) {
    for (var range in otherBookedRanges) {
      final bookedFrom = range['from']!;
      final bookedTo = range['to']!;
      if (start.isBefore(bookedTo) && end.isAfter(bookedFrom)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Conflict with existing booking:\n"
                  "${DateFormat('yyyy-MM-dd hh:mm a').format(bookedFrom)} to "
                  "${DateFormat('yyyy-MM-dd hh:mm a').format(bookedTo)}",
            ),
          ),
        );
        return true;
      }
    }

    if (fullyBookedDates.any((d) =>
    d.year == start.year &&
        d.month == start.month &&
        d.day == start.day)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This date is fully booked")),
      );
      return true;
    }

    return false;
  }

  Future<void> _submitChange() async {
    if (functionDate == null || allotedFrom == null || allotedTo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select all dates and times")),
      );
      return;
    }

    if (!allotedFrom!.isBefore(allotedTo!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Alloted From must be before Alloted To")),
      );
      return;
    }

    if (functionDate!.isBefore(allotedFrom!) ||
        functionDate!.isAfter(allotedTo!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
            Text("Function date must be on or between allotted from–to")),
      );
      return;
    }

    if (_checkConflict(allotedFrom!, allotedTo!)) return;

    setState(() => _loading = true);

    try {
      final res = await http.patch(
        Uri.parse(
            '$baseUrl/bookings/${widget.hallId}/${widget.bookingId}/time'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'function_date': DateFormat('yyyy-MM-dd').format(functionDate!),
          'alloted_datetime_from': allotedFrom!.toIso8601String(),
          'alloted_datetime_to': allotedTo!.toIso8601String(),
        }),
      );

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Booking date/time updated successfully")),
        );
        Navigator.pop(context, true);
      } else {
        final error = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${error['message'] ?? res.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label,
                style:
                TextStyle(fontWeight: FontWeight.w600, color: primaryColor)),
          ),
          Expanded(
              flex: 5,
              child: Text(value,
                  style: TextStyle(color: primaryColor, fontSize: 15))),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: Text(
          title,
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 18, color: primaryColor),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text("Change Booking Date/Time",
            style: TextStyle(color: Color(0xFFD8C7A5))),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: cardColor),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// 1️⃣ Change Date Section
            _sectionHeader("Change Date/Time"),
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              color: cardColor,
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      readOnly: true,
                      onTap: _pickFunctionDate,
                      decoration: InputDecoration(
                        labelText: "Function Date",
                        labelStyle: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w600),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        suffixIcon: const Icon(Icons.calendar_today),
                      ),
                      controller: TextEditingController(
                        text: functionDate != null
                            ? DateFormat('yyyy-MM-dd').format(functionDate!)
                            : "",
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      readOnly: true,
                      onTap: _pickAllotedFrom,
                      decoration: InputDecoration(
                        labelText: "Alloted From",
                        labelStyle: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w600),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        suffixIcon: const Icon(Icons.access_time),
                      ),
                      controller: TextEditingController(
                        text: allotedFrom != null
                            ? DateFormat('yyyy-MM-dd hh:mm a')
                            .format(allotedFrom!)
                            : "",
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      readOnly: true,
                      onTap: _pickAllotedTo,
                      decoration: InputDecoration(
                        labelText: "Alloted To",
                        labelStyle: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w600),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        suffixIcon: const Icon(Icons.access_time),
                      ),
                      controller: TextEditingController(
                        text: allotedTo != null
                            ? DateFormat('yyyy-MM-dd hh:mm a')
                            .format(allotedTo!)
                            : "",
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            /// Save button
            ElevatedButton(
              onPressed: _submitChange,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(
                    vertical: 15, horizontal: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                "Save Changes",
                style: TextStyle(fontSize: 15, color: Color(0xFFD8C7A5)),
              ),
            ),
            const SizedBox(height: 20),

            /// 2️⃣ Booking Details Section
            _sectionHeader("Booking Details"),
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              color: cardColor,
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _infoRow("Booking ID", booking!['booking_id'].toString()),
                    _infoRow("Name", booking!['name']),
                    _infoRow("Phone", booking!['phone']),
                    if (booking!['email'] != null)
                      _infoRow("Email", booking!['email']),
                    if (booking!['address'] != null)
                      _infoRow("Address", booking!['address']),
                    _infoRow("Event Type", booking!['event_type'] ?? "N/A"),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/// Reusable Themed DateTime Picker
class ThemedDateTimePicker {
  static Future<DateTime?> pick({
    required BuildContext context,
    required DateTime initialDate,
    required Color primaryColor,
    required Color backgroundColor,
  }) async {
    // Pick Date
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: primaryColor,
            onPrimary: backgroundColor,
            surface: backgroundColor,
            onSurface: primaryColor,
          ),
          dialogBackgroundColor: backgroundColor,
        ),
        child: child!,
      ),
    );

    if (pickedDate == null) return null;

    // Pick Time
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: primaryColor,
            onPrimary: backgroundColor,
            surface: backgroundColor,
            onSurface: primaryColor,
          ),
          timePickerTheme: TimePickerThemeData(
            backgroundColor: backgroundColor,
            hourMinuteTextColor: MaterialStateColor.resolveWith(
                    (states) => states.contains(MaterialState.selected)
                    ? backgroundColor
                    : primaryColor),
            hourMinuteShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: primaryColor),
            ),
            hourMinuteColor: MaterialStateColor.resolveWith(
                    (states) => states.contains(MaterialState.selected)
                    ? primaryColor
                    : Colors.transparent),
            dayPeriodTextColor: MaterialStateColor.resolveWith(
                    (states) => states.contains(MaterialState.selected)
                    ? backgroundColor
                    : primaryColor),
            dayPeriodShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: primaryColor),
            ),
            dayPeriodColor: MaterialStateColor.resolveWith(
                    (states) => states.contains(MaterialState.selected)
                    ? primaryColor
                    : Colors.transparent),
            dialHandColor: primaryColor,
            dialBackgroundColor: backgroundColor,
            entryModeIconColor: primaryColor,
          ),
        ),
        child: child!,
      ),
    );

    if (pickedTime == null) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }
}
