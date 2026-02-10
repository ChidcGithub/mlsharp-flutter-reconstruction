import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/inference_logger.dart';

class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key});

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Color _getLogColor(LogLevel level, ColorScheme colorScheme) {
    switch (level) {
      case LogLevel.error: return colorScheme.error;
      case LogLevel.warning: return Colors.orange.shade600;
      case LogLevel.success: return Colors.green.shade600;
      case LogLevel.debug: return colorScheme.onSurfaceVariant;
      case LogLevel.info: return colorScheme.onSurface;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final logger = context.watch<InferenceLogger>();
    final logs = logger.logs;

    _scrollToBottom();

    return Scaffold(
      appBar: AppBar(
        title: const Text('终端日志'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              context.read<InferenceLogger>().clearLogs();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('日志已清空')),
              );
            },
            tooltip: '清空日志',
          ),
          IconButton(
            icon: const Icon(Icons.vertical_align_bottom),
            onPressed: _scrollToBottom,
            tooltip: '滚动到底部',
          ),
        ],
      ),
      body: Container(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
        child: logs.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.terminal, size: 64, color: colorScheme.onSurfaceVariant.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    Text(
                      '暂无日志信息',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  final level = log['level'] as LogLevel;
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(
                            text: '[${log['timestamp']}] ',
                            style: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.8)),
                          ),
                          TextSpan(
                            text: log['fullText'].toString().split('] ').sublist(1).join('] '),
                            style: TextStyle(
                              color: _getLogColor(level, colorScheme),
                              fontWeight: level == LogLevel.error || level == LogLevel.warning 
                                  ? FontWeight.bold 
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
