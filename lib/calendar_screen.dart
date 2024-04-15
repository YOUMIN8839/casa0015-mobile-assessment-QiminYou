import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

void main() => runApp(MyApp());

//Discount类用于管理discount
class Discount {
  final String merchantName;
  final String description;
  final dynamic endTime;

  Discount({required this.merchantName, required this.description, required this.endTime});

  factory Discount.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    var endTimeData = data['endTime'];
    dynamic endTime;
    if (endTimeData is Timestamp) {
      endTime = endTimeData.toDate();
    } else if (endTimeData is String) {
      endTime = endTimeData;
    }
    return Discount(
      merchantName: data['merchantName'],
      description: data['description'],
      endTime: endTime,
    );
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CalendarScreen(),
    );
  }
}

class CalendarScreen extends StatefulWidget {
  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // 示例：特定日期
  final List<DateTime> _eventDays = [
    DateTime.now().subtract(Duration(days: 2)),
    DateTime.now().add(Duration(days: 4)),
  ];

  Stream<List<Discount>> streamDiscounts() {
    return FirebaseFirestore.instance
        .collection('discounts')
        .orderBy('endTime', descending: false)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => Discount.fromFirestore(doc)).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Discount Calendar'),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2010, 10, 16),
            lastDay: DateTime.utc(2030, 3, 14),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                for (DateTime eventDay in _eventDays) {
                  if (isSameDay(day, eventDay)) {
                    // 为有事件的日子添加底部线条
                    return Container(
                      margin: const EdgeInsets.all(4.0),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.lightBlue[100],
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Text('${day.day}'),
                          ),
                          Positioned(
                            bottom: 1,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 4,
                              color: Colors.deepOrange,
                            ),
                          )
                        ],
                      ),
                    );
                  }
                }
                // 没有事件的日子保持默认样式
                return null;
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Discount>>(
              stream: streamDiscounts(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                List<Discount> allDiscounts = snapshot.data!;
                List<Discount> activeDiscounts = [];
                List<Discount> expiredDiscounts = [];
                for (Discount discount in allDiscounts) {
                  if (discount.endTime is DateTime && discount.endTime.isBefore(DateTime.now())) {
                    expiredDiscounts.add(discount);
                  } else {
                    activeDiscounts.add(discount);
                  }
                }
                return Column(
                  children: [
                    Text(
                       '有效折扣',
                        style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      flex: 2,
                      child: ListView.builder(
                        itemCount: activeDiscounts.length,
                        itemBuilder: (context, index) {
                          Discount discount = activeDiscounts[index];
                          return ListTile(
                            title: Text(discount.merchantName),
                            subtitle: Text(discount.description),
                            trailing: Text(
                              discount.endTime is DateTime ? DateFormat('yyyy-MM-dd').format(discount.endTime) : discount.endTime.toString(),
                            ),
                          );
                        },
                      ),
                    ),
                    Text(
                      '过期折扣',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: expiredDiscounts.length,
                        itemBuilder: (context, index) {
                          Discount discount = expiredDiscounts[index];
                          return ListTile(
                            title: Text(
                              discount.merchantName,
                              style: TextStyle(color: Colors.grey),
                            ),
                            subtitle: Text(
                              discount.description,
                              style: TextStyle(color: Colors.grey),
                            ),
                            trailing: Text(
                              DateFormat('yyyy-MM-dd').format(discount.endTime),
                              style: TextStyle(color: Colors.grey),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

