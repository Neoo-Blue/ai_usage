import 'package:uuid/uuid.dart';

import 'account_mirror.dart';
import 'capture_screen.dart';
import 'db.dart';
import 'models.dart';
import 'vault.dart';

// Turns a capture or a pasted key into a stored account. The UUID is what keeps
// two accounts of the same provider from overwriting each other.
class AccountRepository {
  static final _uuid = Uuid();

  static Future<String> connectFromCapture({
    required CapturedCredential captured,
    required String label,
  }) async {
    // Duplicate guard: same provider + same remote id relabels in place.
    final remote = captured.remoteUserId;
    if (remote != null) {
      final existing = await Db.instance.findByRemote(captured.provider, remote);
      if (existing != null) {
        await Vault.save(existing.id, captured.bundle);
        await AccountMirror.push();
        return existing.id;
      }
    }

    final id = _uuid.v4();
    await Vault.save(id, captured.bundle);
    await Db.instance.insertAccount(Account(
      id: id,
      provider: captured.provider,
      kind: AccountKind.subscription,
      label: label,
      remoteUserId: remote,
      planName: captured.plan,
      status: AccountStatus.active,
      createdAt: DateTime.now(),
    ));
    await AccountMirror.push();
    return id;
  }

  static Future<String> connectApiKey({
    required ProviderId provider,
    required String label,
    required String apiKey,
  }) async {
    final id = _uuid.v4();
    await Vault.save(id, {'apiKey': apiKey});
    await Db.instance.insertAccount(Account(
      id: id,
      provider: provider,
      kind: AccountKind.api,
      label: label,
      status: AccountStatus.active,
      createdAt: DateTime.now(),
    ));
    await AccountMirror.push();
    return id;
  }

  static Future<void> delete(String accountId) async {
    await Vault.delete(accountId);
    await Db.instance.deleteAccount(accountId);
    await AccountMirror.push();
  }
}
