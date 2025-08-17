import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;

DateTime convertToSydneyTime(DateTime utcTime) {
  tz.initializeTimeZones(); // ideally move to `main()`
  final sydney = tz.getLocation('Australia/Sydney');
  return tz.TZDateTime.from(utcTime, sydney);
}

String formatSydneyTime(DateTime utcTime) {
  final sydneyTime = convertToSydneyTime(utcTime);
  return DateFormat('HH:mm:ss').format(sydneyTime);
}
