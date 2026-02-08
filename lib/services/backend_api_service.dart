import 'dart:io';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

class BackendApiService {
  late Dio _dio;
  final Logger _logger = Logger();
  String _baseUrl = 'http://127.0.0.1:8000';
  bool _isConnected = false;

  BackendApiService() {
    _initializeDio();
  }

  /// 初始化 Dio 客户端，配置网络请求
  void _initializeDio() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
        contentType: 'application/json',
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    // 添加日志拦截器
    _dio.interceptors.add(
      LogInterceptor(
        requestHeader: true,
        requestBody: false,
        responseHeader: true,
        responseBody: false,
        logPrint: (obj) => _logger.i('API: $obj'),
      ),
    );
  }

  /// 设置后端服务器地址
  void setBaseUrl(String url) {
    _baseUrl = url;
    _dio.options.baseUrl = url;
    _logger.i('✅ 后端地址已更新: $_baseUrl');
  }

  /// 检查后端连接状态
  Future<bool> checkConnection() async {
    try {
      _logger.i('🔄 检查后端连接: $_baseUrl');
      
      final response = await _dio.get('/health');
      
      if (response.statusCode == 200) {
        _isConnected = true;
        _logger.i('✅ 后端连接成功');
        return true;
      } else {
        _isConnected = false;
        _logger.w('⚠️  后端返回错误状态码: ${response.statusCode}');
        return false;
      }
    } on DioException catch (e) {
      _isConnected = false;
      _logger.e('❌ 连接失败: ${e.message}');
      _logger.e('💡 故障排查:');
      _logger.e('  1. 确保后端服务已启动: python app.py');
      _logger.e('  2. 检查后端地址: $_baseUrl');
      _logger.e('  3. 确保手机和电脑在同一网络');
      _logger.e('  4. 检查防火墙是否允许 8000 端口');
      _logger.e('  5. 尝试在电脑浏览器访问: $_baseUrl/health');
      return false;
    } catch (e) {
      _isConnected = false;
      _logger.e('❌ 未知错误: $e');
      return false;
    }
  }

  /// 上传图像并生成 3D 模型
  Future<Map<String, dynamic>?> predictImage(File imageFile) async {
    try {
      if (!_isConnected) {
        _logger.w('⚠️  后端未连接，尝试重新连接...');
        final connected = await checkConnection();
        if (!connected) {
          throw Exception('无法连接到后端服务');
        }
      }

      _logger.i('🔄 上传图像: ${imageFile.path}');
      
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.path.split('/').last,
        ),
      });

      final response = await _dio.post(
        '/api/predict',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      if (response.statusCode == 200) {
        _logger.i('✅ 推理成功');
        return response.data as Map<String, dynamic>;
      } else {
        _logger.e('❌ 推理失败: ${response.statusCode}');
        _logger.e('响应: ${response.data}');
        return null;
      }
    } on DioException catch (e) {
      _logger.e('❌ 请求失败: ${e.message}');
      
      if (e.type == DioExceptionType.connectionTimeout) {
        _logger.e('💡 连接超时，请检查:');
        _logger.e('  1. 后端服务是否运行');
        _logger.e('  2. 网络连接是否正常');
        _logger.e('  3. 防火墙设置');
      } else if (e.type == DioExceptionType.receiveTimeout) {
        _logger.e('💡 接收超时，推理可能耗时较长，请稍候');
      } else if (e.type == DioExceptionType.unknown) {
        _logger.e('💡 网络错误: ${e.error}');
        if (e.error is SocketException) {
          _logger.e('  检查: 后端地址是否正确，防火墙是否开放');
        }
      }
      
      return null;
    } catch (e) {
      _logger.e('❌ 未知错误: $e');
      return null;
    }
  }

  /// 获取系统统计信息
  Future<Map<String, dynamic>?> getStats() async {
    try {
      _logger.i('🔄 获取系统统计信息...');
      
      final response = await _dio.get('/stats');
      
      if (response.statusCode == 200) {
        _logger.i('✅ 获取统计信息成功');
        return response.data as Map<String, dynamic>;
      } else {
        _logger.e('❌ 获取统计信息失败: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _logger.e('❌ 获取统计信息失败: $e');
      return null;
    }
  }

  /// 获取 Prometheus 指标
  Future<String?> getMetrics() async {
    try {
      _logger.i('🔄 获取 Prometheus 指标...');
      
      final response = await _dio.get(
        '/metrics',
        options: Options(responseType: ResponseType.plain),
      );
      
      if (response.statusCode == 200) {
        _logger.i('✅ 获取指标成功');
        return response.data as String;
      } else {
        _logger.e('❌ 获取指标失败: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _logger.e('❌ 获取指标失败: $e');
      return null;
    }
  }

  // Getters
  bool get isConnected => _isConnected;
  String get baseUrl => _baseUrl;
}
