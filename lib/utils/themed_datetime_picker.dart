import 'package:flutter/material.dart';

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
                  : primaryColor,
            ),
            hourMinuteShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: primaryColor),
            ),
            hourMinuteColor: MaterialStateColor.resolveWith(
                  (states) => states.contains(MaterialState.selected)
                  ? primaryColor
                  : Colors.transparent,
            ),
            dayPeriodTextColor: MaterialStateColor.resolveWith(
                  (states) => states.contains(MaterialState.selected)
                  ? backgroundColor
                  : primaryColor,
            ),
            dayPeriodShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: primaryColor),
            ),
            dayPeriodColor: MaterialStateColor.resolveWith(
                  (states) => states.contains(MaterialState.selected)
                  ? primaryColor
                  : Colors.transparent,
            ),
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
