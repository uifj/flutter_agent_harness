// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

/// Package-scoped diagnostic logger for the MQTT module.
///
/// Follows the sentry-dart integration naming convention (`sentry_<name>`)
/// and mirrors `grpc/src/internal_logger.dart` / `link/src/internal_logger.dart`.
@internal
const internalLogger = SentryInternalLogger('sentry_mqtt');
