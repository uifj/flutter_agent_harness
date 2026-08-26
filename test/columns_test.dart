// Covers every branch of the ported concession chain, plus the properties the
// source headers call out by contract: the sidebar never concedes, auto-closing
// a panel is derived rather than remembered, and the workbench concedes last.

import 'package:agent_harness/ui/layout/columns.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('clampWidth', () {
    test('clamps into the contract range', () {
      expect(clampWidth(100, sidebarMin, sidebarMax), sidebarMin);
      expect(clampWidth(999, sidebarMin, sidebarMax), sidebarMax);
      expect(clampWidth(320, sidebarMin, sidebarMax), 320);
    });

    test('rounds before clamping, so bounds land exactly', () {
      expect(clampWidth(279.6, sidebarMin, sidebarMax), 280);
      expect(clampWidth(280.4, sidebarMin, sidebarMax), 280);
      expect(clampWidth(sidebarMax + 0.4, sidebarMin, sidebarMax), sidebarMax);
    });
  });

  group('computeColumns step 1 — everything fits', () {
    test('center takes the remainder', () {
      final cols = computeColumns(
        2000,
        sidebarDefault,
        detailsDefault,
        workbenchDefault,
      );
      expect(
        cols,
        const Columns(sidebar: 280, center: 960, details: 360, workbench: 400),
      );
    });

    test('center grows without bound as the window widens', () {
      final cols = computeColumns(
        2400,
        sidebarDefault,
        detailsDefault,
        workbenchDefault,
      );
      expect(cols.center, 2400 - 280 - 360 - 400);
      expect(cols.details, detailsDefault);
      expect(cols.workbench, workbenchDefault);
    });

    test('re-clamps stale preferences from the state layer', () {
      final cols = computeColumns(2400, 999, 999, 999);
      expect(cols.sidebar, sidebarMax);
      expect(cols.details, detailsMax);
      expect(cols.workbench, workbenchMax);
    });

    test('a closed workbench behaves as before it existed', () {
      final cols = computeColumns(1400, sidebarDefault, detailsDefault, 0);
      expect(
        cols,
        const Columns(sidebar: 280, center: 760, details: 360, workbench: 0),
      );
    });
  });

  group('computeColumns step 2 — details concedes', () {
    test('details shrinks so center holds at its floor', () {
      // 1650 is 30px short of fitting 280 + 360 + 400 + 640.
      final cols = computeColumns(
        1650,
        sidebarDefault,
        detailsDefault,
        workbenchDefault,
      );
      expect(cols.details, 330);
      expect(cols.center, centerMin);
      expect(cols.workbench, workbenchDefault);
    });

    test('details stops exactly at its minimum', () {
      const viewport =
          sidebarDefault + detailsMin + workbenchDefault + centerMin; // 1680
      final cols = computeColumns(
        viewport,
        sidebarDefault,
        detailsDefault,
        workbenchDefault,
      );
      expect(
        cols,
        const Columns(
          sidebar: 280,
          center: centerMin,
          details: 300,
          workbench: 400,
        ),
      );
    });
  });

  group('computeColumns step 3 — details auto-closes', () {
    test('one pixel below the details floor closes the panel outright', () {
      const viewport =
          sidebarDefault + detailsMin + workbenchDefault + centerMin - 1;
      final cols = computeColumns(
        viewport,
        sidebarDefault,
        detailsDefault,
        workbenchDefault,
      );
      expect(cols.details, 0);
      // Center absorbs the width the closed panel gave up, so it is back above
      // its floor rather than pinned to it.
      expect(cols.center, viewport - sidebarDefault - workbenchDefault);
      expect(cols.center, greaterThan(centerMin));
      // The workbench has not conceded yet — that is the next step.
      expect(cols.workbench, workbenchDefault);
    });

    test('center drops below its floor as the last resort', () {
      final cols = computeColumns(
        800,
        sidebarDefault,
        detailsDefault,
        workbenchDefault,
      );
      expect(cols, const Columns(sidebar: 280, center: 520, details: 0, workbench: 0));
      expect(cols.center, lessThan(centerMin));
    });

    test('center floors at zero rather than going negative', () {
      final cols = computeColumns(
        200,
        sidebarDefault,
        detailsDefault,
        workbenchDefault,
      );
      expect(cols.center, 0);
    });
  });

  group('computeColumns step 4 — the workbench concedes last', () {
    test('the workbench shrinks once details has closed', () {
      // One pixel short of fitting 280 + 640 + 400 at the workbench's
      // preference, so it gives up that pixel before it would close.
      const viewport = sidebarDefault + centerMin + workbenchDefault - 1;
      final cols = computeColumns(
        viewport,
        sidebarDefault,
        detailsDefault,
        workbenchDefault,
      );
      expect(cols.details, 0);
      expect(cols.workbench, workbenchDefault - 1);
      expect(cols.center, centerMin);
    });

    test('the workbench stops exactly at its minimum', () {
      const viewport = sidebarDefault + centerMin + workbenchMin; // 1200
      final cols = computeColumns(
        viewport,
        sidebarDefault,
        detailsDefault,
        workbenchDefault,
      );
      expect(
        cols,
        const Columns(
          sidebar: 280,
          center: centerMin,
          details: 0,
          workbench: workbenchMin,
        ),
      );
    });
  });

  group('computeColumns step 5 — the workbench auto-closes', () {
    test('one pixel below the workbench floor closes it outright', () {
      const viewport = sidebarDefault + centerMin + workbenchMin - 1; // 1199
      final cols = computeColumns(
        viewport,
        sidebarDefault,
        detailsDefault,
        workbenchDefault,
      );
      expect(cols.workbench, 0);
      expect(cols.details, 0);
      expect(cols.center, viewport - sidebarDefault);
      expect(cols.center, greaterThan(centerMin));
    });
  });

  group('the sidebar never concedes', () {
    test('it keeps its full preference even when center is starved', () {
      for (final viewport in [1600.0, 1200.0, 800.0, 400.0, 200.0]) {
        expect(
          computeColumns(
            viewport,
            sidebarMax,
            detailsDefault,
            workbenchDefault,
          ).sidebar,
          sidebarMax,
          reason: 'viewport $viewport',
        );
      }
    });

    test('a closed preference resolves to the rail, not to zero', () {
      final cols = computeColumns(
        1400,
        0,
        detailsDefault,
        workbenchDefault,
      );
      expect(cols.sidebar, sidebarCollapsed);
      // The rail frees 224px, but that is not enough for details at its
      // preference beside the open workbench, so details concedes to 304 and
      // center holds its floor.
      expect(cols.details, 304);
      expect(cols.center, centerMin);
      expect(cols.workbench, workbenchDefault);
    });

    test('the rail also survives a starved center', () {
      expect(
        computeColumns(300, 0, detailsDefault, workbenchDefault).sidebar,
        sidebarCollapsed,
      );
    });
  });

  group('closed panels stay closed', () {
    test('a zero preference is never opened by having room', () {
      expect(computeColumns(2400, sidebarDefault, 0, 0).details, 0);
      expect(computeColumns(2400, sidebarDefault, 0, 0).workbench, 0);
      expect(computeColumns(2400, sidebarDefault, 0, 0).center, 2400 - 280);
    });
  });

  group('purity', () {
    test('auto-closing a panel is derived, so re-widening restores it', () {
      // The preferences are the same in all three calls — nothing was written
      // when the panels closed at 1100.
      final wide = computeColumns(
        1800,
        sidebarDefault,
        detailsDefault,
        workbenchDefault,
      );
      final squeezed = computeColumns(
        1100,
        sidebarDefault,
        detailsDefault,
        workbenchDefault,
      );
      expect(squeezed.details, 0);
      expect(squeezed.workbench, 0);
      final again = computeColumns(
        1800,
        sidebarDefault,
        detailsDefault,
        workbenchDefault,
      );
      expect(again, wide);
    });

    test('no hysteresis: output depends only on its inputs', () {
      expect(
        computeColumns(1800, sidebarDefault, detailsDefault, workbenchDefault),
        computeColumns(1800, sidebarDefault, detailsDefault, workbenchDefault),
      );
    });
  });

  group('computeBottom', () {
    test('a zero preference stays closed', () {
      expect(computeBottom(0, 900), 0);
    });

    test('the preference passes through inside the contract range', () {
      expect(computeBottom(bottomDefault, 900), bottomDefault);
      expect(computeBottom(300, 900), 300);
    });

    test('floors at bottomMin rather than closing', () {
      expect(computeBottom(40, 900), bottomMin);
    });

    test('caps at the viewport less the region above it', () {
      expect(computeBottom(800, 900), 900 - bottomKeepAbove);
      expect(computeBottom(9999, 400), 400 - bottomKeepAbove);
    });

    test('a short viewport still gets a usable panel', () {
      // 200 < bottomKeepAbove, so the cap would be negative — the floor wins.
      expect(computeBottom(bottomDefault, 200), bottomMin);
    });
  });

  group('effectiveSidebarPreference', () {
    test('wide passes the preference straight through', () {
      expect(
        effectiveSidebarPreference(
          viewport: 1400,
          sidebarPreference: 320,
          narrowExpanded: false,
        ),
        320,
      );
    });

    test('wide and closed stays closed', () {
      expect(
        effectiveSidebarPreference(
          viewport: 1400,
          sidebarPreference: 0,
          narrowExpanded: false,
        ),
        0,
      );
    });

    test('narrow collapses regardless of the preference', () {
      expect(
        effectiveSidebarPreference(
          viewport: sidebarAutoCollapse - 1,
          sidebarPreference: 320,
          narrowExpanded: false,
        ),
        0,
      );
    });

    test('the breakpoint itself counts as wide', () {
      expect(
        effectiveSidebarPreference(
          viewport: sidebarAutoCollapse,
          sidebarPreference: 320,
          narrowExpanded: false,
        ),
        320,
      );
    });

    test('a narrow manual re-expand restores the preference', () {
      expect(
        effectiveSidebarPreference(
          viewport: 900,
          sidebarPreference: 320,
          narrowExpanded: true,
        ),
        320,
      );
    });

    test('re-expanding over a closed preference falls back to the default', () {
      expect(
        effectiveSidebarPreference(
          viewport: 900,
          sidebarPreference: 0,
          narrowExpanded: true,
        ),
        sidebarDefault,
      );
    });

    test('a narrow re-expand squeezes center instead of the sidebar', () {
      const viewport = 900.0;
      final preference = effectiveSidebarPreference(
        viewport: viewport,
        sidebarPreference: 320,
        narrowExpanded: true,
      );
      final cols = computeColumns(viewport, preference, 0, 0);
      expect(cols.sidebar, 320);
      expect(cols.center, viewport - 320);
      expect(cols.center, lessThan(centerMin));
    });
  });
}
