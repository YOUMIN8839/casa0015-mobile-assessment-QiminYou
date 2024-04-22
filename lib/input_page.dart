import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_cropper/image_cropper.dart';




import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';


import 'dart:typed_data';
import 'package:flutter/services.dart';


//try to solve the format problem
class ImageProcessor {
  static const MethodChannel _channel = MethodChannel('com.yourcompany.imageprocessing');

  Future<void> sendImageToNative(CameraImage image) async {
    List<int> strides = Int32List(image.planes.length * 2);
    int index = 0;
    List<Uint8List> data = image.planes.map((plane) {
      strides[index] = plane.bytesPerRow;
      index++;
      strides[index] = plane.bytesPerPixel!;
      index++;
      return plane.bytes;
    }).toList();

    try {
      final Uint8List? result = await _channel.invokeMethod('processImage', {
        'data': data,
        'height': image.height,
        'width': image.width,
        'strides': strides,
      });
      // Handle the result if needed
    } catch (e) {
      print("Failed to send image to native: $e");
    }
  }
}


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
    // 初始化可用相机列表
    _initializeCameras();
  }

  Future<void> _initializeCameras() async {
    _cameras = await availableCameras();
  }

  Future<void> _openCamera() async {
    // Ensure everytime establish a new CameraController
    //thus fix the bug that a camera can not be open twice
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

    if (_cameras != null && _cameras!.isNotEmpty) {
      _cameraController = CameraController(
        _cameras!.first,
        ResolutionPreset.veryHigh,
      );
      _cameraController!.initialize().then((_) {
        if (!mounted) {
          return;
        }
        // 在初始化后推送到新页面
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CameraPage(controller: _cameraController!),
          ),
        ).then((_) {
          // 当从CameraPage返回时，释放相机资源
          _cameraController?.dispose();
          _cameraController = null; // Reset the controller after the camera page is popped
        });
      }).catchError((e) {
        print("Error initializing camera: $e");
      });
    }
  }

  // @override
  // void dispose() {
  //   // 在这里不需要dispose，因为已经在_openCamera中处理了
  //   super.dispose();
  // }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Choose a Method'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              icon: Icon(Icons.camera_alt),
              onPressed: _openCamera,
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

class CameraPage extends StatefulWidget {
  final CameraController controller;

  CameraPage({required this.controller});

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  String _text = '';
  bool _isLoading = false; // 添加一个状态指示是否正在处理


  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    if (!widget.controller.value.isInitialized) {
      await widget.controller.initialize().catchError((e) {
        print('Camera initialization error: $e');
      });
    }
  }

  Future<void> takePicture() async {
    try {
      final XFile file = await widget.controller.takePicture();
      // 显示图片预览并允许用户裁剪图片
      final croppedFile = await ImageCropper().cropImage(
          sourcePath: file.path,
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9
          ],
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Edit Photo',
              toolbarColor: Colors.blue,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false,
            ),
            IOSUiSettings(
              minimumAspectRatio: 1.0,
            ),
          ]
      );

      if (croppedFile != null) {
        // 如果用户编辑了图片，继续OCR流程
        performOCR(File(croppedFile.path));
      } else {
        // 用户取消了编辑或编辑失败，可以显示一条消息或者日志
        print('Image cropping cancelled or failed.');
      }
    } catch (e) {
      print(e);
      safeSetState(() {
        _text = 'Error: $e';
      });
    }
  }


  Future<void> performOCR(File imageFile) async {
    safeSetState(() {
      _isLoading = true;
    });

    final inputImage = InputImage.fromFile(imageFile);
    final textRecognizer = GoogleMlKit.vision.textRecognizer();

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(
          inputImage);
      final String fullOcrText = recognizedText.text;
      print("OCR Result: $fullOcrText"); // 打印完整的OCR结果

      String merchantName = '';
      String startDate = '';
      String endDate = '';
      String productName = '';
      String discountDescription = '';

      // 检测商家名称
      if (fullOcrText.contains('Clubcard')) {
        merchantName = 'Tesco';
      }

      // 使用正则表达式匹配开始日期和结束日期
      final RegExp datePattern = RegExp(
          r'from\s+(\d{2}/\d{2}/\d{4})\s+until\s+(\d{2}/\d{2}/\d{4})');
      final RegExpMatch? datesMatch = datePattern.firstMatch(fullOcrText);
      if (datesMatch != null) {
        startDate = datesMatch.group(1)!; // 获取开始日期
        endDate = datesMatch.group(2)!; // 获取结束日期
      }

      // 正则表达式匹配从文本开始到 "Write a review" 之前的所有文字
      RegExp namePattern = RegExp(
          r'^([\s\S]*?)\s(?=.*Write a review)', multiLine: true);
      RegExpMatch? nameMatch = namePattern.firstMatch(fullOcrText);
      if (nameMatch != null) {
        // 提取匹配的文本
        String matchedText = nameMatch.group(1)!.trim();

        // 将匹配到的多行文本合并为一行
        String oneLineText = matchedText.replaceAll('\n', ' ');

        // 更新产品名称
        productName = oneLineText;
      }


      // 使用正则表达式匹配包含 "club" 的一行或者包含 "£" 的一行
      RegExp discountPattern = RegExp(r'^.*(?:club|£).*$', multiLine: true);
      List<RegExpMatch> matches = discountPattern.allMatches(fullOcrText)
          .toList();


      if (matches.isNotEmpty) {
        // 将所有匹配的行添加到一个Set中去重，然后合并成单个字符串
        final lines = <String>{};
        for (final match in matches) {
          lines.add(match.group(0)!.trim());
        }

        // 将唯一的行连接成一个描述
        discountDescription = lines.join('\n');
      }

      DateTime? parsedStartDate;
      DateTime? parsedEndDate;
      try {
        if (startDate.isNotEmpty) {
          parsedStartDate = DateFormat('dd/MM/yyyy').parse(startDate);
        }
        if (endDate.isNotEmpty) {
          parsedEndDate = DateFormat('dd/MM/yyyy').parse(endDate);
        }
      } catch (e) {
        print("Date parsing error: $e");
      }


      safeSetState(() {
        _text =
        'Merchant Name: $merchantName\nStart Date: $startDate\nEnd Date: $endDate\nProduct Name: $productName\nDiscount Description: $discountDescription\n';
        _isLoading = false; // OCR完成，更新加载状态
      });

      //navigate to InputPage
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) =>
          InputPage(
            merchantName: merchantName,
            productName: productName,
            description: discountDescription,
            startTime: parsedStartDate,
            endTime: parsedEndDate,
          )));
    } catch (e) {
      print("OCR Exception: $e"); // 打印异常信息
      safeSetState(() {
        _text = 'Error: $e';
        _isLoading = false; // 异常处理，更新异常信息和加载状态
      });
    } finally {
      textRecognizer.close(); // 释放分配给文本识别器的资源
    }
  }


  void safeSetState(void Function() updateFunction) {
    if (mounted) setState(updateFunction);
  }


  @override
  void dispose() {
    widget.controller.dispose(); // 确保释放相机控制器
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('OCR'),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: CameraPreview(widget.controller), // 显示相机预览。
          ),
          if (_isLoading) CircularProgressIndicator(), // 显示加载指示器
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(_text),
          ),
          ElevatedButton(
            onPressed: takePicture,
            child: Icon(Icons.camera_alt),
          )
        ],
      ),
    );
  }
}


 class InputPage extends StatefulWidget {

  //initialized for ocr input
  final String merchantName;
   final String productName;
   final String description;
   final DateTime? startTime;
   final DateTime? endTime;

   InputPage({
     Key? key,
     this.merchantName = '',
     this.productName = '',
     this.description = '',
     this.startTime,
     this.endTime,
   }) : super(key: key);

   @override
   _InputPageState createState() => _InputPageState();
 }

class _InputPageState extends State<InputPage> {
  late TextEditingController _nameController = TextEditingController();
  late TextEditingController _descriptionController = TextEditingController();
  late TextEditingController _productNameController = TextEditingController();
  DateTime? _startTime;  // 使用 DateTime 来存储日期
  dynamic _endTime = 'Subject to availability';
  String _selectedQuantity = '余量充足';  // 默认选中的数量

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.merchantName?? '');
    _productNameController = TextEditingController(text: widget.productName?? '');
    _descriptionController = TextEditingController(text: widget.description?? '');
    _startTime = widget.startTime;
    _endTime = widget.endTime?? 'Subject to availability';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _productNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }



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
      } else if (_productNameController.text.isEmpty) {
        missingInput = '商品名称';
      }
      _showInputAlert(missingInput);
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('discounts').add({
        'merchantName': _nameController.text,
        'productName' : _productNameController.text,
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
  Future<void> _selectEndDate(BuildContext context, bool isStartTime) async {
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

  Future<void> _selectStartDate(BuildContext context, bool isStartTime) async {
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
            TextField(controller: _productNameController, decoration: InputDecoration(labelText: '商品名称')),
            TextField(controller: _descriptionController, decoration: InputDecoration(labelText: '折扣描述')),
            ListTile(
              title: Text('开始时间: ${_startTime != null ? DateFormat('yyyy-MM-dd').format(_startTime!) : '未选择'}'),
              trailing: Icon(Icons.calendar_today),
              onTap: () => _selectStartDate(context, true),
            ),
            ListTile(
              title: Text('结束时间: ' + (_endTime is DateTime ? DateFormat('yyyy-MM-dd').format(_endTime) : _endTime)),
              trailing: Icon(Icons.calendar_today),
              onTap: () => _selectEndDate(context, false),
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

