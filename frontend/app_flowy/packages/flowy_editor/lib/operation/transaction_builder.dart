import 'dart:collection';
import 'package:flowy_editor/editor_state.dart';
import 'package:flowy_editor/document/node.dart';
import 'package:flowy_editor/document/path.dart';
import 'package:flowy_editor/document/text_delta.dart';
import 'package:flowy_editor/document/attributes.dart';
import 'package:flowy_editor/document/selection.dart';

import './operation.dart';
import './transaction.dart';

///
/// This class is used to
/// build the transaction from the state.
///
/// This class automatically save the
/// cursor from the state.
///
/// When the transaction is undo, the
/// cursor can be restored.
///
class TransactionBuilder {
  final List<Operation> operations = [];
  EditorState state;
  Selection? cursorSelection;

  TransactionBuilder(this.state);

  /// Commit the operations to the state
  commit() {
    final transaction = _finish();
    state.apply(transaction);
  }

  insertNode(Path path, Node node) {
    cursorSelection = state.cursorSelection;
    add(InsertOperation(path: path, value: node));
  }

  updateNode(Node node, Attributes attributes) {
    cursorSelection = state.cursorSelection;
    add(UpdateOperation(
      path: node.path,
      attributes: Attributes.from(node.attributes)..addAll(attributes),
      oldAttributes: node.attributes,
    ));
  }

  deleteNode(Node node) {
    cursorSelection = state.cursorSelection;
    add(DeleteOperation(path: node.path, removedValue: node));
  }

  textEdit(TextNode node, Delta Function() f) {
    cursorSelection = state.cursorSelection;
    final path = node.path;

    final delta = f();

    final inverted = delta.invert(node.delta);

    add(TextEditOperation(path: path, delta: delta, inverted: inverted));
  }

  insertText(TextNode node, int index, String content) {
    textEdit(node, () => Delta().retain(index).insert(content));
  }

  formatText(TextNode node, int index, int length, Attributes attributes) {
    textEdit(node, () => Delta().retain(index).retain(length, attributes));
  }

  deleteText(TextNode node, int index, int length) {
    textEdit(node, () => Delta().retain(index).delete(length));
  }

  add(Operation op) {
    final Operation? last = operations.isEmpty ? null : operations.last;
    if (last != null) {
      if (op is TextEditOperation &&
          last is TextEditOperation &&
          pathEquals(op.path, last.path)) {
        final newOp = TextEditOperation(
          path: op.path,
          delta: last.delta.compose(op.delta),
          inverted: op.inverted.compose(last.inverted),
        );
        operations[operations.length - 1] = newOp;
        return;
      }
    }
    operations.add(op);
  }

  Transaction _finish() {
    return Transaction(
      operations: UnmodifiableListView(operations),
      cursorSelection: cursorSelection,
    );
  }
}