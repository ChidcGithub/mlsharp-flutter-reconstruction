
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MLSharp 3D Maker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'MLSharp 3D Maker Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File? _image;
  String? _modelUrl;
  final ImagePicker _picker = ImagePicker();
  final String _backendUrl = 'http://127.0.0.1:8000'; // Assuming Python backend runs on this address

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    setState(() {
      if (image != null) {
        _image = File(image.path);
      }
    });
  }

  Future<void> _uploadImageAndGenerateModel() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择一张图片！')),
      );
      return;
    }

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_backendUrl/api/predict'),
      );
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        _image!.path,
      ));

      var response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final jsonResponse = json.decode(responseBody);
        setState(() {
          _modelUrl = jsonResponse['model_url']; // Assuming backend returns a URL to the 3D model
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('3D 模型生成成功！')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('模型生成失败: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发生错误: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _image == null
                  ? const Text('未选择图片')
                  : Image.file(_image!, height: 200),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _pickImage,
                child: const Text('选择图片'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _uploadImageAndGenerateModel,
                child: const Text('生成 3D 模型'),
              ),
              const SizedBox(height: 20),
              _modelUrl == null
                  ? const Text('模型未生成')
                  : Text('3D 模型 URL: $_modelUrl'),
              // Here you would integrate a 3D viewer widget using three_dart or similar
              // For now, we just display the URL.
            ],
          ),
        ),
      ),
    );
  }
}
