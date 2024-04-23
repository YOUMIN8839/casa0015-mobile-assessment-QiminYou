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

  // Check each discount for active status and appropriate date range
  for (var discount in activeDiscounts) {
    bool isActiveOnDay = false;
    // Determine if the discount is within the date range or if it's set to "subject to availability"
    if (discount.endTime is DateTime) {
      isActiveOnDay = day.isAfter(discount.startTime.subtract(const Duration(days: 1))) &&
          day.isBefore(discount.endTime.add(const Duration(days: 1)));
    } else if (discount.endTime.toString() == "Subject to availability") {
      isActiveOnDay = day.isAfter(discount.startTime.subtract(const Duration(days: 1))) &&
          day.isBefore(DateTime.now().add(const Duration(days: 1)));
    }

    if (discount.status && isActiveOnDay) {
      children.add(Positioned(
        bottom: (20 * children.length).toDouble(), // Stagger the color bars
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
