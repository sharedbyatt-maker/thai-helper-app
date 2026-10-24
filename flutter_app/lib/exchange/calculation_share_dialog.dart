import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'user_language.dart' show Text, uiText;

/// A visible, selectable receipt remains available even without system sharing
/// or clipboard permission. Financial text is never translated or rewritten.
class CalculationShareDialog extends StatefulWidget {
  final String receipt;
  final Future<void> Function(String)? copy;
  const CalculationShareDialog({super.key, required this.receipt, this.copy});
  @override
  State<CalculationShareDialog> createState() => _CalculationShareDialogState();
}

class _CalculationShareDialogState extends State<CalculationShareDialog> {
  bool copying = false, sharing = false;
  String? status;
  Future<void> copy() async {
    setState(() => copying = true);
    try {
      if (widget.copy != null) {
        await widget.copy!(widget.receipt);
      } else {
        await Clipboard.setData(ClipboardData(text: widget.receipt));
      }
      if (mounted) setState(() => status = 'စာသား ကူးပြီးပါပြီ။');
    } catch (_) {
      if (mounted) setState(() => status = 'ကူးမရသေးပါ။ အောက်ကစာသားကို ရွေးပြီး ကိုယ်တိုင်ကူးနိုင်ပါတယ်။');
    } finally {
      if (mounted) setState(() => copying = false);
    }
  }
  Future<void> share() async {
    setState(() => sharing = true);
    try {
      final box = context.findRenderObject() as RenderBox?;
      final result = await Share.share(widget.receipt,
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size);
      if (mounted) setState(() => status = result.status == ShareResultStatus.success
          ? 'မျှဝေပြီးပါပြီ။'
          : result.status == ShareResultStatus.dismissed
          ? 'မျှဝေမှုကို ပယ်ဖျက်ထားပါတယ်။'
          : 'မျှဝေမရသေးပါ။ စာသားကို ကူးပြီး ပို့နိုင်ပါတယ်။');
    } catch (_) {
      if (mounted) setState(() => status = 'မျှဝေမရသေးပါ။ စာသားကို ကူးပြီး ပို့နိုင်ပါတယ်။');
    } finally {
      if (mounted) setState(() => sharing = false);
    }
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('တွက်ချက်ရလဒ် မျှဝေမယ်'),
    content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(
      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('တွက်ချက်ရလဒ်သာ ဖြစ်ပါတယ်။ ငွေလွှဲပြီးကြောင်း ပြေစာမဟုတ်ပါ။'),
        const SizedBox(height: 12),
        if (status != null) ...[Text(status!, key: const ValueKey('calculation_share_status')), const SizedBox(height: 12)],
        SelectableText(widget.receipt, key: const ValueKey('calculation_share_text')),
      ],
    ))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('ပိတ်မယ်')),
      if (!kIsWeb) TextButton.icon(onPressed: sharing ? null : share,
        icon: const Icon(Icons.share_outlined), label: const Text('မျှဝေမယ်')),
      FilledButton.icon(key: const ValueKey('calculation_share_copy'), onPressed: copying ? null : copy,
        icon: const Icon(Icons.copy_outlined), label: Text(copying ? 'ကူးနေပါတယ်…' : 'စာသားကူးမယ်')),
    ],
    semanticLabel: uiText(context, 'တွက်ချက်ရလဒ် မျှဝေမယ်'),
  );
}
