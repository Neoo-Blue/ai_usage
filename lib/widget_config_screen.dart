import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'db.dart';
import 'models.dart';
import 'widget_bridge.dart';

const _channel = MethodChannel('aiusage/widget_config');

// Shown by the native WidgetConfigActivity when a widget is placed. Picks the
// account, theme, and metrics for that specific widget instance.
class WidgetConfigScreen extends StatefulWidget {
  final String widgetId;
  const WidgetConfigScreen({super.key, required this.widgetId});

  @override
  State<WidgetConfigScreen> createState() => _WidgetConfigScreenState();
}

class _WidgetConfigScreenState extends State<WidgetConfigScreen> {
  List<Account> _accounts = [];
  Account? _account;
  WidgetTheme _theme = WidgetTheme.adaptive;
  final _metrics = <String>{'plan'};
  bool _loading = true;

  static const _available = {
    'plan': 'Plan',
    'session_used': 'Session used',
    'quota_used': 'Quota used',
    'quota_limit': 'Quota limit',
    'resets_at': 'Time to reset',
    'tokens_remaining': 'Tokens remaining',
    'requests_remaining': 'Requests remaining',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final accounts = await Db.instance.allAccounts();
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _account = accounts.isNotEmpty ? accounts.first : null;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_account == null) return;
    await Db.instance.upsertWidgetConfig(WidgetConfig(
      id: widget.widgetId,
      accountId: _account!.id,
      theme: _theme,
      metricTypes: _metrics.toList(),
    ));
    await pushWidgetSnapshot(widget.widgetId);
    await _channel.invokeMethod('finish');
  }

  String _themeLabel(WidgetTheme t) => switch (t) {
        WidgetTheme.minimalist => 'Minimalist',
        WidgetTheme.elegant => 'Elegant',
        WidgetTheme.futuristic => 'Futuristic',
        WidgetTheme.neumorphic => 'Neumorphic',
        WidgetTheme.retro => 'Retro',
        WidgetTheme.adaptive => 'Adaptive (Material You)',
      };

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _channel.invokeMethod('cancel');
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Widget setup'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _channel.invokeMethod('cancel'),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _accounts.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Connect an account in the app first, then add the widget.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text('Account', style: TextStyle(fontWeight: FontWeight.bold)),
                      for (final a in _accounts)
                        RadioListTile<Account>(
                          value: a,
                          groupValue: _account,
                          title: Text(a.label),
                          subtitle: Text(a.provider.name),
                          onChanged: (v) => setState(() => _account = v),
                        ),
                      const Divider(),
                      const Text('Theme', style: TextStyle(fontWeight: FontWeight.bold)),
                      for (final t in WidgetTheme.values)
                        RadioListTile<WidgetTheme>(
                          value: t,
                          groupValue: _theme,
                          title: Text(_themeLabel(t)),
                          onChanged: (v) => setState(() => _theme = v!),
                        ),
                      const Divider(),
                      const Text('Metrics', style: TextStyle(fontWeight: FontWeight.bold)),
                      for (final e in _available.entries)
                        CheckboxListTile(
                          value: _metrics.contains(e.key),
                          title: Text(e.value),
                          onChanged: (on) => setState(() =>
                              on == true ? _metrics.add(e.key) : _metrics.remove(e.key)),
                        ),
                      const SizedBox(height: 20),
                      FilledButton(onPressed: _save, child: const Text('Add widget')),
                    ],
                  ),
      ),
    );
  }
}
