import 'dart:convert';
import 'dart:io';
import '../models/automaton.dart';

class SavedMachine {
  final String id;
  final String name;
  final DateTime updatedAt;
  final Automaton automaton;
  final String defaultInput;

  SavedMachine({
    required this.id,
    required this.name,
    required this.updatedAt,
    required this.automaton,
    this.defaultInput = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'updatedAt': updatedAt.toIso8601String(),
        'defaultInput': defaultInput,
        'automaton': automaton.toJson(),
      };

  factory SavedMachine.fromJson(Map<String, dynamic> json) => SavedMachine(
        id: json['id'] as String,
        name: json['name'] as String,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        defaultInput: json['defaultInput'] as String? ?? '',
        automaton: Automaton.fromJson(json['automaton'] as Map<String, dynamic>),
      );
}

class MachineStorage {
  static File? _getFile() {
    try {
      final home = Platform.environment['HOME'];
      if (home == null) return null;
      final dir = Directory('$home/.config/infinite_state');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return File('${dir.path}/machines.json');
    } catch (_) {
      return null;
    }
  }

  static List<SavedMachine> loadAll() {
    try {
      final file = _getFile();
      if (file == null || !file.existsSync()) return [];
      final text = file.readAsStringSync();
      if (text.trim().isEmpty) return [];
      final list = jsonDecode(text) as List;
      return list
          .map((item) => SavedMachine.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static void saveAll(List<SavedMachine> machines) {
    try {
      final file = _getFile();
      if (file == null) return;
      final data = jsonEncode(machines.map((m) => m.toJson()).toList());
      file.writeAsStringSync(data);
    } catch (_) {}
  }

  static void saveMachine(SavedMachine machine) {
    final all = loadAll();
    final index = all.indexWhere((m) => m.id == machine.id);
    if (index >= 0) {
      all[index] = machine;
    } else {
      all.insert(0, machine);
    }
    saveAll(all);
  }

  static void deleteMachine(String id) {
    final all = loadAll()..removeWhere((m) => m.id == id);
    saveAll(all);
  }
}
