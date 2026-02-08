import 'dart:io';
import 'package:logger/logger.dart';
import 'package:onnxruntime/onnxruntime.dart';

class OnnxInferenceService {
  OrtSession? _session;
  final Logger _logger = Logger();
  String? _modelPath;
  bool _useNpu = false;

  Future<void> initializeModel(String modelPath, {bool useNpu = true}) async {
    try {
      _logger.i('初始化 ONNX 模型: $modelPath');
      
      final modelFile = File(modelPath);
      if (!modelFile.existsSync()) {
        throw Exception('模型文件不存在: $modelPath');
      }

      _modelPath = modelPath;
      _useNpu = useNpu;

      // 初始化 ONNX Runtime 环境
      OrtEnv.instance.init();

      // 创建会话选项
      final sessionOptions = OrtSessionOptions();
      
      if (useNpu) {
        _logger.i('尝试启用骁龙 NPU 加速...');
        _logger.i('💡 NPU 加速需要在原生层配置');
      }

      // 从文件加载模型（兼容 1.4.1 API）
      _session = OrtSession.fromFile(
        modelFile,
        sessionOptions,
      );
      _logger.i('✅ ONNX 模型初始化成功 (IR 版本兼容)');
    } catch (e) {
      _logger.e('❌ ONNX 模型初始化失败: $e');
      rethrow;
    }
  }

  Future<List<OrtValue?>> runInference(List<List<double>> inputData) async {
    try {
      if (_session == null) {
        throw Exception('模型未初始化');
      }

      _logger.i('开始推理...');
      
      // 创建输入 Tensor（onnxruntime 2.0.0+ API）
      final shape = [1, inputData[0].length];
      final input = OrtValueTensor.createTensorWithDataList(
        inputData[0],
        shape,
      );

      // 执行推理
      final runOptions = OrtRunOptions();
      final outputs = await _session!.run(runOptions, {"input": input});

      _logger.i('✅ 推理完成');
      return outputs;
    } catch (e) {
      _logger.e('❌ 推理失败: $e');
      rethrow;
    }
  }

  Future<void> releaseModel() async {
    try {
      _session?.release();
      _session = null;
      _logger.i('✅ 模型已释放');
    } catch (e) {
      _logger.e('❌ 释放模型失败: $e');
    }
  }

  bool get isModelLoaded => _session != null;
  String? get modelPath => _modelPath;
  bool get isNpuEnabled => _useNpu;
}
