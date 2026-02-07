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
    _addLog('本地推理引擎已初始化');
  }

  void _addLog(String message) {
    context.read<InferenceLogger>().addLog(message);
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        _addLog('已选择图片: ${image.name}');
      }
    } catch (e) {
      _addLog('选择图片失败: $e');
    }
  }

  Future<void> _pickModel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['onnx', 'pb', 'tflite'],
        dialogTitle: '选择 ONNX 模型',
      );

      if (result != null && result.files.isNotEmpty) {
        final modelFile = File(result.files.first.path!);
        setState(() {
          _selectedModel = modelFile;
        });
        _addLog('已选择模型: ${result.files.first.name}');
        
        // 尝试加载模型
        await _loadModel(modelFile.path);
      }
    } catch (e) {
      _addLog('选择模型失败: $e');
    }
  }

  Future<void> _loadModel(String modelPath) async {
    try {
      setState(() {
        _isInferencing = true;
      });
      _addLog('正在加载模型...');
      
      await _inferenceService.initializeModel(
        modelPath,
        useNpu: _useNpu,
      );
      
      _addLog('模型加载成功');
      _addLog('NPU 加速: $_useNpu');
      
      setState(() {
        _isInferencing = false;
      });
    } catch (e) {
      _addLog('模型加载失败: $e');
      setState(() {
        _isInferencing = false;
      });
    }
  }

  Future<void> _runInference() async {
    if (_selectedImage == null) {
      _addLog('请先选择图片');
      return;
    }

    if (!_inferenceService.isModelLoaded) {
      _addLog('请先加载模型');
      return;
    }

    try {
      setState(() {
        _isInferencing = true;
      });
      _addLog('开始本地推理...');
      
      // 这是一个示例推理过程
      // 实际应用中需要根据模型的输入格式进行处理
      final dummyInput = List<List<double>>.generate(
        1,
        (i) => List<double>.generate(224 * 224 * 3, (j) => 0.5),
      );

      final results = await _inferenceService.runInference(dummyInput);
      
      _addLog('推理完成，输出数量: ${results.length}');
      _addLog('推理结果已生成');
      
      setState(() {
        _isInferencing = false;
      });
    } catch (e) {
      _addLog('推理失败: $e');
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('本地推理'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 模型选择卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '模型配置',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      Text(
                        '已选择: ${_selectedModel!.path.split('/').last}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      )
                    else
                      const Text(
                        '未选择模型',
                        style: TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('启用骁龙 NPU'),
                      subtitle: const Text('使用 NPU 加速推理（如果硬件支持）'),
                      value: _useNpu,
                      onChanged: (value) {
                        setState(() {
                          _useNpu = value;
                        });
                        _addLog('NPU 加速: $value');
                      },
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
                    const Text(
                      '输入图片',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    if (_selectedImage != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _selectedImage!,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image_outlined, size: 48, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('未选择图片'),
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
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在推理中...'),
                  ],
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _runInference,
                icon: const Icon(Icons.play_arrow),
                label: const Text('开始推理'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
