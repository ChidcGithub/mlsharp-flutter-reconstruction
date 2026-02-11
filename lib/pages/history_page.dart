import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:flutter_gaussian_splatter/widgets/gaussian_splatter_widget.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '../services/history_service.dart';
import '../services/inference_logger.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _showDeleteAllDialog,
            tooltip: '清空历史记录',
          ),
        ],
      ),
      body: _buildHistoryList(),
    );
  }

  Widget _buildHistoryList() {
    return Consumer<HistoryService>(
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
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        '暂无历史记录',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '生成3D模型后将在这里显示',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: historyItems.length,
                itemBuilder: (context, index) {
                  final item = historyItems[index];
                  return _buildHistoryItemCard(item);
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHistoryItemCard(HistoryItem item) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _viewHistoryItem(item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 缩略图或图标
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              // 详细信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.imageFileName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '生成时间: ${_formatDateTime(item.timestamp)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '格式: ${_getModelFormat(item.modelUrl)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // 操作按钮
              PopupMenuButton<String>(
                onSelected: (value) => _handleMenuSelection(value, item),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'view',
                    child: Text('查看'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('删除'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getModelFormat(String modelUrl) {
    final extension = modelUrl.split('.').last.toLowerCase();
    switch (extension) {
      case 'ply':
        return 'PLY';
      case 'glb':
        return 'GLB';
      case 'gltf':
        return 'GLTF';
      default:
        return extension.toUpperCase();
    }
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

  void _viewHistoryItem(HistoryItem item) {
    // 导航到3D模型查看页面
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => HistoryItemViewer(historyItem: item),
      ),
    );
  }

  void _handleMenuSelection(String value, HistoryItem item) {
    switch (value) {
      case 'view':
        _viewHistoryItem(item);
        break;
      case 'delete':
        _deleteHistoryItem(item);
        break;
    }
  }

  void _deleteHistoryItem(HistoryItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 "${item.imageFileName}" 的历史记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final historyService = context.read<HistoryService>();
              await historyService.removeFromHistory(item.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已删除历史记录')),
                );
                setState(() {}); // 刷新列表
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteAllDialog() async {
    final historyService = context.read<HistoryService>();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空历史记录'),
        content: const Text('确定要清空所有历史记录吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result == true) {
      await historyService.clearHistory();
      if (mounted) {
        setState(() {}); // 刷新列表
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('历史记录已清空')),
      );
    }
  }
}

class HistoryItemViewer extends StatefulWidget {
  final HistoryItem historyItem;

  const HistoryItemViewer({super.key, required this.historyItem});

  @override
  State<HistoryItemViewer> createState() => _HistoryItemViewerState();
}

class _HistoryItemViewerState extends State<HistoryItemViewer> {
  late ViewerType _currentViewerType;

  @override
  void initState() {
    super.initState();
    _currentViewerType = widget.historyItem.viewerType;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.historyItem.imageFileName),
        elevation: 0,
        actions: [
          SegmentedButton<ViewerType>(
            segments: const [
              ButtonSegment(
                value: ViewerType.threejs,
                label: Text('3D'),
                icon: Icon(Icons.threed_rotation),
              ),
              ButtonSegment(
                value: ViewerType.gaussianSplatter,
                label: Text('PLY'),
                icon: Icon(Icons.scatter_plot),
              ),
              ButtonSegment(
                value: ViewerType.webview,
                label: Text('Web'),
                icon: Icon(Icons.web),
              ),
            ],
            selected: {_currentViewerType},
            onSelectionChanged: (Set<ViewerType> newSelection) {
              setState(() {
                _currentViewerType = newSelection.first;
              });
              // 注意：HistoryItem是不可变的，我们不能直接修改它
              // 如果需要保存查看器类型更改，需要通过其他方式实现
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                const Icon(Icons.info, size: 16),
                const SizedBox(width: 8),
                Text(
                  _getViewerTypeName(_currentViewerType),
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildCurrentViewer(context, colorScheme),
          ),
        ],
      ),
    );
  }

  String _getViewerTypeName(ViewerType type) {
    switch (type) {
      case ViewerType.threejs:
        return 'Three.js查看器';
      case ViewerType.gaussianSplatter:
        return 'Gaussian Splatter查看器';
      case ViewerType.webview:
        return 'WebView查看器';
    }
  }

  void _changeViewerType(ViewerType newType) async {
    setState(() {
      _currentViewerType = newType;
    });

    // 更新历史记录中的查看器类型
    final historyItem = widget.historyItem;
    final updatedItem = HistoryItem(
      id: historyItem.id,
      imageUrl: historyItem.imageUrl,
      modelUrl: historyItem.modelUrl,
      localModelPath: historyItem.localModelPath,
      timestamp: historyItem.timestamp,
      imageFileName: historyItem.imageFileName,
      viewerType: newType,
    );

    final historyService = context.read<HistoryService>();
    await historyService.removeFromHistory(historyItem.id);
    await historyService.addToHistory(updatedItem);
  }

  Widget _buildCurrentViewer(BuildContext context, ColorScheme colorScheme) {
    switch (_currentViewerType) {
      case ViewerType.threejs:
        return _buildModelViewer(context, colorScheme);
      case ViewerType.gaussianSplatter:
        return _buildPlyViewer(context);
      case ViewerType.webview:
        return _buildWebView(context, colorScheme);
    }
  }

  Widget _buildPlyViewer(BuildContext context) {
    // 使用GaussianSplatterWidget显示PLY格式的模型
    final colorScheme = Theme.of(context).colorScheme;
    try {
      return Container(
        color: colorScheme.surfaceContainerLow,
        child: GaussianSplatterWidget(
          assetPath: widget.historyItem.localModelPath,
        ),
      );
    } catch (e) {
      return Container(
        color: colorScheme.surfaceContainerLow,
        child: Center(
          child: Text('无法加载PLY模型: $e'),
        ),
      );
    }
  }

  Widget _buildModelViewer(BuildContext context, ColorScheme colorScheme) {
    // 使用ModelViewer显示3D模型
    try {
      return ModelViewer(
        backgroundColor: colorScheme.surfaceContainerLow,
        src: widget.historyItem.localModelPath.startsWith('http') 
            ? widget.historyItem.localModelPath 
            : 'file://${widget.historyItem.localModelPath}',
        alt: "历史记录中的3D模型",
        ar: true,
        arModes: const ['scene-viewer', 'webxr', 'quick-look'],
        autoRotate: false,
        cameraControls: true,
        exposure: 1.0,
        environmentImage: null,
        loading: Loading.lazy,
      );
    } catch (e) {
      return Container(
        color: colorScheme.surfaceContainerLow,
        child: Center(
          child: Text('无法加载模型: $e'),
        ),
      );
    }
  }

  Widget _buildWebView(BuildContext context, ColorScheme colorScheme) {
    // 使用WebView显示自定义HTML查看器
    try {
      // 检查模型文件是否存在
      if (!File(widget.historyItem.localModelPath).existsSync()) {
        return Container(
          color: colorScheme.surfaceContainerLow,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  '模型文件不存在',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.error),
                ),
                const SizedBox(height: 8),
                Text(
                  '路径: ${widget.historyItem.localModelPath}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        );
      }
      
      // 从viewer.html创建WebView
      final String htmlContent = _createViewerHtml(widget.historyItem.localModelPath);
      
      late final WebViewController controller;
      controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String url) {
              // 页面加载完成后可能需要执行一些初始化
            },
          ),
        )
        ..loadRequest(
          Uri.parse(
            Uri.dataFromString(
              htmlContent,
              mimeType: 'text/html',
              encoding: Encoding.getByName('utf-8'),
            ).toString(),
          ),
        );

      return WebViewWidget(controller: controller);
    } catch (e) {
      return Container(
        color: colorScheme.surfaceContainerLow,
        child: Center(
          child: Text('无法加载WebView: $e'),
        ),
      );
    }
  }

  String _createViewerHtml(String modelPath) {
    // 从viewer.html提取核心渲染逻辑
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>3D Model Viewer</title>
    <style>
        body { margin: 0; overflow: hidden; background-color: #121212; }
        #container { width: 100vw; height: 100vh; display: block; }
        #loading { 
            position: absolute; 
            top: 0; left: 0; 
            width: 100%; height: 100%; 
            display: flex; 
            justify-content: center; 
            align-items: center; 
            background-color: #121212; 
            color: #d4af37; 
            font-family: Arial, sans-serif;
        }
    </style>
    <script type="importmap">
        {
            "imports": {
                "three": "https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.module.js",
                "three/addons/": "https://cdn.jsdelivr.net/npm/three@0.160.0/examples/jsm/"
            }
        }
    </script>
</head>
<body>
    <div id="loading">加载中...</div>
    <div id="container"></div>
    
    <script type="module">
        import * as THREE from 'three';
        
        // 简化的PLY加载器
        class PLYLoader {
            parse(data) {
                // 这是一个简化的PLY解析器，实际实现会更复杂
                const text = new TextDecoder().decode(data);
                const lines = text.split('\\n');
                
                let vertexCount = 0;
                let headerEnded = false;
                const vertices = [];
                const colors = [];
                
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim();
                    if (line === 'end_header') {
                        headerEnded = true;
                        continue;
                    }
                    
                    if (!headerEnded) {
                        if (line.startsWith('element vertex')) {
                            vertexCount = parseInt(line.split(' ')[2]);
                        }
                        continue;
                    }
                    
                    if (headerEnded && line) {
                        const values = line.split(' ').map(Number);
                        if (values.length >= 6) { // x, y, z, r, g, b
                            vertices.push(...values.slice(0, 3));
                            colors.push(...values.slice(3, 6).map(c => c / 255));
                        }
                    }
                }
                
                return { vertices, colors };
            }
        }
        
        // 初始化场景
        const scene = new THREE.Scene();
        scene.background = new THREE.Color(0x121212);
        
        const camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.1, 1000);
        camera.position.z = 5;
        
        const renderer = new THREE.WebGLRenderer({ antialias: true });
        renderer.setSize(window.innerWidth, window.innerHeight);
        document.getElementById('container').appendChild(renderer.domElement);
        
        // 创建点云几何体
        const geometry = new THREE.BufferGeometry();
        const material = new THREE.PointsMaterial({ size: 0.02, vertexColors: true });
        const points = new THREE.Points(geometry, material);
        scene.add(points);
        
        // 添加光源
        const ambientLight = new THREE.AmbientLight(0xffffff, 0.6);
        scene.add(ambientLight);
        
        const directionalLight = new THREE.DirectionalLight(0xffffff, 0.8);
        directionalLight.position.set(1, 1, 1);
        scene.add(directionalLight);
        
        // 加载PLY文件
        fetch('$modelPath')
            .then(response => response.arrayBuffer())
            .then(data => {
                const loader = new PLYLoader();
                const result = loader.parse(data);
                
                geometry.setAttribute('position', new THREE.Float32BufferAttribute(result.vertices, 3));
                geometry.setAttribute('color', new THREE.Float32BufferAttribute(result.colors, 3));
                
                // 调整模型大小和位置
                geometry.computeBoundingSphere();
                const center = geometry.boundingSphere.center;
                const radius = geometry.boundingSphere.radius;
                
                points.position.x = -center.x;
                points.position.y = -center.y;
                points.position.z = -center.z;
                
                const scale = 3 / radius;
                points.scale.set(scale, scale, scale);
                
                // 隐藏加载指示器
                document.getElementById('loading').style.display = 'none';
            })
            .catch(error => {
                console.error('Error loading PLY file:', error);
                document.getElementById('loading').textContent = '加载失败: ' + error.message;
            });
        
        // 相机控制
        let isDragging = false;
        let previousMousePosition = { x: 0, y: 0 };
        
        document.addEventListener('mousedown', (e) => {
            isDragging = true;
            previousMousePosition = { x: e.clientX, y: e.clientY };
        });
        
        document.addEventListener('mousemove', (e) => {
            if (isDragging) {
                const deltaX = e.clientX - previousMousePosition.x;
                const deltaY = e.clientY - previousMousePosition.y;
                
                points.rotation.y += deltaX * 0.01;
                points.rotation.x += deltaY * 0.01;
                
                previousMousePosition = { x: e.clientX, y: e.clientY };
            }
        });
        
        document.addEventListener('mouseup', () => {
            isDragging = false;
        });
        
        document.addEventListener('mouseleave', () => {
            isDragging = false;
        });
        
        // 缩放控制
        document.addEventListener('wheel', (e) => {
            e.preventDefault();
            camera.position.z += e.deltaY * 0.01;
            camera.position.z = Math.max(1, Math.min(20, camera.position.z));
        });
        
        // 响应窗口大小变化
        window.addEventListener('resize', () => {
            camera.aspect = window.innerWidth / window.innerHeight;
            camera.updateProjectionMatrix();
            renderer.setSize(window.innerWidth, window.innerHeight);
        });
        
        // 渲染循环
        function animate() {
            requestAnimationFrame(animate);
            renderer.render(scene, camera);
        }
        animate();
    </script>
</body>
</html>
    ''';
  }
}