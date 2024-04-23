import 'package:flutter/material.dart';
import 'Discount.dart'; // Ensure that the 'Discount' class has a 'status' and 'endTime' attribute

Widget dayBuilder(BuildContext context, DateTime day, List<Discount> activeDiscounts, bool isToday) {
  List<Widget> children = [
    Center(
      child: Text('${day.day}',
          style: TextStyle(
              color: isToday ? Colors.blue : Colors.black,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              fontSize: isToday ? 30 : 25)),
    )
  ];

  for (var discount in activeDiscounts) {
    bool isActiveOnDay = false;
    DateTime now = DateTime.now();

    // If the discount's endTime is a DateTime type, handle according to original logic
    if (discount.endTime is DateTime) {
      isActiveOnDay = day.isAfter(discount.startTime.subtract(const Duration(days: 1))) &&
          day.isBefore(discount.endTime.add(const Duration(days: 1)));
    }
    // If the discount's endTime is "subject to availability", set the activity period to end at today's end
    else if (discount.endTime.toString() == "Subject to availability") {
      // Use 23:59:59 of the current day as the end time
      DateTime endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
      isActiveOnDay = day.isAfter(discount.startTime.subtract(const Duration(days: 1))) &&
          day.isBefore(endOfDay);
    }

    // If the discount is active and applicable for the day, add a color bar
    if (discount.status && isActiveOnDay) {
      children.add(Positioned(
        bottom: (20 * children.length).toDouble(),
        left: 0,
        right: 0,
        child: Container(
          height: 10,
          color: discount.color,
        ),
      ));
    }
  }

  return Container(
    margin: const EdgeInsets.all(4.0),
    alignment: Alignment.center,
    child: Stack(children: children),
  );
}



