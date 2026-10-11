// The seed-name bridge — the one piece of l10n glue that is neither generated
// nor allowed to live in `lib/model`.
//
// This file used to hold the app's two dictionaries (`enStrings`/`zhStrings`),
// `translate()`, the `AppLocaleScope` seat and the `context.tr` extension.
// ADR-0082 moved all of that onto `flutter gen-l10n`: the ARB files
// (`app_en.arb` / `app_zh.arb`) are the single on-disk source, `AppLocalizations`
// exposes the typed getters, dynamic keys resolve through `tr_key.dart`, and the
// MaterialApp's `Localizations` delegate is the only locale seat. What is left
// here is the single mapping that cannot be generated.
//
// It stays out of `lib/model` because `PlanSeedNames` is model data but
// `AppLocalizations` is generated Flutter code, and invariant 2 keeps
// `lib/model` framework-free. So the bridge lives in the l10n layer: `main`
// resolves the launch locale, looks the localizations up synchronously, and
// hands them here.

import '../model/plan_mock_content.dart';
import 'app_localizations.dart';

/// The 企划 demo seed's furniture names, read off the resolved localizations
/// (ADR-0074, ADR-0082 §6). The seed is user data once written, so the strings
/// ride the app copy — both locales come from the same generated getters every
/// other label uses, and `l10n_parity_test`'s bridge guard keeps them covered.
/// Demo record CONTENT (the sample note titles) deliberately stays English: it
/// is sample data, not UI copy.
PlanSeedNames planSeedNamesOf(AppLocalizations l10n) => PlanSeedNames(
  deliveryBoard: l10n.seedDeliveryBoard,
  readingInbox: l10n.seedReadingInbox,
  viewBoard: l10n.seedViewBoard,
  viewAllTasks: l10n.seedViewAllTasks,
  viewOpenOnly: l10n.seedViewOpenOnly,
  viewCards: l10n.seedViewCards,
  viewCalendar: l10n.seedViewCalendar,
  viewGraph: l10n.seedViewGraph,
  viewList: l10n.seedViewList,
  viewTable: l10n.seedViewTable,
  relStatus: l10n.seedRelStatus,
  relTags: l10n.seedRelTags,
  relEffort: l10n.seedRelEffort,
  relDue: l10n.seedRelDue,
  optTodo: l10n.seedOptTodo,
  optDoing: l10n.seedOptDoing,
  optBlocked: l10n.seedOptBlocked,
  optShipped: l10n.seedOptShipped,
  optUrgent: l10n.seedOptUrgent,
  optClient: l10n.seedOptClient,
  optInternal: l10n.seedOptInternal,
);
