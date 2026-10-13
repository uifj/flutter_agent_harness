import 'package:flutter/material.dart';
import 'package:app_common/better_auth/flutter_better_auth.dart';
import 'package:app_common/better_auth/plugins/multi_session/multi_session_plugin.dart';

import '../harness/widgets.dart';

class MultiSessionTab extends StatefulWidget {
  const MultiSessionTab({super.key});
  @override
  State<MultiSessionTab> createState() => _MultiSessionTabState();
}

class _MultiSessionTabState extends State<MultiSessionTab> {
  final _console = ConsoleController();
  final _token = TextEditingController();

  BetterAuthClient get c => FlutterBetterAuth.client;

  @override
  void dispose() {
    _console.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HarnessTab(
      console: _console,
      children: [
        Act(
          'List device sessions',
          () => runAction(
            _console,
            'multiSession.listDeviceSessions',
            () => c.multiSession.listDeviceSessions(),
          ),
        ),
        Field('sessionToken', _token),
        Act(
          'Set active',
          () => runAction(
            _console,
            'multiSession.setActive',
            () => c.multiSession.setActive(sessionToken: _token.text),
          ),
        ),
        Act(
          'Revoke',
          () => runAction(
            _console,
            'multiSession.revoke',
            () => c.multiSession.revoke(sessionToken: _token.text),
          ),
        ),
      ],
    );
  }
}
