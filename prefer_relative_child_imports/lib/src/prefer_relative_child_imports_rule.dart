import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import 'prefer_relative_child_imports_logic.dart';

/// Same conditions as the built-in `prefer_relative_imports` lint, but only
/// suggests a relative URI when the canonical path from the importing file to
/// the imported library contains no `..` segments (so a fix would never use `../`).
///
/// Also reports relative imports whose URI still contains `../` even though a
/// canonical relative path without parent segments exists, and relative imports
/// whose canonical path requires `../` (those should use a `package:` URI instead).
class PreferRelativeChildImportsRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'prefer_relative_child_imports',
    'Prefer relative imports for files in `lib/` when they stay within or below '
        "the importing file's directory (no `../` in the relative path); "
        'otherwise prefer a `package:` URI instead of a relative URI that uses `../`.',
    correctionMessage:
        'Replace the import URI with the canonical relative path without `../`, '
        'or with the `package:` URI for the same library when a relative path must '
        'use `../`.',
    severity: DiagnosticSeverity.WARNING,
  );

  PreferRelativeChildImportsRule()
    : super(
        name: 'prefer_relative_child_imports',
        description:
            'Like prefer_relative_imports, but never for imports that would '
            "require a relative URI containing `../`.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  List<String> get incompatibleRules => const [
    'always_use_package_imports',
    'prefer_relative_imports',
  ];

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    var visitor = _Visitor(this, context);
    registry.addImportDirective(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final PreferRelativeChildImportsRule rule;
  final RuleContext context;

  _Visitor(this.rule, this.context);

  bool shouldReport(ImportDirective node) {
    final unit = context.currentUnit;
    if (unit == null || !context.isInLibDir) return false;

    final package = context.package;
    if (package == null) return false;

    return computePreferredRelativeChildImportUri(
          importingUnitPath: unit.file.path,
          sourceLibrary: context.libraryElement,
          node: node,
          packageRoot: package.root.path,
        ) !=
        null;
  }

  @override
  void visitImportDirective(ImportDirective node) {
    if (shouldReport(node)) {
      rule.reportAtNode(node.uri);
    }
  }
}
