part of '../../../sync.dart';

// MARK: - Opaque Wire Response

abstract base class _OpaqueWireResponse {
  _OpaqueWireResponse(Map<String, Object?> wire)
      : wire = Map.unmodifiable(wire);
  final Map<String, Object?> wire;
}
