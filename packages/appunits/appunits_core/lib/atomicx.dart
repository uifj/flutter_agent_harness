/// Compatibility barrel for the vendored Tencent TUIKit `base_component`.
///
/// Upstream sources import `package:appunits_core/atomicx.dart` — the original
/// package's entry name (`atomicx`). The vendored entry here is
/// `appunits_core.dart`; this alias re-exports it so those internal imports
/// resolve without editing the vendored files. (ADR-0083)
library;

export 'appunits_core.dart';
