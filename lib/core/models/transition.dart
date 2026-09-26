/// Represents a directed transition edge between states in an automaton.
class Transition {
  /// The canonical symbol used to denote an epsilon (spontaneous) transition.
  static const String epsilon = 'ε';

  final String id;
  final String fromId;
  final String toId;
  final Set<String> symbols;

  Transition({
    required this.id,
    required this.fromId,
    required this.toId,
    required Set<String> symbols,
  }) : symbols = Set.unmodifiable(symbols);

  bool get isSelfLoop => fromId == toId;
  bool get hasEpsilon => symbols.contains(epsilon);

  Transition copyWith({
    String? id,
    String? fromId,
    String? toId,
    Set<String>? symbols,
  }) {
    return Transition(
      id: id ?? this.id,
      fromId: fromId ?? this.fromId,
      toId: toId ?? this.toId,
      symbols: symbols ?? this.symbols,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromId': fromId,
        'toId': toId,
        'symbols': symbols.toList(),
      };

  factory Transition.fromJson(Map<String, dynamic> json) => Transition(
        id: json['id'] as String,
        fromId: json['fromId'] as String,
        toId: json['toId'] as String,
        symbols: Set<String>.from(json['symbols'] as List),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Transition &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          fromId == other.fromId &&
          toId == other.toId &&
          symbols.length == other.symbols.length &&
          symbols.containsAll(other.symbols);

  @override
  int get hashCode => Object.hash(id, fromId, toId, Object.hashAll(symbols));

  @override
  String toString() =>
      'Transition($fromId -> $toId on [${symbols.join(", ")}])';
}
