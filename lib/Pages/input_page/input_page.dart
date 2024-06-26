import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  static const MethodChannel _channel =
      MethodChannel('com.yourcompany.imageprocessing');

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
    _initializeCameras(); //initialize camera first time
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
        ResolutionPreset
            .medium, //hard to raise the resolution because of screen ratio
      );
      _cameraController!.initialize().then((_) {
        if (!mounted) {
          return;
        }
        // Navigate to camera controller
        Navigator.of(context)
            .push(
          MaterialPageRoute(
            builder: (context) => CameraPage(controller: _cameraController!),
          ),
        )
            .then((_) {
          _cameraController?.dispose();
          _cameraController =
              null; // Reset the controller after the camera page is popped
        });
      }).catchError((e) {
        print("Error initializing camera: $e");
      });
    }
  }

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
  bool _isLoading = false; // Flag for loading

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
      //using ImageCropper to cut the image into proper size
      final croppedFile = await ImageCropper()
          .cropImage(sourcePath: file.path, aspectRatioPresets: [
        CropAspectRatioPreset.square,
        CropAspectRatioPreset.ratio3x2,
        CropAspectRatioPreset.original,
        CropAspectRatioPreset.ratio4x3,
        CropAspectRatioPreset.ratio16x9
      ], uiSettings: [
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
      ]);

      if (croppedFile != null) {
        // proceed to OCR
        performOCR(File(croppedFile.path));
      } else {
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
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);
      final String fullOcrText = recognizedText.text;
      print("OCR Result: $fullOcrText"); // For testing

      String merchantName = '';
      String startDate = '';
      String endDate = '';
      String productName = '';
      String discountDescription = '';

      // Merchant name
      if (fullOcrText.contains('Clubcard')) {
        merchantName = 'Tesco';
      }

      // Start and end date
      final RegExp datePattern =
          RegExp(r'from\s+(\d{2}/\d{2}/\d{4})\s+until\s+(\d{2}/\d{2}/\d{4})');
      final RegExpMatch? datesMatch = datePattern.firstMatch(fullOcrText);
      if (datesMatch != null) {
        startDate = datesMatch.group(1)!;
        endDate = datesMatch.group(2)!;
      }

      //product name
      RegExp namePattern =
          RegExp(r'^([\s\S]*?)\s(?=.*Write a review)', multiLine: true);
      RegExpMatch? nameMatch = namePattern.firstMatch(fullOcrText);
      if (nameMatch != null) {
        String matchedText = nameMatch.group(1)!.trim();
        String oneLineText =
            matchedText.replaceAll('\n', ' '); // Combine multiple texts
        productName = oneLineText;
      }

      // description
      RegExp discountPattern = RegExp(r'^.*(?:club|£).*$', multiLine: true);
      List<RegExpMatch> matches =
          discountPattern.allMatches(fullOcrText).toList();

      if (matches.isNotEmpty) {
        // Combine multiple texts
        final lines = <String>{};
        for (final match in matches) {
          lines.add(match.group(0)!.trim());
        }
        discountDescription = lines.join('\n');
      }

      // parse time string to Datetime format
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
        //_text = 'Merchant Name: $merchantName\nStart Date: $startDate\nEnd Date: $endDate\nProduct Name: $productName\nDiscount Description: $discountDescription\n';
        _isLoading = false;
      });

      //navigate to InputPage with information obtained for OCR
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => InputPage(
                    merchantName: merchantName,
                    productName: productName,
                    description: discountDescription,
                    startTime: parsedStartDate,
                    endTime: parsedEndDate,
                  )));
    } catch (e) {
      print("OCR Exception: $e");
      safeSetState(() {
        _text = 'Error: $e';
        _isLoading = false;
      });
    } finally {
      textRecognizer.close();
    }
  }

  void safeSetState(void Function() updateFunction) {
    if (mounted) setState(updateFunction);
  }

  @override
  void dispose() {
    widget.controller.dispose();
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
  DateTime? _startTime; // 使用 DateTime 来存储日期
  dynamic _endTime = 'Subject to availability';
  String _selectedQuantity = 'Sufficient stock'; // 默认选中的数量
  Color? _color;
  final Map<String, Color> _colorOptions = {
    'Red': Colors.red,
    'Blue': Colors.blue,
    'Green': Colors.green,
    'Yellow': Colors.yellow,
    'Orange': Colors.orange,
    'Purple': Colors.purple,
    'Pink': Colors.pink,
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.merchantName ?? '');
    _productNameController =
        TextEditingController(text: widget.productName ?? '');
    _descriptionController =
        TextEditingController(text: widget.description ?? '');
    _startTime = widget.startTime;
    _endTime = widget.endTime ?? 'Subject to availability';
    _color = _colorOptions['Red'];
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
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    'Sufficient stock'
  ];
  final String subjectToAvailability = 'Subject to availability';

  // update quantity
  void _updateSelectedQuantity(String? newQuantity) {
    if (newQuantity != null) {
      setState(() {
        _selectedQuantity = newQuantity;
      });
    }
  }

  //color choice
  void _updateSelectedColor(String? newValue) {
    setState(() {
      _color = _colorOptions[newValue];
    });
  }

  Future<void> _uploadDiscount() async {
    if (_nameController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _selectedQuantity == '0') {
      String missingInput = 'All fields';
      if (_nameController.text.isEmpty) {
        missingInput = 'Merchant Name';
      } else if (_descriptionController.text.isEmpty) {
        missingInput = 'Discount Description';
      } else if (_selectedQuantity == '0') {
        missingInput = 'Availability';
      } else if (_productNameController.text.isEmpty) {
        missingInput = 'Product Name';
      } else if (_color == null) {
        missingInput = 'Color';
      }
      _showInputAlert(missingInput);
      return;
    }

    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Get the user's UID
        String uid = currentUser.uid;

        // Ensure the data is written to the users collection, under the current user's UID
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('discounts')
            .add({
          'merchantName': _nameController.text,
          'productName': _productNameController.text,
          'description': _descriptionController.text,
          'startTime':
              _startTime != null ? Timestamp.fromDate(_startTime!) : null,
          'endTime': _endTime is DateTime
              ? Timestamp.fromDate(_endTime as DateTime)
              : _endTime,
          'quantity': _selectedQuantity,
          'color': _color?.value.toRadixString(16), // Store color as a hexadecimal string
          'status': true,  // Default status added as "true"
        });
        _showUploadSuccess(context);
        Navigator.pop(context); // 导航回主页
        Navigator.pop(context);
      } else {
        // Handle the user not being logged in
        _showNoLogin(context, "User not logged in");
      }
    } catch (e) {
      _showUploadFailure(context, e.toString());
    }
  }

  void _showUploadFailure(BuildContext context, String message) {
    final snackBar = SnackBar(
      content: Text('Upload failed: $message'),
      duration: Duration(seconds: 2),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void _showNoLogin(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Upload Faliure'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
            ),
            TextButton(
              child: Text('To Login'),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pushNamed('/login'); // Navigate to login
              },
            ),
          ],
        );
      },
    );
  }

  void _showUploadSuccess(BuildContext context) {
    final snackBar = SnackBar(
      content: Text('Discount Uploaded'),
      duration: Duration(seconds: 2),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }


  // endTime picker function
  Future<void> _selectEndDate(BuildContext context, bool isStartTime) async {
    // A dialog box pops up allowing the user to choose between date of use or "Subject to availability"
    final bool useAvailability = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Choose end time'),
            content: Text('Do you want to set a specific date or use "Subject to availability"? '),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('specific date'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Subject to availability'),
              ),
            ],
          ),
        ) ??
        false;

    if (useAvailability) {
      setState(() {
        _endTime = 'Subject to availability';
      });
      return;
    }

    // If the user selects a specific date, show the date picker
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
      barrierDismissible: false, // User must click a button to close the pop-up window
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Missing input'),
          content: Text('please enter $missingInput。'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
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
        title: Text('Enter Discount'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: <Widget>[
            TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Merchant Name')),
            TextField(
                controller: _productNameController,
                decoration: InputDecoration(labelText: 'Product Name')),
            TextField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Discount Description')),
            ListTile(
              title: Text(
                  'Start Time: ${_startTime != null ? DateFormat('yyyy-MM-dd').format(_startTime!) : 'Not selected'}'),
              trailing: Icon(Icons.calendar_today),
              onTap: () => _selectStartDate(context, true),
            ),
            ListTile(
              title: Text('End Time: ' +
                  (_endTime is DateTime
                      ? DateFormat('yyyy-MM-dd').format(_endTime)
                      : _endTime)),
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
                labelText: 'availability',
                labelStyle: TextStyle(
                  fontSize: 22,
                  color: Colors.black,
                  //fontWeight: FontWeight.bold,
                ),
              ),

            ),
            DropdownButtonFormField<String>(
              value: _color == null ? null : _colorOptions.entries
                  .firstWhere((entry) => entry.value == _color, orElse: () => _colorOptions.entries.first)
                  .key,
              items: _colorOptions.entries.map((MapEntry<String, Color> entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Container(
                    width: 290,
                    height: 50,
                    decoration: BoxDecoration(
                      color: entry.value, // 设置颜色
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.all(8),

                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                _updateSelectedColor(newValue);
              },
              decoration: InputDecoration(
                labelText: 'choose color on calendar',
                labelStyle: TextStyle(
                  fontSize: 22,
                  color: Colors.black,
                  //fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadDiscount,
        tooltip: 'Upload Discount',
        child: Icon(Icons.upload),
      ),
    );
  }
}
