import 'dart:io';
import 'package:dio/dio.dart';
import 'inference_logger.dart';

class BackendApiService {
  late Dio _dio;
  String _baseUrl = 'http://127.0.0.1:8000';
  bool _isConnected = false;
  InferenceLogger? _logger;

  BackendApiService() {
    _initializeDio();
  }

  void setLogger(InferenceLogger logger) {
    _logger = logger;
  }

  void _initializeDio() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 120), // 后端推理可能较慢，增加超时时间
        sendTimeout: const Duration(seconds: 60),
        contentType: 'application/json',
        validateStatus: (status) => status != null && status < 500,
      ),
    );
  }

  void setBaseUrl(String url) {
    _baseUrl = url;
    _dio.options.baseUrl = url;
    _logger?.info('后端地址已更新: $_baseUrl');
  }

  Future<bool> checkConnection() async {
    try {
      _logger?.info('正在尝试连接后端服务: $_baseUrl');
      
      // 根据后端文档，健康检查端点是 /v1/health
      final response = await _dio.get('/v1/health');
      
      if (response.statusCode == 200) {
        _isConnected = true;
        _logger?.success('后端连接成功');
        _logger?.debug('服务器响应: ${response.data}');
        return true;
      } else {
        _isConnected = false;
        _logger?.warning('后端返回非预期状态码: ${response.statusCode}');
        return false;
      }
    } on DioException catch (e) {
      _isConnected = false;
      _logger?.error('后端连接失败', error: e);
      
      _logger?.info('诊断建议:');
      if (e.type == DioExceptionType.connectionTimeout || e.error is SocketException) {
        if (_baseUrl.contains('127.0.0.1') || _baseUrl.contains('localhost')) {
          _logger?.warning('检测到正在使用 127.0.0.1/localhost');
          _logger?.info('提示: 手机无法通过 127.0.0.1 访问电脑。');
          _logger?.info('  - 如果是真机: 请使用电脑的局域网 IP (如 192.168.x.x)');
          _logger?.info('  - 如果是模拟器: 请尝试使用 10.0.2.2');
        }
        _logger?.info('1. 确保电脑端服务已启动 (python app.py)');
        _logger?.info('2. 确保手机和电脑连接在同一个 WiFi');
        _logger?.info('3. 检查电脑防火墙是否允许 8000 端口入站访问');
      }
      return false;
    } catch (e) {
      _isConnected = false;
      _logger?.error('连接过程中发生未知错误', error: e);
      return false;
    }
  }

  Future<Map<String, dynamic>?> predictImage(File imageFile) async {
    try {
      _logger?.info('准备上传图像进行 3D 生成...');
      _logger?.debug('图像路径: ${imageFile.path}');
      
      // 根据后端文档，预测接口是 /v1/predict，字段名是 file
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.path.split('/').last,
        ),
      });

      _logger?.info('正在上传并等待推理结果 (可能需要 30-60 秒)...');
      final response = await _dio.post(
        '/v1/predict',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      if (response.statusCode == 200) {
        _logger?.success('3D 模型生成成功');
        // 后端返回格式: { "status": "success", "url": "...", "processing_time": ..., "task_id": "..." }
        return response.data as Map<String, dynamic>;
      } else {
        _logger?.error('服务器推理失败，状态码: ${response.statusCode}');
        _logger?.debug('错误详情: ${response.data}');
        return null;
      }
    } on DioException catch (e) {
      _logger?.error('推理请求失败', error: e);
      if (e.response?.data != null) {
        _logger?.debug('服务器错误响应: ${e.response?.data}');
      }
      return null;
    } catch (e) {
      _logger?.error('推理过程中发生未知错误', error: e);
      return null;
    }
  }

  bool get isConnected => _isConnected;
  String get baseUrl => _baseUrl;
}
