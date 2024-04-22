import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Discount {
  final String documentId;  // 新增属性
  final String merchantName;
  final String productName;
  final String description;
  final dynamic endTime;
  final DateTime startTime;
  final String quantity;
  final Color color;
  final bool status;

  Discount({
    required this.documentId,  // 修改构造器来接受 documentId 参数
    required this.merchantName,
    required this.productName,
    required this.description,
    required this.endTime,
    required this.startTime,
    required this.quantity,
    required this.color,
    required this.status,
  });

  static Color _getRandomColor() {
    Random random = Random();
    return Color.fromRGBO(
      random.nextInt(256),
      random.nextInt(256),
      random.nextInt(256),
      1,
    );
  }

  static Color _parseColor(dynamic colorData) {
    if (colorData is String) {
      return Color(int.parse(colorData, radix: 16) + 0xFF000000);
    }
    return _getRandomColor();
  }

  factory Discount.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    dynamic parsedEndTime;
    var endTimeData = data['endTime'];
    if (endTimeData is Timestamp) {
      parsedEndTime = endTimeData.toDate();
    } else if (endTimeData is String) {
      parsedEndTime = endTimeData;
    }

    DateTime parsedStartTime;
    var startTimeData = data['startTime'];
    if (startTimeData is Timestamp) {
      parsedStartTime = startTimeData.toDate();
    } else {
      parsedStartTime = DateTime.now();  // 提供默认值
    }

    Color parsedColor =
    data['color'] != null ? _parseColor(data['color']) : _getRandomColor();

    bool parsedStatus = data['status'] ?? false;

    return Discount(
      documentId: doc.id,  // 使用文档 ID
      merchantName: data['merchantName'] ?? 'Unknown',
      productName: data['productName'] ?? 'Unknown',
      description: data['description'] ?? 'No description provided',
      endTime: parsedEndTime ?? 'No end time provided',
      startTime: parsedStartTime,
      quantity: data['quantity'] ?? 'Unavailable',
      color: parsedColor,
      status: parsedStatus,
    );
  }
}
