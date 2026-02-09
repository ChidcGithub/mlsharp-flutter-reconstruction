import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:flutter_gaussian_splatter/widgets/gaussian_splatter_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:gal/gal.dart';
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
  String? _localPlyPath;
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
    try {
      // 检查并请求权限
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
      }

      final image = await _screenshotController.capture();
      if (image != null) {
        // gal 库需要 Uint8List
        await Gal.putImageBytes(image);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('截图已保存到相册')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  Future<void> _downloadPly(String url) async {
    final logger = context.read<InferenceLogger>();
    try {
      String fullUrl = url;
      if (!url.startsWith('http')) {
        final backendUrl = context.read<AppSettingsProvider>().backendUrl;
        // 确保 backendUrl 不以 / 结尾，url 以 / 开头
        final base = backendUrl.endsWith('/') ? backendUrl.substring(0, backendUrl.length - 1) : backendUrl;
        final path = url.startsWith('/') ? url : '/$url';
        fullUrl = '$base$path';
      }
      
      logger.debug('正在从完整 URL 下载 PLY: $fullUrl');
      final response = await http.get(Uri.parse(fullUrl));
      
      if (response.statusCode == 200) {
        logger.debug('PLY 下载成功，文件大小: ${response.bodyBytes.length} bytes');
        
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/temp_model.ply');
        await file.writeAsBytes(response.bodyBytes);
        
        logger.debug('PLY 文件已保存到: ${file.path}');
        logger.debug('文件是否存在: ${file.existsSync()}');
        logger.debug('文件大小: ${file.lengthSync()} bytes');
        
        setState(() {
          _localPlyPath = file.path;
        });
        
        logger.success('PLY 文件准备就绪，路径: $_localPlyPath');
      } else {
        logger.error('PLY 下载失败，状态码: ${response.statusCode}');
        logger.debug('响应内容: ${response.body}');
      }
    } catch (e) {
      logger.error('下载 PLY 失败', error: e);
    }
  }

  Future<void> _uploadImageAndGenerateModel() async {
    final logger = context.read<InferenceLogger>();
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
        logger.debug('正在解析推理结果: $result');
        
        // 后端返回字段是 'url'，而不是 'model_url'
        final String? url = result['url'] as String?;
        
        if (url != null && url.isNotEmpty) {
          logger.success('获取到模型 URL: $url');
          if (url.toLowerCase().endsWith('.ply')) {
            logger.warning('检测到模型格式为 PLY。提示：PLY 格式在移动端预览可能显示为空白，建议后端转换为 GLB 格式。');
          }
          setState(() {
            _modelUrl = url;
            _exposure = 1.0;
            _environmentImage = 'neutral';
          });
          
          if (url.toLowerCase().endsWith('.ply')) {
            _downloadPly(url);
          }
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('3D 模型生成成功，正在加载预览')),
            );
          }
        } else {
          logger.error('推理结果中未找到有效的 url 字段');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('推理成功但未获取到模型地址')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('推理失败，请查看终端日志')),
          );
        }
      }
    } catch (e) {
      logger.error('处理推理结果时发生错误', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发生错误: $e')),
        );
      }
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
                            child: _modelUrl!.toLowerCase().endsWith('.ply')
                                ? (_localPlyPath != null
                                    ? _buildPlyViewer()
                                    : const Center(child: CircularProgressIndicator()))
                                : ModelViewer(
                                    key: ValueKey('$_modelUrl-$_exposure-$_environmentImage'),
                                    backgroundColor: colorScheme.surfaceContainerLow,
                                    src: _modelUrl!.startsWith('http') 
                                        ? _modelUrl! 
                                        : '${context.read<AppSettingsProvider>().backendUrl}${_modelUrl!.startsWith('/') ? '' : '/'}$_modelUrl',
                                    alt: "生成的 3D 模型",
                                    ar: true,
                                    arModes: const ['scene-viewer', 'webxr', 'quick-look'],
                                    autoRotate: false,
                                    cameraControls: true,
                                    exposure: _exposure,
                                    environmentImage: _environmentImage == 'neutral' ? null : _environmentImage,
                                    loading: Loading.lazy,
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
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildEnvOption('neutral', '中性', Icons.brightness_5),
                                    _buildEnvOption('room', '室内', Icons.room),
                                    _buildEnvOption('park', '室外', Icons.park),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
                if (_isGenerating)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black45,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            const Text(
                              '正在生成 3D 模型...',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '这可能需要一分钟左右',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isGenerating ? null : _pickImage,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('选择图片'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (_isGenerating || !_isConnected || _image == null) 
                        ? null 
                        : _uploadImageAndGenerateModel,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('开始生成'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.tertiary,
                      foregroundColor: colorScheme.onTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvOption(String value, String label, IconData icon) {
    final isSelected = _environmentImage == value;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        avatar: Icon(icon, size: 16, color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() => _environmentImage = value);
          }
        },
      ),
    );
  }

  Widget _buildPlyViewer() {
    final logger = context.read<InferenceLogger>();
    final colorScheme = Theme.of(context).colorScheme;
    
    return Stack(
      children: [
        // PLY 渲染器（带错误捕获）
        Builder(
          builder: (context) {
            return ErrorBoundary(
              onError: (error, stackTrace) {
                logger.error('PLY 渲染错误: $error', error: error, stackTrace: stackTrace);
              },
              child: GaussianSplatterWidget(
                assetPath: _localPlyPath!,
              ),
            );
          },
        ),
        // 加载状态指示器
        const Positioned(
          top: 10,
          left: 10,
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('加载 PLY 模型...', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
        // 调试信息按钮
        Positioned(
          bottom: 10,
          right: 10,
          child: FloatingActionButton.small(
            heroTag: 'debug_ply',
            onPressed: () {
              logger.debug('PLY 模型路径: $_localPlyPath');
              logger.debug('文件是否存在: ${File(_localPlyPath!).existsSync()}');
              if (File(_localPlyPath!).existsSync()) {
                final file = File(_localPlyPath!);
                logger.debug('文件大小: ${file.lengthSync()} bytes');
              }
            },
            child: const Icon(Icons.bug_report),
            tooltip: '调试信息',
          ),
        ),
      ],
    );
  }
}

// 自定义错误边界组件
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final void Function(Object error, StackTrace stackTrace)? onError;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.onError,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _error = null;
        _stackTrace = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      final colorScheme = Theme.of(context).colorScheme;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'PLY 模型渲染失败',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.error),
              ),
              const SizedBox(height: 8),
              Text(
                '错误信息: $_error',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _stackTrace = null;
                  });
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    return widget.child;
  }
}
