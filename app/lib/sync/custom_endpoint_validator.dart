import 'package:spendwise/sync/sync_backend_resolver.dart';

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

final class ValidCustomEndpoint extends CustomEndpointValidation {
  const ValidCustomEndpoint(this.uri);

  final Uri uri;
}

final class InvalidCustomEndpoint extends CustomEndpointValidation {
  const InvalidCustomEndpoint(this.failure);

  final SyncBackendConfigurationException failure;
}
