import 'dart:io';
import 'package:onnxruntime/onnxruntime.dart';
import 'inference_logger.dart';

class OnnxInferenceService {
  OrtSession? _session;
  String? _modelPath;
  bool _useNpu = false;
  String? _dataFilePath;
  InferenceLogger? _logger;

  void setLogger(InferenceLogger logger) {
    _logger = logger;
  }

  Future<void> initializeModel(String modelPath, {bool useNpu = true}) async {
    try {
      _logger?.info('开始初始化本地推理引擎...');
      _logger?.info('模型路径: $modelPath');
      
      final modelFile = File(modelPath);
      if (!modelFile.existsSync()) {
        throw Exception('模型文件不存在，请检查路径是否正确');
      }

      final dataFilePath = '$modelPath.data';
      final dataFile = File(dataFilePath);
      
      if (dataFile.existsSync()) {
        _logger?.info('检测到配套权重文件: $dataFilePath');
        _logger?.info('权重文件大小: ${(dataFile.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB');
        _dataFilePath = dataFilePath;
      } else {
        _logger?.warning('未发现配套 .data 文件，对于大型模型这可能导致加载失败');
      }

      _modelPath = modelPath;
      _useNpu = useNpu;

      _logger?.info('正在初始化 ONNX Runtime 环境...');
      OrtEnv.instance.init();
      _logger?.success('ONNX Runtime 环境初始化成功');

      final sessionOptions = OrtSessionOptions();
      if (useNpu) {
        _logger?.info('尝试配置 NPU 加速 (QNN Delegate)...');
        // 注意：实际 NPU 支持依赖于原生层配置
      }

      _logger?.info('正在从文件加载模型会话...');
      _session = OrtSession.fromFile(
        modelFile,
        sessionOptions,
      );
      
      _logger?.success('模型会话创建成功，本地推理引擎就绪');
    } catch (e, stack) {
      _logger?.error('本地推理引擎初始化失败', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<List<OrtValue?>> runInference(List<List<double>> inputData) async {
    try {
      if (_session == null) {
        throw Exception('模型未初始化，请先加载模型');
      }

      _logger?.info('开始执行推理任务...');
      _logger?.debug('输入数据维度: [1, ${inputData[0].length}]');
      
      final shape = [1, inputData[0].length];
      final input = OrtValueTensor.createTensorWithDataList(
        inputData[0],
        shape,
      );

      final runOptions = OrtRunOptions();
      _logger?.info('正在运行模型计算...');
      final outputs = _session!.run(runOptions, {"input": input});

      _logger?.success('推理任务执行完成，获取到 ${outputs.length} 个输出节点');
      return outputs;
    } catch (e, stack) {
      _logger?.error('推理执行过程中发生错误', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> releaseModel() async {
    try {
      _logger?.info('正在释放模型资源...');
      _session?.release();
      _session = null;
      _modelPath = null;
      _dataFilePath = null;
      _logger?.success('模型资源已安全释放');
    } catch (e) {
      _logger?.error('释放模型资源时发生错误', error: e);
    }
  }

  bool get isModelLoaded => _session != null;
}
