import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class TutorialScreen extends StatefulWidget {
  @override
  _TutorialScreenState createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  PageController _pageController = PageController();
  List<VideoPlayerController> _controllers = [];
  List<String> videos = [
    'assets/videos/teach1.mp4',
    'assets/videos/teach2.mp4',
    'assets/videos/teach3.mp4',
    'assets/videos/teach4.mp4',
    'assets/videos/teach5.mp4',
    'assets/videos/teach6.mp4',
    'assets/videos/teach7.mp4',
  ];

  @override
  void initState() {
    super.initState();
    initializeVideos();
  }

  Future<void> initializeVideos() async {
    for (var video in videos) {
      VideoPlayerController controller = VideoPlayerController.asset(video);
      await controller.initialize();
      _controllers.add(controller);
    }
    setState(() {
      _controllers[0].play(); // Auto-play the first video
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView.builder(
        controller: _pageController,
        itemCount: _controllers.length,
        itemBuilder: (context, index) {
          return Stack(
            alignment: Alignment.bottomRight,
            children: [
              VideoPlayer(_controllers[index]),
              if (index < _controllers.length - 1)
                IconButton(
                  icon: Icon(Icons.arrow_forward, size: 40.0, color: Colors.purple),  // Change arrow color to purple
                  onPressed: () {
                    _pageController.nextPage(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
            ],
          );
        },
        onPageChanged: (index) {
          _controllers.forEach((controller) {
            controller.pause();
          });
          _controllers[index].play();

          if (index == _controllers.length - 1) {
            _controllers[index].addListener(() {
              if (_controllers[index].value.position == _controllers[index].value.duration &&
                  !_controllers[index].value.isPlaying) {
                Navigator.pushReplacementNamed(context, '/MainScreen');
              }
            });
          }
        },
      ),
    );
  }
}
