// One slice of the settings page (ADR-0085 D7): the god-file split keeps
// every hand-written file under the 1,000-line budget. Part of the same
// library, so the page's state and private widgets are visible here.
part of 'model_settings.dart';

// Workspace — see the enum `_Section` for what points at it.
extension _WorkspaceSection on _SettingsPanelState {
  /// Opens the platform's directory picker and adopts whatever comes back: the
  /// field and the recent list move together, which is dsh's picker flow
  /// (picked/cancel/error) in the shape one field can carry. A dismissed picker
  /// changes nothing.
  Future<void> _pickFolder() async {
    final next = await widget.onPickFolder(_edited);
    if (next == null) return;
    rebuild(() {
      _workspace.text = next.workspaceRoot ?? '';
      _recent = List.of(next.recentWorkspaces);
    });
  }

  /// Adopts [path] from the recent list — the same move as picking, minus the
  /// picker.
  void _adoptRecent(String path) {
    rebuild(() {
      _workspace.text = path;
      _recent = [
        path,
        for (final other in _recent)
          if (other != path) other,
      ];
    });
  }

  /// Drops [path] from the recent list alone. The field keeps whatever it
  /// holds: forgetting where the user has been is not taking a permission
  /// back.
  void _forgetRecent(String path) => rebuild(
    () => _recent = [
      for (final other in _recent)
        if (other != path) other,
    ],
  );

  List<Widget> _workspaceSection(DswAlias color) => [
    _heading(
      color,
      AppLocalizations.of(context).settingsWorkspace,
      AppLocalizations.of(context).settingsWorkspaceIntro,
    ),
    const SizedBox(height: 12),
    _Field(
      label: AppLocalizations.of(context).folder,
      controller: _workspace,
      hint: '~/projects/my-app',
      autofocus: true,
      code: true,
      trailing: CapsuleButton(
        label: AppLocalizations.of(context).choose,
        onTap: _pickFolder,
      ),
    ),
    const SizedBox(height: 12),
    _RecentWorkspaces(
      paths: _recent,
      current: _workspace.text.trim(),
      missing: _workspaceMissing,
      onAdopt: _adoptRecent,
      onForget: _forgetRecent,
    ),
  ];
}

/// The recent-workspaces list — dsh's picker menu flattened into the section:
/// each row adopts on click, forgets on its trailing button, and says so when
/// its folder has gone missing on disk.
class _RecentWorkspaces extends StatelessWidget {
  const _RecentWorkspaces({
    required this.paths,
    required this.current,
    required this.missing,
    required this.onAdopt,
    required this.onForget,
  });

  final List<String> paths;
  final String current;
  final bool missing;
  final ValueChanged<String> onAdopt;
  final ValueChanged<String> onForget;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) return const SizedBox.shrink();
    final color = context.dsw;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppLocalizations.of(context).recent,
          style: DswType.xxs12.copyWith(color: color.labelSecondary),
        ),
        const SizedBox(height: 6),
        for (final path in paths)
          _RecentRow(
            path: path,
            current: path == current,
            missing: !Directory(path).existsSync(),
            onAdopt: () => onAdopt(path),
            onForget: () => onForget(path),
          ),
        // The typed-path warning rides below the list rather than beside the
        // field: it describes the same document the recents do, and a field
        // with two trailing affordances reads as two decisions.
        if (missing) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                LucideIcons.circle_alert,
                size: DswShape.iconSm,
                color: color.stateWarnPrimary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).folderNotOnDisk,
                  style: DswType.xxxs11.copyWith(color: color.labelTertiary),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// One recent-workspace row: folder glyph, the path in the code face, adopt on
/// click, forget on the trailing button. The current workspace is marked with
/// the interactive wash rather than a check — the row IS the choice.

/// One recent-workspace row: folder glyph, the path in the code face, adopt on
/// click, forget on the trailing button. The current workspace is marked with
/// the interactive wash rather than a check — the row IS the choice.
class _RecentRow extends StatefulWidget {
  const _RecentRow({
    required this.path,
    required this.current,
    required this.missing,
    required this.onAdopt,
    required this.onForget,
  });

  final String path;
  final bool current;
  final bool missing;
  final VoidCallback onAdopt;
  final VoidCallback onForget;

  @override
  State<_RecentRow> createState() => _RecentRowState();
}

class _RecentRowState extends State<_RecentRow> {
  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    // The row adopts the folder; its accessible name is the path itself, so the
    // visible text is left as the label. The forget button is a nested action and
    // is kept out of the row's name.
    return DswHoverTap(
      onTap: widget.missing ? null : widget.onAdopt,
      toggled: widget.current ? true : null,
      builder: (context, hovered, _) => _body(color, hovered),
    );
  }

  Widget _body(DswAlias color, bool hovered) => Container(
    height: 32,
    padding: const EdgeInsets.only(left: 8, right: 4),
    margin: const EdgeInsets.only(bottom: 2),
    decoration: BoxDecoration(
      color: widget.current
          ? color.interactiveBgActive
          : hovered
          ? color.interactiveBgHover
          : Colors.transparent,
      borderRadius: BorderRadius.circular(DswShape.control),
    ),
    child: Row(
      children: [
        Icon(
          LucideIcons.folder,
          size: DswShape.iconSm,
          // A dead folder keeps its seat but wears the caption tint: the row
          // still explains where the user has been.
          color: widget.missing ? color.labelCaption : color.labelSecondary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.path,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DswType.xxs12.copyWith(
              color: widget.missing ? color.labelCaption : color.labelPrimary,
              fontFamily: dswFontFamilyCode,
              fontFamilyFallback: dswFontFamilyCodeFallback,
            ),
          ),
        ),
        if (widget.missing)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              AppLocalizations.of(context).missing,
              style: DswType.xxxs11.copyWith(color: color.stateWarnLabel),
            ),
          ),
        if (hovered)
          DswIconButton(
            icon: LucideIcons.x,
            tooltip: AppLocalizations.of(context).forget,
            onTap: widget.onForget,
            size: 20,
            iconSize: DswShape.iconTiny,
          ),
      ],
    ),
  );
}
