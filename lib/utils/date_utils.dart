// Shared formatting helpers.
// Returns a short weekday name. DateTime.weekday is 1 (Mon) to 7 (Sun).
String weekdayAbbreviation(DateTime date) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];

// Normalize to the calendar date so map lookups ignore the time of day.
DateTime calendarDate(DateTime date) => DateTime(date.year, date.month, date.day);
