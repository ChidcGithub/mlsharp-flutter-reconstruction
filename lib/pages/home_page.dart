import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:provider/provider.dart';
import '../providers/app_settings_provider.dart';
import '../services/backend_api_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? _image;
  String? _modelUrl;
  bool _isGenerating = false;
  bool _isConnected = false;
  final ImagePicker _picker = ImagePicker();
  late BackendApiService _apiService;

  @override
  void initState() {
    super.initState();
    _apiService = BackendApiService();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    final connected = await _apiService.checkConnection();
    setState(() {
      _isConnected = connected;
    });
  }

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
    _apiService.setBaseUrl(backendUrl);

    setState(() {
      _isGenerating = true;
    });

    try {
      final result = await _apiService.predictImage(_image!);
      
      if (result != null) {
        setState(() {
          _modelUrl = result['model_url'] as String?;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 3D 模型生成成功！')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ 推理失败，请查看日志了解详情')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ 发生错误: $e')),
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
            // 连接状态指示器
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _isConnected ? Colors.green.shade100 : Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isConnected ? Colors.green : Colors.red,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isConnected ? Icons.check_circle : Icons.error_circle,
                    color: _isConnected ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isConnected ? '✅ 后端已连接' : '❌ 后端未连接',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isConnected ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
                        Text(
                          context.read<AppSettingsProvider>().backendUrl,
                          style: TextStyle(
                            fontSize: 12,
                            color: _isConnected ? Colors.green.shade600 : Colors.red.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _checkConnection,
                    tooltip: '重新检查连接',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
