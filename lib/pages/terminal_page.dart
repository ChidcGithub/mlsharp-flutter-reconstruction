import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/inference_logger.dart';

class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key});

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _exportLogs(String logsText) async {
    try {
      await Share.share(
        logsText,
        subject: 'MLSharp 推理日志',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('终端'),
        elevation: 0,
        actions: [
          Consumer<InferenceLogger>(
            builder: (context, logger, _) {
              return PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: const Text('导出日志'),
                    onTap: () {
                      _exportLogs(logger.allLogsText);
                    },
                  ),
                  PopupMenuItem(
                    child: const Text('清空日志'),
                    onTap: () {
                      logger.clearLogs();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✅ 日志已清空')),
                        );
                      }
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<InferenceLogger>(
        builder: (context, logger, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.grey.shade900,
                  Colors.grey.shade800,
                ],
              ),
            ),
            child: logger.logs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.terminal,
                          size: 64,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '暂无日志',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '执行推理操作后日志将显示在这里',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12.0),
                    itemCount: logger.logs.length,
                    itemBuilder: (context, index) {
                      final log = logger.logs[index];
                      final isError = log.contains('❌') || log.contains('[ERROR]');
                      final isWarning = log.contains('⚠️') || log.contains('[WARNING]');
                      final isSuccess = log.contains('✅') || log.contains('[SUCCESS]');

                      Color textColor = Colors.grey.shade400;
                      if (isError) {
                        textColor = Colors.red.shade400;
                      } else if (isWarning) {
                        textColor = Colors.orange.shade400;
                      } else if (isSuccess) {
                        textColor = Colors.green.shade400;
                      } else if (log.contains('🔄') || log.contains('[INFO]')) {
                        textColor = Colors.cyan.shade400;
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Text(
                          log,
                          style: TextStyle(
                            color: textColor,
                            fontFamily: 'monospace',
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
