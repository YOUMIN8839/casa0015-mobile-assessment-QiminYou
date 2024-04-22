import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

void main() => runApp(MyApp());

//Discount class to manage discount from firebase


class Discount {
  final String merchantName;
  final String productName;
  final String description;
  final dynamic endTime;
  final DateTime startTime;
  final String quantity;
  final Color color; // 确保这是一个Color对象

  Discount({
    required this.merchantName,
    required this.productName,
    required this.description,
    required this.endTime,
    required this.startTime,
    required this.quantity,
    required this.color, // 修改构造器要求颜色作为参数
  });

  // 生成随机颜色的静态方法
  static Color _getRandomColor() {
    Random random = Random();
    return Color.fromRGBO(
      random.nextInt(256),
      random.nextInt(256),
      random.nextInt(256),
      1, // alpha值设置为1表示不透明
    );
  }

  // 从 Firestore 解析颜色
  static Color _parseColor(dynamic colorData) {
    if (colorData is String) {
      // 假设颜色存储为十六进制字符串
      return Color(int.parse(colorData, radix: 16) + 0xFF000000);
    }
    return _getRandomColor(); // 如果没有有效的颜色数据或格式不正确，生成随机颜色
  }

  factory Discount.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // 解析 endTime 字段
    dynamic parsedEndTime;
    var endTimeData = data['endTime'];
    if (endTimeData is Timestamp) {
      parsedEndTime = endTimeData.toDate();
    } else if (endTimeData is String) {
      parsedEndTime = endTimeData;
    }

    // 解析 startTime 字段
    DateTime parsedStartTime;
    var startTimeData = data['startTime'];
    if (startTimeData is Timestamp) {
      parsedStartTime = startTimeData.toDate();
    } else {
      parsedStartTime = DateTime.now(); // 或根据需要提供默认值
    }

    Color parsedColor = data['color'] != null ? _parseColor(data['color']) : _getRandomColor();

    return Discount(
      merchantName: data['merchantName'] ?? 'Unknown',
      productName: data['productName'] ?? 'Unknown',
      description: data['description'] ?? 'No description provided',
      endTime: parsedEndTime ?? 'No end time provided',
      startTime: parsedStartTime,
      quantity: data['quantity'] ?? 'Unavailable',
      color: parsedColor, // 使用解析或生成的颜色
    );
  }
}



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

  // 示例：特定日期
  final List<DateTime> _eventDays = [
    DateTime.now().subtract(Duration(days: 2)),
    DateTime.now().add(Duration(days: 4)),
  ];


  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      // appBar: AppBar(
      //   title: Text('Discount Calendar'),
      // ),
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
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
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
                                    discount.endTime is DateTime
                                        ? DateFormat('yyyy-MM-dd')
                                            .format(discount.endTime)
                                        : discount.endTime.toString(),
                                  ),
                                );
                              },
                            ),
                          ),
                          Text('Expired Discounts',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: ListView.builder(
                              itemCount: expiredDiscounts.length,
                              itemBuilder: (context, index) {
                                Discount discount = expiredDiscounts[index];
                                return ListTile(
                                  title: Text(discount.merchantName,
                                      style: TextStyle(color: Colors.grey)),
                                  subtitle: Text(discount.description,
                                      style: TextStyle(color: Colors.grey)),
                                  trailing: Text(
                                    DateFormat('yyyy-MM-dd')
                                        .format(discount.endTime),
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  )
                : Center(
                    // 如果用户未登录，显示一张图片
                    child: Image.asset('assets/images/calendar_not_login.png'),
                  ),
          ),
        ],
      ),
    );
  }
}


