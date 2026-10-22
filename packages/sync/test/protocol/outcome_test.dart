import 'package:sync/sync.dart';
import 'package:test/test.dart';

void main() {
  test('named failure codes match protocol vocabulary', () {
    expect(CredentialExpired<void>().code, 'credential_expired');
    expect(RateLimited<void>().code, 'rate_limited');
    expect(DeviceRetired<void>().code, 'device_retired');
    expect(ReconciliationRequired<void>().code, 'reconciliation_required');
    expect(StaleOrInvalidProof<void>().code, 'stale_or_invalid_proof');
    expect(SnapshotHashMismatch<void>().code, 'snapshot_hash_mismatch');
    expect(ProtocolUnsupported<void>().code, 'protocol_unsupported');
    expect(InvalidRequest<void>().code, 'invalid_request');
    expect(NetworkUnavailable<void>().code, 'network_unavailable');
    expect(BackendUnavailable<void>().code, 'backend_unavailable');
  });
}
