import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:provider/provider.dart';
import '../providers/app_settings_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? _image;
  String? _modelUrl;
  bool _isGenerating = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _image = File(image.path);
        _modelUrl = null;
      });
    }
  }

  Future<void> _uploadImageAndGenerateModel() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择一张图片！')),
      );
      return;
    }

    final backendUrl = context.read<AppSettingsProvider>().backendUrl;

    setState(() {
      _isGenerating = true;
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$backendUrl/api/predict'),
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
          _modelUrl = jsonResponse['model_url'];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('3D 模型生成成功！')),
        );
      } else {
        throw Exception('服务器返回错误: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发生错误: $e')),
      );
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MLSharp 3D Maker'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: _modelUrl != null
                    ? ModelViewer(
                        backgroundColor: const Color.fromARGB(0xFF, 0xEE, 0xEE, 0xEE),
                        src: _modelUrl!,
                        alt: "生成的 3D 模型",
                        ar: true,
                        autoRotate: true,
                        cameraControls: true,
                      )
                    : _image != null
                        ? Image.file(_image!, fit: BoxFit.contain)
                        : const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image_outlined, size: 64, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('请上传图片以开始生成'),
                              ],
                            ),
                          ),
              ),
            ),
            const SizedBox(height: 20),
            if (_isGenerating)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在生成 3D 模型，请稍候...'),
                  ],
                ),
              )
            else
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('选择本地图片'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _image != null ? _uploadImageAndGenerateModel : null,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('开始生成 3D 模型'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            const Text(
              '提示：生成的模型将以 GLB 格式展示，支持手势旋转与缩放。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
