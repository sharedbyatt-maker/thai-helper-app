import 'package:flutter/material.dart';
import 'models.dart';
import 'services.dart';
import 'screens/rates_screen.dart';

// ---------------- Home ----------------

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<ContentBundle> _content() => loadContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ထိုင်းအကူ • Thai Helper'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final c = await _content();
              if (context.mounted) {
                showSearch(
                    context: context,
                    delegate: PhraseSearchDelegate(c));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.star_border),
            onPressed: () async {
              final c = await _content();
              if (context.mounted) {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            FavoritesScreen(content: c)));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: FutureBuilder<ContentBundle>(
        future: _content(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final content = snap.data!;
          final dayIndex = DateTime.now()
                  .difference(DateTime(DateTime.now().year, 1, 1))
                  .inDays %
              content.phrases.length;
          final daily = content.phrases[dayIndex];
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _dailyCard(context, daily),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: content.categories.length,
                itemBuilder: (context, i) {
                  final cat = content.categories[i];
                  final count =
                      content.byCategory[cat.id]?.length ?? 0;
                  return Card(
                    child: InkWell(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => PhraseListScreen(
                                  content: content,
                                  category: cat))),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(cat.icon,
                                style:
                                    const TextStyle(fontSize: 30)),
                            const SizedBox(height: 4),
                            Text(cat.my,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                            Text('$count စကားစု',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.teal.shade50,
                child: ListTile(
                  leading: const Text('💸',
                      style: TextStyle(fontSize: 28)),
                  title: const Text('ငွေလွှဲနှုန်း နှိုင်းယှဉ်ချက်'),
                  subtitle:
                      const Text('ဘယ်က အသက်သာဆုံး နှိပ်ကြည့်'),
                  trailing:
                      const Icon(Icons.arrow_forward_ios),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const RatesScreen())),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _dailyCard(BuildContext context, Phrase p) {
    return Card(
      color: Colors.amber.shade50,
      child: ListTile(
        leading: const Text('📅', style: TextStyle(fontSize: 28)),
        title: Text(p.displayThai(Prefs.isMale),
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.bold)),
        subtitle: Text('${p.my} • ${p.pronunciation}'),
        trailing: IconButton(
          icon: const Icon(Icons.volume_up, size: 32),
          onPressed: () =>
              TtsService().speak(p.displayThai(Prefs.isMale)),
        ),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => PhraseDetailScreen(phrase: p))),
      ),
    );
  }
}

// ---------------- Phrase list ----------------

class PhraseListScreen extends StatelessWidget {
  final ContentBundle content;
  final Category category;
  const PhraseListScreen(
      {super.key, required this.content, required this.category});

  @override
  Widget build(BuildContext context) {
    final phrases = content.byCategory[category.id] ?? const [];
    return Scaffold(
      appBar: AppBar(
          title: Text('${category.icon} ${category.my}')),
      body: ListView.separated(
        itemCount: phrases.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final p = phrases[i];
          return ListTile(
            title: Text(p.displayThai(Prefs.isMale),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            subtitle: Text('${p.my}\n${p.pronunciation}'),
            isThreeLine: true,
            trailing: IconButton(
              icon: const Icon(Icons.volume_up),
              onPressed: () =>
                  TtsService().speak(p.displayThai(Prefs.isMale)),
            ),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => PhraseDetailScreen(phrase: p))),
          );
        },
      ),
    );
  }
}

// ---------------- Phrase detail ----------------

class PhraseDetailScreen extends StatefulWidget {
  final Phrase phrase;
  const PhraseDetailScreen({super.key, required this.phrase});

  @override
  State<PhraseDetailScreen> createState() =>
      _PhraseDetailScreenState();
}

class _PhraseDetailScreenState extends State<PhraseDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final p = widget.phrase;
    final isFav = Prefs.favorites.contains(p.id);
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(isFav ? Icons.star : Icons.star_border),
            onPressed: () async {
              await Prefs.toggleFavorite(p.id);
              setState(() {});
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(p.my,
                style:
                    const TextStyle(fontSize: 16, color: Colors.grey)),
            if (p.en != null && p.en!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(p.en!,
                  style: const TextStyle(
                      fontSize: 14, color: Colors.grey)),
            ],
            const SizedBox(height: 16),
            Text(p.displayThai(Prefs.isMale),
                style: const TextStyle(
                    fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('🔊 ${p.pronunciation}',
                  style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.volume_up, size: 32),
              label: const Text('အသံထွက်',
                  style: TextStyle(fontSize: 20)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () =>
                  TtsService().speak(p.displayThai(Prefs.isMale)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.report_outlined),
              label: const Text('ထိုင်းစာ မှားနေရင် နှိပ်ပါ'),
              onPressed: () => _reportDialog(context, p),
            ),
          ],
        ),
      ),
    );
  }

  void _reportDialog(BuildContext context, Phrase p) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('အမှားထောက်ပြရန်'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
              hintText: 'ဘာမှားနေလဲ ရေးပေးပါ'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('မလုပ်တော့')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('ကျေးဇူးပါ! မှတ်ထားပြီ 🙏')));
              // v1.1: send report to backend
            },
            child: const Text('ပို့မယ်'),
          ),
        ],
      ),
    );
  }
}

// ---------------- Search ----------------

class PhraseSearchDelegate extends SearchDelegate<Phrase?> {
  final ContentBundle content;
  PhraseSearchDelegate(this.content);

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => query = ''),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) =>
      _resultList(context);

  @override
  Widget buildSuggestions(BuildContext context) =>
      _resultList(context);

  Widget _resultList(BuildContext context) {
    final q = query.trim();
    final hits = q.isEmpty
        ? <Phrase>[]
        : content.phrases.where((p) => p.matches(q)).toList();
    return ListView.builder(
      itemCount: hits.length,
      itemBuilder: (context, i) {
        final p = hits[i];
        return ListTile(
          title: Text(p.displayThai(Prefs.isMale)),
          subtitle: Text('${p.my} • ${p.pronunciation}'),
          trailing: IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: () =>
                TtsService().speak(p.displayThai(Prefs.isMale)),
          ),
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => PhraseDetailScreen(phrase: p))),
        );
      },
    );
  }
}

// ---------------- Favorites ----------------

class FavoritesScreen extends StatelessWidget {
  final ContentBundle content;
  const FavoritesScreen({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final favs = content.phrases
        .where((p) => Prefs.favorites.contains(p.id))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('⭐ ကြိုက်နှစ်သက်ရာ')),
      body: favs.isEmpty
          ? const Center(
              child: Text('မရှိသေးဘူး — ⭐ နှိပ်ပြီး သိမ်းပါ'))
          : ListView.separated(
              itemCount: favs.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1),
              itemBuilder: (context, i) {
                final p = favs[i];
                return ListTile(
                  title: Text(p.displayThai(Prefs.isMale),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600)),
                  subtitle:
                      Text('${p.my} • ${p.pronunciation}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.volume_up),
                    onPressed: () => TtsService()
                        .speak(p.displayThai(Prefs.isMale)),
                  ),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              PhraseDetailScreen(phrase: p))),
                );
              },
            ),
    );
  }
}

// ---------------- Settings ----------------

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('⚙️ ဆက်တင်')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('ကျွန်တော် ယောက်ျားပါ'),
            subtitle:
                const Text('ပိတ်ထားရင် မိန်းမပုံစံ စကားစုတွေ ပြမယ်'),
            value: Prefs.isMale,
            onChanged: (v) async {
              await Prefs.setIsMale(v);
              setState(() {});
            },
          ),
          ListTile(
            leading: const Icon(Icons.volume_up),
            title: const Text('ထိုင်းအသံ စစ်ဆေးရန်'),
            subtitle: const Text(
                'ဖုန်းမှာ ထိုင်းအသံ မရှိရင် download ဆွဲဖို့ လိုမယ်'),
            onTap: () async {
              final ok = await TtsService().isThaiAvailable;
              if (context.mounted) {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title:
                        Text(ok ? '✅ အဆင်ပြေတယ်' : '⚠️ အသံလိုနေတယ်'),
                    content: Text(ok
                        ? 'ထိုင်းအသံ အသင့်ဖြစ်နေပြီ။ 🔊 ခလုတ်တွေ အမှန်ထွက်မယ်။'
                        : 'ထိုင်းအသံ မရှိသေးဘူး! အသံခလုတ်နှိပ်ရင် ဖုန်းက ထိုင်းစာကို တခြားဘာသာအသံနဲ့ ဖတ်မယ် — နားမလည်နိုင်ဘူး။\n\nဖြေရှင်းချက်: Settings → Language → Text-to-speech → ထိုင်း (ไทย) voice pack ကို download ဆွဲပါ။'),
                    actions: [
                      TextButton(
                          onPressed: () =>
                              Navigator.pop(context),
                          child: const Text('အိုကေ')),
                    ],
                  ),
                );
              }
            },
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Thai Helper v1.0'),
            subtitle: Text(
                'စကားစု ၅၀၀ • ထိုင်းရောက် မြန်မာလုပ်သားများအတွက်\nContent: thai-for-myanmar audit (PROVISIONAL)'),
          ),
        ],
      ),
    );
  }
}
