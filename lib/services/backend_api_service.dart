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
        receiveTimeout: const Duration(seconds: 60),
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
      
      // 增加对 /health 端点的请求
      final response = await _dio.get('/health');
      
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
      if (e.type == DioExceptionType.connectionTimeout) {
        _logger?.info('1. 检查电脑端服务是否已启动 (python app.py)');
        _logger?.info('2. 检查手机和电脑是否在同一 WiFi 网络');
        _logger?.info('3. 检查电脑防火墙是否允许 8000 端口访问');
      } else if (e.error is SocketException) {
        _logger?.info('网络不可达，请检查 IP 地址是否正确: $_baseUrl');
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
      
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.path.split('/').last,
        ),
      });

      _logger?.info('正在上传并等待推理结果 (可能需要 30-60 秒)...');
      final response = await _dio.post(
        '/api/predict',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      if (response.statusCode == 200) {
        _logger?.success('3D 模型生成成功');
        return response.data as Map<String, dynamic>;
      } else {
        _logger?.error('服务器推理失败，状态码: ${response.statusCode}');
        _logger?.debug('错误详情: ${response.data}');
        return null;
      }
    } on DioException catch (e) {
      _logger?.error('推理请求失败', error: e);
      return null;
    } catch (e) {
      _logger?.error('推理过程中发生未知错误', error: e);
      return null;
    }
  }

  bool get isConnected => _isConnected;
  String get baseUrl => _baseUrl;
}
