import 'package:domain/domain.dart';
import 'package:spendwise/persistence/ledger_database.dart';

final _cachedDeviceIDs = Expando<Future<String>>();

Future<String> deviceID(LedgerDatabase db) =>
    _cachedDeviceIDs[db] ??= _claimDeviceID(db);

Future<String> _claimDeviceID(LedgerDatabase db) async {
  final existing = await db.select(db.storeMeta).getSingleOrNull();
  if (existing != null) return normalizedID(existing.deviceId);

  final claimed = normalizedID(newID());
  await db
      .into(db.storeMeta)
      .insert(StoreMetaRow(id: 0, deviceId: claimed, hasSeeded: false));
  return claimed;
}
