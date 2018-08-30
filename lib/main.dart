import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gallery/settings.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

class CameraPage extends StatefulWidget {
  @override
  _CameraPageState createState() {
    return new _CameraPageState();
  }
}

/// Returns a suitable camera icon for [direction].
IconData getCameraLensIcon(CameraLensDirection direction) {
  switch (direction) {
    case CameraLensDirection.back:
      return Icons.camera_rear;
    case CameraLensDirection.front:
      return Icons.camera_front;
    case CameraLensDirection.external:
      return Icons.camera;
  }
  throw new ArgumentError('Unknown lens direction');
}

void logError(String code, String message) =>
    print('Error: $code\nError Message: $message');

class _CameraPageState extends State<CameraPage> {
  CameraController controller;
  String imagePath;
  String videoPath;
  VideoPlayerController videoController;
  VoidCallback videoPlayerListener;

  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      key: _scaffoldKey,
      appBar: new AppBar(
        title: const Text('Camera example'),
      ),
      body: new Column(
        children: <Widget>[
          new Expanded(
            child: new Container(
              child: new Padding(
                padding: const EdgeInsets.all(1.0),
                child: new Center(
                  child: _cameraPreviewWidget(),
                ),
              ),
              decoration: new BoxDecoration(
                color: Colors.black,
                border: new Border.all(
                  color: controller != null && controller.value.isRecordingVideo
                      ? Colors.redAccent
                      : Colors.grey,
                  width: 3.0,
                ),
              ),
            ),
          ),
          _captureControlRowWidget(),
          new Padding(
            padding: const EdgeInsets.all(5.0),
            child: new Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                _cameraTogglesRowWidget(),
                _thumbnailWidget(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Display the preview from the camera (or a message if the preview is not available).
  Widget _cameraPreviewWidget() {
    if (controller == null || !controller.value.isInitialized) {
      return const Text(
        'Tap a camera',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24.0,
          fontWeight: FontWeight.w900,
        ),
      );
    } else {
      return new AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: new CameraPreview(controller),
      );
    }
  }

  /// Display the thumbnail of the captured image or video.
  Widget _thumbnailWidget() {
    return new Expanded(
      child: new Align(
        alignment: Alignment.centerRight,
        child: videoController == null && imagePath == null
            ? null
            : new SizedBox(
          child: (videoController == null)
              ? new Image.file(new File(imagePath))
              : new Container(
            child: new Center(
              child: new AspectRatio(
                  aspectRatio: videoController.value.size != null
                      ? videoController.value.aspectRatio
                      : 1.0,
                  child: new VideoPlayer(videoController)),
            ),
            decoration: new BoxDecoration(
                border: new Border.all(color: Colors.pink)),
          ),
          width: 64.0,
          height: 64.0,
        ),
      ),
    );
  }

  /// Display the control bar with buttons to take pictures and record videos.
  Widget _captureControlRowWidget() {
    return new Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      mainAxisSize: MainAxisSize.max,
      children: <Widget>[
        new IconButton(
          icon: const Icon(Icons.camera_alt),
          color: Colors.blue,
          onPressed: controller != null &&
              controller.value.isInitialized &&
              !controller.value.isRecordingVideo
              ? onTakePictureButtonPressed
              : null,
        ),
        new IconButton(
          icon: const Icon(Icons.videocam),
          color: Colors.blue,
          onPressed: controller != null &&
              controller.value.isInitialized &&
              !controller.value.isRecordingVideo
              ? onVideoRecordButtonPressed
              : null,
        ),
        new IconButton(
          icon: const Icon(Icons.stop),
          color: Colors.red,
          onPressed: controller != null &&
              controller.value.isInitialized &&
              controller.value.isRecordingVideo
              ? onStopButtonPressed
              : null,
        )
      ],
    );
  }

  /// Display a row of toggle to select the camera (or a message if no camera is available).
  Widget _cameraTogglesRowWidget() {
    final List<Widget> toggles = <Widget>[];

    if (cameras == null || cameras.isEmpty) {
      return const Text('No camera found');
    } else {
      for (CameraDescription cameraDescription in cameras) {
        toggles.add(
          new SizedBox(
            width: 90.0,
            child: new RadioListTile<CameraDescription>(
              title:
              new Icon(getCameraLensIcon(cameraDescription.lensDirection)),
              groupValue: controller?.description,
              value: cameraDescription,
              onChanged: controller != null && controller.value.isRecordingVideo
                  ? null
                  : onNewCameraSelected,
            ),
          ),
        );
      }
    }

    return new Row(children: toggles);
  }

  String timestamp() => new DateTime.now().millisecondsSinceEpoch.toString();

  void showInSnackBar(String message) {
    _scaffoldKey.currentState
        .showSnackBar(new SnackBar(content: new Text(message)));
  }

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    if (controller != null) {
      await controller.dispose();
    }
    controller = new CameraController(cameraDescription, ResolutionPreset.high);

    // If the controller is updated then update the UI.
    controller.addListener(() {
      if (mounted) setState(() {});
      if (controller.value.hasError) {
        showInSnackBar('Camera error ${controller.value.errorDescription}');
      }
    });

    try {
      await controller.initialize();
    } on CameraException catch (e) {
      _showCameraException(e);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void onTakePictureButtonPressed() {
    takePicture().then((String filePath) {
      if (mounted) {
        setState(() {
          imagePath = filePath;
          videoController?.dispose();
          videoController = null;
        });
        if (filePath != null) showInSnackBar('Picture saved to $filePath');
      }
    });
  }

  void onVideoRecordButtonPressed() {
    startVideoRecording().then((String filePath) {
      if (mounted) setState(() {});
      if (filePath != null) showInSnackBar('Saving video to $filePath');
    });
  }

  void onStopButtonPressed() {
    stopVideoRecording().then((_) {
      if (mounted) setState(() {});
      showInSnackBar('Video recorded to: $videoPath');
    });
  }

  Future<String> startVideoRecording() async {
    if (!controller.value.isInitialized) {
      showInSnackBar('Error: select a camera first.');
      return null;
    }

    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/Movies/flutter_test';
    await new Directory(dirPath).create(recursive: true);
    final String filePath = '$dirPath/${timestamp()}.mp4';

    if (controller.value.isRecordingVideo) {
      // A recording is already started, do nothing.
      return null;
    }

    try {
      videoPath = filePath;
      await controller.startVideoRecording(filePath);
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
    return filePath;
  }

  Future

  <

  void

  >

  stopVideoRecording

  () async

  {
  if (!controller.value.isRecordingVideo) {
  return null;
  }

  try {
  await controller.stopVideoRecording();
  } on CameraException catch (e) {
  _showCameraException(e);
  return null;
  }

  await _startVideoPlayer();
  }

  Future<void> _startVideoPlayer() async

  {
  final VideoPlayerController vcontroller =
  new VideoPlayerController.file(new File(videoPath));
  videoPlayerListener = () {
  if (videoController != null && videoController.value.size != null) {
  // Refreshing the state to update video player with the correct ratio.
  if (mounted) setState(() {});
  videoController.removeListener(videoPlayerListener);
  }
  };
  vcontroller.addListener(videoPlayerListener);
  await vcontroller.setLooping(true);
  await vcontroller.initialize();
  await videoController?.dispose();
  if (mounted) {
  setState(() {
  imagePath = null;
  videoController = vcontroller;
  });
  }
  await vcontroller.play();
  }

  Future<String> takePicture() async

  {
  if (!controller.value.isInitialized) {
  showInSnackBar('Error: select a camera first.');
  return null;
  }
  final Directory extDir = await getApplicationDocumentsDirectory();
  final String dirPath = '${extDir.path}/Pictures/flutter_test';
  await new Directory(dirPath).create(recursive: true);
  final String filePath = '$dirPath/${timestamp()}.jpg';

  if (controller.value.isTakingPicture) {
  // A capture is already pending, do nothing.
  return null;
  }

  try {
  await controller.takePicture(filePath);
  } on CameraException catch (e) {
  _showCameraException(e);
  return null;
  }
  return filePath;
  }

  void _showCameraException(CameraException e)

  {
  logError(e.code, e.description);
  showInSnackBar('Error: ${e.code}\n${e.description}');
  }
}

List<CameraDescription> cameras;
Map<String, List<String>> images = new Map();

Future<Null> main() async {
  // Fetch the available cameras before initializing the app.
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    logError(e.code, e.description);
  }
  await listDirectories();
  runApp(new MyApp());
}

void log(String msg) {
  print("GalleryApp: " + msg);
}

Future<void> listDirectories() async {
  final Directory directory = await getExternalStorageDirectory();
  log(directory.path);
  directory.list(recursive: true).listen((FileSystemEntity entity) {
    if (entity.path.endsWith(".jpg") || entity.path.endsWith(".jpeg") || entity.path.endsWith(".png")) {
      List<String> splits = entity.path.split("/");
      List<String> folderImagesList = images[splits[splits.length - 2]];
      print(splits[splits.length - 2]);
      print(folderImagesList == null);
      if (folderImagesList == null) {
        folderImagesList = new List<String>();
        images[splits[splits.length - 2]] = folderImagesList;
      }
      folderImagesList.add(entity.path);
    }
  });
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Gallery',
      theme: new ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or press Run > Flutter Hot Reload in IntelliJ). Notice that the
        // counter didn't reset back to zero; the application is not restarted.
        primarySwatch: Colors.blue,
      ),
      initialRoute: "/",
      routes: {
        "/": (context) => MyHomePage(title: 'Gallery'),
        "/camera": (context) => CameraPage(),
        "/settings": (context) => SettingsPage(title: 'Settings')
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => new _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  void openCamera() {
    Navigator.pushNamed(context, "/camera");
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    print("Build Called");
    return new Scaffold(
      drawer: new Drawer(
        child: ListView(
          children: <Widget>[
            DrawerHeader(
              child: new Center(
                  child: Text(
                    "Gallery",
                    style: new TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 30.0
                    ),
                  )
              ),
              decoration: BoxDecoration(
                  color: Colors.blue
              ),
            ),
            ListTile(
              title: Text(
                "Folders",
                style: new TextStyle(
                    color: Colors.black,
                    fontSize: 20.0
                ),
              ),
              onTap: () {
                setState(() {

                });
                Navigator.pushNamed(context, "/");
              },
            ),
            ListTile(
              title: Text(
                "Settings",
                style: new TextStyle(
                    color: Colors.black,
                    fontSize: 20.0
                ),
              ),
              onTap: () {
                Navigator.pushNamed(context, "/settings");
              },
            ),
          ],
        ),
      ),
      appBar: new AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: new Text(widget.title),
      ),
      body: new GridView.count(
        crossAxisCount: 2,
        children: images.keys.map((String key) {
          return new GridTile(
            child: new Text(key)
          );
        }).toList(),
      ),
      floatingActionButton: new FloatingActionButton(
        onPressed: openCamera,
        tooltip: 'Camera',
        child: new Icon(Icons.camera),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
