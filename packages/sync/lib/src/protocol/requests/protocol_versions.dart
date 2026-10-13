part of '../../../sync.dart';

// MARK: - Protocol Versions

/// The confirmed sync protocol major.
///
/// Set to `1` per `docs/sync-protocol.md` §6: "Every request declares exactly
/// one protocol major", with no second major defined anywhere in the design
/// document. This is the confirmed protocol major, not a provisional value.
const int syncProtocolVersion = 1;

/// Operation protocol major declared by every v2 request.
///
/// Deliberately separate from the envelope `protocol_version`: the envelope
/// version stays 1 while bound operations declare major 2 with no downgrade.
const int syncOperationMajor = 2;
