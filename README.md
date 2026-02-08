```
          _____                    _____            _____                    _____                    _____                    _____                    _____          
         /\    \                  /\    \          /\    \                  /\    \                  /\    \                  /\    \                  /\    \         
        /::\____\                /::\____\        /::\    \                /::\____\                /::\    \                /::\    \                /::\    \        
       /::::|   |               /:::/    /       /::::\    \              /:::/    /               /::::\    \              /::::\    \              /::::\    \       
      /:::::|   |              /:::/    /       /::::::\    \            /:::/    /               /::::::\    \            /::::::\    \            /::::::\    \      
     /::::::|   |             /:::/    /       /:::/\:::\    \          /:::/    /               /:::/\:::\    \          /:::/\:::\    \          /:::/\:::\    \     
    /:::/|::|   |            /:::/    /       /:::/__\:::\    \        /:::/____/               /:::/__\:::\    \        /:::/__\:::\    \        /:::/__\:::\    \    
   /:::/ |::|   |           /:::/    /        \:::\   \:::\    \      /::::\    \              /::::\   \:::\    \      /::::\   \:::\    \      /::::\   \:::\    \   
  /:::/  |::|___|______    /:::/    /       ___\:::\   \:::\    \    /::::::\    \   _____    /::::::\   \:::\    \    /::::::\   \:::\    \    /::::::\   \:::\    \  
 /:::/   |::::::::\    \  /:::/    /       /\   \:::\   \:::\    \  /:::/\:::\    \ /\    \  /:::/\:::\   \:::\    \  /:::/\:::\   \:::\____\  /:::/\:::\   \:::\____\ 
/:::/    |:::::::::\____\/:::/____/       /::\   \:::\   \:::\____\/:::/  \:::\    /::\____\/:::/  \:::\   \:::\____\/:::/  \:::\   \:::|    |/:::/  \:::\   \:::|    |
\::/    / ~~~~~/:::/    /\:::\    \       \:::\   \:::\   \::/    /\::/    \:::\  /:::/    /\::/    \:::\  /:::/    /\::/   |::::\  /:::|____|\::/    \:::\  /:::|____|
 \/____/      /:::/    /  \:::\    \       \:::\   \:::\   \/____/  \/____/ \:::\/:::/    /  \/____/ \:::\/:::/    /  \/____|:::::\/:::/    /  \/_____/\:::\/:::/    /  
             /:::/    /    \:::\    \       \:::\   \:::\    \               \::::::/    /            \::::::/    /         |:::::::::/    /            \::::::/    /   
            /:::/    /      \:::\    \       \:::\   \:::\____\               \::::/    /              \::::/    /          |::|\::::/    /              \::::/    /    
           /:::/    /        \:::\    \       \:::\  /:::/    /               /:::/    /               /:::/    /           |::| \::/____/                \::/____/     
          /:::/    /          \:::\    \       \:::\/:::/    /               /:::/    /               /:::/    /            |::|  ~|                       ~~           
         /:::/    /            \:::\    \       \::::::/    /               /:::/    /               /:::/    /             |::|   |                                   
        /:::/    /              \:::\____\       \::::/    /               /:::/    /               /:::/    /              \::|   |                                   
        \::/    /                \::/    /        \::/    /                \::/    /                \::/    /                \:|   |                                   
         \/____/                  \/____/          \/____/                  \/____/                  \/____/                  \|___|                                    
```    

# MLSharp 3D Maker - Flutter 重构版

![Python](https://img.shields.io/badge/Python-3.11+-blue.svg)
![FastAPI](https://img.shields.io/badge/FastAPI-0.128+-green.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)
![API](https://img.shields.io/badge/API-RESTful-blueviolet.svg)
[![Platform: Android](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)](https://www.android.com)
[![Qualcomm Snapdragon](https://img.shields.io/badge/Supports-Qualcomm_Snapdragon_SDK-ED1C24?logo=qualcomm&logoColor=white)](https://developer.qualcomm.com/)
[![stars](https://img.shields.io/github/stars/chidcGithub/mlsharp-flutter-reconstruction)](https://github.com/chidcGithub/mlsharp-flutter-reconstruction)
[![GitHub Release (including pre-releases)](https://img.shields.io/github/v/release/chidcGithub/mlsharp-flutter-reconstruction?label=latest)](https://github.com/ChidcGithub/mlsharp-flutter-reconstruction/releases)

## 项目简介

**MLSharp 3D Maker**（代号：**Ansharp**）是基于 Flutter 框架对原始 [MLSharp-3D-Maker-GPU](https://github.com/ChidcGithub/MLSharp-3D-Maker-GPU) 项目的重构版本。它旨在提供一个跨平台、高性能的移动端应用，用于从单张照片生成高质量的 3D 高斯泼溅（3D Gaussian Splatting）模型。本重构版特别优化了对高通骁龙（Snapdragon）NPU 的支持，以实现更快的本地推理速度。

## 主要特性

*   **跨平台支持**：基于 Flutter 构建，可轻松部署到 Android、iOS 等平台。
*   **本地 ONNX 推理**：集成 `onnxruntime`，支持在设备本地运行 ONNX 格式的 3D 模型。
*   **骁龙 NPU 加速**：通过 `onnxruntime` 适配，可利用高通骁龙处理器的 NPU 进行硬件加速，显著提升推理性能。
*   **本地模型导入**：用户可从设备存储中选择并导入自定义的 ONNX 模型文件。
*   **直观的用户界面**：全新设计的 Flutter UI，提供流畅的用户体验。
*   **底部导航栏**：方便在“主页”（云端生成）、“本地推理”、“终端”和“设置”之间切换。
*   **设置中心**：
    *   **主题切换**：支持明亮/深色模式。
    *   **后端连接**：可配置连接到远程模型服务（例如，运行在 PC 上的 Python 后端）。
    *   **日志导出**：方便导出应用运行日志进行调试和分析。
    *   **版本信息**：显示应用版本、构建号和制作人信息。
*   **实时终端显示**：提供一个内置终端界面，实时显示推理过程中的日志信息。
*   **自动化构建与发布**：通过 GitHub Actions 实现 APK 的自动构建和 Release 发布。

## 技术栈

*   **前端框架**：Flutter
*   **3D 模型渲染**：`model_viewer_plus` (基于 Google `<model-viewer>`)，支持 GLB/GLTF 格式。
*   **AI 推理**：`onnxruntime` (ONNX Runtime Flutter Plugin)
*   **状态管理**：`provider`
*   **其他核心库**：`image_picker`, `file_picker`, `shared_preferences`, `logger`, `package_info_plus`, `share_plus` 等。

## 快速开始

### 前提条件

*   [Flutter SDK](https://flutter.dev/docs/get-started/install) (推荐 `stable` 频道)
*   [Android Studio](https://developer.android.com/studio) 或 [VS Code](https://code.visualstudio.com/) (带 Flutter 插件)
*   Git

### 1. 克隆仓库

```bash
git clone https://github.com/ChidcGithub/mlsharp-flutter-reconstruction.git
cd mlsharp-flutter-reconstruction
```

### 2. 安装依赖

```bash
flutter pub get
```

### 3. 运行应用

连接您的 Android 设备或启动模拟器，然后运行：

```bash
flutter run
```

## 使用指南

### 本地推理

1.  切换到底部导航栏的“本地推理”页面。
2.  点击“选择 ONNX 模型”按钮，从设备中选择您的 `.onnx` 模型文件。
    *   **注意**：如果您的模型文件较大，通常会伴随一个同名的 `.onnx.data` 文件。请确保这两个文件位于同一目录下，应用会自动加载它们。
3.  （可选）打开“启用骁龙 NPU”开关，如果您的设备支持，将尝试使用 NPU 进行加速。
4.  点击“选择图片”按钮，选择一张用于 3D 生成的输入图片。
5.  点击“开始推理”按钮，应用将开始在本地设备上执行推理。

### 终端

切换到底部导航栏的“终端”页面，您可以实时查看推理过程中的日志输出，包括模型加载、推理状态、错误信息等。终端支持导出和清空日志。

### 设置

切换到底部导航栏的“设置”页面，您可以：
*   切换应用的明亮/深色主题。
*   配置后端服务器地址，用于连接远程模型服务。
*   导出应用日志。
*   查看应用的版本信息和制作人。

## GitHub Actions 自动化

本项目配置了 GitHub Actions，实现 APK 的自动构建和发布：

*   **推送 `main` 分支**：每次向 `main` 分支推送代码时，会自动触发构建，并更新一个名为 `Latest Development Build` 的 Release。
*   **推送 `v*` 标签**：当您推送以 `v` 开头的标签（例如 `v0.0.1-rc3`）时，会自动创建一个新的 Release，并将构建好的 APK 上传到该 Release 页面。

您可以在 [Actions](https://github.com/ChidcGithub/mlsharp-flutter-reconstruction/actions) 页面查看构建状态，并在 [Releases](https://github.com/ChidcGithub/mlsharp-flutter-reconstruction/releases) 页面下载最新的 APK。

## 贡献

欢迎所有形式的贡献！如果您有任何建议、功能请求或 Bug 报告，请随时提交 Issue 或 Pull Request。

## 许可证

本项目采用 MIT 许可证 - 详情请参阅 [LICENSE](LICENSE) 文件。

## 鸣谢

*   **Chidc** - 项目发起人与核心开发者
*   **Manus AI** - 协助项目重构与自动化流程构建

---
