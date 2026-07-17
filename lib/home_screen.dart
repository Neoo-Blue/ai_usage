import 'package:flutter/material.dart';

import 'account_repository.dart';
import 'api_key_screen.dart';
import 'capture_screen.dart';
import 'db.dart';
import 'models.dart';
import 'providers.dart';
import 'sync.dart';
import 'widget_bridge.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Account> _accounts = [];
  final Map<String, List<MetricRow>> _metrics = {};
  final Set<String> _syncing = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final accounts = await Db.instance.allAccounts();
    _metrics.clear();
    for (final a in accounts) {
      _metrics[a.id] = await Db.instance.metricsFor(a.id);
    }
    await refreshAllWidgets();
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _loading = false;
    });
  }

  Future<void> _connectSubscription(ProviderId provider) async {
    final config = providerConfigs[provider]!;
    final captured = await Navigator.push<CapturedCredential?>(
      context,
      MaterialPageRoute(builder: (_) => CaptureScreen(config: config)),
    );
    if (!mounted || captured == null || captured.bundle.isEmpty) return;

    // Repaint once the WebView platform view is gone, so the dialog and the
    // list do not sit over a stale black surface on some devices.
    setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;

    final label = await _askLabel(
      defaultLabel: captured.email ?? '${config.displayName} account',
    );
    if (!mounted || label == null) return;

    await AccountRepository.connectFromCapture(captured: captured, label: label);
    if (!mounted) return;
    await _reload();
  }

  Future<void> _addApiKey() async {
    final result = await Navigator.push<ApiKeyResult?>(
      context,
      MaterialPageRoute(builder: (_) => const ApiKeyScreen()),
    );
    if (result == null) return;
    await AccountRepository.connectApiKey(
      provider: result.provider,
      label: result.label,
      apiKey: result.apiKey,
    );
    await _reload();
  }

  Future<String?> _askLabel({required String defaultLabel}) {
    final controller = TextEditingController(text: defaultLabel);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Name this account'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Personal, Work, ...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _sync(Account a) async {
    setState(() => _syncing.add(a.id));
    final result = await syncOne(a);
    await _reload();
    if (!mounted) return;
    setState(() => _syncing.remove(a.id));
    if (result.note != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.note!)));
    }
  }

  Future<void> _delete(Account a) async {
    await AccountRepository.delete(a.id);
    await _reload();
  }

  void _openAddSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Connect a subscription (login)')),
            for (final provider in [ProviderId.openai, ProviderId.anthropic, ProviderId.google])
              ListTile(
                leading: const Icon(Icons.login),
                title: Text(providerConfigs[provider]!.displayName),
                onTap: () {
                  Navigator.pop(ctx);
                  _connectSubscription(provider);
                },
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.key),
              title: const Text('Add a developer API key'),
              subtitle: const Text('Returns live numbers'),
              onTap: () {
                Navigator.pop(ctx);
                _addApiKey();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Usage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Sync all',
            onPressed: () async {
              await syncAll();
              await _reload();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add account'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
              ? const Center(child: Text('No accounts yet. Tap Add account.'))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: _accounts.length,
                  itemBuilder: (_, i) => _accountTile(_accounts[i]),
                ),
    );
  }

  double? _num(List<MetricRow> ms, String type) {
    for (final m in ms) {
      if (m.metricType == type) return m.numValue;
    }
    return null;
  }

  String? _text(List<MetricRow> ms, String type) {
    for (final m in ms) {
      if (m.metricType == type) return m.textValue;
    }
    return null;
  }

  String _resetLabel(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final t = DateTime.tryParse(iso)?.toLocal();
    if (t == null) return '';
    final diff = t.difference(DateTime.now());
    if (diff.inSeconds <= 0) return 'Resets soon';
    if (diff.inHours < 24) {
      final h = diff.inHours;
      final m = diff.inMinutes % 60;
      return h > 0 ? 'Resets in $h hr $m min' : 'Resets in $m min';
    }
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final hh = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final ampm = t.hour < 12 ? 'AM' : 'PM';
    final mm = t.minute.toString().padLeft(2, '0');
    return 'Resets ${days[t.weekday - 1]} $hh:$mm $ampm';
  }

  Widget _bar(String label, double? pct, String? resetIso) {
    if (pct == null) return const SizedBox.shrink();
    final v = (pct / 100).clamp(0.0, 1.0);
    final reset = _resetLabel(resetIso);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text('${pct.round()}% used', style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: v, minHeight: 7),
          ),
          if (reset.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(reset, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ),
        ],
      ),
    );
  }

  Widget _accountTile(Account a) {
    final metrics = _metrics[a.id] ?? const <MetricRow>[];
    final busy = _syncing.contains(a.id);
    final email = _text(metrics, 'account');
    final plan = _text(metrics, 'plan');
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: InkWell(
        onTap: busy ? null : () => _sync(a),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(
                          email ?? '${a.provider.name} . ${a.status.name}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        if (plan != null)
                          Text('plan: $plan', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  if (busy)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    PopupMenuButton<String>(
                      onSelected: (val) {
                        if (val == 'sync') _sync(a);
                        if (val == 'delete') _delete(a);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'sync', child: Text('Sync now')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                ],
              ),
              _bar('Current session', _num(metrics, 'session_used'), _text(metrics, 'session_resets_at')),
              _bar('Weekly, all models', _num(metrics, 'weekly_used'), _text(metrics, 'weekly_resets_at')),
              _bar('Weekly, Fable', _num(metrics, 'weekly_opus_used'), _text(metrics, 'weekly_opus_resets_at')),
              _bar('Weekly, Sonnet', _num(metrics, 'weekly_sonnet_used'), _text(metrics, 'weekly_sonnet_resets_at')),
            ],
          ),
        ),
      ),
    );
  }
}
