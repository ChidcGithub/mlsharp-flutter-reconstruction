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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('终端'),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('日志已清空')),
                      );
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
            color: Colors.black87,
            child: logger.logs.isEmpty
                ? const Center(
                    child: Text(
                      '暂无日志',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12.0),
                    itemCount: logger.logs.length,
                    itemBuilder: (context, index) {
                      final log = logger.logs[index];
                      final isError = log.contains('[ERROR]');
                      final isWarning = log.contains('[WARNING]');
                      final isSuccess = log.contains('[SUCCESS]');

                      Color textColor = Colors.grey;
                      if (isError) {
                        textColor = Colors.red;
                      } else if (isWarning) {
                        textColor = Colors.orange;
                      } else if (isSuccess) {
                        textColor = Colors.green;
                      } else if (log.contains('[INFO]')) {
                        textColor = Colors.cyan;
                      }

                      return Text(
                        log,
                        style: TextStyle(
                          color: textColor,
                          fontFamily: 'Courier',
                          fontSize: 12,
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
