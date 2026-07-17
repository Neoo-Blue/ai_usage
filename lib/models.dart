// Plain model layer. Persistence uses sqflite (raw SQL), so these map to and
// from string keyed rows. Enums are stored by name for readable rows.

enum ProviderId { anthropic, openai, google }

enum AccountKind { subscription, api }

enum AccountStatus { active, needsReauth, error }

T enumByName<T>(List<T> values, String name, T fallback) {
  for (final v in values) {
    if ((v as Enum).name == name) return v;
  }
  return fallback;
}

class Account {
  final String id; // client UUID, provider agnostic, stable
  final ProviderId provider;
  final AccountKind kind;
  final String label;
  final String? remoteUserId;
  final String? planName;
  final AccountStatus status;
  final DateTime? lastSyncAt;
  final DateTime createdAt;

  Account({
    required this.id,
    required this.provider,
    required this.kind,
    required this.label,
    this.remoteUserId,
    this.planName,
    this.status = AccountStatus.active,
    this.lastSyncAt,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'provider': provider.name,
        'kind': kind.name,
        'label': label,
        'remote_user_id': remoteUserId,
        'plan_name': planName,
        'status': status.name,
        'last_sync_at': lastSyncAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  factory Account.fromMap(Map<String, Object?> m) => Account(
        id: m['id'] as String,
        provider: enumByName(ProviderId.values, m['provider'] as String, ProviderId.openai),
        kind: enumByName(AccountKind.values, m['kind'] as String, AccountKind.subscription),
        label: m['label'] as String,
        remoteUserId: m['remote_user_id'] as String?,
        planName: m['plan_name'] as String?,
        status: enumByName(AccountStatus.values, m['status'] as String, AccountStatus.active),
        lastSyncAt: (m['last_sync_at'] as String?) == null
            ? null
            : DateTime.tryParse(m['last_sync_at'] as String),
        createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}

class MetricRow {
  final String accountId;
  final String metricType;
  final double? numValue;
  final String? textValue;
  final String? unit;
  final DateTime capturedAt;

  MetricRow({
    required this.accountId,
    required this.metricType,
    this.numValue,
    this.textValue,
    this.unit,
    required this.capturedAt,
  });

  factory MetricRow.fromMap(Map<String, Object?> m) => MetricRow(
        accountId: m['account_id'] as String,
        metricType: m['metric_type'] as String,
        numValue: (m['num_value'] as num?)?.toDouble(),
        textValue: m['text_value'] as String?,
        unit: m['unit'] as String?,
        capturedAt: DateTime.tryParse(m['captured_at'] as String? ?? '') ?? DateTime.now(),
      );

  String display() {
    if (textValue != null) return textValue!;
    if (numValue != null) {
      final n = numValue! % 1 == 0 ? numValue!.toInt().toString() : numValue!.toStringAsFixed(1);
      return unit != null ? '$n $unit' : n;
    }
    return 'unavailable';
  }
}

enum WidgetTheme { minimalist, elegant, futuristic, neumorphic, retro, adaptive }

class WidgetConfig {
  final String id; // native appWidgetId as string
  final String? accountId;
  final WidgetTheme theme;
  final List<String> metricTypes;

  const WidgetConfig({
    required this.id,
    this.accountId,
    required this.theme,
    required this.metricTypes,
  });
}
