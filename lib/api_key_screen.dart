import 'package:flutter/material.dart';

import 'models.dart';

class ApiKeyResult {
  final ProviderId provider;
  final String label;
  final String apiKey;
  ApiKeyResult(this.provider, this.label, this.apiKey);
}

// Developer API keys are pasted, not captured. This path returns real numbers
// because api.* endpoints are not behind Cloudflare and report live budget in
// response headers.
class ApiKeyScreen extends StatefulWidget {
  const ApiKeyScreen({super.key});

  @override
  State<ApiKeyScreen> createState() => _ApiKeyScreenState();
}

class _ApiKeyScreenState extends State<ApiKeyScreen> {
  ProviderId _provider = ProviderId.anthropic;
  final _label = TextEditingController(text: 'API key');
  final _key = TextEditingController();

  @override
  void dispose() {
    _label.dispose();
    _key.dispose();
    super.dispose();
  }

  void _save() {
    if (_key.text.trim().isEmpty) return;
    Navigator.pop(context, ApiKeyResult(_provider, _label.text.trim(), _key.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add API key')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<ProviderId>(
            value: _provider,
            decoration: const InputDecoration(labelText: 'Provider'),
            items: const [
              DropdownMenuItem(value: ProviderId.anthropic, child: Text('Anthropic')),
              DropdownMenuItem(value: ProviderId.openai, child: Text('OpenAI')),
            ],
            onChanged: (v) => setState(() => _provider = v ?? ProviderId.anthropic),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _label,
            decoration: const InputDecoration(labelText: 'Label'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _key,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'API key',
              hintText: 'sk-ant-... or sk-...',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}
