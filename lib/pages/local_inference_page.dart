import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../services/onnx_inference_service.dart';
import '../services/inference_logger.dart';

class LocalInferencePage extends StatefulWidget {
  const LocalInferencePage({super.key});

  @override
  State<LocalInferencePage> createState() => _LocalInferencePageState();
}

class _LocalInferencePageState extends State<LocalInferencePage> {
  final OnnxInferenceService _inferenceService = OnnxInferenceService();
  final ImagePicker _picker = ImagePicker();
  
  File? _selectedImage;
  File? _selectedModel;
  bool _isInferencing = false;
  bool _useNpu = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inferenceService.setLogger(context.read<InferenceLogger>());
      context.read<InferenceLogger>().info('本地推理页面已就绪');
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        context.read<InferenceLogger>().info('已选择本地推理图像: ${image.name}');
      }
    } catch (e) {
      context.read<InferenceLogger>().error('选择图片失败', error: e);
    }
  }

  Future<void> _pickModel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        dialogTitle: '选择 ONNX 模型',
      );

      if (result != null && result.files.isNotEmpty) {
        final fileName = result.files.first.name.toLowerCase();
        if (fileName.endsWith('.onnx') || fileName.endsWith('.pb') || fileName.endsWith('.tflite')) {
          final modelFile = File(result.files.first.path!);
          setState(() {
            _selectedModel = modelFile;
          });
          context.read<InferenceLogger>().info('已选择模型文件: ${result.files.first.name}');
          await _loadModel(modelFile.path);
        } else {
          context.read<InferenceLogger>().warning('不支持的文件格式，请选择 .onnx, .pb 或 .tflite');
        }
      }
    } catch (e) {
      context.read<InferenceLogger>().error('选择模型失败', error: e);
    }
  }

  Future<void> _loadModel(String modelPath) async {
    try {
      setState(() {
        _isInferencing = true;
      });
      await _inferenceService.initializeModel(
        modelPath,
        useNpu: _useNpu,
      );
      setState(() {
        _isInferencing = false;
      });
    } catch (e) {
      setState(() {
        _isInferencing = false;
      });
    }
  }

  Future<void> _runInference() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先选择图片')));
      return;
    }

    if (!_inferenceService.isModelLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先加载模型')));
      return;
    }

    try {
      setState(() {
        _isInferencing = true;
      });
      
      final dummyInput = List<List<double>>.generate(
        1,
        (i) => List<double>.generate(224 * 224 * 3, (j) => 0.5),
      );

      await _inferenceService.runInference(dummyInput);
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('本地推理完成')));
      setState(() {
        _isInferencing = false;
      });
    } catch (e) {
      setState(() {
        _isInferencing = false;
      });
    }
  }

  @override
  void dispose() {
    _inferenceService.releaseModel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('本地推理'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 模型配置卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.primaryContainer,
                          ),
                          child: Icon(
                            Icons.model_training,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '模型配置',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _pickModel,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('选择 ONNX 模型'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_selectedModel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '已选择: ${_selectedModel!.path.split('/').last}',
                                style: const TextStyle(fontSize: 12, color: Colors.green),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colorScheme.errorContainer),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.cancel, color: colorScheme.error, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              '未选择模型',
                              style: TextStyle(fontSize: 12, color: colorScheme.error),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('启用骁龙 NPU'),
                      subtitle: const Text('使用 NPU 加速推理'),
                      value: _useNpu,
                      onChanged: (value) {
                        setState(() {
                          _useNpu = value;
                        });
                        context.read<InferenceLogger>().info('NPU 加速已${value ? "开启" : "关闭"}');
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 图片选择卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.secondaryContainer,
                          ),
                          child: Icon(
                            Icons.image,
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '输入图片',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_selectedImage != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _selectedImage!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: colorScheme.outlineVariant),
                          borderRadius: BorderRadius.circular(12),
                          color: colorScheme.surfaceContainerLow,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image_outlined, size: 48, color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
                              const SizedBox(height: 8),
                              Text(
                                '未选择图片',
                                style: TextStyle(color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('选择图片'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 推理按钮
            if (_isInferencing)
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      const Text('正在处理中'),
                    ],
                  ),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _runInference,
                icon: const Icon(Icons.play_arrow),
                label: const Text('开始推理'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
