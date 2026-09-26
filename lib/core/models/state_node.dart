import 'dart:ui';

/// Represents a state $q_i$ in the finite state automaton.
class StateNode {
  final String id;
  final String label;
  final Offset position;
  final bool isInitial;
  final bool isAccept;

  const StateNode({
    required this.id,
    required this.label,
    required this.position,
    this.isInitial = false,
    this.isAccept = false,
  });

  StateNode copyWith({
    String? id,
    String? label,
    Offset? position,
    bool? isInitial,
    bool? isAccept,
  }) {
    return StateNode(
      id: id ?? this.id,
      label: label ?? this.label,
      position: position ?? this.position,
      isInitial: isInitial ?? this.isInitial,
      isAccept: isAccept ?? this.isAccept,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'x': position.dx,
        'y': position.dy,
        'isInitial': isInitial,
        'isAccept': isAccept,
      };

  factory StateNode.fromJson(Map<String, dynamic> json) => StateNode(
        id: json['id'] as String,
        label: json['label'] as String,
        position: Offset(
          (json['x'] as num).toDouble(),
          (json['y'] as num).toDouble(),
        ),
        isInitial: json['isInitial'] as bool? ?? false,
        isAccept: json['isAccept'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StateNode &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          label == other.label &&
          position == other.position &&
          isInitial == other.isInitial &&
          isAccept == other.isAccept;

  @override
  int get hashCode => Object.hash(id, label, position, isInitial, isAccept);

  @override
  String toString() =>
      'StateNode(id: $id, label: $label, pos: (${position.dx.toStringAsFixed(1)}, ${position.dy.toStringAsFixed(1)}), init: $isInitial, accept: $isAccept)';
}
