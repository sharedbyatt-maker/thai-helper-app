import 'package:flutter/material.dart' hide Text;

import 'user_language.dart' show Text;

/// Keep forms readable on desktop without changing their mobile scroll area.
class ContentWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const ContentWidth({super.key, required this.child, this.maxWidth = 760});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// Back navigation must not silently lose a financial entry being edited.
class DraftGuard extends StatefulWidget {
  final bool dirty, busy;
  final Widget child;
  const DraftGuard({
    super.key,
    required this.dirty,
    required this.busy,
    required this.child,
  });

  @override
  State<DraftGuard> createState() => DraftGuardState();
}

class DraftGuardState extends State<DraftGuard> {
  bool leaving = false, prompting = false;

  Future<void> leave() async {
    if (!mounted || leaving) return;
    setState(() => leaving = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _back(bool didPop, Object? result) async {
    if (didPop || leaving || prompting) return;
    if (widget.busy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('သိမ်းနေပါတယ်။ ခဏစောင့်ပေးပါ။')),
      );
      return;
    }
    prompting = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('မသိမ်းရသေးတာတွေ ရှိတယ်'),
        content: const Text(
          'ပြန်ထွက်ရင် အခုဖြည့်ထားတဲ့ ပြင်ဆင်ချက်တွေ ပျောက်သွားမယ်။',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ဆက်ဖြည့်မယ်'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('မသိမ်းဘဲ ထွက်မယ်'),
          ),
        ],
      ),
    );
    prompting = false;
    if (mounted && discard == true) await leave();
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: leaving || (!widget.dirty && !widget.busy),
    onPopInvokedWithResult: _back,
    child: widget.child,
  );
}
