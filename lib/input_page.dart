import 'package:flutter/material.dart';

class InputPage extends StatefulWidget {
  @override
  _InputPageState createState() => _InputPageState();
}

class _InputPageState extends State<InputPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('输入详情'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: '商家名称'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: '折扣描述'),
            ),
            TextField(
              controller: _startTimeController,
              decoration: InputDecoration(labelText: '开始时间'),
            ),
            TextField(
              controller: _endTimeController,
              decoration: InputDecoration(labelText: '结束时间'),
            ),
          ],
        ),
      ),
    );
  }
}
