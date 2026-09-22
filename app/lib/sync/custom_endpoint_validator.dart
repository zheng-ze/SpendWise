import 'package:spendwise/sync/sync_backend_resolver.dart';

/// Shared non-throwing validator for custom sync endpoints.
///
/// Both [SyncBackendResolver] and a future backend-picker controller enforce
/// the same rule from here: the endpoint must be an absolute HTTPS URI with a
/// non-empty host. A picker consumes [InvalidCustomEndpoint.failure] as
/// validation state; the resolver throws that same failure at its own call
/// site, preserving its throw-based contract.
sealed class CustomEndpointValidation {
  const CustomEndpointValidation();

  static CustomEndpointValidation validate(String? endpoint) {
    final uri = endpoint == null ? null : Uri.tryParse(endpoint);
    if (uri == null || !uri.isAbsolute) {
      return InvalidCustomEndpoint(
        SyncBackendConfigurationException(
          'Custom sync endpoint must be an absolute URI; got "$endpoint".',
        ),
      );
    }
    if (uri.scheme != 'https') {
      return InvalidCustomEndpoint(
        SyncBackendConfigurationException(
          'Custom sync endpoint scheme must be "https"; got "${uri.scheme}".',
        ),
      );
    }
    if (uri.host.isEmpty) {
      return InvalidCustomEndpoint(
        SyncBackendConfigurationException(
          'Custom sync endpoint must have a non-empty host; got "$endpoint".',
        ),
      );
    }
    return ValidCustomEndpoint(uri);
  }
}

/// A validated custom sync endpoint ready for backend construction.
final class ValidCustomEndpoint extends CustomEndpointValidation {
  const ValidCustomEndpoint(this.uri);

  final Uri uri;
}

/// A rejected custom sync endpoint carrying the typed failure.
///
/// The failure is a return value, never thrown here.
final class InvalidCustomEndpoint extends CustomEndpointValidation {
  const InvalidCustomEndpoint(this.failure);

  final SyncBackendConfigurationException failure;
}
