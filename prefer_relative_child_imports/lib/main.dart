import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/prefer_relative_child_imports_rule.dart';
import 'src/replace_with_child_relative_import_fix.dart';

final plugin = PreferRelativeChildImportsPlugin();

class PreferRelativeChildImportsPlugin extends Plugin {
  @override
  String get name => 'prefer_relative_child_imports';

  @override
  void register(PluginRegistry registry) {
    registry.registerWarningRule(PreferRelativeChildImportsRule());
    registry.registerFixForRule(
      PreferRelativeChildImportsRule.code,
      ReplaceWithChildRelativeImportFix.new,
    );
  }
}
