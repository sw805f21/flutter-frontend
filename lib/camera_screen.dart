import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_camera/gallery.dart';
import 'package:flutter_camera/video_timer.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:thumbnails/thumbnails.dart';
import 'package:http/http.dart' as http;

import 'package:image_picker/image_picker.dart';
import 'package:multipart_request/multipart_request.dart';

/// Flutter code sample for FloatingActionButton

// This example shows how to make an extended [FloatingActionButton] in a
// [Scaffold], with a  pink [backgroundColor], a thumbs up [Icon] and a
// [Text] label that reads "Approve".
//
// ![](https://flutter.github.io/assets-for-api-docs/assets/material/floating_action_button_label.png)

import 'package:flutter/material.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key key}) : super(key: key);

  @override
  CameraScreenState createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen>
    with AutomaticKeepAliveClientMixin {
  CameraController _controller;
  List<CameraDescription> _cameras;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isRecordingMode = false;
  bool _isRecording = false;
  final _timerKey = GlobalKey<VideoTimerState>();
  String latest = '';

  @override
  void initState() {
    _initCamera();
    super.initState();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    _controller = CameraController(_cameras[0], ResolutionPreset.medium);
    _controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_controller != null) {
      if (!_controller.value.isInitialized) {
        return Container();
      }
    } else {
      return const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_controller.value.isInitialized) {
      return Container();
    }
    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      key: _scaffoldKey,
      extendBody: true,
      body: Stack(
        children: <Widget>[
          _buildCameraPreview(),
          Positioned(
            top: 24.0,
            left: 12.0,
            child: IconButton(
              icon: Icon(
                Icons.switch_camera,
                color: Colors.white,
              ),
              onPressed: () {
                _onCameraSwitch();
              },
            ),
          ),
          if (_isRecordingMode)
            Positioned(
              left: 0,
              right: 0,
              top: 32.0,
              child: VideoTimer(
                key: _timerKey,
              ),
            )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Add your onPressed code here!
          _displayTextInputDialog(context);
        },
        label: const Text('Textbox'),
        backgroundColor: Colors.blue,
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildCameraPreview() {
    final size = MediaQuery.of(context).size;
    return ClipRect(
      child: Container(
        child: Transform.scale(
          scale: _controller.value.aspectRatio / size.aspectRatio,
          child: Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: CameraPreview(_controller),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      color: Theme.of(context).bottomAppBarColor,
      height: 100.0,
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          FutureBuilder(
            future: getLastImage(),
            builder: (context, snapshot) {
              if (snapshot.data == null) {
                return Container(
                  width: 40.0,
                  height: 40.0,
                );
              }
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Gallery(),
                  ),
                ),
                child: Container(
                  width: 40.0,
                  height: 40.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4.0),
                    child: Image.file(
                      snapshot.data,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
          ),
          CircleAvatar(
            backgroundColor: Colors.white,
            radius: 28.0,
            child: IconButton(
              icon: Icon(
                (_isRecordingMode)
                    ? (_isRecording) ? Icons.stop : Icons.videocam
                    : Icons.camera_alt,
                size: 28.0,
                color: (_isRecording) ? Colors.red : Colors.black,
              ),
              onPressed: () {
                if (!_isRecordingMode) {
                  _captureImage();
                } else {
                  if (_isRecording) {
                    stopVideoRecording();
                    var file = File(latest);
                    var url = "https://sembrik.pythonanywhere.com/upload";
                    sleep(Duration(seconds:3));
                    _asyncFileUpload();
                    //Upload(); / To test connection to the server

                  } else {
                    startVideoRecording();
                  }
                }
              },
            ),
          ),
          IconButton(
            icon: Icon(
              (_isRecordingMode) ? Icons.camera_alt : Icons.videocam,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isRecordingMode = !_isRecordingMode;
              });
            },
          ),
        ],
      ),
    );
  }

  Future<FileSystemEntity> getLastImage() async {
    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/media';
    final myDir = Directory(dirPath);
    List<FileSystemEntity> _images;
    _images = myDir.listSync(recursive: true, followLinks: false);
    _images.sort((a, b) {
      return b.path.compareTo(a.path);
    });
    var lastFile = _images[0];
    var extension = path.extension(lastFile.path);
    if (extension == '.jpeg') {
      return lastFile;
    } else {
      String thumb = await Thumbnails.getThumbnail(
          videoFile: lastFile.path, imageType: ThumbFormat.PNG, quality: 30);
      return File(thumb);
    }
  }

  Future<void> _onCameraSwitch() async {
    final CameraDescription cameraDescription =
        (_controller.description == _cameras[0]) ? _cameras[1] : _cameras[0];
    if (_controller != null) {
      await _controller.dispose();
    }
    _controller = CameraController(cameraDescription, ResolutionPreset.medium);
    _controller.addListener(() {
      if (mounted) setState(() {});
      if (_controller.value.hasError) {
        showInSnackBar('Camera error ${_controller.value.errorDescription}');
      }
    });

    try {
      await _controller.initialize();
    } on CameraException catch (e) {
      _showCameraException(e);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _captureImage() async {
    print('_captureImage');
    if (_controller.value.isInitialized) {
      SystemSound.play(SystemSoundType.click);
      final Directory extDir = await getApplicationDocumentsDirectory();
      final String dirPath = '${extDir.path}/media';
      await Directory(dirPath).create(recursive: true);
      final String filePath = '$dirPath/${_timestamp()}.jpeg';
      print('path: $filePath');
      await _controller.takePicture(filePath);
      setState(() {});
    }
  }

  Future<String> startVideoRecording() async {
    print('startVideoRecording');
    if (!_controller.value.isInitialized) {
      return null;
    }
    setState(() {
      _isRecording = true;
    });
    _timerKey.currentState.startTimer();

    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/media';
    await Directory(dirPath).create(recursive: true);
    final String filePath = '$dirPath/${_timestamp()}.mp4';

    if (_controller.value.isRecordingVideo) {
      // A recording is already started, do nothing.
      return null;
    }

    try {
//      videoPath = filePath;
      await _controller.startVideoRecording(filePath);
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
    print('SET FILEPATH');
    latest = filePath;
    print(filePath);
    return filePath;
  }

  Future<void> stopVideoRecording() async {
    print('CALLED STOP');
    if (!_controller.value.isRecordingVideo) {
      return null;
    }
    _timerKey.currentState.stopTimer();
    setState(() {
      _isRecording = false;
    });

    try {
      await _controller.stopVideoRecording();
      print('STOPPED RECORDING WITH FILEPATH : ');
      print(latest);
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
  }

  Upload() async {
    print('HANDSHAKE');
    var url = Uri.parse('https://sembrik.pythonanywhere.com/');
    var response = await http.get(url);
    print('Response status: ${response.statusCode}');
  }

  _asyncFileUpload() async{
    print('inside');
    //create multipart request for POST or PATCH method
    var request = http.MultipartRequest("POST", Uri.parse("https://sembrik.pythonanywhere.com/upload"));
    //create multipart using filepath, string or bytes
    var file = File(latest);
    var url = "https://sembrik.pythonanywhere.com/upload";
    print('inside fileload');
    var pic = await http.MultipartFile.fromPath("file", file.path);
    //add multipart to request
    print('inside load');
    request.files.add(pic);
    var response = await request.send();
    print('inside after respo');

    //Get the response from the server
    var responseData = await response.stream.toBytes();
    var responseString = String.fromCharCodes(responseData);
    print(responseString);
    _showReply(responseString);
    print('Response UPLOAD: ${response.statusCode}');
  }

  Future<void> _showReply(String inference) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Translated Sentence to English"),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(inference)
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Thanks'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _displayTextInputDialog(BuildContext context) async {
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Text Area Communication'),
            content: TextField(
              maxLines: null,
              onChanged: (value) {
                setState(() {
                  var valueText = value;
                });
              },
              decoration: InputDecoration(hintText: "Text Field in Dialog"),
            ),
            actions: <Widget>[
              FlatButton(
                color: Colors.green,
                textColor: Colors.white,
                child: Text('OK'),
                onPressed: () {
                  setState(() {
                    Navigator.pop(context);
                  });
                },
              ),

            ],
          );
        });
  }

  Future<String> uploadImageHTTP(file, url) async {

    var request = http.MultipartRequest('POST', Uri.parse(url));
    request.files.add(await http.MultipartFile.fromPath('picture', file.path));
    var res = await request.send();
    return res.reasonPhrase;

  }


  sendtoapi() async{
    var request = MultipartRequest();
    print('INSIDE WITH URL' + latest);

    request.setUrl("https://sembrik.pythonanywhere.com/upload");
    request.addFile("file", latest);

    Response response = request.send();

    response.onError = () {
      print("Error");
    };

    response.onComplete = (response) {
      print(response);
    };

    response.progress.listen((int progress) {
      print("progress from response object " + progress.toString());
    });
  }

  String _timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

  void _showCameraException(CameraException e) {
    logError(e.code, e.description);
    showInSnackBar('Error: ${e.code}\n${e.description}');
  }

  void showInSnackBar(String message) {
    _scaffoldKey.currentState.showSnackBar(SnackBar(content: Text(message)));
  }

  void logError(String code, String message) =>
      print('Error: $code\nError Message: $message');

  @override
  bool get wantKeepAlive => true;
}
