import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../public/config.dart';
import 'booking_page.dart';
import 'package:intl/intl.dart';
import 'update_page.dart'; // for update mode
import 'cancel_page.dart';

enum CalendarMode { book, cancel, update }

class CalendarPage extends StatefulWidget {
  final CalendarMode mode;

  const CalendarPage({super.key, required this.mode});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  Map<String, dynamic> calendarData = {};
  DateTime focusedDay = DateTime.now();
  DateTime? selectedDay;
  bool _loading = true;

  final Color oliveGreen = const Color(0xFF5B6547);
  final Color lightTan = const Color(0xFFF3E2CB);
  final Color pageBackground = const Color(0xFFECE5D8);

  @override
  void initState() {
    super.initState();
    _loadCalendar();
  }

  Future<void> _loadCalendar() async {
    final prefs = await SharedPreferences.getInstance();
    final hallId = prefs.getInt('hallId');

    if (hallId != null) {
      await _fetchCalendar(hallId);
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchCalendar(int hallId) async {
    try {
      final url = Uri.parse('$baseUrl/calendar/$hallId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          calendarData = jsonDecode(response.body);
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Color _getDayColor(DateTime day) {
    final dateStr = day.toIso8601String().split('T')[0];
    if (!calendarData.containsKey(dateStr)) {
      return widget.mode == CalendarMode.book ? Colors.green : Colors.transparent;
    }

    final entry = calendarData[dateStr];

    switch (widget.mode) {
      case CalendarMode.book:
        if (entry['booked'].isNotEmpty) return Colors.red;
        if (entry['peakHours'].isNotEmpty) return Colors.orange;
        return Colors.green;
      case CalendarMode.cancel:
      case CalendarMode.update:
        return entry['booked'].isNotEmpty ? Colors.red : Colors.transparent;
    }
  }

  void _onDaySelected(DateTime selected, DateTime focused) async {
    final dateStr = selected.toIso8601String().split('T')[0];
    final entry = calendarData[dateStr];

    if (widget.mode == CalendarMode.book) {
      if (entry != null && entry['booked'].isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("This date is already booked!")),
        );
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BookingPage(selectedDate: selected)),
      );

    } else {
      // Cancel or Update mode
      final prefs = await SharedPreferences.getInstance();
      final hallId = prefs.getInt('hallId');
      if (hallId == null) return;

      try {
        final url = Uri.parse('$baseUrl/bookings/$hallId/date/$dateStr');
        final response = await http.get(url);

        if (response.statusCode != 200) return; // no booking
        final bookingDetails = jsonDecode(response.body);

        showDialog(
          context: context,
          builder: (_) {
            final fromUtc = DateTime.parse(bookingDetails['alloted_datetime_from']).toLocal();
            final toUtc = DateTime.parse(bookingDetails['alloted_datetime_to']).toLocal();

            final fromFormatted = DateFormat('dd-MM-yyyy hh:mm a').format(fromUtc);
            final toFormatted = DateFormat('dd-MM-yyyy hh:mm a').format(toUtc);
            final selectedDateFormatted = DateFormat('dd-MM-yyyy').format(selected);

            return Dialog(
              backgroundColor: lightTan,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Booking Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: oliveGreen)),
                    const SizedBox(height: 12),
                    _detailRow("Event Date", selectedDateFormatted),
                    _detailRow("Name", bookingDetails['name']),
                    _detailRow("Event Type", bookingDetails['event_type'] ?? 'N/A'),
                    _detailRow("From", fromFormatted),
                    _detailRow("To", toFormatted),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(foregroundColor: oliveGreen),
                          child: const Text("Close"),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context); // Close dialog first

                            final prefs = await SharedPreferences.getInstance();
                            final userId = prefs.getInt('userId');
                            if (userId == null) return;

                            bool actionSuccess = false;

                            if (widget.mode == CalendarMode.cancel) {
                              // Await result from CancelBookingPage
                              actionSuccess = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CancelBookingPage(
                                    hallId: bookingDetails['hall_id'],
                                    bookingId: bookingDetails['booking_id'],
                                    userId: userId,
                                  ),
                                ),
                              ) ?? false;
                            } else if (widget.mode == CalendarMode.update) {
                              // Await result from UpdateBookingPage
                              actionSuccess = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UpdateBookingPage(
                                    hallId: bookingDetails['hall_id'],
                                    bookingId: bookingDetails['booking_id'],
                                    userId: userId,
                                    bookingDetails: bookingDetails,
                                  ),
                                ),
                              ) ?? false;
                            }

                            if (actionSuccess) {
                              // Refresh calendar after successful cancel/update
                              final hallId = prefs.getInt('hallId');
                              if (hallId != null) await _fetchCalendar(hallId);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: oliveGreen,
                            foregroundColor: const Color(0xFFD8C9A9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(widget.mode == CalendarMode.cancel ? "Cancel" : "Update"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      } catch (e) {
        // ignore errors
      }
    }

    setState(() {
      selectedDay = selected;
      focusedDay = focused;
    });
  }


  Widget _buildDayCell(DateTime day, {bool isSelected = false, bool isToday = false}) {
    final dayColor = _getDayColor(day);

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dayColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border: isSelected ? Border.all(color: oliveGreen, width: 2) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: oliveGreen,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLegend() {
    if (widget.mode == CalendarMode.book) {
      return _legendCard([
        _legendItem(Colors.green.shade300, "Available"),
        _legendItem(Colors.red.shade300, "Booked"),
        _legendItem(Colors.orange.shade300, "Peak hour"),
      ]);
    } else {
      return _legendCard([
        _legendItem(Colors.red.shade300, "Booked"),
      ]);
    }
  }

  Widget _legendCard(List<Widget> items) {
    return Card(
      color: lightTan,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: items
              .map((widget) => Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: widget))
              .toList(),
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 16, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: oliveGreen)),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label: ",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: oliveGreen,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: oliveGreen),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        title: Text(
          widget.mode == CalendarMode.book
              ? "Booking"
              : widget.mode == CalendarMode.cancel
              ? "Cancel Booking"
              : "Update Booking",
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD8C9A9)),
        ),
        backgroundColor: oliveGreen,
        centerTitle: true,
        elevation: 4,
        iconTheme: const IconThemeData(color: Color(0xFFD8C9A9)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF5B6547)))
          : Column(
        children: [
          const SizedBox(height: 20),
          Card(
            color: lightTan,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TableCalendar(
                firstDay: DateTime.now(),
                lastDay: DateTime.utc(2100, 12, 31),
                focusedDay: focusedDay,
                selectedDayPredicate: (day) => isSameDay(selectedDay, day),
                onDaySelected: _onDaySelected,
                onPageChanged: (focused) => setState(() => focusedDay = focused),
                calendarFormat: CalendarFormat.month,
                headerStyle: const HeaderStyle(
                  titleCentered: true,
                  formatButtonVisible: false,
                  titleTextStyle: TextStyle(color: Color(0xFF5B6547), fontWeight: FontWeight.bold, fontSize: 18),
                  leftChevronIcon: Icon(Icons.chevron_left, color: Color(0xFF5B6547)),
                  rightChevronIcon: Icon(Icons.chevron_right, color: Color(0xFF5B6547)),
                ),
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: Color(0xFF5B6547), fontWeight: FontWeight.bold),
                  weekendStyle: TextStyle(color: Color(0xFF5B6547), fontWeight: FontWeight.bold),
                ),
                enabledDayPredicate: (day) {
                  if (widget.mode == CalendarMode.book) return true;
                  final dateStr = day.toIso8601String().split('T')[0];
                  final entry = calendarData[dateStr];
                  return entry != null && entry['booked'].isNotEmpty;
                },
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    final isSelected = isSameDay(day, selectedDay);
                    return _buildDayCell(day, isSelected: isSelected);
                  },
                  todayBuilder: (context, day, focusedDay) {
                    final isSelected = isSameDay(day, selectedDay);
                    return _buildDayCell(day, isSelected: isSelected, isToday: true);
                  },
                  selectedBuilder: (context, day, focusedDay) {
                    return _buildDayCell(day, isSelected: true);
                  },
                  outsideBuilder: (context, day, focusedDay) => Container(
                    margin: const EdgeInsets.all(4),
                    alignment: Alignment.center,
                    child: Text('${day.day}', style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
                  ),
                  disabledBuilder: (context, day, focusedDay) => Container(
                    margin: const EdgeInsets.all(4),
                    alignment: Alignment.center,
                    child: Text('${day.day}', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildLegend(),
        ],
      ),
    );
  }
}
