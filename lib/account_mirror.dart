import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import 'db.dart';

// Writes a small, secret free projection of the account list into the App Group
// so the iOS widget configuration EntityQuery can list accounts. Harmless on
// Android. Wrapped so a missing App Group never crashes the app.
class AccountMirror {
  static Future<void> push() async {
    try {
      final accounts = await Db.instance.allAccounts();
      final index = [
        for (final a in accounts)
          {
            'id': a.id,
            'label': a.label,
            'provider': a.provider.name,
            'kind': a.kind.name,
            'status': a.status.name,
          }
      ];
      await HomeWidget.saveWidgetData('accounts_index', jsonEncode(index));
    } catch (_) {
      // No App Group configured yet (this cut ships without the native widget).
    }
  }
}
