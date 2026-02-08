import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
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
  
  // 编辑器参数
  double _exposure = 1.0;
  String _environmentImage = 'neutral';
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _showEditor = false;

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

  Future<void> _takeScreenshot() async {
    final status = await Permission.photos.request();
    if (status.isGranted || status.isLimited) {
      final image = await _screenshotController.capture();
      if (image != null) {
        final result = await ImageGallerySaver.saveImage(image);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('截图已保存到相册')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要相册权限才能保存截图')),
        );
      }
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
      // 重置编辑器参数
      setState(() {
        _exposure = 1.0;
        _environmentImage = 'neutral';
      });
      
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
            Stack(
              children: [
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    height: 400,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                    ),
                    child: _modelUrl != null
                        ? Screenshot(
                            controller: _screenshotController,
                            child: ModelViewer(
                              key: ValueKey('$_modelUrl-$_exposure-$_environmentImage'),
                              backgroundColor: colorScheme.surfaceContainerLow,
                              src: _modelUrl!,
                              alt: "生成的 3D 模型",
                              ar: true,
                              autoRotate: false,
                              cameraControls: true,
                              exposure: _exposure,
                              environmentImage: _environmentImage == 'neutral' ? null : _environmentImage,
                            ),
                          )
                        : _image != null
                            ? Image.file(_image!, fit: BoxFit.cover, width: double.infinity)
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
                if (_modelUrl != null) ...[
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Column(
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'screenshot',
                          onPressed: _takeScreenshot,
                          child: const Icon(Icons.camera_alt),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'editor',
                          onPressed: () => setState(() => _showEditor = !_showEditor),
                          child: Icon(_showEditor ? Icons.close : Icons.tune),
                        ),
                      ],
                    ),
                  ),
                  if (_showEditor)
                    Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: Card(
                        color: colorScheme.surface.withOpacity(0.9),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.light_mode, size: 16),
                                  const SizedBox(width: 8),
                                  const Text('曝光度', style: TextStyle(fontSize: 12)),
                                  Expanded(
                                    child: Slider(
                                      value: _exposure,
                                      min: 0.1,
                                      max: 2.0,
                                      onChanged: (v) => setState(() => _exposure = v),
                                    ),
                                  ),
                                  Text(_exposure.toStringAsFixed(1), style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                              const Divider(),
                              Row(
                                children: [
                                  const Icon(Icons.landscape, size: 16),
                                  const SizedBox(width: 8),
                                  const Text('环境', style: TextStyle(fontSize: 12)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: SegmentedButton<String>(
                                      segments: const [
                                        ButtonSegment(value: 'neutral', label: Text('中性', style: TextStyle(fontSize: 10))),
                                        ButtonSegment(value: 'legacy', label: Text('室内', style: TextStyle(fontSize: 10))),
                                        ButtonSegment(value: 'spruit_sunrise', label: Text('室外', style: TextStyle(fontSize: 10))),
                                      ],
                                      selected: {_environmentImage},
                                      onSelectionChanged: (v) => setState(() => _environmentImage = v.first),
                                      showSelectedIcon: false,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ],
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
