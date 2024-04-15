import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';


class ChoicePage extends StatefulWidget {
  @override
  _ChoicePageState createState() => _ChoicePageState();
}

class _ChoicePageState extends State<ChoicePage> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;

  @override
  void initState() {
    super.initState();
    availableCameras().then((availableCameras) {
      _cameras = availableCameras;
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.medium,
        );
        _cameraController!.initialize().then((_) {
          if (!mounted) {
            return;
          }
          setState(() {});
        });
      }
    }).catchError((e) {
      // Handle errors here, such as displaying an error message
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('选择操作'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              icon: Icon(Icons.camera_alt),
              onPressed: () {
                // 确保摄像头可用
                if (_cameraController != null && _cameraController!.value.isInitialized) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CameraPage(controller: _cameraController!),
                    ),
                  );
                } else {
                  // 提示用户摄像头不可用或未授权
                }
              },
              iconSize: 50.0,
            ),
            SizedBox(height: 20),
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => InputPage()),
                );
              },
              iconSize: 50.0,
            ),
          ],
        ),
      ),
    );
  }
}

class CameraPage extends StatelessWidget {
  final CameraController controller;

  CameraPage({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('OCR'),
      ),
      body: CameraPreview(this.controller), // 显示相机预览
    );
  }
}

 class InputPage extends StatefulWidget {
   @override
   _InputPageState createState() => _InputPageState();
 }

class _InputPageState extends State<InputPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime? _startTime;  // 使用 DateTime 来存储日期
  dynamic _endTime = 'Subject to availability';
  String _selectedQuantity = '0';  // 默认选中的数量

  // 数量选项
  final List<String> _quantityOptions = [
    '0','1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '余量充足'
  ];
  final String subjectToAvailability = 'Subject to availability';

  // 更新选中的数量
  void _updateSelectedQuantity(String? newQuantity) {
    if (newQuantity != null) {
      setState(() {
        _selectedQuantity = newQuantity;
      });
    }
  }

  Future<void> _uploadDiscount() async {
    if (_nameController.text.isEmpty || _descriptionController.text.isEmpty || _selectedQuantity == '0') {
      String missingInput = '所有字段';
      if (_nameController.text.isEmpty) {
        missingInput = '商家名称';
      } else if (_descriptionController.text.isEmpty) {
        missingInput = '折扣描述';
      } else if (_selectedQuantity == '0') {
        missingInput = '剩余个数';
      }
      _showInputAlert(missingInput);
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('discounts').add({
        'merchantName': _nameController.text,
        'description': _descriptionController.text,
        'startTime': _startTime != null ? Timestamp.fromDate(_startTime!) : null,
        'endTime': _endTime is DateTime ? Timestamp.fromDate(_endTime as DateTime) : _endTime,
        'quantity': _selectedQuantity,
      });
      _showUploadSuccess(context);
      Navigator.pop(context);  // 导航回主页
      Navigator.pop(context);
    } catch (e) {
      _showUploadFailure(context);
    }
  }

  void _showUploadSuccess(BuildContext context) {
    final snackBar = SnackBar(
      content: Text('折扣已上传'),
      duration: Duration(seconds: 2),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void _showUploadFailure(BuildContext context) {
    final snackBar = SnackBar(
      content: Text('上传失败，请重试'),
      duration: Duration(seconds: 2),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  // 日期选择器函数
  Future<void> _selectDate(BuildContext context, bool isStartTime) async {
    // 弹出对话框让用户选择使用日期还是“Subject to availability”
    final bool useAvailability = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('选择结束时间'),
        content: Text('您希望设置一个具体日期还是使用“Subject to availability”？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('具体日期'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Subject to availability'),
          ),
        ],
      ),
    ) ?? false;

    if (useAvailability) {
      setState(() {
        _endTime = 'Subject to availability';
      });
      return;
    }

    // 如果用户选择具体日期，则展示日期选择器
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _showInputAlert(String missingInput) {
    showDialog(
      context: context,
      barrierDismissible: false,  // 用户必须点击按钮才能关闭弹窗
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('输入缺失'),
          content: Text('请输入$missingInput。'),
          actions: <Widget>[
            TextButton(
              child: Text('确定'),
              onPressed: () {
                Navigator.of(context).pop(); // 关闭弹窗
              },
            ),
          ],
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('输入折扣'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: <Widget>[
            TextField(controller: _nameController, decoration: InputDecoration(labelText: '商家名称')),
            TextField(controller: _descriptionController, decoration: InputDecoration(labelText: '折扣描述')),
            ListTile(
              title: Text('开始时间: ${_startTime != null ? DateFormat('yyyy-MM-dd').format(_startTime!) : '未选择'}'),
              trailing: Icon(Icons.calendar_today),
              onTap: () => _selectDate(context, true),
            ),
            ListTile(
              title: Text('结束时间: ' + (_endTime is DateTime ? DateFormat('yyyy-MM-dd').format(_endTime) : _endTime)),
              trailing: Icon(Icons.calendar_today),
              onTap: () => _selectDate(context, false),
            ),
            DropdownButtonFormField(
              value: _selectedQuantity,
              items: _quantityOptions.map((String quantity) {
                return DropdownMenuItem(
                  value: quantity,
                  child: Text(quantity),
                );
              }).toList(),
              onChanged: _updateSelectedQuantity,
              decoration: InputDecoration(
                labelText: '剩余个数',
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadDiscount,
        tooltip: '上传折扣',
        child: Icon(Icons.upload),
      ),
    );
  }
}

