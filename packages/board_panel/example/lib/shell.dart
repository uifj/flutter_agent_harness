import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'multi_board_list_example.dart';
import 'multi_board_shrinkwrap_list_example.dart';
import 'pages/calendar_view_demo_page.dart';
import 'pages/expandable_table_demo_page.dart';
import 'single_board_list_example.dart';

class _NavItem {
  final String label;
  final IconData icon;
  final Widget page;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.page,
  });
}

class ExampleShell extends StatefulWidget {
  const ExampleShell({super.key});

  @override
  State<ExampleShell> createState() => _ExampleShellState();
}

class _ExampleShellState extends State<ExampleShell> {
  int _selectedIndex = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  final _navItems = const [
    _NavItem(
      label: 'Board',
      icon: LucideIcons.columns3,
      page: MultiBoardListExample(),
    ),
    _NavItem(
      label: 'ShrinkWrap',
      icon: LucideIcons.layoutDashboard,
      page: MultiBoardShrinkwrapListExample(),
    ),
    _NavItem(
      label: 'Calendar',
      icon: LucideIcons.calendar,
      page: CalendarViewDemoPage(),
    ),
    _NavItem(
      label: 'Table',
      icon: LucideIcons.table,
      page: ExpandableTableDemoPage(),
    ),
    _NavItem(
      label: 'Single Column',
      icon: LucideIcons.columns2,
      page: SingleBoardListExample(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ShadResponsiveBuilder(
      builder: (context, breakpoint) {
        final isDesktop = breakpoint >= ShadTheme.of(context).breakpoints.lg;

        if (isDesktop) {
          return _buildDesktopLayout();
        }
        return _buildMobileLayout();
      },
    );
  }

  Widget _buildDesktopLayout() {
    final theme = ShadTheme.of(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.colorScheme.background,
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 240,
            decoration: BoxDecoration(
              color: theme.colorScheme.card,
              border: Border(
                right: BorderSide(
                  color: theme.colorScheme.border.withAlpha(128),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // App header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShadBadge.secondary(
                        child: Text(
                          'BOARD PANEL',
                          style: theme.textTheme.small.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Component Gallery',
                        style: theme.textTheme.h4.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'shadcn_ui powered example',
                        style: theme.textTheme.muted,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Navigation
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      ..._navItems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final isSelected = _selectedIndex == index;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: isSelected
                              ? ShadButton.secondary(
                                  width: double.infinity,
                                  onPressed: () => _onNavChanged(index),
                                  leading: Icon(item.icon, size: 18),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      item.label,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                )
                              : ShadButton.ghost(
                                  width: double.infinity,
                                  onPressed: () => _onNavChanged(index),
                                  leading: Icon(item.icon, size: 18),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      item.label,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: theme.colorScheme
                                            .mutedForeground,
                                      ),
                                    ),
                                  ),
                                ),
                        );
                      }),
                    ],
                  ),
                ),
                // Footer
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'board_panel v0.1.0',
                    style: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          // Content area
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _navItems.map((item) => item.page).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    final theme = ShadTheme.of(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.card,
        surfaceTintColor: Colors.transparent,
        leading: ShadIconButton.ghost(
          icon: const Icon(LucideIcons.menu, size: 20),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          _navItems[_selectedIndex].label,
          style: theme.textTheme.h4.copyWith(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
      ),
      drawer: Drawer(
        backgroundColor: theme.colorScheme.card,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShadBadge.secondary(
                      child: Text(
                        'BOARD PANEL',
                        style: theme.textTheme.small.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Component Gallery',
                      style: theme.textTheme.h4.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: _navItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final isSelected = _selectedIndex == index;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: ShadButton.ghost(
                        width: double.infinity,
                        onPressed: () {
                          Navigator.of(context).pop();
                          _onNavChanged(index);
                        },
                        leading: Icon(item.icon, size: 18),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  isSelected ? FontWeight.w600 : null,
                              color: isSelected
                                  ? null
                                  : theme.colorScheme.mutedForeground,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _navItems.map((item) => item.page).toList(),
      ),
    );
  }

  void _onNavChanged(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }
}
