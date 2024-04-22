import 'calendar_screen.dart';
import 'package:flutter/material.dart';
import 'Discount.dart';

/*
The widget used for establish the most important function on calendar
*/
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
  activeDiscounts
      .where((discount) =>
  day.isAfter(discount.startTime.subtract(const Duration(days: 1))) &&
      day.isBefore(discount.endTime.add(const Duration(days: 1))))
      .forEach((discount) {
    children.add(Positioned(
      bottom: (20* children.length).toDouble(), // Stagger the color bars
      left: 0,
      right: 0,
      child: Container(
        height: 10,
        color: discount.color,
      ),
    ));
  });

  return Container(
    margin: const EdgeInsets.all(4.0),
    alignment: Alignment.center,
    child: Stack(children: children),
  );
}