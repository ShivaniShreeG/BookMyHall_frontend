import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateTimeRangePicker {
  static void _showThemedSnackBar(BuildContext context, String message, Color oliveGreen, Color tan) {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

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
    final pickedDate = await _pickDate(
      context,
      selectedDate,
      isFrom,
      currentValue ?? selectedDate,
      oliveGreen,
      tan,
    );

    if (pickedDate == null) return null;

    final initialTime = currentValue != null
        ? TimeOfDay(hour: currentValue.hour, minute: currentValue.minute)
        : TimeOfDay.now();

    final pickedTime = await _pickTime(context, initialTime, oliveGreen, tan);

    if (pickedTime == null) return null;

    final dt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    // Check fully booked
    if (fullyBookedDates.any((d) =>
    d.year == dt.year && d.month == dt.month && d.day == dt.day)) {
      _showThemedSnackBar(context, "This date is fully booked", oliveGreen, tan);
      return null;
    }

    // Check overlapping ranges
    for (var range in bookedRanges) {
      final bookedFrom = range['from']!.toLocal();
      final bookedTo = range['to']!.toLocal();

      final pickedFrom = isFrom ? dt : currentValue ?? dt;
      final pickedTo = isFrom ? currentValue ?? dt : dt;

      if (pickedFrom.isBefore(bookedTo) && pickedTo.isAfter(bookedFrom)) {
        _showThemedSnackBar(
          context,
          "Conflict with existing booking:\n${DateFormat('dd-MM-yyyy hh:mm a').format(bookedFrom)} "
              "to ${DateFormat('dd-MM-yyyy hh:mm a').format(bookedTo)}",
          oliveGreen,
          tan,
        );
        return null;
      }
    }

    return dt;
  }

  // -------------------- Helpers --------------------
  static Future<DateTime?> _pickDate(
      BuildContext context,
      DateTime selectedDate,
      bool isFrom,
      DateTime initialDate,
      Color oliveGreen,
      Color tan,
      ) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: isFrom ? DateTime(2000) : selectedDate,
      lastDate: isFrom ? selectedDate : DateTime(2100),
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
  }

  static Future<TimeOfDay?> _pickTime(
      BuildContext context, TimeOfDay initialTime, Color oliveGreen, Color tan) {
    return showTimePicker(
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
            dialHandColor: oliveGreen,
            dialBackgroundColor: tan,
            dayPeriodColor: MaterialStateColor.resolveWith((states) {
              return states.contains(MaterialState.selected) ? oliveGreen : tan;
            }),
            dayPeriodTextColor: MaterialStateColor.resolveWith((states) {
              return states.contains(MaterialState.selected) ? tan : oliveGreen;
            }),
          ),
        ),
        child: child!,
      ),
    );
  }
}
