import 'package:flutter/material.dart';
import 'package:shivapps_shell/shivapps_shell.dart';

import '../../theme.dart';

/// First-run, local age selection. It has no gameplay or purchase effect.
class AgeScreen extends StatefulWidget {
  const AgeScreen({super.key, required this.policy, required this.onComplete});

  final AgePolicy policy;
  final VoidCallback onComplete;

  @override
  State<AgeScreen> createState() => _AgeScreenState();
}

class _AgeScreenState extends State<AgeScreen> {
  bool _saving = false;
  String? _error;

  Future<void> _choose(AgeGroup group) async {
    if (_saving || !widget.policy.needsSelection) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.policy.choose(group);
      if (mounted) widget.onComplete();
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save your choice. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Dusk(child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.shield_outlined, color: kText, size: 44),
                  const SizedBox(height: 24),
                  Text(
                    'Which age group are you in?',
                    textAlign: TextAlign.center,
                    style: body(size: 26, weight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'We use this choice for age-appropriate privacy settings. It stays on this device.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 28),
                  for (final group in AgeGroup.values) ...[
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 52),
                      child: OutlinedButton(
                        key: Key('age-choice-${group.storageValue}'),
                        onPressed: _saving ? null : () => _choose(group),
                        child: Text(group.label),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_error != null)
                    Text(_error!, style: TextStyle(color: colors.error)),
                ],
              ),
            ),
          ),
        ),
      )),
    );
  }
}
