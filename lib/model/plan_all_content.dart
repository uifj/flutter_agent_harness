// All Content's query and grouping answers (ADR-0037 P6, module 2). Upstream
// maps each tab onto a set of object layouts and groups the results by a
// handful of date boundaries (`feature-all-content/.../models/`); the sort is
// restored per space from persisted preferences (`RestoreAllContentState.kt`).
// The client's four user-facing sort keys are created / modified / name /
// last-used — our records carry created and modified stamps, so last-used
// stays a named option that falls back to modified.

import 'dart:collection';

import 'plan_object_type.dart';
import 'plan_struct.dart';

/// The five tabs (`AllContentModels.kt:29-31`) and the layouts each one asks
/// for (`AllContentSearchParams.kt:20-44`).
enum PlanAllContentTab {
  pages('PAGES', [
    PlanObjectTypeIds.page,
    PlanObjectTypeIds.note,
    PlanObjectTypeIds.task,
    PlanObjectTypeIds.human,
  ]),
  lists('LISTS', [
    PlanObjectTypeIds.set,
    PlanObjectTypeIds.collection,
    PlanObjectTypeIds.objectType,
  ]),
  media('MEDIA', [
    PlanObjectTypeIds.image,
    PlanObjectTypeIds.video,
    PlanObjectTypeIds.audio,
  ]),
  bookmarks('BOOKMARKS', [PlanObjectTypeIds.bookmark]),
  files('FILES', [PlanObjectTypeIds.file]);

  const PlanAllContentTab(this.code, this.typeKeys);

  final String code;
  final List<String> typeKeys;

  /// The two menu modes (`AllContentMenuMode.kt:33-43`): the unlinked reading
  /// keeps only objects nothing links to.
  static const modes = ['allContent', 'unlinked'];
}

enum PlanAllContentSort { created, modified, name, lastUsed }

/// The time groups upstream shows, in order (`AllContentModels.kt:87-94`).
enum PlanAllContentGroup {
  today,
  yesterday,
  previous7Days,
  previous14Days,
  month,
  monthAndYear,
  older,
}

String planAllContentGroupLabelCode(PlanAllContentGroup group) =>
    switch (group) {
      PlanAllContentGroup.today => 'planGroupToday',
      PlanAllContentGroup.yesterday => 'planGroupYesterday',
      PlanAllContentGroup.previous7Days => 'planGroupPrevious7Days',
      PlanAllContentGroup.previous14Days => 'planGroupPrevious14Days',
      PlanAllContentGroup.month => 'planGroupMonth',
      PlanAllContentGroup.monthAndYear => 'planGroupMonthAndYear',
      PlanAllContentGroup.older => 'planGroupOlder',
    };

/// Groups records by [PlanObject.editedAt] against [now], the client's bucket
/// order preserved and empty groups dropped.
LinkedHashMap<PlanAllContentGroup, List<PlanObject>> groupPlanAllContent(
  List<PlanObject> records,
  DateTime now,
) {
  final buckets = <PlanAllContentGroup, List<PlanObject>>{};
  for (final record in records) {
    final edited = record.date('editedAt');
    var group = PlanAllContentGroup.older;
    if (edited != null) {
      final days = DateTime(
        now.year,
        now.month,
        now.day,
      ).difference(DateTime(edited.year, edited.month, edited.day)).inDays;
      if (days <= 0) {
        group = PlanAllContentGroup.today;
      } else if (days == 1) {
        group = PlanAllContentGroup.yesterday;
      } else if (days < 7) {
        group = PlanAllContentGroup.previous7Days;
      } else if (days < 14) {
        group = PlanAllContentGroup.previous14Days;
      } else if (edited.year == now.year && edited.month == now.month) {
        group = PlanAllContentGroup.month;
      } else if (edited.year == now.year) {
        group = PlanAllContentGroup.monthAndYear;
      }
    }
    (buckets[group] ??= []).add(record);
  }
  return LinkedHashMap.fromEntries(buckets.entries.toList());
}

/// Sorts records for the screen: name reads case-insensitively, the stamp
/// sorts newest first in both directions' descents.
List<PlanObject> sortPlanAllContent(
  List<PlanObject> records,
  PlanAllContentSort sort, {
  required bool ascending,
}) {
  // Ascending everywhere — stamps read oldest first — and the direction
  // inverts wholesale; the id tie-break keeps either cut stable.
  int compare(PlanObject a, PlanObject b) {
    switch (sort) {
      case PlanAllContentSort.name:
        final an = (a.text(PlanRelationKeys.name) ?? '').toLowerCase();
        final bn = (b.text(PlanRelationKeys.name) ?? '').toLowerCase();
        return an.compareTo(bn) != 0 ? an.compareTo(bn) : a.id.compareTo(b.id);
      case PlanAllContentSort.created:
      case PlanAllContentSort.modified:
      case PlanAllContentSort.lastUsed:
        final aDate = a.date('editedAt') ?? a.date('createdAt');
        final bDate = b.date('editedAt') ?? b.date('createdAt');
        if (aDate == null || bDate == null) {
          return aDate == null && bDate == null
              ? a.id.compareTo(b.id)
              : aDate == null
              ? 1
              : -1;
        }
        final byDate = aDate.compareTo(bDate);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
    }
  }

  final sorted = [...records]..sort(compare);
  return ascending ? sorted : sorted.reversed.toList();
}
