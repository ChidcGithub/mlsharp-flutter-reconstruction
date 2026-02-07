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

      // 修复 1: 新版本中 init() 可能不再返回 Future 或已更改
      OrtEnv.instance.init();

      // 创建会话选项
      final sessionOptions = OrtSessionOptions();
      
      if (useNpu) {
        _logger.i('尝试启用骁龙 NPU 加速...');
        // 实际 NPU 委托配置通常在原生端处理
      }

      // 修复 2: fromFile 现在需要两个必填参数
      _session = OrtSession.fromFile(
        modelFile,
        sessionOptions,
      );

      _logger.i('ONNX 模型初始化成功');
    } catch (e) {
      _logger.e('ONNX 模型初始化失败: $e');
      rethrow;
    }
  }

  Future<List<OrtValue?>> runInference(List<List<double>> inputData) async {
    try {
      if (_session == null) {
        throw Exception('模型未初始化');
      }

      _logger.i('开始推理...');
      
      // 修复 3: 使用正确的 Tensor 创建方法
      // 注意：根据 onnxruntime 1.4.1 的 API，创建方式已更改
      final shape = [1, inputData[0].length];
      final input = OrtValueTensor.createTensorWithDataList(
        inputData[0],
        shape,
      );

      // 修复 4: run 方法的参数类型和 Map 键类型修复
      final runOptions = OrtRunOptions();
      final outputs = await _session!.run(runOptions, {"input": input});

      _logger.i('推理完成');
      return outputs;
    } catch (e) {
      _logger.e('推理失败: $e');
      rethrow;
    }
  }

  Future<void> releaseModel() async {
    try {
      _session?.release();
      _session = null;
      _logger.i('模型已释放');
    } catch (e) {
      _logger.e('释放模型失败: $e');
    }
  }

  bool get isModelLoaded => _session != null;
  String? get modelPath => _modelPath;
  bool get isNpuEnabled => _useNpu;
}
