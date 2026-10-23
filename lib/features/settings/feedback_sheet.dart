import 'package:flutter/material.dart';

import '../../services/feedback.dart';
import '../../services/juice.dart';
import '../../theme.dart';
import '../common/toast.dart';

/// Settings › Send feedback: the player writes a message (and their email
/// if they'd like a reply) and [send] emails it to Shiva. A failed send
/// keeps the text and says so.
Future<void> showFeedbackSheet(BuildContext context, {required FeedbackSender send, Juice? juice}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(child: _FeedbackForm(send: send, juice: juice)),
    ),
  );
}

class _FeedbackForm extends StatefulWidget {
  const _FeedbackForm({required this.send, this.juice});
  final FeedbackSender send;
  final Juice? juice;

  @override
  State<_FeedbackForm> createState() => _FeedbackFormState();
}

class _FeedbackFormState extends State<_FeedbackForm> {
  final _message = TextEditingController();
  final _email = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _message.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _message.dispose();
    _email.dispose();
    super.dispose();
  }

  bool get _canSend => !_sending && _message.text.trim().isNotEmpty;

  Future<void> _send() async {
    if (!_canSend) return;
    widget.juice?.tap();
    setState(() {
      _sending = true;
      _error = null;
    });
    final ok = await widget.send(message: _message.text.trim(), replyTo: _email.text.trim());
    if (!mounted) return;
    if (ok) {
      showToast(context, 'Thanks! Your message is on its way.', icon: Icons.favorite_rounded);
      Navigator.of(context).pop();
    } else {
      setState(() {
        _sending = false;
        _error = "Couldn't send it. Check your connection and try again.";
      });
    }
  }

  /// A dark glass box with a violet tube that lights magenta while typing.
  InputDecoration _box(String hint) {
    OutlineInputBorder tube(Color c, double w) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));
    return InputDecoration(
      hintText: hint,
      hintStyle: body(color: kMuted, weight: FontWeight.w600),
      filled: true,
      fillColor: kCell,
      counterStyle: body(size: 11, color: kMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: tube(kViolet.withValues(alpha: 0.6), 1.5),
      enabledBorder: tube(kViolet.withValues(alpha: 0.6), 1.5),
      focusedBorder: tube(kMagenta, 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Send feedback',
            textAlign: TextAlign.center,
            style: display(size: 22, spacing: 2, glowColor: kMagenta, glowStrength: 0.6),
          ),
          const SizedBox(height: 8),
          Text(
            "Tell me what you love, what bugs you, or what you'd like next. It goes straight to my inbox.",
            textAlign: TextAlign.center,
            style: body(size: 14, color: kMuted, weight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('feedback-message'),
            controller: _message,
            minLines: 5,
            maxLines: 8,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            cursorColor: kMagenta,
            style: body(size: 16, color: kText, weight: FontWeight.w600),
            decoration: _box('Your message'),
          ),
          const SizedBox(height: 6),
          TextField(
            key: const Key('feedback-email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            cursorColor: kMagenta,
            style: body(size: 16, color: kText, weight: FontWeight.w600),
            decoration: _box("Your email (optional, if you'd like a reply)"),
          ),
          if (_error case final e?) ...[
            const SizedBox(height: 10),
            Text(e, key: const Key('feedback-error'), textAlign: TextAlign.center, style: body(size: 14, color: kBad)),
          ],
          const SizedBox(height: 20),
          Center(
            child: Opacity(
              opacity: _canSend ? 1 : 0.45,
              child: NeonButton(
                key: const Key('feedback-send'),
                label: _sending ? 'Sending…' : 'Send',
                pulse: false,
                onPressed: _send,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
