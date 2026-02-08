import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:provider/provider.dart';
import '../providers/app_settings_provider.dart';
import '../services/backend_api_service.dart';
import '../services/inference_logger.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final logger = context.read<InferenceLogger>();
      _apiService.setLogger(logger);
      _checkConnection();
    });
  }

  Future<void> _checkConnection() async {
    final backendUrl = context.read<AppSettingsProvider>().backendUrl;
    _apiService.setBaseUrl(backendUrl);
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
      context.read<InferenceLogger>().info('已选择输入图像: ${image.name}');
    }
  }

  Future<void> _uploadImageAndGenerateModel() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择一张图片')),
      );
      return;
    }

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
          const SnackBar(content: Text('3D 模型生成成功')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('推理失败，请查看终端日志')),
        );
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
    final colorScheme = Theme.of(context).colorScheme;
    
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
                color: _isConnected 
                    ? colorScheme.primaryContainer.withOpacity(0.2)
                    : colorScheme.errorContainer.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isConnected ? colorScheme.primary : colorScheme.error,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isConnected ? Icons.check_circle : Icons.error,
                    color: _isConnected ? colorScheme.primary : colorScheme.error,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isConnected ? '后端已连接' : '后端未连接',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: _isConnected ? colorScheme.primary : colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.watch<AppSettingsProvider>().backendUrl,
                          style: TextStyle(
                            fontSize: 12,
                            color: (_isConnected ? colorScheme.primary : colorScheme.error).withOpacity(0.7),
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
                    color: _isConnected ? colorScheme.primary : colorScheme.error,
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
                  color: colorScheme.surfaceContainerLow,
                ),
                child: _modelUrl != null
                    ? ModelViewer(
                        backgroundColor: colorScheme.surfaceContainerLow,
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
                                  color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '请上传图片以开始生成',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colorScheme.onSurfaceVariant,
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
                        '正在生成 3D 模型，请稍候',
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
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _image != null && _isConnected ? _uploadImageAndGenerateModel : null,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('开始生成 3D 模型'),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.secondaryContainer),
              ),
              child: Text(
                '提示：生成的模型将以 GLB 格式展示，支持手势旋转与缩放',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
