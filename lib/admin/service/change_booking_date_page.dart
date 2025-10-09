import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../public/config.dart';
import '../../utils/themed_datetime_picker.dart';
import '../../utils/hall_header.dart';
import 'pdf/change_date_pdf.dart';


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
  Map<String, dynamic>? _hallDetails;

  DateTime? functionDate;
  DateTime? allotedFrom;
  DateTime? allotedTo;

  DateTime? originalFunctionDate;
  DateTime? originalAllotedFrom;
  DateTime? originalAllotedTo;

  List<Map<String, DateTime>> otherBookedRanges = [];
  List<DateTime> fullyBookedDates = [];
  List<DateTime> otherFunctionDates = [];

  final Color primaryColor = const Color(0xFF5B6547);
  final Color backgroundColor = const Color(0xFFECE5D8);
  final Color cardColor = const Color(0xFFD8C9A9);

  @override
  void initState() {
    super.initState();
    _loadBooking();
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

  Future<void> _loadBooking() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/bookings/${widget.hallId}/${widget.bookingId}'),
      );

      if (res.statusCode == 200) {
        booking = jsonDecode(res.body);

        functionDate = DateTime.parse(booking!['function_date']);
        allotedFrom =
            DateTime.parse(booking!['alloted_datetime_from']);
        allotedTo = DateTime.parse(booking!['alloted_datetime_to']);

        originalFunctionDate = functionDate;
        originalAllotedFrom = allotedFrom;
        originalAllotedTo = allotedTo;

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

  bool _saved = false; // add at state level
  Map<String, dynamic>? _updatedBooking;

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
    if (functionDate!.isBefore(allotedFrom!) || functionDate!.isAfter(allotedTo!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Function date must be on or between allotted from–to")),
      );
      return;
    }
    if (_checkConflict(allotedFrom!, allotedTo!)) return;

    setState(() => _loading = true);

    try {
      final res = await http.patch(
        Uri.parse('$baseUrl/bookings/${widget.hallId}/${widget.bookingId}/time'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'function_date': DateFormat('yyyy-MM-dd').format(functionDate!),
          'alloted_datetime_from': allotedFrom!.toIso8601String(),
          'alloted_datetime_to': allotedTo!.toIso8601String(),
        }),
      );

      if (res.statusCode == 200) {
        _updatedBooking = jsonDecode(res.body); // store updated info
        setState(() => _saved = true); // show PDF button

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Booking date/time updated successfully")),
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
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: child ?? Text(
                value ?? "—",
                style: TextStyle(color: primaryColor),
                textAlign: TextAlign.center,
              ),
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

  // Widget _sectionHeader(String title) {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(vertical: 16.0),
  //     child: Center(
  //       child: Text(
  //         title,
  //         style: TextStyle(
  //             fontWeight: FontWeight.bold, fontSize: 18, color: primaryColor),
  //       ),
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          Navigator.pop(context, true); // send refresh signal
          return false; // prevent default pop (we already did it)
        },child:Scaffold(
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
            if (_hallDetails != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: HallHeader(
                  hallDetails: _hallDetails!,
                  oliveGreen: primaryColor,
                  tan: cardColor,
                ),
              ),

            _sectionContainer(
              "CHANGE DATE/TIME",
              [
                // Function Date
                _plainRowWithTanValue(
                  "FUNCTION DATE",
                  child: InkWell(
                    onTap: _saved ? null : _pickFunctionDate, // disable after save
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        functionDate != null
                            ? DateFormat('dd-MM-yyyy').format(functionDate!)
                            : "Select Date",
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),

// Alloted From
                _plainRowWithTanValue(
                  "ALLOTED FROM",
                  child: InkWell(
                    onTap: _saved ? null : _pickAllotedFrom, // disable after save
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          allotedFrom != null
                              ? DateFormat('dd-MM-yyyy').format(allotedFrom!)
                              : "Select Date",
                          style: TextStyle(
                              color: primaryColor, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          allotedFrom != null
                              ? DateFormat('hh:mm a').format(allotedFrom!)
                              : "Select Time",
                          style: TextStyle(color: primaryColor),
                        ),
                      ],
                    ),
                  ),
                ),

// Alloted To
                _plainRowWithTanValue(
                  "ALLOTED TO",
                  child: InkWell(
                    onTap: _saved ? null : _pickAllotedTo, // disable after save
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          allotedTo != null
                              ? DateFormat('dd-MM-yyyy').format(allotedTo!)
                              : "Select Date",
                          style: TextStyle(
                              color: primaryColor, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          allotedTo != null
                              ? DateFormat('hh:mm a').format(allotedTo!)
                              : "Select Time",
                          style: TextStyle(color: primaryColor),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                if (!_saved)
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.5, // 50% of screen width
                    child: ElevatedButton(
                      onPressed: _submitChange,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Save Changes",
                        style: TextStyle(fontSize: 15, color: Color(0xFFD8C7A5)),
                      ),
                    ),
                  ),
              ],
            ),


            const SizedBox(height: 20),
            _sectionContainer(
              "BOOKING DETAILS",
              [
                _plainRowWithTanValue(
                  "BOOKING ID",
                  value: booking!['booking_id'].toString(),
                ),
                _plainRowWithTanValue(
                  "NAME",
                  value: booking!['name'],
                ),
                _plainRowWithTanValue(
                  "PHONE",
                  value: booking!['phone'],
                ),
                if (booking!['email'] != null)
                  _plainRowWithTanValue(
                    "EMAIL",
                    value: booking!['email'],
                  ),
                if (booking!['address'] != null)
                  _plainRowWithTanValue(
                    "ADDRESS",
                    value: booking!['address'],
                  ),
                _plainRowWithTanValue(
                  "EVENT",
                  value: booking!['event_type'] ?? "N/A",
                ),
                _plainRowWithTanValue(
                  "EVENT DATE",
                  value: functionDate != null
                      ? DateFormat('yyyy-MM-dd').format(originalFunctionDate!)
                      : "—",
                ),
                _plainRowWithTanValue(
                  "Alloted From",
                  child: originalAllotedFrom!= null
                      ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('dd-MM-yyyy').format(originalAllotedFrom!),
                        style: TextStyle(color: primaryColor),
                      ),
                      Text(
                        DateFormat('hh:mm a').format(originalAllotedFrom!),
                        style: TextStyle(color: primaryColor),
                      ),
                    ],
                  )
                      : Text("—", style: TextStyle(color: primaryColor)),
                ),
                _plainRowWithTanValue(
                  "Alloted To",
                  child: originalAllotedTo!= null
                      ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('dd-MM-yyyy').format(originalAllotedTo!),
                        style: TextStyle(color: primaryColor),
                      ),
                      Text(
                        DateFormat('hh:mm a').format(originalAllotedTo!),
                        style: TextStyle(color: primaryColor),
                      ),
                    ],
                  )
                      : Text("—", style: TextStyle(color: primaryColor)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_saved && booking != null && _hallDetails != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChangeDatePdfPage(
                          bookingData: booking!,
                          hallDetails: _hallDetails!,
                          updatedFunctionDate: functionDate!,
                          updatedFrom: allotedFrom!,
                          updatedTo: allotedTo!,
                          oliveGreen: primaryColor,
                          tan: cardColor,
                          beigeBackground: backgroundColor,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text("Generate & View PDF"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: cardColor,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            const SizedBox(height: 60)
          ],
        ),
      ),
    ),
    );
  }
}

