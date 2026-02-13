import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'inference_logger.dart';

class ModelFormatConverter {
  InferenceLogger? _logger;

  void setLogger(InferenceLogger logger) {
    _logger = logger;
  }

  /// 将 PLY 文件转换为 GLB 格式
  /// 返回转换后的 GLB 文件路径
  Future<String?> convertPlyToGlb(String plyPath) async {
    try {
      _logger?.info('开始 PLY 到 GLB 转换...');
      _logger?.debug('源文件: $plyPath');

      // 1. 读取 PLY 文件
      final plyFile = File(plyPath);
      if (!plyFile.existsSync()) {
        throw Exception('PLY 文件不存在');
      }

      final fileSize = plyFile.lengthSync();
      _logger?.debug('文件大小: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

      if (fileSize > 100 * 1024 * 1024) {
        _logger?.warning('文件过大（超过100MB），转换可能失败或耗时很长');
      }

      // 2. 解析 PLY 文件
      _logger?.info('正在解析 PLY 文件...');
      final plyData = await _parsePlyFile(plyFile);

      _logger?.info('解析完成，共 ${plyData.vertices.length} 个顶点');

      if (plyData.vertices.isEmpty) {
        throw Exception('PLY 文件没有有效的顶点数据');
      }

      // 3. 构建 GLB 格式
      _logger?.info('正在构建 GLB 格式...');
      final glbData = _buildGlbData(plyData);

      _logger?.debug('GLB 数据大小: ${(glbData.lengthInBytes / 1024 / 1024).toStringAsFixed(2)} MB');

      // 4. 保存 GLB 文件
      final tempDir = await getTemporaryDirectory();
      final glbPath = '${tempDir.path}/converted_model.glb';
      final glbFile = File(glbPath);
      await glbFile.writeAsBytes(glbData.buffer.asUint8List());

      _logger?.success('GLB 转换成功: $glbPath');
      _logger?.debug('GLB 文件大小: ${(glbFile.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB');
      return glbPath;
    } catch (e, stack) {
      _logger?.error('PLY 到 GLB 转换失败', error: e, stackTrace: stack);
      _logger?.info('将尝试使用原始 PLY 格式');
      return null;
    }
  }

  /// 解析 PLY 文件
  Future<_PlyData> _parsePlyFile(File plyFile) async {
    final bytes = await plyFile.readAsBytes();
    final content = String.fromCharCodes(bytes);

    // 查找头部结束位置
    final headerEndIndex = content.indexOf('end_header');
    if (headerEndIndex == -1) {
      throw Exception('无效的 PLY 文件格式：未找到 end_header');
    }

    final header = content.substring(0, headerEndIndex);
    final dataStartIndex = headerEndIndex + 'end_header'.length + 1;

    // 解析头部信息
    final isBinary = header.contains('format binary');
    final vertexCount = _extractElementCount(header, 'element vertex');

    if (vertexCount == 0) {
      throw Exception('PLY 文件没有顶点数据');
    }

    _logger?.debug('PLY 格式: ${isBinary ? "二进制" : "ASCII"}');
    _logger?.debug('顶点数量: $vertexCount');

    // 解析顶点数据
    final vertices = <_Vertex>[];

    if (isBinary) {
      vertices.addAll(_parseBinaryVertices(bytes, dataStartIndex, vertexCount));
    } else {
      vertices.addAll(_parseAsciiVertices(content, dataStartIndex, vertexCount));
    }

    return _PlyData(vertices: vertices);
  }

  /// 提取元素数量
  int _extractElementCount(String header, String elementName) {
    final pattern = RegExp('$elementName\\s+(\\d+)');
    final match = pattern.firstMatch(header);
    if (match != null) {
      return int.parse(match.group(1)!);
    }
    return 0;
  }

  /// 解析 ASCII 格式的顶点
  List<_Vertex> _parseAsciiVertices(String content, int startIndex, int count) {
    final vertices = <_Vertex>[];
    final lines = content.substring(startIndex).split('\n');

    for (int i = 0; i < count && i < lines.length; i++) {
      final parts = lines[i].trim().split(RegExp(r'\s+'));
      if (parts.length >= 3) {
        final x = double.parse(parts[0]);
        final y = double.parse(parts[1]);
        final z = double.parse(parts[2]);

        // 尝试解析颜色（如果有）
        double r = 1.0, g = 1.0, b = 1.0;
        if (parts.length >= 6) {
          r = double.parse(parts[3]) / 255.0;
          g = double.parse(parts[4]) / 255.0;
          b = double.parse(parts[5]) / 255.0;
        }

        vertices.add(_Vertex(x: x, y: y, z: z, r: r, g: g, b: b));
      }
    }

    return vertices;
  }

  /// 解析二进制格式的顶点
  List<_Vertex> _parseBinaryVertices(Uint8List bytes, int startIndex, int count) {
    final vertices = <_Vertex>[];
    final byteData = ByteData.sublistView(bytes);

    // 假设每个顶点有 6 个 float（x, y, z, r, g, b）
    const bytesPerVertex = 6 * 4; // 6 floats * 4 bytes
    int offset = startIndex;

    for (int i = 0; i < count; i++) {
      if (offset + bytesPerVertex > bytes.length) break;

      final x = byteData.getFloat32(offset, Endian.little);
      final y = byteData.getFloat32(offset + 4, Endian.little);
      final z = byteData.getFloat32(offset + 8, Endian.little);

      double r = 1.0, g = 1.0, b = 1.0;
      if (offset + 24 <= bytes.length) {
        r = byteData.getFloat32(offset + 12, Endian.little) / 255.0;
        g = byteData.getFloat32(offset + 16, Endian.little) / 255.0;
        b = byteData.getFloat32(offset + 20, Endian.little) / 255.0;
      }

      vertices.add(_Vertex(x: x, y: y, z: z, r: r, g: g, b: b));
      offset += bytesPerVertex;
    }

    return vertices;
  }

  /// 构建 GLB 数据
  Uint8List _buildGlbData(_PlyData plyData) {
    // 构建 JSON 内容
    final vertexCount = plyData.vertices.length;

    // 创建顶点数据
    final positions = Float32List(vertexCount * 3);
    final colors = Float32List(vertexCount * 3);

    for (int i = 0; i < vertexCount; i++) {
      final v = plyData.vertices[i];
      positions[i * 3] = v.x;
      positions[i * 3 + 1] = v.y;
      positions[i * 3 + 2] = v.z;

      colors[i * 3] = v.r;
      colors[i * 3 + 1] = v.g;
      colors[i * 3 + 2] = v.b;
    }

    // 合并顶点数据（位置 + 颜色）
    final vertexData = Float32List(vertexCount * 6);
    for (int i = 0; i < vertexCount; i++) {
      vertexData[i * 6] = positions[i * 3];
      vertexData[i * 6 + 1] = positions[i * 3 + 1];
      vertexData[i * 6 + 2] = positions[i * 3 + 2];
      vertexData[i * 6 + 3] = colors[i * 3];
      vertexData[i * 6 + 4] = colors[i * 3 + 1];
      vertexData[i * 6 + 5] = colors[i * 3 + 2];
    }

    // 计算访问器长度（对齐到 4 字节）
    final vertexDataBytes = vertexData.buffer.asUint8List();
    final vertexDataAlignedLength = _alignTo4Bytes(vertexDataBytes.length);

    // 构建 JSON
    final jsonContent = {
      "asset": {
        "version": "2.0",
        "generator": "Ansharp"
      },
      "scenes": [
        {
          "nodes": [0]
        }
      ],
      "nodes": [
        {
          "mesh": 0
        }
      ],
      "meshes": [
        {
          "primitives": [
            {
              "attributes": {
                "POSITION": 0,
                "COLOR_0": 1
              },
              "mode": 0 // POINTS
            }
          ]
        }
      ],
      "accessors": [
        {
          "bufferView": 0,
          "byteOffset": 0,
          "componentType": 5126, // FLOAT
          "count": vertexCount,
          "type": "VEC3",
          "max": _computeMax(positions),
          "min": _computeMin(positions)
        },
        {
          "bufferView": 0,
          "byteOffset": vertexCount * 12,
          "componentType": 5126, // FLOAT
          "count": vertexCount,
          "type": "VEC3",
          "max": [1.0, 1.0, 1.0],
          "min": [0.0, 0.0, 0.0]
        }
      ],
      "bufferViews": [
        {
          "buffer": 0,
          "byteOffset": 0,
          "byteLength": vertexDataBytes.length,
          "target": 34962 // ARRAY_BUFFER
        }
      ],
      "buffers": [
        {
          "byteLength": vertexDataAlignedLength
        }
      ]
    };

    // 转换 JSON 为字符串
    final jsonString = _jsonEncode(jsonContent);
    final jsonBytes = utf8.encode(jsonString);
    final jsonAlignedLength = _alignTo4Bytes(jsonBytes.length);

    // 构建 GLB
    final glbBuilder = BytesBuilder();

    // GLB 头部
    glbBuilder.add(_writeUint32(0x46546C67)); // magic
    glbBuilder.add(_writeUint32(2)); // version
    glbBuilder.add(_writeUint32(12 + 8 + jsonAlignedLength + 8 + vertexDataAlignedLength)); // total length

    // JSON chunk
    glbBuilder.add(_writeUint32(jsonAlignedLength)); // chunk length
    glbBuilder.add(_writeUint32(0x4E4F534A)); // JSON chunk type
    glbBuilder.add(jsonBytes);
    // 填充
    final jsonPadding = jsonAlignedLength - jsonBytes.length;
    if (jsonPadding > 0) {
      glbBuilder.add(List.filled(jsonPadding, 0x20)); // space padding
    }

    // Binary chunk
    glbBuilder.add(_writeUint32(vertexDataAlignedLength)); // chunk length
    glbBuilder.add(_writeUint32(0x004E4942)); // BIN chunk type
    glbBuilder.add(vertexDataBytes);
    // 填充
    final binPadding = vertexDataAlignedLength - vertexDataBytes.length;
    if (binPadding > 0) {
      glbBuilder.add(List.filled(binPadding, 0x00)); // null padding
    }

    return glbBuilder.toBytes();
  }

  /// 简单的 JSON 编码（避免依赖 dart:convert）
  String _jsonEncode(dynamic obj) {
    if (obj is Map) {
      final entries = obj.entries.map((e) => '"${e.key}":${_jsonEncode(e.value)}').join(',');
      return '{$entries}';
    } else if (obj is List) {
      final items = obj.map((e) => _jsonEncode(e)).join(',');
      return '[$items]';
    } else if (obj is String) {
      return '"${obj.replaceAll('"', '\\"')}"';
    } else if (obj is num) {
      return obj.toString();
    } else if (obj is bool) {
      return obj ? 'true' : 'false';
    } else {
      return 'null';
    }
  }

  /// 写入 Uint32
  Uint8List _writeUint32(int value) {
    final byteData = ByteData(4);
    byteData.setUint32(0, value, Endian.little);
    return byteData.buffer.asUint8List();
  }

  /// 对齐到 4 字节
  int _alignTo4Bytes(int length) {
    return ((length + 3) ~/ 4) * 4;
  }

  /// 计算最大值
  List<double> _computeMax(Float32List positions) {
    double maxX = positions[0], maxY = positions[1], maxZ = positions[2];
    for (int i = 3; i < positions.length; i += 3) {
      if (positions[i] > maxX) maxX = positions[i];
      if (positions[i + 1] > maxY) maxY = positions[i + 1];
      if (positions[i + 2] > maxZ) maxZ = positions[i + 2];
    }
    return [maxX, maxY, maxZ];
  }

  /// 计算最小值
  List<double> _computeMin(Float32List positions) {
    double minX = positions[0], minY = positions[1], minZ = positions[2];
    for (int i = 3; i < positions.length; i += 3) {
      if (positions[i] < minX) minX = positions[i];
      if (positions[i + 1] < minY) minY = positions[i + 1];
      if (positions[i + 2] < minZ) minZ = positions[i + 2];
    }
    return [minX, minY, minZ];
  }
}

/// PLY 数据结构
class _PlyData {
  final List<_Vertex> vertices;

  _PlyData({required this.vertices});
}

/// 顶点数据结构
class _Vertex {
  final double x, y, z;
  final double r, g, b;

  _Vertex({
    required this.x,
    required this.y,
    required this.z,
    required this.r,
    required this.g,
    required this.b,
  });
}