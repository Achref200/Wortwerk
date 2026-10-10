import 'package:wortwerk/core/l10n/localized_text.dart';
import 'package:flutter/material.dart';

import '../../../design_system/components.dart';
import '../../../design_system/fritz_avatar.dart';
import '../../../design_system/wortwerk_theme.dart';

typedef FritzTutorPrompt = ({String text, String mode});

final class FritzAiSheet extends StatefulWidget {
  const FritzAiSheet({required this.onStartTutor, super.key});

  final ValueChanged<FritzTutorPrompt> onStartTutor;

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<FritzTutorPrompt> onStartTutor,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FritzAiSheet(onStartTutor: onStartTutor),
    );
  }

  @override
  State<FritzAiSheet> createState() => _FritzAiSheetState();
}

final class _FritzAiSheetState extends State<FritzAiSheet> {
  static const _actions = [
    ('Erklären', Icons.lightbulb_outline_rounded, 'Erkläre mir', 'explain'),
    ('Übersetzen', Icons.translate_rounded, 'Übersetze', 'translate'),
    ('Üben', Icons.edit_outlined, 'Übe mit mir', 'practice'),
    ('Sprechen', Icons.mic_none_rounded, 'Lass uns sprechen', 'speak'),
  ];
  static const _suggestions = [
    ('Dativ erklären', 'explain'),
    ('Im Café bestellen', 'practice'),
    ('Meine Fehler verstehen', 'explain'),
  ];

  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .92,
        ),
        decoration: const BoxDecoration(
          color: WortwerkColors.paper,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(WortwerkRadii.sheet),
          ),
          border: Border.fromBorderSide(BorderSide(color: WortwerkColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: WortwerkColors.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: WortwerkColors.a2,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const FritzAvatar(size: 54),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LocalizedText(
                            'Fritz',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          LocalizedText(
                            'Frag mich auf Deutsch.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Schließen',
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                LocalizedText(
                  'Wobei kann ich helfen?',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.8,
                  children: [
                    for (final action in _actions)
                      _AiAction(
                        title: action.$1,
                        icon: action.$2,
                        onPressed: () => widget.onStartTutor((
                          text: action.$3,
                          mode: action.$4,
                        )),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                const Eyebrow('Zum Ausprobieren'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (suggestion, mode) in _suggestions)
                      ActionChip(
                        label: LocalizedText(suggestion),
                        onPressed: () =>
                            widget.onStartTutor((text: suggestion, mode: mode)),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Schreib auf Deutsch …',
                    filled: true,
                    fillColor: const Color(0xFFFFFEFC),
                    contentPadding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: WortwerkColors.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: WortwerkColors.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: WortwerkColors.ink),
                    ),
                    suffixIcon: IconButton(
                      onPressed: _controller.text.trim().isEmpty
                          ? null
                          : () => widget.onStartTutor((
                              text: _controller.text.trim(),
                              mode: 'chat',
                            )),
                      tooltip: 'Mit Fritz sprechen',
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      widget.onStartTutor((text: value.trim(), mode: 'chat'));
                    }
                  },
                ),
                const SizedBox(height: 8),
                LocalizedText(
                  'Fritz übt mit dir auf deinem Niveau.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _AiAction extends StatelessWidget {
  const _AiAction({
    required this.title,
    required this.icon,
    required this.onPressed,
  });

  final String title;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 19),
          const SizedBox(width: 7),
          Flexible(
            child: LocalizedText(
              title,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
