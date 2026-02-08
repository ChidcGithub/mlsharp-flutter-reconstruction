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
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 连接状态卡片
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isConnected
                      ? [const Color(0xFF00A8E8).withOpacity(0.1), const Color(0xFF00D4FF).withOpacity(0.1)]
                      : [const Color(0xFFE63946).withOpacity(0.1), const Color(0xFFFF6B6B).withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isConnected ? const Color(0xFF00A8E8) : const Color(0xFFE63946),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isConnected ? Icons.check_circle : Icons.error,
                    color: _isConnected ? const Color(0xFF00A8E8) : const Color(0xFFE63946),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isConnected ? '✅ 后端已连接' : '❌ 后端未连接',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: _isConnected ? const Color(0xFF00A8E8) : const Color(0xFFE63946),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.read<AppSettingsProvider>().backendUrl,
                          style: TextStyle(
                            fontSize: 12,
                            color: _isConnected ? const Color(0xFF00A8E8).withOpacity(0.7) : const Color(0xFFE63946).withOpacity(0.7),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _checkConnection,
                    tooltip: '重新检查连接',
                    color: _isConnected ? const Color(0xFF00A8E8) : const Color(0xFFE63946),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3D 模型预览卡片
            Card(
              clipBehavior: Clip.antiAlias,
              child: Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                ),
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
                        ? Image.file(_image!, fit: BoxFit.cover)
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_outlined,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '请上传图片以开始生成',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
              ),
            ),
            const SizedBox(height: 24),

            // 操作按钮区域
            if (_isGenerating)
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        '正在生成 3D 模型，请稍候...',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('选择本地图片'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _image != null && _isConnected ? _uploadImageAndGenerateModel : null,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('开始生成 3D 模型'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                '💡 提示：生成的模型将以 GLB 格式展示，支持手势旋转与缩放。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
