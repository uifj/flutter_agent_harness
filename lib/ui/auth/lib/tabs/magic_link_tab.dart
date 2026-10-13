import 'package:flutter/material.dart';
import 'package:app_common/better_auth/flutter_better_auth.dart';
import 'package:app_common/better_auth/plugins/magic_link/magic_link_plugin.dart';

import '../harness/widgets.dart';

class MagicLinkTab extends StatefulWidget {
  const MagicLinkTab({super.key});
  @override
  State<MagicLinkTab> createState() => _MagicLinkTabState();
}

class _MagicLinkTabState extends State<MagicLinkTab> {
  final _console = ConsoleController();
  final _email = TextEditingController(text: 'test@mail.com');
  final _token = TextEditingController();

  BetterAuthClient get c => FlutterBetterAuth.client;

  @override
  void dispose() {
    _console.dispose();
    _email.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HarnessTab(
      console: _console,
      children: [
        Field('email', _email),
        Act(
          'Send magic link',
          () => runAction(
            _console,
            'magicLink.signIn',
            () =>
                c.magicLink.signIn(email: _email.text, callbackURL: 'myapp://'),
          ),
        ),
        Field('token (from link)', _token),
        Act(
          'Verify token',
          () => runAction(
            _console,
            'magicLink.verify',
            () => c.magicLink.verify(token: _token.text),
          ),
        ),
      ],
    );
  }
}
