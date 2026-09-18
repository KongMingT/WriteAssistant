import 'package:flutter/material.dart';

class UndoStack {
  final List<TextEditingValue> _stack = [];
  final List<TextEditingValue> _redoStack = [];
  final int _maxSize;
  String? _lastSnapshot;

  UndoStack({int maxSize = 200}) : _maxSize = maxSize;

  bool get canUndo => _stack.length >= 2;
  bool get canRedo => _redoStack.isNotEmpty;

  void push(TextEditingValue value) {
    final text = value.text;
    if (text == _lastSnapshot) return;
    _lastSnapshot = text;
    _stack.add(value);
    _redoStack.clear();
    if (_stack.length > _maxSize) {
      _stack.removeAt(0);
    }
  }

  TextEditingValue? undo(TextEditingValue current) {
    if (!canUndo) return null;
    _redoStack.add(current);
    _lastSnapshot = _stack.last.text;
    final value = _stack.removeLast();
    return value;
  }

  TextEditingValue? redo(TextEditingValue current) {
    if (!canRedo) return null;
    _stack.add(current);
    _lastSnapshot = current.text;
    return _redoStack.removeLast();
  }

  void clear() {
    _stack.clear();
    _redoStack.clear();
    _lastSnapshot = null;
  }
}
