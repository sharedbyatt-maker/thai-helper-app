import 'models.dart';

class PersonalRecord {
  final String id, name, note;
  final ExchangeQuote quote;
  final int budgetMinor, receivedMinor;
  final DateTime savedAt;
  final DateTime? completedAt;
  final bool completed;
  const PersonalRecord({
    required this.id,
    required this.name,
    required this.note,
    required this.quote,
    required this.budgetMinor,
    required this.receivedMinor,
    required this.savedAt,
    this.completed = false,
    this.completedAt,
  });
  factory PersonalRecord.fromJson(Map<String, dynamic> j) {
    final budget = j['budget_minor'], received = j['received_minor'];
    for (final pair in [('id', 100), ('name', 1000), ('note', 2000)]) {
      final value = j[pair.$1] ?? (pair.$1 == 'note' ? '' : null);
      if (value is! String ||
          value.length > pair.$2 ||
          (pair.$1 == 'id' && value.isEmpty)) {
        throw const FormatException('Invalid record text');
      }
    }
    if (budget is! int ||
        received is! int ||
        budget <= 0 ||
        received <= 0 ||
        budget > maxMoneyMinor ||
        received > maxMoneyMinor) {
      throw const FormatException('Invalid stored amounts');
    }
    return PersonalRecord(
      id: j['id'] as String,
      name: j['name'] as String,
      note: j['note'] as String? ?? '',
      quote: ExchangeQuote.fromJson(j['quote'] as Map<String, dynamic>),
      budgetMinor: budget,
      receivedMinor: received,
      savedAt: DateTime.parse(j['saved_at'] as String),
      completed: j['completed'] == true,
      completedAt: j['completed_at'] == null
          ? null
          : DateTime.parse(j['completed_at'] as String),
    );
  }
  PersonalRecord withCompleted(bool value, {DateTime? at}) => PersonalRecord(
    id: id,
    name: name,
    note: note,
    quote: quote,
    budgetMinor: budgetMinor,
    receivedMinor: receivedMinor,
    savedAt: savedAt,
    completed: value,
    completedAt: value ? at ?? DateTime.now() : null,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'note': note,
    'quote': quote.toJson(),
    'budget_minor': budgetMinor,
    'received_minor': receivedMinor,
    'saved_at': savedAt.toUtc().toIso8601String(),
    'completed': completed,
    if (completedAt != null)
      'completed_at': completedAt!.toUtc().toIso8601String(),
  };
}

