import 'dart:io';
import 'package:logger/logger.dart';
import 'package:onnxruntime/onnxruntime.dart';

class OnnxInferenceService {
  OrtSession? _session;
  final Logger _logger = Logger();
  String? _modelPath;
  bool _useNpu = false;
  String? _dataFilePath;

  /// 初始化 ONNX 模型，支持大型模型权重加载
  /// 
  /// 关键改进：
  /// 1. 检测并验证配套的 .onnx.data 权重文件
  /// 2. 提供清晰的文件路径提示
  /// 3. 支持 NPU 加速配置
  Future<void> initializeModel(String modelPath, {bool useNpu = true}) async {
    try {
      _logger.i('🔄 正在初始化 ONNX 模型: $modelPath');
      
      final modelFile = File(modelPath);
      if (!modelFile.existsSync()) {
        throw Exception('❌ 模型文件不存在: $modelPath');
      }

      // 检查配套的 .data 文件（大型模型必需）
      final dataFilePath = '$modelPath.data';
      final dataFile = File(dataFilePath);
      
      if (dataFile.existsSync()) {
        _logger.i('✅ 检测到配套权重文件: $dataFilePath');
        _logger.i('📊 权重文件大小: ${(dataFile.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB');
        _dataFilePath = dataFilePath;
      } else {
        _logger.w('⚠️  未发现配套 .data 文件');
        _logger.w('📌 如果模型加载失败，请确保 .onnx 和 .onnx.data 文件在同一目录');
        _logger.i('💡 文件路径: ${modelFile.parent.path}');
      }

      _modelPath = modelPath;
      _useNpu = useNpu;

      // 初始化 ONNX Runtime 环境
      OrtEnv.instance.init();
      _logger.i('✅ ONNX Runtime 环境已初始化');

      // 创建会话选项
      final sessionOptions = OrtSessionOptions();
      
      if (useNpu) {
        _logger.i('🚀 尝试启用骁龙 NPU 加速...');
        try {
          // 注意：NPU 支持需要在原生层配置
          // 这里仅作为配置标记
          _logger.i('💡 NPU 加速需要在 Android 原生层配置 QNN delegate');
        } catch (e) {
          _logger.w('⚠️  NPU 配置失败，将使用 CPU: $e');
        }
      }

      // 从文件加载模型
      _session = OrtSession.fromFile(
        modelFile,
        sessionOptions,
      );
      
      _logger.i('✅ ONNX 模型初始化成功');
      _logger.i('📝 模型路径: $_modelPath');
      _logger.i('🎯 NPU 加速: $_useNpu');
    } catch (e) {
      _logger.e('❌ ONNX 模型初始化失败: $e');
      _logger.e('💡 故障排查建议:');
      _logger.e('  1. 检查模型文件是否完整（.onnx 和 .onnx.data 都需要）');
      _logger.e('  2. 确保两个文件在同一目录下');
      _logger.e('  3. 尝试使用 USB 重新传输文件（避免网络传输损坏）');
      _logger.e('  4. 检查文件权限是否正确');
      rethrow;
    }
  }

  /// 执行推理
  Future<List<OrtValue?>> runInference(List<List<double>> inputData) async {
    try {
      if (_session == null) {
        throw Exception('❌ 模型未初始化，请先加载模型');
      }

      _logger.i('🔄 开始推理...');
      
      // 创建输入 Tensor
      final shape = [1, inputData[0].length];
      final input = OrtValueTensor.createTensorWithDataList(
        inputData[0],
        shape,
      );

      // 执行推理
      final runOptions = OrtRunOptions();
      final outputs = await _session!.run(runOptions, {"input": input});

      _logger.i('✅ 推理完成，输出数量: ${outputs.length}');
      return outputs;
    } catch (e) {
      _logger.e('❌ 推理失败: $e');
      rethrow;
    }
  }

  /// 释放模型资源
  Future<void> releaseModel() async {
    try {
      _session?.release();
      _session = null;
      _modelPath = null;
      _dataFilePath = null;
      _logger.i('✅ 模型已释放');
    } catch (e) {
      _logger.e('❌ 释放模型失败: $e');
    }
  }

  // Getters
  bool get isModelLoaded => _session != null;
  String? get modelPath => _modelPath;
  String? get dataFilePath => _dataFilePath;
  bool get isNpuEnabled => _useNpu;
}
