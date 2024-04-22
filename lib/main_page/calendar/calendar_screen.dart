import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'daybuilder.dart';
import 'Discount.dart';
import '/Pages/discount_detail_page/discount_detail_page.dart';

//strange bug
bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

void main() => runApp(MyApp());

//Discount class to manage discount from firebase



Stream<List<Discount>> streamDiscounts() {
  User? currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    throw FlutterError('User not logged in');
  }
  return FirebaseFirestore.instance
      .collection('users')
      .doc(currentUser.uid)
      .collection('discounts')
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => Discount.fromFirestore(doc)).toList());
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


  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: Column(
        children: [
          user != null
              ? StreamBuilder<List<Discount>>(
            stream: streamDiscounts(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }
              List<Discount> allDiscounts = snapshot.data!;
              List<Discount> activeDiscounts = allDiscounts
                  .where((discount) =>
              discount.endTime is DateTime &&
                  discount.endTime.isAfter(DateTime.now()))
                  .toList();

              DateTime now = DateTime.now();
              DateTime startOfCalendar = DateTime(now.year, now.month,
                  now.day - 21); // Start from 21 days before today
              DateTime endOfCalendar = DateTime(now.year, now.month,
                  now.day + 42); // Span of three weeks after today

              return Column(
                children: [
                  TableCalendar(
                    firstDay: startOfCalendar,
                    lastDay: endOfCalendar,
                    rowHeight: 200,
                    focusedDay: _focusedDay,
                    calendarFormat: CalendarFormat.week,
                    onPageChanged: (focusedDay) {
                      setState(() {
                        _focusedDay = focusedDay; // Update focused day
                      });
                    },
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, day, focusedDay) {
                        return dayBuilder(context, day, activeDiscounts, false);
                      },
                      todayBuilder: (context, day, focusedDay) {
                        return dayBuilder(context, day, activeDiscounts, true);
                      },
                    ),

                  ),
                  SizedBox(height: 20), // Adding a space between the calendar and the next content
                ],
              );
            },
          )
              : Padding(// default base calendar
            padding: const EdgeInsets.symmetric(vertical: 20.0), // Space before and after the default display
            child: TableCalendar(
              firstDay: DateTime.utc(2010, 10, 16),
              lastDay: DateTime.utc(2030, 3, 14),
              focusedDay: _focusedDay,
              calendarFormat: CalendarFormat.week,
            ),
          ),
          Expanded(
            child: user != null
                ? StreamBuilder<List<Discount>>(
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
                        if (discount.endTime is DateTime &&
                            discount.endTime.isBefore(DateTime.now())) {
                          expiredDiscounts.add(discount);
                        } else {
                          activeDiscounts.add(discount);
                        }
                      }

                      return Column(
                        children: [
                          Text('Available Discounts',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Expanded(
                            flex: 2,
                            child: ListView.builder(
                              itemCount: activeDiscounts.length,
                              itemBuilder: (context, index) {
                                Discount discount = activeDiscounts[index];
                                return ListTile(
                                  title: Text(discount.merchantName),
                                  subtitle: Text('${discount.description}\nProduct: ${discount.productName}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        discount.endTime is DateTime
                                            ? DateFormat('yyyy-MM-dd').format(discount.endTime)
                                            : discount.endTime.toString(),
                                      ),
                                      SizedBox(width: 10), // Add space between text and circle
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: discount.color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),

                                    ],
                                  ),
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true, // 设置为true，使底部表单可滚动
                                      builder: (BuildContext context) {
                                        return FractionallySizedBox(
                                          heightFactor: 0.8, // 底部窗口高度占屏幕高度的比例，可根据需求调整
                                          child: DiscountDetailPage(discount: discount), // 下面定义这个新的Widget类
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          Text('Expired Discounts',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: ListView.builder(
                              itemCount: expiredDiscounts.length,
                              itemBuilder: (context, index) {
                                Discount discount = expiredDiscounts[index];
                                return ListTile(
                                  title: Text(discount.merchantName, style: TextStyle(color: Colors.grey)),
                                  subtitle: Text('${discount.description}\nProduct: ${discount.productName}',
                                      style: TextStyle(color: Colors.grey)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        DateFormat('yyyy-MM-dd').format(discount.endTime),
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                      SizedBox(width: 10), // Space between text and circle
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: discount.color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );


                    },
                  )
                : Center(//display default picture while leading user to login
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Image.asset('assets/images/calendar_not_login.png'),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/login');
                          },
                          child: Text('Go to Login'),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
