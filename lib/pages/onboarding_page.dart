import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_settings_provider.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _skipOnboarding() {
    context.read<AppSettingsProvider>().setOnboardingCompleted(true);
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (page) {
              setState(() {
                _currentPage = page;
              });
            },
            children: [
              _buildWelcomePage(colorScheme),
              _buildFeaturePage1(colorScheme),
              _buildFeaturePage2(colorScheme),
              _buildSetupPage(colorScheme),
            ],
          ),
          // 页面指示器
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4,
                (index) => Container(
                  width: _currentPage == index ? 32 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _currentPage == index
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
          ),
          // 底部按钮
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Row(
              children: [
                if (_currentPage > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Text('上一步'),
                    ),
                  ),
                if (_currentPage > 0) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentPage == 3) {
                        _skipOnboarding();
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    child: Text(_currentPage == 3 ? '开始使用' : '下一步'),
                  ),
                ),
              ],
            ),
          ),
          // 跳过按钮
          if (_currentPage < 3)
            Positioned(
              top: 16,
              right: 16,
              child: SafeArea(
                child: TextButton(
                  onPressed: _skipOnboarding,
                  child: const Text('跳过'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWelcomePage(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            colorScheme.secondary,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 40),
          const Text(
            'MLSharp 3D Maker',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            '一键生成高质量 3D 模型',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildFeaturePage1(ColorScheme colorScheme) {
    return _buildBaseFeaturePage(
      colorScheme: colorScheme,
      icon: Icons.cloud_upload,
      title: '远程推理',
      description: '连接到电脑上的 Python 后端，享受强大的 GPU 加速。',
      features: [
        '支持 NVIDIA/AMD/Intel GPU',
        '自动 GPU 显存管理',
        '推理结果实时预览',
      ],
    );
  }

  Widget _buildFeaturePage2(ColorScheme colorScheme) {
    return _buildBaseFeaturePage(
      colorScheme: colorScheme,
      icon: Icons.phone_android,
      title: '本地推理',
      description: '直接在手机上运行 ONNX 模型，无需网络连接。',
      features: [
        '支持 Snapdragon NPU 加速',
        '离线推理，隐私保护',
        '支持自定义模型导入',
      ],
    );
  }

  Widget _buildSetupPage(ColorScheme colorScheme) {
    return _buildBaseFeaturePage(
      colorScheme: colorScheme,
      icon: Icons.settings_suggest,
      title: '准备就绪',
      description: '配置您的后端地址或导入本地模型，开启 3D 创作之旅。',
      features: [
        '支持 Material 3 动态配色',
        '详尽的终端日志输出',
        '一键导出应用日志',
      ],
    );
  }

  Widget _buildBaseFeaturePage({
    required ColorScheme colorScheme,
    required IconData icon,
    required String title,
    required String description,
    required List<String> features,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primaryContainer,
            ),
            child: Icon(
              icon,
              size: 50,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ...features.map((feature) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, size: 18, color: colorScheme.primary),
                const SizedBox(width: 12),
                Text(feature, style: const TextStyle(fontSize: 14)),
              ],
            ),
          )),
          const Spacer(),
        ],
      ),
    );
  }
}
