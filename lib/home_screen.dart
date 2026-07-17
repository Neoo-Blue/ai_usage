import 'package:flutter/material.dart';

import 'account_repository.dart';
import 'api_key_screen.dart';
import 'capture_screen.dart';
import 'db.dart';
import 'models.dart';
import 'providers.dart';
import 'sync.dart';

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

  Widget _accountTile(Account a) {
    final metrics = _metrics[a.id] ?? const [];
    final busy = _syncing.contains(a.id);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: ListTile(
        title: Text(a.label),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${a.provider.name} . ${a.kind.name} . ${a.status.name}'),
            if (metrics.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  metrics.map((m) => '${m.metricType}: ${m.display()}').join('\n'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            if (a.lastSyncAt != null)
              Text('Last synced ${a.lastSyncAt}', style: const TextStyle(fontSize: 11)),
          ],
        ),
        isThreeLine: true,
        trailing: busy
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'sync') _sync(a);
                  if (v == 'delete') _delete(a);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'sync', child: Text('Sync now')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
        onTap: busy ? null : () => _sync(a),
      ),
    );
  }
}
