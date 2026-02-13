import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../providers/app_settings_provider.dart';
import '../services/backend_api_service.dart';
import '../services/inference_logger.dart';
import '../services/history_service.dart';
import 'history_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isConnected = false;
  bool _isGenerating = false;
  late BackendApiService _apiService;
  final ImagePicker _picker = ImagePicker();
  
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
    if (mounted) {
      setState(() {
        _isConnected = connected;
      });
    }
  }

  Future<void> _pickAndGenerate() async {
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先连接后端服务器')),
      );
      return;
    }

    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: context.read<AppSettingsProvider>().imageQuality,
    );

    if (image == null) return;

    setState(() => _isGenerating = true);
    final logger = context.read<InferenceLogger>();
    final historyService = context.read<HistoryService>();
    final baseUrl = context.read<AppSettingsProvider>().backendUrl;

    try {
      logger.info('开始上传图片进行 3D 生成...');
      final result = await _apiService.predictImage(File(image.path));

      if (result != null && result['status'] == 'success') {
        String modelUrl = result['url'];
        if (!modelUrl.startsWith('http')) {
          modelUrl = baseUrl + (modelUrl.startsWith('/') ? '' : '/') + modelUrl;
        }
        
        logger.info('生成成功，正在下载模型...');
        final downloadedPath = await _downloadModel(modelUrl);
        
        if (downloadedPath != null) {
          final timestamp = DateTime.now();
          final isPly = modelUrl.toLowerCase().endsWith('.ply');
          
          final historyItem = HistoryItem(
            id: timestamp.millisecondsSinceEpoch.toString(),
            imageUrl: image.path,
            modelUrl: modelUrl,
            localModelPath: downloadedPath,
            timestamp: timestamp,
            imageFileName: '作品_${timestamp.hour}${timestamp.minute}${timestamp.second}',
            viewerType: isPly ? ViewerType.gaussianSplatter : ViewerType.threejs,
          );
          
          await historyService.addToHistory(historyItem);
          logger.success('作品已保存到历史记录');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('3D 作品生成并保存成功！')),
            );
          }
        }
      } else {
        logger.error('模型生成失败');
      }
    } catch (e) {
      logger.error('生成过程中出错', error: e);
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<String?> _downloadModel(String modelUrl) async {
    try {
      final response = await http.get(Uri.parse(modelUrl));
      if (response.statusCode == 200) {
        final appDir = await getApplicationDocumentsDirectory();
        final ext = modelUrl.split('.').last;
        final fileName = 'model_${DateTime.now().millisecondsSinceEpoch}.$ext';
        final file = File('${appDir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        return file.path;
      }
    } catch (e) {
      context.read<InferenceLogger>().error('下载模型失败', error: e);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Ansharp', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              _isConnected ? Icons.cloud_done : Icons.cloud_off,
              color: _isConnected ? colorScheme.primary : colorScheme.error,
            ),
            onPressed: _checkConnection,
          ),
        ],
      ),
      body: Stack(
        children: [
          Consumer<HistoryService>(
            builder: (context, historyService, child) {
              return FutureBuilder<List<HistoryItem>>(
                future: historyService.getHistory(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final items = snapshot.data ?? [];

                  if (items.isEmpty) {
                    return _buildEmptyState(colorScheme);
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      await _checkConnection();
                      historyService.reloadHistory();
                    },
                    child: GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) => _buildMasonryCard(items[index], colorScheme),
                    ),
                  );
                },
              );
            },
          ),
          if (_isGenerating)
            Container(
              color: Colors.black26,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        const Text('正在生成 3D 模型...', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('这可能需要一分钟时间', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isGenerating ? null : _pickAndGenerate,
        icon: const Icon(Icons.add_a_photo),
        label: const Text('添加作品'),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome, size: 80, color: colorScheme.primary.withOpacity(0.2)),
          const SizedBox(height: 24),
          const Text('开启您的 3D 创作', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('点击下方按钮上传图片生成模型', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildMasonryCard(HistoryItem item, ColorScheme colorScheme) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => HistoryItemViewer(historyItem: item)),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(item.imageUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(color: colorScheme.surfaceVariant),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        item.modelUrl.split('.').last.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.imageFileName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 12, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        _formatDateTime(item.timestamp),
                        style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
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
    final diff = now.difference(dateTime);
    if (diff.inDays > 0) return '${diff.inDays}天前';
    if (diff.inHours > 0) return '${diff.inHours}小时前';
    if (diff.inMinutes > 0) return '${diff.inMinutes}分钟前';
    return '刚刚';
  }
}
