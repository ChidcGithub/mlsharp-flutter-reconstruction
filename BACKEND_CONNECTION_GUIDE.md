# MLSharp 3D Maker - 后端连接指南

本文档说明如何正确配置 Flutter 应用与 Python 后端的连接。

## 📋 前置要求

### 电脑端（后端服务器）
- Python 3.11+
- PyTorch 2.0+
- Apple ml-sharp 库
- ONNX Runtime
- 支持的 GPU：NVIDIA/AMD/Intel 或 CPU

### 手机端（Flutter 应用）
- Android 8.0+（推荐 Android 11+）
- 与电脑在同一 WiFi 网络
- 应用版本：v0.0.1-rc7 或更高

---

## 🚀 快速开始

### 步骤 1：启动后端服务

在电脑上运行 Python 后端：

```bash
cd /path/to/MLSharp-3D-Maker-GPU
python app.py --mode gpu --port 8000
```

**常用启动参数：**

| 参数 | 说明 | 示例 |
|------|------|------|
| `--mode` | 运行模式（auto/gpu/cpu/nvidia/amd） | `--mode gpu` |
| `--port` | 服务端口（默认 8000） | `--port 8080` |
| `--input-size` | 输入图像尺寸 | `--input-size 1536 1536` |
| `--enable-cache` | 启用推理缓存 | 无参数 |
| `--auto-gc-interval` | GPU 垃圾回收间隔（秒） | `--auto-gc-interval 30` |

**启动示例：**

```bash
# 使用 GPU，启用缓存，自动垃圾回收
python app.py --mode gpu --port 8000 --enable-cache --auto-gc-interval 30

# 仅使用 CPU
python app.py --mode cpu --port 8000

# 强制使用 NVIDIA GPU
python app.py --mode nvidia --port 8000
```

### 步骤 2：获取电脑 IP 地址

#### Windows
```powershell
ipconfig
```
查找 IPv4 地址（通常为 `192.168.x.x` 或 `10.x.x.x`）

#### macOS/Linux
```bash
ifconfig
```
查找 `inet` 地址

### 步骤 3：配置 Flutter 应用

1. 打开应用，进入 **设置** 页面
2. 在 **连接设置** 中输入后端地址：
   - **本地开发**（手机与电脑同一网络）：`http://<电脑IP>:8000`
   - 示例：`http://192.168.1.100:8000`
3. 点击 ✓ 保存

### 步骤 4：检查连接

在主页面，您会看到连接状态指示器：
- ✅ **绿色**：后端已连接，可以开始生成
- ❌ **红色**：后端未连接，检查设置和防火墙

点击 🔄 刷新按钮重新检查连接。

---

## 🔧 故障排查

### 问题 1：连接超时 (Connection Timeout)

**症状：** 应用显示"❌ 后端未连接"

**解决方案：**

1. **检查后端是否运行**
   ```bash
   # 在电脑上运行
   python app.py --mode gpu --port 8000
   ```

2. **验证 IP 地址**
   - 确保输入的 IP 地址正确
   - 在电脑浏览器中测试：`http://127.0.0.1:8000/health`

3. **检查防火墙**
   - Windows：允许 Python 通过防火墙
   - macOS：系统偏好设置 → 安全性与隐私 → 允许传入连接
   - Linux：`sudo ufw allow 8000`

4. **检查网络**
   - 确保手机和电脑在同一 WiFi 网络
   - 尝试 ping 电脑 IP：`ping 192.168.x.x`

### 问题 2：推理失败 (Inference Failed)

**症状：** 连接成功但推理返回错误

**解决方案：**

1. **查看后端日志**
   - 检查电脑终端中的错误信息
   - 常见错误：内存不足、GPU 显存不足

2. **检查图像格式**
   - 支持的格式：JPG、PNG
   - 推荐分辨率：1536×1536

3. **重启后端服务**
   ```bash
   # 停止服务（Ctrl+C）
   # 然后重新启动
   python app.py --mode gpu --port 8000
   ```

### 问题 3：大型模型加载失败 (Protobuf Parsing Error)

**症状：** 本地推理时显示"Protobuf parsing failed"

**解决方案：**

1. **确保文件完整**
   - ONNX 模型需要两个文件：
     - `sharp_final.onnx`（模型结构）
     - `sharp_final.onnx.data`（权重参数）
   - 两个文件必须在同一目录

2. **使用 USB 传输**
   - 避免网络传输导致文件损坏
   - 使用 USB 线连接电脑和手机
   - 使用文件管理器复制文件到手机存储

3. **检查文件权限**
   - 确保应用有权限读取文件
   - 文件应该在 `/sdcard/Download/` 或应用缓存目录

### 问题 4：NPU 加速不可用

**症状：** 启用 NPU 但推理仍使用 CPU

**解决方案：**

- NPU 支持需要在原生 Android 层配置 QNN delegate
- 当前版本主要支持 CPU 推理
- NPU 加速将在后续版本中完全实现

---

## 📊 API 端点参考

### 健康检查
```
GET /health
```
检查后端是否在线

**响应：**
```json
{
  "status": "ok",
  "version": "0.0.1"
}
```

### 推理接口
```
POST /api/predict
Content-Type: multipart/form-data

file: <image_file>
```

**响应：**
```json
{
  "model_url": "https://example.com/model.glb",
  "processing_time": 45.2,
  "status": "success"
}
```

### 系统统计
```
GET /stats
```

获取 GPU 使用情况、推理时间等统计信息

---

## 🌐 网络配置说明

### Android 网络安全配置

应用已配置支持以下地址的明文 HTTP 流量：

- **本地地址**：`127.0.0.1`、`localhost`
- **局域网**：`192.168.x.x`、`10.x.x.x`

这些配置仅用于开发环境。生产环境应使用 HTTPS。

### 防火墙配置

确保防火墙允许以下：
- **协议**：TCP
- **端口**：8000（或您配置的端口）
- **来源**：局域网内的所有设备

---

## 💡 最佳实践

1. **使用固定 IP**
   - 配置路由器为电脑分配固定 IP
   - 避免 IP 变化导致连接中断

2. **监控资源使用**
   - 推理前检查 GPU 显存是否充足
   - 使用 `--auto-gc-interval` 定期清理显存

3. **启用缓存**
   - 使用 `--enable-cache` 加快重复推理
   - 定期清理缓存避免磁盘满

4. **日志记录**
   - 在应用设置中导出日志
   - 遇到问题时提供日志便于调试

---

## 📞 获取帮助

如果问题未解决，请：

1. 检查应用日志（设置 → 导出日志）
2. 查看后端服务的错误输出
3. 确保所有依赖已正确安装
4. 尝试重启应用和后端服务

---

**版本信息**
- 应用版本：v0.0.1-rc7
- 后端版本：MLSharp-3D-Maker-GPU
- 最后更新：2026-02-08
