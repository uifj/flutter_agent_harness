// Product metadata and help links (ADR-0045 PG).
//
// [version] is a THIRD copy of the pubspec version and that is deliberate:
// the About dialog needs the value synchronously without a package_info
// dependency (adding one needs its own DEP ADR). `app_meta_test.dart` pins
// the two against each other, so a bump that misses one fails the suite.
//
// The help URLs point at the product's future home. They are shipped as
// placeholders today — the real domain belongs to the same self-built
// backend decision as the rest of ADR-0045 form ②; changing them here is
// the whole switch.

abstract final class AppMeta {
  /// Must match pubspec.yaml's `version:` — pinned by test.
  static const String version = '0.1.0';

  static const String productName = 'agent_harness';

  /// 产品文档 (product docs).
  static const String docsUrl = 'https://docs.agent-harness.dev';

  /// 用户社群 (user community).
  static const String communityUrl = 'https://community.agent-harness.dev';

  /// 问题上报 (issue tracker).
  static const String issuesUrl =
      'https://github.com/uifj/flutter_agent_harness/issues';

  /// 给产品提需求 (feature requests — the same tracker, feature label).
  static const String featureRequestUrl =
      'https://github.com/uifj/flutter_agent_harness/issues';

  /// 发现新版本's landing page: the release channel the updater will poll
  /// once signing lands (ADR-0045 PD 前置). Today the row opens this page.
  static const String releasesUrl =
      'https://github.com/uifj/flutter_agent_harness/releases';
}
