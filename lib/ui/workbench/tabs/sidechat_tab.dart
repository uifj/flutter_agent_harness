// The side-chat tab.
//
// A port of `DSH-better-sidebar/src/client/SideChatView.tsx`, narrowed the way
// the controller under it already is (see `side_chat_controller.dart`): the
// source's side threads are persisted child sessions with a thread menu, a
// fork-to-session save button, transcript polling and an agent badge; this
// app's side chat is ONE in-memory exchange over the current runtime, so the
// page is the parts that survive that narrowing —
//
//   * the bubbles: the user's asides right-aligned, the agent's answers
//     plain, the live answer one bubble that grows as it streams;
//   * the composer: Enter sends (Shift+Enter breaks the line), disabled
//     while busy — the source's swap of the send icon for a stop button is
//     dropped because this source has no cancel channel (`SideChatSource`
//     stops nothing, and a stop button that cannot stop would lie);
//   * the "new side chat" button: the reset, which drops the exchange and
//     the thread's context;
//   * the empty hero, which explains what the page is for — and, when no
//     runtime has been adopted, that there is nothing to talk to yet.
//
// The host is the SubagentHost pattern again: bodies are built by the global
// registry, so the controller reaches them from an InheritedWidget rather
// than a captured constructor argument.

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../l10n/locales.dart';
import '../../../state/side_chat_controller.dart';
import '../../../theme/dsw_theme.dart';
import '../../../theme/dsw_typography.dart';
import '../../../model/sidebar_tab.dart';
import '../../../state/workbench_controller.dart';

// ---- The host ----------------------------------------------------------------

/// The side-chat seam, in reach of tab bodies. Same reason as [SubagentHost]
/// in subagent_tab.dart: the registry's builders cannot capture an
/// app-scoped object without pinning whichever instance registered first.
class SideChatHost extends InheritedWidget {
  const SideChatHost({
    super.key,
    required this.chat,
    required super.child,
  });

  final SideChatController chat;

  /// The controller below [context]. Throws rather than defaulting: a
  /// side-chat tab outside a SideChatHost is a wiring bug.
  static SideChatController of(BuildContext context) {
    final host = context.dependOnInheritedWidgetOfExactType<SideChatHost>();
    if (host == null) {
      throw StateError('SideChatTab needs a SideChatHost ancestor');
    }
    return host.chat;
  }

  @override
  bool updateShouldNotify(SideChatHost oldWidget) => chat != oldWidget.chat;
}

// ---- The tab -----------------------------------------------------------------

class SideChatTab extends StatefulWidget {
  const SideChatTab({super.key, required this.workbench, required this.tab});

  final WorkbenchController workbench;
  final SidebarTab tab;

  @override
  State<SideChatTab> createState() => _SideChatTabState();
}

class _SideChatTabState extends State<SideChatTab> {
  late final TextEditingController _composer;
  final _scroll = ScrollController();

  /// The controller, adopted from the host so a runtime swap mid-flight is
  /// followed rather than survived.
  SideChatController? _chat;

  @override
  void initState() {
    super.initState();
    _composer = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final chat = SideChatHost.of(context);
    if (chat != _chat) {
      _chat?.removeListener(_onChat);
      _chat = chat;
      chat.addListener(_onChat);
    }
  }

  @override
  void dispose() {
    _chat?.removeListener(_onChat);
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// A change in the exchange rebuilds the list and keeps the view at the
  /// tail — the source's own stick-to-bottom rule, which a streaming answer
  /// exercises on every delta.
  void _onChat() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _composer.text;
    final chat = _chat;
    if (chat == null || text.trim().isEmpty) return;
    _composer.clear();
    await chat.send(text);
  }

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final chat = _chat;
    final messages = chat?.messages ?? const [];
    return DecoratedBox(
      decoration: BoxDecoration(color: color.bgLayer2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context),
          Expanded(
            child: messages.isEmpty
                ? _EmptyState(ready: chat?.ready ?? false)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) => _Bubble(
                      message: messages[index],
                    ),
                  ),
          ),
          if (chat?.busy ?? false) _statusBar(context),
          _composerBar(context),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final color = context.dsw;
    return Container(
      height: 36,
      padding: const EdgeInsets.only(left: 12, right: 8),
      decoration: BoxDecoration(
        color: color.bgLayer1,
        border: Border(bottom: BorderSide(color: color.borderL1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.tr('sidechat'),
              style: DswType.s14.copyWith(color: color.labelSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _HeaderButton(
            icon: LucideIcons.message_square_plus,
            tooltip: context.tr('sideChatNew'),
            onTap: () => _chat?.reset(),
          ),
        ],
      ),
    );
  }

  Widget _statusBar(BuildContext context) {
    final color = context.dsw;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
      child: Row(
        children: [
          SizedBox(
            width: 8,
            height: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color.stateSuccessPrimary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            context.tr('sideChatThinking'),
            style: DswType.xxxs11.copyWith(color: color.labelTertiary),
          ),
        ],
      ),
    );
  }

  Widget _composerBar(BuildContext context) {
    final color = context.dsw;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: color.bgLayer1,
        border: Border(top: BorderSide(color: color.borderL1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _composer,
              minLines: 1,
              maxLines: 4,
              style: DswType.xs13.copyWith(color: color.labelPrimary),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: context.tr('sideChatPlaceholder'),
                hintStyle: DswType.xs13.copyWith(color: color.labelTertiary),
              ),
              // Enter sends; Shift+Enter keeps the newline, the source's own
              // split.
              onSubmitted: (_) => _send(),
            ),
          ),
          _SendButton(onTap: _send),
        ],
      ),
    );
  }
}

// ---- The pieces ----------------------------------------------------------------

/// One bubble: the user's aside in a filled chip on the right, the agent's
/// answer as plain text on the left.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final SideChatMessage message;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8, left: 32),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.interactiveBgHover,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            message.text,
            style: DswType.xs13.copyWith(color: color.labelPrimary),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 32),
      child: Text(
        message.text,
        style: DswType.xs13.copyWith(color: color.labelPrimary, height: 1.4),
      ),
    );
  }
}

/// `.sidechatHero`: the block-centred explainer — a different one when no
/// model is connected, so the page never claims a capability it lacks.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.message_square_plus,
              size: 20,
              color: color.labelTertiary,
            ),
            const SizedBox(height: 8),
            Text(
              ready ? context.tr('sideChatEmpty') : context.tr('settings'),
              textAlign: TextAlign.center,
              style: DswType.xxs12.copyWith(color: color.labelTertiary),
            ),
            const SizedBox(height: 2),
            Text(
              ready
                  ? context.tr('sideChatEmptyDesc')
                  : context.tr('sideChatNoModel'),
              textAlign: TextAlign.center,
              style: DswType.xxxs11.copyWith(color: color.labelDimmed),
            ),
          ],
        ),
      ),
    );
  }
}

/// The composer's send button — disabled while busy, matching the composer's
/// own gate. No stop button: see the file header.
class _SendButton extends StatefulWidget {
  const _SendButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hovered
                ? color.interactiveBgHoverAccent
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            LucideIcons.send,
            size: 14,
            color: _hovered ? color.labelPrimary : color.labelSecondary,
          ),
        ),
      ),
    );
  }
}

/// The header's reset button — `.sidechatIconBtn`'s shape at this tab's scale.
class _HeaderButton extends StatefulWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_HeaderButton> createState() => _HeaderButtonState();
}

class _HeaderButtonState extends State<_HeaderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hovered
                  ? color.interactiveBgHover
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: 13,
              color: _hovered ? color.labelPrimary : color.labelSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
