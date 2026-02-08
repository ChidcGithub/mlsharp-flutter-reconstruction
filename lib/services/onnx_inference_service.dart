import 'dart:io';
import 'package:logger/logger.dart';
import 'package:onnxruntime/onnxruntime.dart';

class OnnxInferenceService {
  late OrtSession _session;
  final Logger _logger = Logger();
  String? _modelPath;
  bool _useNpu = false;
  bool _isInitialized = false;

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
      await OrtEnv.instance.init();

      // 创建会话选项
      final sessionOptions = OrtSessionOptions();
      
      if (useNpu) {
        _logger.i('尝试启用骁龙 NPU 加速...');
        // NPU 委托配置（如果支持）
        try {
          // 尝试添加 QNN 委托（高通 NPU）
          sessionOptions.addQnnDelegate();
          _logger.i('✅ 骁龙 NPU 已启用');
        } catch (e) {
          _logger.w('⚠️ NPU 启用失败，将使用 CPU: $e');
        }
      }

      // 从文件加载模型（onnxruntime 2.0.0+ API）
      _session = await OrtSession.fromFile(
        modelFile.path,
        sessionOptions: sessionOptions,
      );

      _isInitialized = true;
      _logger.i('✅ ONNX 模型初始化成功 (IR 版本兼容)');
    } catch (e) {
      _logger.e('❌ ONNX 模型初始化失败: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  Future<List<OrtValue?>> runInference(List<List<double>> inputData) async {
    try {
      if (!_isInitialized) {
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
      final outputs = await _session.run(runOptions, {"input": input});

      _logger.i('✅ 推理完成');
      return outputs;
    } catch (e) {
      _logger.e('❌ 推理失败: $e');
      rethrow;
    }
  }

  Future<void> releaseModel() async {
    try {
      if (_isInitialized) {
        _session.release();
        _isInitialized = false;
        _logger.i('✅ 模型已释放');
      }
    } catch (e) {
      _logger.e('❌ 释放模型失败: $e');
    }
  }

  bool get isModelLoaded => _isInitialized;
  String? get modelPath => _modelPath;
  bool get isNpuEnabled => _useNpu;
}
