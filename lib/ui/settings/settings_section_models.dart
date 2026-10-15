// One slice of the settings page (ADR-0085 D7): the god-file split keeps
// every hand-written file under the 1,000-line budget. Part of the same
// library, so the page's state and private widgets are visible here.
part of 'model_settings.dart';

// Models — see the enum `_Section` for what points at it.
extension _ModelSections on _SettingsPanelState {
  /// Drops the fetch state — the list, and whatever the last probe said —
  /// because both describe an endpoint that is no longer the one on screen.
  void _onBaseUrlChanged() {
    if (_endpointModels.isEmpty && _probeError == null && _probeCount == null) {
      return;
    }
    // Bumped so an in-flight fetch for the abandoned endpoint cannot land.
    _modelsFetchGeneration++;
    rebuild(() {
      _endpointModels = const [];
      _probeError = null;
      _probeCount = null;
    });
  }

  /// The connection test: one fetch against the DRAFT's endpoint and key,
  /// reported beside the button that caused it rather than in a dialog.
  /// Success is the list itself — a 200 with model ids proves the URL, the
  /// auth, and the response shape at once, and the ids are what the model
  /// field's quick select then offers.
  Future<void> _testConnection() async {
    final fetcher = widget.modelsFetcher;
    if (fetcher == null || _modelsLoading) return;
    final generation = ++_modelsFetchGeneration;
    final provider = _provider;
    final baseUrl = _baseUrl.text.trim().isEmpty
        ? defaultBaseUrlFor(_provider)
        : _baseUrl.text.trim();
    final apiKey = _key.text.trim();
    rebuild(() {
      _modelsLoading = true;
      _probeError = null;
      _probeCount = null;
    });
    try {
      final models = await fetcher.listModels(
        provider: provider,
        baseUrl: baseUrl,
        apiKey: apiKey,
      );
      if (!mounted || generation != _modelsFetchGeneration) return;
      rebuild(() {
        _modelsLoading = false;
        _endpointModels = models;
        _probeCount = models.length;
      });
    } catch (error) {
      if (!mounted || generation != _modelsFetchGeneration) return;
      rebuild(() {
        _modelsLoading = false;
        _probeError = _probeMessage(error);
      });
    }
  }

  /// The shortest sentence an error earns. A status code is the most useful
  /// thing a 401 says; a timeout says so by name; anything else falls back to
  /// its own toString, trimmed to one line.
  String _probeMessage(Object error) => switch (error) {
    HttpException e => e.message,
    TimeoutException _ => AppLocalizations.of(context).probeTimeout,
    FormatException e => e.message,
    SocketException _ => AppLocalizations.of(context).connectionFailed,
    _ => error.toString(),
  };

  void _addServer() {
    rebuild(() {
      final draft = _ServerDraft();
      for (final controller in draft.controllers) {
        controller.addListener(_onEdited);
      }
      _servers.add(draft);
    });
  }

  void _removeServer(_ServerDraft draft) {
    rebuild(() {
      _servers.remove(draft);
      for (final controller in draft.controllers) {
        controller
          ..removeListener(_onEdited)
          ..dispose();
      }
    });
  }

  /// Switches provider, resetting the connection fields to the new provider's
  /// defaults — a DeepSeek URL leaking into an Anthropic client is worse than
  /// retyping one field — and moves the editor card to the new provider's row.
  /// The fetch state goes with the old endpoint: a fetched list describes the
  /// provider it was asked about, not the seat it happened to sit in.
  void _selectProvider(LlmProvider provider) {
    final reset = widget.settings.model.forProvider(provider);
    _modelsFetchGeneration++;
    rebuild(() {
      _provider = provider;
      _expanded = provider;
      _disclosure.value = const <String>[];
      _endpointModels = const [];
      _probeError = null;
      _probeCount = null;
      _key.text = reset.apiKey;
      _baseUrl.text = reset.baseUrl;
      _model.text = reset.model;
      _revealed = false;
    });
  }

  /// The document as the fields currently read it.
  ///
  /// Trimmed: a pasted key or path routinely arrives with a trailing newline, and
  /// every one of these fields is compared or concatenated somewhere downstream.
  AppSettings get _edited {
    final model = ModelSettings(
      provider: _provider,
      apiKey: _key.text.trim(),
      baseUrl: _baseUrl.text.trim().isEmpty
          ? defaultBaseUrlFor(_provider)
          : _baseUrl.text.trim(),
      model: _model.text.trim().isEmpty
          ? defaultModelFor(_provider)
          : _model.text.trim(),
      // The manual model list is not a form field; it rides the document the
      // panel was last given (ADR-0045 PG), and the book rides with it — a
      // form-only rebuild would silently drop both (caught by the hardening
      // test's panel-save guard).
      manualModels: widget.settings.model.manualModels,
    );
    final workspace = _workspace.text.trim();
    final skills = _skills.text.trim();
    return AppSettings(
      model: model,
      workspaceRoot: workspace.isEmpty ? null : workspace,
      mcpServers: [for (final draft in _servers) ?draft.asConfig()],
      skillsRoot: skills.isEmpty ? null : skills,
      theme: _theme,
      locale: _locale,
      recentWorkspaces: _recent,
      fontSize: _textSize,
      conversationWidth: _conversationWidth,
      expandToolCalls: _expandToolCalls,
      notificationsOn: _notificationsOn,
      diagnosticRequestLog: _diagnosticRequestLog,
      diagnosticContextLog: _diagnosticContextLog,
      savedProviders: widget.settings.savedProviders,
      activeProviderId: widget.settings.activeProviderId,
    );
  }

  bool get _dirty => _edited != widget.settings;

  /// Models, as dsh's provider rows: one outlined card per provider, the
  /// saved provider's dot telling whether its key is on file, and one editor
  /// card at a time — the draft provider's row starts expanded, and Edit on
  /// another row adopts that provider (resetting the connection fields, see
  /// [_selectProvider]) and moves the card there.
  List<Widget> _models(DswAlias color) => [
    _heading(
      color,
      AppLocalizations.of(context).settingsModels,
      AppLocalizations.of(context).settingsModelsIntro,
    ),
    // `.rows` carries its own `margin-top: 12` on top of the section gap —
    // dsh calls this "extra air between the title/intro block and the first
    // provider card", 24px all told.
    const SizedBox(height: 24),
    for (final provider in LlmProvider.values) ...[
      _providerRowCard(color, provider),
      if (provider != LlmProvider.values.last) const SizedBox(height: 8),
    ],
    const SizedBox(height: 8),
    ..._savedConnectionsCard(color),
  ];

  /// The saved-provider book (ADR-0045 PF-2): the active connection can be
  /// saved into the book, and every entry can be activated (its connection
  /// becomes the active one) or deleted. Keys never render — each row shows
  /// whether one is on file.
  List<Widget> _savedConnectionsCard(DswAlias color) {
    final book = widget.settings.savedProviders;
    return [
      SettingsCard(
        dividers: true,
        children: [
          _ActionRow(
            title: AppLocalizations.of(context).providersSaveCurrent,
            description: AppLocalizations.of(context).providersSaveCurrentDesc,
            button: CapsuleButton(
              label: AppLocalizations.of(context).providersSaveCurrent,
              onTap: widget.onSaveCurrentToBook,
            ),
          ),
          if (book.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Text(
                AppLocalizations.of(context).providersBookEmpty,
                style: DswType.xs13.copyWith(color: color.labelTertiary),
              ),
            )
          else
            for (final (index, entry) in book.indexed) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    _CredentialDot(configured: entry.isConfigured),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_providerName(context, entry.provider)} · ${entry.model}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DswType.s14.copyWith(
                          color: color.labelPrimary,
                          fontWeight:
                              entry.id == widget.settings.activeProviderId
                              ? FontWeight.w600
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CapsuleButton(
                      label: AppLocalizations.of(context).providersActivate,
                      onTap: () => widget.onActivateSavedProvider(entry.id!),
                    ),
                    const SizedBox(width: 6),
                    DswIconButton(
                      icon: LucideIcons.trash,
                      tooltip: AppLocalizations.of(context).providersDelete,
                      onTap: () => widget.onDeleteSavedProvider(entry.id!),
                    ),
                  ],
                ),
              ),
              if (index != book.length - 1)
                dswEnsureShadTheme(
                  context,
                  ShadSeparator.horizontal(thickness: 1, color: color.borderL2),
                ),
            ],
        ],
      ),
    ];
  }

  /// `.rowCard`: outlined on the panel fill so the filled editor card it
  /// expands into reads as the nested object. dsh's `padding: 12px 14px`
  /// (vertical 12, horizontal 14), column gap 12.
  /// A `ShadCard` wearing the bridge's card skin (`borderL2` at `shell`, ADR-0029)
  /// with the page's own fill left showing through: this row is a container
  /// *inside* a section card, and a second fill would say two surfaces where
  /// there is one (§1B S6).
  Widget _providerRowCard(DswAlias color, LlmProvider provider) => ShadCard(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    backgroundColor: Colors.transparent,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  // The dot keeps its seat, so the name is what yields: a bare
                  // Text here is handed the row's whole width and spills past it
                  // once the system amplifies text.
                  Flexible(
                    child: Text(
                      _providerName(context, provider),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DswType.s14.copyWith(
                        color: color.labelPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (_savedProvider == provider) ...[
                    const SizedBox(width: 6),
                    _CredentialDot(configured: _keyOnFile),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            _RowEditButton(
              expanded: _expanded == provider,
              onTap: () {
                if (_provider != provider) {
                  _selectProvider(provider);
                  return;
                }
                // Toggling the one card the draft already edits: collapsing it
                // hides the fields, it does not throw the draft away.
                rebuild(
                  () => _expanded = _expanded == provider ? null : provider,
                );
              },
            ),
          ],
        ),
        if (_expanded == provider) ...[
          const SizedBox(height: 12),
          _editorCard(color, provider),
        ],
      ],
    ),
  );

  /// The provider whose connection the SAVED document carries — the row that
  /// earns a credential dot. Rows for the other providers are dormant: no
  /// dot, and Edit on them is dsh's "add" flow.
  LlmProvider get _savedProvider => widget.settings.model.provider;

  /// Whether the saved document's key field is non-empty — what the dot says.
  /// Read from the document, not the draft: the dot's question is "can this
  /// app talk to anyone yet?", and a half-typed key is not an answer to it.
  bool get _keyOnFile => widget.settings.model.apiKey.trim().isNotEmpty;

  /// The filled editor card inside the expanded row — `.editor` on
  /// `--dsw-alias-bg-module-platform`: radius 12, `padding: 14px 16px`, column
  /// gap 14, so the outlined row reads as the container and this as the
  /// object in it.
  /// The filled inner surface: `ShadCard` for the corner and the padding, and it
  /// says its own two differences from the bridge's card tier — the module fill,
  /// and no stroke, because a fill already ends where it begins (ADR-0029).
  Widget _editorCard(DswAlias color, LlmProvider provider) => ShadCard(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    backgroundColor: color.bgModulePlatform,
    border: ShadBorder.all(width: 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Field(
          label: AppLocalizations.of(context).apiKey,
          controller: _key,
          // The placeholder is the stored-state sentence dsh's editor shows:
          // a saved key needs no retyping, and the field says so instead of
          // sitting blank over a value the panel already holds.
          hint: _savedProvider == provider && _keyOnFile
              ? AppLocalizations.of(context).keyStored
              : 'sk-…',
          obscured: !_revealed,
          autofocus: true,
          // The one field with an affordance of its own, so it carries the
          // reveal rather than the card growing a control that applies to
          // nothing else.
          trailing: _RevealButton(
            revealed: _revealed,
            onTap: () => rebuild(() => _revealed = !_revealed),
          ),
        ),
        const SizedBox(height: 14),
        ShadAccordion<String>(
          controller: _disclosure,
          children: [
            ShadAccordionItem<String>(
              value: 'customized',
              // Named, because the library's own heading style is its
              // `textTheme.list` -- a second type ramp nobody mapped (ADR-0027).
              title: Text(
                AppLocalizations.of(context).customized,
                style: DswType.xxsStrong12.copyWith(
                  color: color.labelSecondary,
                ),
              ),
              padding: const EdgeInsets.only(top: 12, bottom: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Field(
                    label: AppLocalizations.of(context).baseUrl,
                    controller: _baseUrl,
                    // Empty means the provider's own endpoint — only the
                    // OpenAI-compatible path has a default worth hinting.
                    hint: provider == LlmProvider.openai
                        ? defaultBaseUrl
                        : AppLocalizations.of(context).providerDefault,
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    label: AppLocalizations.of(context).model,
                    controller: _model,
                    hint: defaultModelFor(provider),
                    // The model id is a wire value, and reads as one.
                    code: true,
                    // The quick select over the fetched list — free text stays
                    // valid, the list is an offer, not a constraint.
                    trailing: widget.modelsFetcher == null
                        ? null
                        : _ModelPickButton(
                            models: _endpointModels,
                            onPick: (id) => rebuild(() => _model.text = id),
                          ),
                  ),
                  const SizedBox(height: 12),
                  // The manual model list (ADR-0045 PG): ZCode's 模型列表 —
                  // ids the endpoint's catalog does not carry, registered by
                  // hand and persisted with the connection.
                  _ManualModelsField(
                    models: _edited.model.manualModels,
                    activeModel: _model.text.trim(),
                    onAdd: (id) async {
                      if (_edited.model.manualModels.contains(id)) return;
                      await _saveWith(
                        _edited.copyWith(
                          model: _edited.model.copyWith(
                            manualModels: [..._edited.model.manualModels, id],
                          ),
                        ),
                      );
                    },
                    onRemove: (id) async {
                      await _saveWith(
                        _edited.copyWith(
                          model: _edited.model.copyWith(
                            manualModels: [
                              for (final existing in _edited.model.manualModels)
                                if (existing != id) existing,
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // The probe row: one button, one sentence of outcome, dsh's
        // `editorActions` + inline `error` shape. Absent entirely when no
        // fetcher was wired — a test control without a network is a lie.
        if (widget.modelsFetcher != null)
          LayoutBuilder(
            builder: (context, box) {
              final status = _ModelProbeStatus(
                loading: _modelsLoading,
                error: _probeError,
                count: _probeCount,
              );
              final button = CapsuleButton(
                label: AppLocalizations.of(context).testConnection,
                size: CapsuleSize.sm,
                enabled: !_modelsLoading,
                onTap: _testConnection,
              );
              // The capsule is the unshrinkable half — its label is its name —
              // so the sentence keeps a floor beside it and the button drops
              // under the sentence when the card cannot hold both: measured at
              // 700px wide and 2.2x, the row spilled 16px past the card.
              final beside =
                  _oneLineWidth(context, button.label, DswType.xxs12) +
                  20 +
                  160;
              if (beside <= box.maxWidth) {
                return Row(
                  children: [
                    Expanded(child: status),
                    button,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  status,
                  SizedBox(
                    height: 12 * MediaQuery.textScalerOf(context).scale(1),
                  ),
                  button,
                ],
              );
            },
          ),
      ],
    ),
  );

  static String _providerName(BuildContext context, LlmProvider provider) =>
      switch (provider) {
        // The OpenAI-compatible path is what a custom baseUrl is for, so the
        // label says what it accepts rather than which vendor it defaults to.
        LlmProvider.openai => AppLocalizations.of(
          context,
        ).providerOpenAiCompatible,
        LlmProvider.anthropic => AppLocalizations.of(context).providerAnthropic,
        LlmProvider.google => AppLocalizations.of(context).providerGoogle,
      };

  /// One server, as a bordered card of four fields plus its remove button.
  /// Args are space-separated here and split at commit — the field is a
  /// single line either way.
  /// Exactly the tier the bridge answers for a card, so nothing is restated here.
  Widget _serverCard(DswAlias color, _ServerDraft draft) => ShadCard(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _Field(
                label: AppLocalizations.of(context).serverName,
                controller: draft.name,
                hint: 'fs',
                code: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Field(
                label: AppLocalizations.of(context).arguments,
                controller: draft.args,
                hint: '-y @modelcontextprotocol/server-filesystem',
                code: true,
              ),
            ),
            const SizedBox(width: 6),
            DswIconButton.destructive(
              icon: LucideIcons.x,
              tooltip: AppLocalizations.of(context).removeServer,
              onTap: () => _removeServer(draft),
              size: 28,
              iconSize: DswShape.iconMd,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Field(
          label: AppLocalizations.of(context).commandStdio,
          controller: draft.command,
          hint: 'npx',
          code: true,
        ),
        const SizedBox(height: 12),
        _Field(
          label: AppLocalizations.of(context).urlHttp,
          controller: draft.url,
          hint: 'https://example.test/mcp',
          code: true,
        ),
      ],
    ),
  );
}

/// The provider row's trailing control: the same small outline capsule the rest
/// of this page uses for a labelled action (保存, 添加服务器, 测试连接), because a
/// second spelling of "small bordered button" in the same panel is the
/// inconsistency the screenshot was filed for (ADR-0036 §1B S4). Its body is
/// shad's `ShadButton` already, so keyboard, focus and the disabled dimming come
/// from there. The label flips to "Close" on the row whose card is open, since
/// that is what the tap then does.
class _RowEditButton extends StatelessWidget {
  const _RowEditButton({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CapsuleButton(
    label: expanded
        ? AppLocalizations.of(context).close
        : AppLocalizations.of(context).edit,
    onTap: onTap,
    size: CapsuleSize.sm,
  );
}

/// The model field's quick-select: the `_RevealButton` box shape opening a
/// menu of the endpoint's fetched ids. Disabled until a fetch has landed — a
/// menu with nothing to offer is a control that lies about being one.

/// The model field's quick-select: the `_RevealButton` box shape opening a
/// menu of the endpoint's fetched ids. Disabled until a fetch has landed — a
/// menu with nothing to offer is a control that lies about being one.
class _ModelPickButton extends StatelessWidget {
  const _ModelPickButton({required this.models, required this.onPick});

  final List<String> models;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final enabled = models.isNotEmpty;
    return DswSelect<String>(
      // Nothing is ever selected here: the box is a way in, not a value, so the
      // trigger is always the placeholder branch.
      value: null,
      onChanged: (id) {
        if (id != null) onPick(id);
      },
      enabled: enabled,
      label: enabled
          ? AppLocalizations.of(context).chooseModel
          : AppLocalizations.of(context).noModelsFetched,
      popupMinWidth: 260,
      maxHeight: 320,
      options: (context, close) => [
        for (final id in models)
          ShadOption<String>(
            value: id,
            child: Text(
              id,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DswType.xs13.copyWith(
                color: color.labelPrimary,
                fontFamily: dswFontFamilyCode,
                fontFamilyFallback: dswFontFamilyCodeFallback,
              ),
            ),
          ),
      ],
      trigger: (context, selected, hovered) => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: hovered ? color.interactiveBgHover : Colors.transparent,
          borderRadius: BorderRadius.circular(DswShape.inner),
        ),
        child: Icon(
          LucideIcons.list,
          size: DswShape.iconMd,
          color: enabled ? color.labelTertiary : color.labelDimmed,
        ),
      ),
    );
  }
}

/// The probe's one sentence: fetching, the count, or the failure — the
/// status line dsh's editor paints between its fields and its actions.

/// The probe's one sentence: fetching, the count, or the failure — the
/// status line dsh's editor paints between its fields and its actions.
class _ModelProbeStatus extends StatelessWidget {
  const _ModelProbeStatus({
    required this.loading,
    required this.error,
    required this.count,
  });

  final bool loading;
  final String? error;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    if (loading) {
      return Text(
        AppLocalizations.of(context).fetchingModels,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: DswType.xxs12.copyWith(color: color.labelTertiary),
      );
    }
    if (error != null) {
      return Row(
        children: [
          Icon(
            LucideIcons.circle_alert,
            size: DswShape.iconSm,
            color: color.stateErrorPrimary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              error!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DswType.xxs12.copyWith(color: color.stateErrorPrimary),
            ),
          ),
        ],
      );
    }
    if (count != null) {
      return Text(
        AppLocalizations.of(context).connectionOk('$count'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: DswType.xxs12.copyWith(color: color.stateSuccessPrimary),
      );
    }
    return const SizedBox.shrink();
  }
}

/// One MCP server row under edit. Holds its own controllers so rows can be
/// added and removed without rebuilding the others, and so dispose walks
/// exactly the rows that still exist.

/// One MCP server row under edit. Holds its own controllers so rows can be
/// added and removed without rebuilding the others, and so dispose walks
/// exactly the rows that still exist.
class _ServerDraft {
  _ServerDraft();

  factory _ServerDraft.of(McpServerConfig server) {
    final draft = _ServerDraft();
    draft.name.text = server.name;
    draft.command.text = server.command ?? '';
    draft.url.text = server.url ?? '';
    draft.args.text = server.args.join(' ');
    return draft;
  }

  final name = TextEditingController();
  final command = TextEditingController();
  final url = TextEditingController();

  /// Space-separated on screen, since the common case is a short flag list;
  /// split at commit.
  final args = TextEditingController();

  List<TextEditingController> get controllers => [name, command, url, args];

  /// Null when the row cannot yield a server — no name, or neither a command
  /// nor a URL. Commit drops the row rather than the panel refusing the field,
  /// the same repair-not-reject contract a corrupt entry gets at load.
  McpServerConfig? asConfig() {
    final trimmed = name.text.trim();
    if (trimmed.isEmpty) return null;
    final commandText = command.text.trim();
    final urlText = url.text.trim();
    if (commandText.isEmpty && urlText.isEmpty) return null;
    return McpServerConfig(
      name: trimmed,
      command: commandText.isEmpty ? null : commandText,
      args: [
        for (final arg in args.text.split(RegExp(r'\s+')))
          if (arg.isNotEmpty) arg,
      ],
      url: urlText.isEmpty ? null : urlText,
    );
  }
}

/// The manual model list (ADR-0045 PG): one input row to register an id and
/// one row per registered id with a remove affordance — ZCode's 模型列表
/// shape at its smallest honest size. The add input commits on submit; a
/// duplicate id is a silent no-op (the list already shows it).

/// The manual model list (ADR-0045 PG): one input row to register an id and
/// one row per registered id with a remove affordance — ZCode's 模型列表
/// shape at its smallest honest size. The add input commits on submit; a
/// duplicate id is a silent no-op (the list already shows it).
class _ManualModelsField extends StatelessWidget {
  const _ManualModelsField({
    required this.models,
    required this.activeModel,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> models;
  final String activeModel;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final controller = TextEditingController();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                AppLocalizations.of(context).modelsListLabel,
                style: DswType.xs13.copyWith(color: color.labelSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final id in models)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DswShape.sm,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.bgLayer2,
                      borderRadius: BorderRadius.circular(DswShape.inner),
                    ),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            id,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DswType.xs13.copyWith(
                              color: color.labelPrimary,
                            ),
                          ),
                        ),
                        if (id == activeModel) ...[
                          const SizedBox(width: 6),
                          Text(
                            AppLocalizations.of(context).modelsActiveTag,
                            style: DswType.xs13.copyWith(
                              color: color.labelTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                DswIconButton(
                  icon: LucideIcons.x,
                  tooltip: AppLocalizations.of(context).modelsRemove,
                  onTap: () => onRemove(id),
                ),
              ],
            ),
          ),
        dswEnsureShadTheme(
          context,
          ShadInput(
            controller: controller,
            placeholder: dswInputHint(
              AppLocalizations.of(context).modelsAddHint,
              style: DswType.xs13.copyWith(color: color.labelTertiary),
            ),
            style: DswType.xs13,
            onSubmitted: (id) {
              final trimmed = id.trim();
              if (trimmed.isNotEmpty) onAdd(trimmed);
              controller.clear();
            },
          ),
        ),
      ],
    );
  }
}
