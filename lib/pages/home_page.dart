import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:flutter_gaussian_splatter/widgets/gaussian_splatter_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:gal/gal.dart';
import 'package:uuid/uuid.dart';
import '../providers/app_settings_provider.dart';
import '../services/backend_api_service.dart';
import '../services/inference_logger.dart';
import '../services/history_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isConnected = false;
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

  @override
  void dispose() {
    super.dispose();
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

  Future<String> _downloadModel(String url) async {
    try {
      final logger = context.read<InferenceLogger>();
      String fullUrl = url;
      if (!url.startsWith('http')) {
        final backendUrl = context.read<AppSettingsProvider>().backendUrl;
        // 确保 backendUrl 不以 / 结尾，url 以 / 开头
        final base = backendUrl.endsWith('/') ? backendUrl.substring(0, backendUrl.length - 1) : backendUrl;
        final path = url.startsWith('/') ? url : '/$url';
        fullUrl = '$base$path';
      }
      
      logger.debug('正在从完整 URL 下载模型: $fullUrl');
      final response = await http.get(Uri.parse(fullUrl));
      
      if (response.statusCode == 200) {
        logger.debug('模型下载成功，文件大小: ${response.bodyBytes.length} bytes');
        
        // 获取历史记录服务的路径
        final historyService = context.read<HistoryService>();
        final modelsPath = historyService.getModelsPath();
        
        // 生成唯一的文件名
        final fileExtension = url.split('.').last.toLowerCase();
        final fileName = 'model_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
        final modelFile = File('$modelsPath/$fileName');
        await modelFile.writeAsBytes(response.bodyBytes);
        
        logger.debug('模型文件已保存到: ${modelFile.path}');
        logger.debug('文件是否存在: ${modelFile.existsSync()}');
        logger.debug('文件大小: ${modelFile.lengthSync()} bytes');
        
        logger.success('模型文件准备就绪，路径: ${modelFile.path}');
        return modelFile.path;
      } else {
        logger.error('模型下载失败，状态码: ${response.statusCode}');
        logger.debug('响应内容: ${response.body}');
        return '';
      }
    } catch (e) {
      if (mounted) {
        final logger = context.read<InferenceLogger>();
        logger.error('下载模型失败', error: e);
        logger.error('错误详情: ${e.toString()}');
      }
      return '';
    }
  }

  Future<void> _downloadPly(String url) async {
    try {
      final logger = context.read<InferenceLogger>();
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
        final plyFile = File('${directory.path}/temp_model.ply');
        await plyFile.writeAsBytes(response.bodyBytes);
        
        logger.debug('PLY 文件已保存到: ${plyFile.path}');
        logger.debug('文件是否存在: ${plyFile.existsSync()}');
        logger.debug('文件大小: ${plyFile.lengthSync()} bytes');
        
        if (mounted) {
          setState(() {
            _localPlyPath = plyFile.path;
          });
        }
        
        logger.success('PLY 文件准备就绪，路径: ${plyFile.path}');
      } else {
        logger.error('PLY 下载失败，状态码: ${response.statusCode}');
        logger.debug('响应内容: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        final logger = context.read<InferenceLogger>();
        logger.error('下载 PLY 失败', error: e);
      }
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
          
          setState(() {
            _modelUrl = url;
            _exposure = 1.0;
            _environmentImage = 'neutral';
          });
          
          // 检查是否为PLY格式，并需要下载到本地
          String localModelPath = '';
          if (url.toLowerCase().endsWith('.ply')) {
            logger.warning('检测到模型格式为 PLY');
            logger.info('提示：PLY 格式在移动端预览可能显示为空白或加载缓慢');
            logger.info('建议：可以尝试使用较小的 PLY 文件或使用 GLB/GLTF 格式');
            await _downloadPly(url);
            // 设置本地模型路径
            if (_localPlyPath != null) {
              localModelPath = _localPlyPath!;
            }
          } else {
            logger.info('检测到模型格式为: ${url.split('.').last.toUpperCase()}');
            logger.info('该格式通常在移动设备上有更好的兼容性');
            // 对于非PLY格式，我们可能需要下载到本地
            localModelPath = await _downloadModel(url);
          }
          
          // 保存到历史记录 - 在异步操作中检查mounted状态
          if (mounted) {
            await _saveToHistory(url, localModelPath);
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

  // 根据模型URL决定使用哪种3D查看器
  Widget _getModelViewer(ColorScheme colorScheme) {
    final String modelFormat = _modelUrl!.split('.').last.toLowerCase();
    
    switch (modelFormat) {
      case 'ply':
        // PLY格式需要先下载到本地再使用GaussianSplatterWidget渲染
        if (_localPlyPath != null) {
          return _buildPlyViewer();
        } else {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在下载 PLY 模型...'),
              ],
            ),
          );
        }
      case 'glb':
      case 'gltf':
      case 'obj':
      case 'fbx':
        // 使用ModelViewer渲染标准3D格式
        final fullUrl = _modelUrl!.startsWith('http') 
            ? _modelUrl! 
            : '${context.read<AppSettingsProvider>().backendUrl}${_modelUrl!.startsWith('/') ? '' : '/'}$_modelUrl';
            
        return ModelViewer(
          key: ValueKey('$_modelUrl-$_exposure-$_environmentImage'),
          backgroundColor: colorScheme.surfaceContainerLow,
          src: fullUrl,
          alt: "生成的 3D 模型",
          ar: true,
          arModes: const ['scene-viewer', 'webxr', 'quick-look'],
          autoRotate: false,
          cameraControls: true,
          exposure: _exposure,
          environmentImage: _environmentImage == 'neutral' ? null : _environmentImage,
          loading: Loading.lazy,
        );
      default:
        // 对于未知格式，尝试使用ModelViewer，如果失败则显示错误信息
        final fullUrl = _modelUrl!.startsWith('http') 
            ? _modelUrl! 
            : '${context.read<AppSettingsProvider>().backendUrl}${_modelUrl!.startsWith('/') ? '' : '/'}$_modelUrl';
            
        return ModelViewer(
          key: ValueKey('$_modelUrl-$_exposure-$_environmentImage'),
          backgroundColor: colorScheme.surfaceContainerLow,
          src: fullUrl,
          alt: "生成的 3D 模型 (格式: $modelFormat)",
          ar: true,
          arModes: const ['scene-viewer', 'webxr', 'quick-look'],
          autoRotate: false,
          cameraControls: true,
          exposure: _exposure,
          environmentImage: _environmentImage == 'neutral' ? null : _environmentImage,
          loading: Loading.lazy,
        );
    }
  }

  Future<void> _saveToHistory(String modelUrl, String localModelPath) async {
    try {
      if (!mounted) return;
      
      final logger = context.read<InferenceLogger>();
      final historyService = context.read<HistoryService>();
      final imageFileName = _image!.path.split('/').last;
      
      // 根据模型格式选择合适的查看器类型
      ViewerType viewerType;
      if (modelUrl.toLowerCase().endsWith('.ply')) {
        viewerType = ViewerType.gaussianSplatter; // PLY格式使用GaussianSplatter查看器
      } else {
        viewerType = ViewerType.threejs; // 其他格式使用Three.js查看器
      }
      
      final historyItem = HistoryItem(
        id: const Uuid().v4(),
        imageUrl: _image!.path,
        modelUrl: modelUrl,
        localModelPath: localModelPath,
        timestamp: DateTime.now(),
        imageFileName: imageFileName,
        viewerType: viewerType,
      );
      
      await historyService.addToHistory(historyItem);
      logger.info('模型已保存到历史记录: $imageFileName');
    } catch (e) {
      if (mounted) {
        final logger = context.read<InferenceLogger>();
        logger.error('保存模型到历史记录失败', error: e);
      }
    }
  }

// 显示渲染器选择对话框
  Future<void> _showRendererSelectionDialog() async {
    final selected = await showDialog<ViewerType>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('选择渲染器'),
          content: SizedBox(
            width: double.maxFinite, // 确保内容宽度合适
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.threed_rotation),
                  title: const Text('Three.js渲染器'),
                  subtitle: const Text('适用于GLB/GLTF格式'),
                  onTap: () => Navigator.pop(context, ViewerType.threejs),
                ),
                ListTile(
                  leading: const Icon(Icons.scatter_plot),
                  title: const Text('Gaussian Splatter'),
                  subtitle: const Text('适用于PLY格式'),
                  onTap: () => Navigator.pop(context, ViewerType.gaussianSplatter),
                ),
                ListTile(
                  leading: const Icon(Icons.web),
                  title: const Text('WebView渲染器'),
                  subtitle: const Text('高级Three.js渲染'),
                  onTap: () => Navigator.pop(context, ViewerType.webview),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );

    if (selected != null && mounted) {
      // 这里可以更新当前渲染器类型
      // 由于当前实现没有状态保存渲染器类型，我们只是通知用户选择
      final snackBar = SnackBar(
        content: Text('已选择: ${_getViewerTypeName(selected)}'),
        duration: const Duration(seconds: 2),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }
  }
  
  String _getViewerTypeName(ViewerType type) {
    switch (type) {
      case ViewerType.threejs:
        return 'Three.js渲染器';
      case ViewerType.gaussianSplatter:
        return 'Gaussian Splatter';
      case ViewerType.webview:
        return 'WebView渲染器';
      default:
        return '默认渲染器';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('MLSharp 3D Maker'),
        elevation: 0,
        actions: [
          // 连接状态指示器
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isConnected 
                  ? colorScheme.primaryContainer
                  : colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isConnected ? Icons.cloud_done : Icons.cloud_off,
                  size: 16,
                  color: _isConnected ? colorScheme.primary : colorScheme.error,
                ),
                const SizedBox(width: 4),
                Text(
                  _isConnected ? '已连接' : '未连接',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isConnected ? colorScheme.onPrimaryContainer : colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Consumer<HistoryService>(
        builder: (context, historyService, child) {
          return RefreshIndicator(
            onRefresh: () async {
              // 刷新历史记录列表
              if (mounted) {
                setState(() {});
              }
            },
            child: FutureBuilder<List<HistoryItem>>(
              future: historyService.getHistory(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('加载历史记录出错: ${snapshot.error}'));
                }

                final historyItems = snapshot.data ?? [];

                if (historyItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 80,
                          color: colorScheme.primary.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          '还没有作品',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '点击右下角的 + 按钮开始创建您的第一个3D作品',
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                // 使用GridView显示历史记录项目，类似小红书的两列布局
                return GridView.builder(
                  padding: const EdgeInsets.all(8.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // 两列布局
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.85, // 控制项目的宽高比
                  ),
                  itemCount: historyItems.length,
                  itemBuilder: (context, index) {
                    final item = historyItems[index];
                    return _buildHistoryItemGrid(item);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  // 构建网格项
  Widget _buildHistoryItemGrid(HistoryItem item) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: () {
          // 导航到历史记录详情页面
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HistoryItemViewer(historyItem: item),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图片预览
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                child: Image.file(
                  File(item.imageUrl),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.image_not_supported,
                        color: colorScheme.onSurfaceVariant,
                        size: 32,
                      ),
                    );
                  },
                ),
              ),
            ),
            // 底部信息
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.imageFileName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 10,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDateTime(item.timestamp),
                        style: TextStyle(
                          fontSize: 9,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }
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
                            child: _getModelViewer(colorScheme),
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
                                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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
                                      const SizedBox(height: 8),
                                      if (_modelUrl != null)
                                        FloatingActionButton.small(
                                          heroTag: 'renderer',
                                          onPressed: _showRendererSelectionDialog,
                                          child: const Icon(Icons.view_in_ar),
                                          tooltip: '选择渲染器',
                                        ),
                                    ],
                                  ),
                                ),                  if (_showEditor)
                    Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: Card(
                        color: colorScheme.surface.withValues(alpha: 0.9),
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
    
    // 检查本地PLY文件是否存在
    if (_localPlyPath == null || !File(_localPlyPath!).existsSync()) {
      logger.error('PLY 文件不存在或路径为空: $_localPlyPath');
      return Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  'PLY 模型文件不存在',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.error),
                ),
                const SizedBox(height: 8),
                Text(
                  '请重新生成模型',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // 开始加载计时
    if (!_isPlyLoading) {
      _isPlyLoading = true;
      _plyLoadingTimer?.cancel();
      _plyLoadingTimer = Timer(const Duration(seconds: 120), () { // 增加超时时间到120秒
        if (mounted && _isPlyLoading) {
          logger.warning('PLY 模型加载超时（120秒）');
          logger.info('提示: PLY 文件较大，可能需要更长时间加载');
          logger.info('建议: 可以尝试使用较小的 PLY 文件或转换为 GLB 格式');
          setState(() {
            _isPlyLoading = false;
          });
        }
      });
    }
    
    return Stack(
      children: [
        // PLY 渲染器（带错误捕获）
        Builder(
          builder: (context) {
            return ErrorBoundary(
              onError: (error, stackTrace) {
                logger.error('PLY 渲染错误: $error', error: error, stackTrace: stackTrace);
                logger.error('PLY 路径: $_localPlyPath');
                
                // 检查文件是否存在
                if (_localPlyPath != null) {
                  final file = File(_localPlyPath!);
                  logger.error('文件存在: ${file.existsSync()}');
                  if (file.existsSync()) {
                    logger.error('文件大小: ${file.lengthSync()} bytes');
                  }
                }
                
                setState(() {
                  _isPlyLoading = false;
                });
              },
              child: Container(
                color: colorScheme.surfaceContainerLow,
                child: GaussianSplatterWidget(
                  assetPath: _localPlyPath!,
                ),
              ),
            );
          },
        ),
        // 加载状态指示器
        Positioned(
          top: 10,
          left: 10,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text('加载 PLY 模型... (${(File(_localPlyPath!).lengthSync() / 1024 / 1024).toStringAsFixed(1)} MB)', style: const TextStyle(fontSize: 12)),
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
                logger.debug('文件修改时间: ${file.lastModifiedSync()}');
              }
            },
            child: const Icon(Icons.bug_report),
            tooltip: '调试信息',
          ),
        ),
        // 错误提示和重试按钮（超时后显示）
        if (!_isPlyLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time, size: 48, color: colorScheme.error),
                        const SizedBox(height: 16),
                        Text(
                          'PLY 模型加载超时',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.error),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '文件较大，加载时间可能较长',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                        Text(
                          '文件路径: ${_localPlyPath ?? 'N/A'}',
                          style: const TextStyle(fontSize: 10, color: Colors.white70),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isPlyLoading = true;
                              _plyLoadingTimer?.cancel();
                              _plyLoadingTimer = Timer(const Duration(seconds: 120), () {
                                if (mounted && _isPlyLoading) {
                                  logger.warning('PLY 模型加载超时（120秒）');
                                  setState(() {
                                    _isPlyLoading = false;
                                  });
                                }
                              });
                            });
                          },
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
  FlutterErrorDetails? _errorDetails;

  @override
  void initState() {
    super.initState();
    // 设置全局错误处理
    FlutterError.onError = (FlutterErrorDetails details) {
      if (mounted) {
        setState(() {
          _error = details.exception;
          _errorDetails = details;
        });
      }
    };
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
                '错误信息: ${_error.toString()}',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // 重置错误状态并调用外部错误处理函数
                  setState(() {
                    _error = null;
                    _errorDetails = null;
                  });
                  // 如果有外部错误处理函数，则调用它
                  if (widget.onError != null) {
                    widget.onError!(_error!, _errorDetails?.stack ?? StackTrace.empty);
                  }
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    // 使用Builder包装widget.child以确保它正确构建
    return Builder(
      builder: (context) {
        return widget.child;
      },
    );
  }

  @override
  void dispose() {
    FlutterError.onError = null;
    super.dispose();
  }
}
