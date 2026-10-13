import 'package:flutter/material.dart';
import 'models.dart';
import 'services.dart';

const Map<String, String> categoryIcons = {
  'greetings': '👋',
  'emergency': '🚨',
  'hospital': '🏥',
  'police_immigration': '👮',
  'employer_work': '💼',
  'market_shopping': '🛒',
  'housing': '🏠',
  'transport': '🚌',
  'money': '💸',
  'phone_sim': '📱',
};

// ---------------- Home ----------------

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ထိုင်းအကူ • Thai Helper'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final cats = await loadCategories();
              if (context.mounted) {
                showSearch(
                    context: context,
                    delegate: PhraseSearchDelegate(cats));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.star_border),
            onPressed: () async {
              final cats = await loadCategories();
              if (context.mounted) {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            FavoritesScreen(categories: cats)));
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
      body: FutureBuilder<List<Category>>(
        future: loadCategories(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final cats = snap.data!;
          final all = cats.expand((c) => c.phrases).toList();
          final dayIndex = DateTime.now()
                  .difference(DateTime(DateTime.now().year, 1, 1))
                  .inDays %
              all.length;
          final daily = all[dayIndex];
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
                  childAspectRatio: 1.4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: cats.length,
                itemBuilder: (context, i) {
                  final c = cats[i];
                  return Card(
                    child: InkWell(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  PhraseListScreen(category: c))),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(categoryIcons[c.id] ?? '💬',
                                style:
                                    const TextStyle(fontSize: 32)),
                            const SizedBox(height: 4),
                            Text(c.my,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text('${c.phrases.length} စကားစု',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
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
                  subtitle: const Text('မကြာမီ လာမည်'),
                  onTap: () => ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(
                          content: Text('Phase 1B မှာ ပါမယ်'))),
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
        title: Text(p.th,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold)),
        subtitle: Text('${p.my} • ${p.phon}'),
        trailing: IconButton(
          icon: const Icon(Icons.volume_up, size: 32),
          onPressed: () =>
              TtsService().speak(p.displayTh(Prefs.isMale)),
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
  final Category category;
  const PhraseListScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(
              '${categoryIcons[category.id] ?? ''} ${category.my}')),
      body: ListView.separated(
        itemCount: category.phrases.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final p = category.phrases[i];
          return ListTile(
            title: Text(p.th,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600)),
            subtitle: Text('${p.my}\n${p.phon}'),
            isThreeLine: true,
            trailing: IconButton(
              icon: const Icon(Icons.volume_up),
              onPressed: () =>
                  TtsService().speak(p.displayTh(Prefs.isMale)),
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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(p.my,
                style:
                    const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 16),
            Text(p.displayTh(Prefs.isMale),
                style: const TextStyle(
                    fontSize: 34, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('🔊 ${p.phon}',
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
                  TtsService().speak(p.displayTh(Prefs.isMale)),
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
  final List<Category> categories;
  PhraseSearchDelegate(this.categories);

  List<Phrase> _all() =>
      categories.expand((c) => c.phrases).toList();

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
        : _all()
            .where((p) =>
                p.my.contains(q) ||
                p.th.contains(q) ||
                p.phon.contains(q))
            .toList();
    return ListView.builder(
      itemCount: hits.length,
      itemBuilder: (context, i) {
        final p = hits[i];
        return ListTile(
          title: Text(p.th),
          subtitle: Text('${p.my} • ${p.phon}'),
          trailing: IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: () =>
                TtsService().speak(p.displayTh(Prefs.isMale)),
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
  final List<Category> categories;
  const FavoritesScreen({super.key, required this.categories});

  @override
  Widget build(BuildContext context) {
    final favs = categories
        .expand((c) => c.phrases)
        .where((p) => Prefs.favorites.contains(p.id))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('⭐ ကြိုက်နှစ်သက်ရာ')),
      body: favs.isEmpty
          ? const Center(child: Text('မရှိသေးဘူး — ⭐ နှိပ်ပြီး သိမ်းပါ'))
          : ListView.separated(
              itemCount: favs.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1),
              itemBuilder: (context, i) {
                final p = favs[i];
                return ListTile(
                  title: Text(p.th,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600)),
                  subtitle: Text('${p.my} • ${p.phon}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.volume_up),
                    onPressed: () => TtsService()
                        .speak(p.displayTh(Prefs.isMale)),
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
                    title: Text(ok ? '✅ အဆင်ပြေတယ်' : '⚠️ အသံလိုနေတယ်'),
                    content: Text(ok
                        ? 'ထိုင်းအသံ အသင့်ဖြစ်နေပြီ။'
                        : 'Settings → Language → Text-to-speech မှာ ထိုင်း (ไทย) voice pack ကို download ဆွဲပါ။'),
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
                'ထိုင်းရောက် မြန်မာလုပ်သားများအတွက်\nထိုင်းစာသားများ native speaker စစ်ဆေးဆဲ (beta)'),
          ),
        ],
      ),
    );
  }
}
