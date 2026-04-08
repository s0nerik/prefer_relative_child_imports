import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

import 'prefer_relative_child_imports_logic.dart';

/// Replaces a `package:` self-import or an over-parented relative URI with the
/// canonical relative URI (no `../` when the target is under or beside the file),
/// or replaces a relative URI that requires `../` with the `package:` URI.
class ReplaceWithChildRelativeImportFix extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'prefer_relative_child_imports.apply_preferred_import',
    DartFixKindPriority.standard,
    '{0}',
  );

  ReplaceWithChildRelativeImportFix({required super.context});

  /// Shown as the quick-fix title after `compute` (see [fixArguments]).
  String? _fixMessage;

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.acrossSingleFile;

  @override
  FixKind get fixKind => _kind;

  @override
  List<String>? get fixArguments =>
      _fixMessage != null ? <String>[_fixMessage!] : null;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    _fixMessage = null;
    final importNode = node.thisOrAncestorOfType<ImportDirective>();
    if (importNode == null) return;

    final replacement = computePreferredRelativeChildImportUri(
      importingUnitPath: unitResult.path,
      sourceLibrary: libraryElement2,
      node: importNode,
      resourceProvider: resourceProvider,
    );
    if (replacement == null) return;

    if (replacement.startsWith('package:')) {
      _fixMessage = 'Replace with a package import';
    } else {
      _fixMessage = 'Replace with a relative import';
    }

    final uriNode = importNode.uri;
    final existing = utils.getRangeText(range.node(uriNode));
    final quoted = _quotedImportUri(replacement, existing);

    await builder.addDartFileEdit(file, (dartBuilder) {
      dartBuilder.addSimpleReplacement(range.node(uriNode), quoted);
    });
  }
}

String _quotedImportUri(String uri, String existingLiteral) {
  if (existingLiteral.isEmpty) return "'$uri'";
  final quote = existingLiteral[0];
  if (quote != "'" && quote != '"') return "'$uri'";
  final escaped = _escapeDartStringContent(uri, quote);
  return '$quote$escaped$quote';
}

String _escapeDartStringContent(String value, String delimiter) {
  final b = StringBuffer();
  for (var i = 0; i < value.length; i++) {
    final c = value[i];
    if (c == r'\') {
      b.write(r'\\');
    } else if (c == r'$') {
      b.write(r'\$');
    } else if (c == delimiter) {
      b.write(r'\');
      b.write(c);
    } else {
      b.write(c);
    }
  }
  return b.toString();
}
