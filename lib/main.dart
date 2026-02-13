import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'theme/app_theme.dart';
import 'providers/app_settings_provider.dart';
import 'services/inference_logger.dart';
import 'services/history_service.dart';
import 'pages/onboarding_page.dart';
import 'pages/home_page.dart';
import 'pages/local_inference_page.dart';
import 'pages/terminal_page.dart';
import 'pages/settings_page.dart';
import 'pages/history_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settingsProvider = AppSettingsProvider();
  await settingsProvider.init();
  
  final historyService = HistoryService();
  await historyService.init();

  // 初始化 Sentry
  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://example@sentry.io/example'; // 占位 DSN
      options.tracesSampleRate = 1.0;
      options.reportSilentFlutterErrors = true;
    },
    appRunner: () => runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => settingsProvider),
          ChangeNotifierProvider(create: (_) => InferenceLogger()),
          Provider<HistoryService>.value(value: historyService),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettingsProvider>(
      builder: (context, settings, _) {
        return DynamicColorBuilder(
          builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
            ColorScheme lightColorScheme;
            ColorScheme darkColorScheme;

            if (settings.useDynamicColor && lightDynamic != null && darkDynamic != null) {
              // 为Android 16优化动态颜色
              lightColorScheme = lightDynamic.copyWith(
                primaryContainer: lightDynamic.primaryContainer,
                secondaryContainer: lightDynamic.secondaryContainer,
                tertiaryContainer: lightDynamic.tertiaryContainer,
              ).harmonized();
              darkColorScheme = darkDynamic.copyWith(
                primaryContainer: darkDynamic.primaryContainer,
                secondaryContainer: darkDynamic.secondaryContainer,
                tertiaryContainer: darkDynamic.tertiaryContainer,
              ).harmonized();
            } else {
              lightColorScheme = ColorScheme.fromSeed(
                seedColor: settings.seedColor,
                brightness: Brightness.light,
              );
              darkColorScheme = ColorScheme.fromSeed(
                seedColor: settings.seedColor,
                brightness: Brightness.dark,
              );
            }

            return MaterialApp(
              title: 'Ansharp',
              theme: AppTheme.lightTheme(colorScheme: lightColorScheme),
              darkTheme: AppTheme.darkTheme(colorScheme: darkColorScheme),
              themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
              navigatorObservers: [
                SentryNavigatorObserver(),
              ],
              home: settings.onboardingCompleted 
                  ? const MyHomePage(title: 'Ansharp')
                  : const OnboardingPage(),
              routes: {
                '/home': (context) => const MyHomePage(title: 'Ansharp'),
                '/onboarding': (context) => const OnboardingPage(),
              },
              debugShowCheckedModeBanner: false,
            );
          },
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const HistoryPage(), // 历史记录页面
    const TerminalPage(),
    const SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showInferenceChoiceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('选择推理方式'),
          content: const Text('请选择您想要的推理方式：'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // 关闭对话框
                // 导航到云端推理页面（当前的LocalInferencePage）
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LocalInferencePage()),
                );
              },
              child: const Text('云端推理'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // 关闭对话框
                // TODO: 这里可以添加本地推理页面的导航
                // Navigator.push(
                //   context,
                //   MaterialPageRoute(builder: (context) => const LocalInferencePage()),
                // );
                // 暂时提示功能未实现
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('本地推理功能暂未实现')),
                );
              },
              child: const Text('本地推理'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      floatingActionButton: _selectedIndex == 0 
          ? FloatingActionButton(
              onPressed: () {
                _showInferenceChoiceDialog(context);
              },
              child: const Icon(Icons.add),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: _onItemTapped,
        selectedIndex: _selectedIndex,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '主页',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            selectedIcon: Icon(Icons.history),
            label: '历史记录',
          ),
          NavigationDestination(
            icon: Icon(Icons.terminal_outlined),
            selectedIcon: Icon(Icons.terminal),
            label: '终端',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
