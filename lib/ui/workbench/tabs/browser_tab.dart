// The browser tab: an address bar and an embedded web view.
//
// A port of `DSH-better-sidebar/src/client/BrowserView.tsx` from the source's
// sandboxed iframe to `flutter_inappwebview`, which narrows the security model
// by replacing it rather than porting it: a real web engine is not an opaque
// origin inside the GUI's own page, so the sandbox token algebra, the loopback
// allowlist and the embed probe (X-Frame-Options) have no equivalent here —
// the address bar keeps only the source's REFUSAL rules (http/https only,
// loopback refused). What survives intact is the part that was never about
// the iframe:
//
//   * The URL persists onto the tab (`patchTab`), so a restored layout
//     reopens the page it was left on.
//   * The back/forward stack tracks ADDRESS-BAR navigations. In the source
//     that was a limitation (in-frame link clicks are cross-origin and
//     invisible to the parent); here it is a choice — the web view owns its
//     own full history, and this stack is the deterministic one the buttons
//     answer to.
//   * The reload remounts the view (the source's `reloadKey`), which is also
//     what makes a navigation land: a fresh initial URL on a fresh widget.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../l10n/locales.dart';
import '../../../theme/dsw_theme.dart';
import '../../../theme/dsw_typography.dart';
import '../../../model/sidebar_tab.dart';
import '../../../state/workbench_controller.dart';

// ---- The URL rules, pure and testable --------------------------------------

/// What [normalizeBrowserUrl] decided about an address.
enum BrowserUrlVerdict { ok, invalid, blockedScheme, blockedLoopback }

/// The checked address: a verdict, and the normalized URL when it is ok.
class NormalizedBrowserUrl {
  const NormalizedBrowserUrl._(this.verdict, [this.url]);

  const NormalizedBrowserUrl.ok(String url) : this._(BrowserUrlVerdict.ok, url);
  const NormalizedBrowserUrl.invalid() : this._(BrowserUrlVerdict.invalid);
  const NormalizedBrowserUrl.blockedScheme()
    : this._(BrowserUrlVerdict.blockedScheme);
  const NormalizedBrowserUrl.blockedLoopback()
    : this._(BrowserUrlVerdict.blockedLoopback);

  final BrowserUrlVerdict verdict;
  final String? url;

  bool get isOk => verdict == BrowserUrlVerdict.ok;
}

const _loopbackHosts = {'localhost', 'localhost.', '::1', '[::1]', '0.0.0.0'};

/// Whether [host] names this machine — the addresses the tab refuses.
bool isLoopbackHost(String host) =>
    _loopbackHosts.contains(host) || host.startsWith('127.');

/// The address the address bar will load, or why it will not.
///
/// A bare host is promoted to https, the way every browser's bar does; the
/// scheme set is closed at http/https; loopback is refused outright (the
/// source's own default, minus its allowlist — see the file header).
NormalizedBrowserUrl normalizeBrowserUrl(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return const NormalizedBrowserUrl.invalid();
  final withScheme = text.contains('://') ? text : 'https://$text';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || uri.host.isEmpty) {
    return const NormalizedBrowserUrl.invalid();
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return const NormalizedBrowserUrl.blockedScheme();
  }
  if (isLoopbackHost(uri.host)) {
    return const NormalizedBrowserUrl.blockedLoopback();
  }
  return NormalizedBrowserUrl.ok(withScheme);
}

/// The host of [url], or the whole text when it does not parse — the title a
/// persisted browser tab carries.
String browserHostOf(String url) {
  final uri = Uri.tryParse(url);
  final host = uri?.host;
  return (host == null || host.isEmpty) ? url : host;
}

// ---- The tab ----------------------------------------------------------------

class BrowserTab extends StatefulWidget {
  const BrowserTab({super.key, required this.workbench, required this.tab});

  final WorkbenchController workbench;
  final SidebarTab tab;

  @override
  State<BrowserTab> createState() => _BrowserTabState();
}

class _BrowserTabState extends State<BrowserTab> {
  /// The page being shown, from the tab's persisted path at mount.
  String? _url;

  /// The address bar's live text — ahead of [_url] between edits.
  late final TextEditingController _input;

  /// The refusal hint under the bar, or null for none.
  String? _message;

  /// Address-bar navigations only — see the file header.
  late final List<String> _history;

  /// Where in [_history] the current page is.
  late int _cursor;

  /// Bumped to remount the view — a reload, and the only way a repeated
  /// navigation (or the same URL) lands.
  int _reloadKey = 0;

  @override
  void initState() {
    super.initState();
    final path = widget.tab.path;
    _url = path;
    _input = TextEditingController(text: path ?? '');
    _history = [
      ?path,
    ];
    _cursor = path != null ? 0 : -1;
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  /// The `+` menu's fresh tab: no address yet, so the start page says so.
  bool get _fresh => _url == null;

  void _navigate() {
    final result = normalizeBrowserUrl(_input.text);
    if (result.isOk) {
      _load(result.url!, push: true);
      setState(() => _message = null);
      return;
    }
    final hint = switch (result.verdict) {
      BrowserUrlVerdict.invalid => context.tr('browserInvalid'),
      BrowserUrlVerdict.blockedScheme => context.tr('browserBlockedScheme'),
      BrowserUrlVerdict.blockedLoopback => context.tr('browserBlockedLoopback'),
      BrowserUrlVerdict.ok => '',
    };
    setState(() => _message = hint);
  }

  /// Shows [url]: pushes it onto the stack when [push], which is what
  /// distinguishes an address-bar navigation from a back/forward hop.
  void _load(String url, {required bool push}) {
    if (push) {
      _history.removeRange(_cursor + 1, _history.length);
      _history.add(url);
      _cursor = _history.length - 1;
    }
    setState(() {
      _url = url;
      _input.text = url;
      _reloadKey++;
    });
    _persist(url);
  }

  void _back() {
    if (_cursor <= 0) return;
    _cursor--;
    _load(_history[_cursor], push: false);
  }

  void _forward() {
    if (_cursor >= _history.length - 1) return;
    _cursor++;
    _load(_history[_cursor], push: false);
  }

  /// Writes the address onto the tab — the persistence the source's own
  /// `persist` does, so a restored layout reopens this page.
  void _persist(String url) => widget.workbench.patchTab(
    widget.tab.id,
    path: url,
    title: browserHostOf(url),
  );

  /// Hands the page to the platform's browser — the source's
  /// `window.open(..., 'noopener')`.
  Future<void> _openExternal() async {
    final url = _url;
    if (url == null) return;
    if (Platform.isMacOS) {
      await Process.run('open', [url]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return DecoratedBox(
      decoration: BoxDecoration(color: color.bgLayer2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _bar(context),
          if (_message != null) _messageBar(context),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }

  Widget _bar(BuildContext context) {
    final color = context.dsw;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.bgLayer1,
        border: Border(bottom: BorderSide(color: color.borderL1)),
      ),
      child: Row(
        children: [
          _BarIconButton(
            icon: LucideIcons.chevron_left,
            tooltip: context.tr('browserBack'),
            onTap: _back,
            enabled: _cursor > 0,
          ),
          _BarIconButton(
            icon: LucideIcons.chevron_right,
            tooltip: context.tr('browserForward'),
            onTap: _forward,
            enabled: _cursor < _history.length - 1,
          ),
          _BarIconButton(
            icon: LucideIcons.refresh_cw,
            tooltip: context.tr('refresh'),
            // A fresh tab has nothing to remount.
            onTap: _fresh ? null : () => setState(() => _reloadKey++),
          ),
          Expanded(
            child: TextField(
              controller: _input,
              style: DswType.xs13.copyWith(color: color.labelPrimary),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: context.tr('browserPlaceholder'),
                hintStyle: DswType.xs13.copyWith(color: color.labelTertiary),
              ),
              onSubmitted: (_) => _navigate(),
            ),
          ),
          _BarIconButton(
            icon: LucideIcons.arrow_right,
            tooltip: context.tr('browserGo'),
            onTap: _navigate,
          ),
          _BarIconButton(
            icon: LucideIcons.external_link,
            tooltip: context.tr('browserOpenExternal'),
            onTap: _fresh ? null : _openExternal,
          ),
        ],
      ),
    );
  }

  Widget _messageBar(BuildContext context) {
    final color = context.dsw;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.stateErrorPrimary.withValues(alpha: 0.08),
        border: Border(bottom: BorderSide(color: color.borderL1)),
      ),
      child: Text(
        _message!,
        style: DswType.xxxs11.copyWith(color: color.stateErrorPrimary),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final color = context.dsw;
    if (_fresh) {
      return Center(
        child: Text(
          context.tr('browserStart'),
          textAlign: TextAlign.center,
          style: DswType.xs13.copyWith(color: color.labelTertiary),
        ),
      );
    }
    return InAppWebView(
      key: ValueKey('browser:${widget.tab.id}:$_reloadKey'),
      initialUrlRequest: URLRequest(url: WebUri(_url!)),
      // A link click the view made itself: the bar and the tab follow the
      // page — but the history stack does not, which is the source's own
      // rule carried over (see the file header).
      onLoadStop: (controller, url) {
        final next = url?.toString();
        if (next == null || next == _url) return;
        setState(() {
          _url = next;
          _input.text = next;
        });
        _persist(next);
      },
    );
  }
}

/// One address-bar button — the source's `.iconButton`: 24x24, hover fill,
/// dimmed rather than hidden when it has nothing to do.
class _BarIconButton extends StatefulWidget {
  const _BarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<_BarIconButton> createState() => _BarIconButtonState();
}

class _BarIconButtonState extends State<_BarIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final enabled = widget.enabled && widget.onTap != null;
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? widget.onTap : null,
          child: Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: enabled && _hovered
                  ? color.interactiveBgHover
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: 14,
              color: enabled
                  ? (_hovered ? color.labelPrimary : color.labelSecondary)
                  : color.labelCaption,
            ),
          ),
        ),
      ),
    );
  }
}
