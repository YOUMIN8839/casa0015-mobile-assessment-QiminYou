import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

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
        title: Text('拍照'),
      ),
      body: CameraPreview(this.controller), // 显示相机预览
    );
  }
}



// InputPage 类的代码保持不变
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
        title: Text('输入折扣'),
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
