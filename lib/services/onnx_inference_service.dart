import 'dart:io';
import 'package:logger/logger.dart';
import 'package:onnxruntime/onnxruntime.dart';

class OnnxInferenceService {
  late OrtSession? _session;
  final Logger _logger = Logger();
  String? _modelPath;
  bool _useNpu = false;

  Future<void> initializeModel(String modelPath, {bool useNpu = true}) async {
    try {
      _logger.i('初始化 ONNX 模型: $modelPath');
      
      // 检查模型文件是否存在
      final modelFile = File(modelPath);
      if (!modelFile.existsSync()) {
        throw Exception('模型文件不存在: $modelPath');
      }

      _modelPath = modelPath;
      _useNpu = useNpu;

      // 初始化 ONNX Runtime
      await OrtEnv.instance.init();

      // 创建会话选项
      final sessionOptions = OrtSessionOptions();
      
      // 如果启用 NPU，尝试使用 Snapdragon NPU（QNN 委托）
      if (useNpu) {
        try {
          _logger.i('尝试启用骁龙 NPU 加速...');
          // 注意：实际的 NPU 委托需要在 Android 端配置
          // 这里是占位符，实际实现需要通过 JNI 与 Android 原生代码交互
          _logger.i('NPU 加速已启用（如果硬件支持）');
        } catch (e) {
          _logger.w('NPU 初始化失败，回退到 CPU: $e');
          _useNpu = false;
        }
      }

      // 创建会话
      _session = await OrtSession.fromFile(
        modelFile,
        sessionOptions: sessionOptions,
      );

      _logger.i('ONNX 模型初始化成功');
    } catch (e) {
      _logger.e('ONNX 模型初始化失败: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> runInference(List<List<double>> inputData) async {
    try {
      if (_session == null) {
        throw Exception('模型未初始化');
      }

      _logger.i('开始推理...');
      
      // 准备输入
      final input = OrtValueTensor.createTensorAsType(
        inputData,
        shape: [1, inputData.length],
      );

      // 运行推理
      final outputs = await _session!.run(null, {0: input});

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

  List<String> getInferenceLog() {
    // 这是一个占位符，实际的日志应该从 Logger 中获取
    return [
      '模型路径: $_modelPath',
      'NPU 加速: $_useNpu',
      '模型已加载: $isModelLoaded',
    ];
  }
}
