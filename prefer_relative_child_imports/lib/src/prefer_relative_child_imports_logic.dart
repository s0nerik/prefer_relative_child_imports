import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:path/path.dart' as p;

/// Same package check as the built-in prefer_relative_imports logic.
bool isSamePackage(Uri a, Uri b) {
  return a.isScheme('package') &&
      b.isScheme('package') &&
      a.pathSegments.isNotEmpty &&
      b.pathSegments.isNotEmpty &&
      a.pathSegments.first == b.pathSegments.first;
}

bool relativeUriHasParentSegment(String uri) {
  return p.posix
      .split(p.posix.normalize(uri.replaceAll(r'\', '/')))
      .any((segment) => segment == '..');
}

/// Directory containing [pubspec.yaml] that owns [filePath], or `null`.
String? findPackageRootContaining(ResourceProvider provider, String filePath) {
  var dir = p.dirname(filePath);
  while (true) {
    final pubspec = provider.getFile(p.join(dir, 'pubspec.yaml'));
    if (pubspec.exists) return dir;
    final parent = p.dirname(dir);
    if (parent == dir) return null;
    dir = parent;
  }
}

/// Canonical relative import URI (posix, `/`) from [importingFile] to [importedFile].
String canonicalRelativeChildImportUri(
  String importedFile,
  String importingFile,
) {
  final currentDir = p.dirname(importingFile);
  final rel = p.relative(importedFile, from: currentDir);
  return p.posix.normalize(rel.replaceAll(r'\', '/'));
}

/// When non-null, the import should use this URI instead of [node]'s current URI
/// (either a canonical relative path without `../`, or a `package:` URI when the
/// relative path would require `../`).
///
/// [packageRoot] is the package directory (folder that contains `pubspec.yaml`).
/// Pass [resourceProvider] with [importingUnitPath] when [packageRoot] is unknown
/// (e.g. in a quick-fix producer).
String? computePreferredRelativeChildImportUri({
  required String importingUnitPath,
  required LibraryElement? sourceLibrary,
  required ImportDirective node,
  String? packageRoot,
  ResourceProvider? resourceProvider,
}) {
  packageRoot ??= resourceProvider != null
      ? findPackageRootContaining(resourceProvider, importingUnitPath)
      : null;
  if (packageRoot == null || sourceLibrary == null) return null;

  final libDir = p.join(packageRoot, 'lib');
  if (!p.isWithin(libDir, importingUnitPath)) return null;

  final libraryImport = node.libraryImport;
  if (libraryImport == null) return null;
  final importedLibrary = libraryImport.importedLibrary;
  if (importedLibrary == null) return null;

  if (!isSamePackage(sourceLibrary.uri, importedLibrary.uri)) return null;

  final importedPath = importedLibrary.firstFragment.source.fullName;
  if (!p.isWithin(libDir, importedPath)) return null;

  final canonical = canonicalRelativeChildImportUri(
    importedPath,
    importingUnitPath,
  );
  final uriLiteral = node.uri.stringValue;
  if (uriLiteral == null) return null;

  if (uriLiteral.startsWith('package:')) {
    if (relativeUriHasParentSegment(canonical)) return null;
    return canonical;
  }

  if (uriLiteral.startsWith('dart:')) return null;

  // Canonical path steps into a parent directory — use a `package:` URI instead
  // of a relative URI that contains `../`.
  if (relativeUriHasParentSegment(canonical)) {
    final importedUri = importedLibrary.uri;
    if (importedUri.scheme != 'package') return null;
    final preferred = importedUri.toString();
    if (uriLiteral == preferred) return null;
    if (uriLiteral.startsWith('package:')) return null;
    return preferred;
  }

  // Redundant `../` (or other non-canonical) relative URI while a child path exists.
  if (!relativeUriHasParentSegment(uriLiteral)) return null;
  if (p.posix.normalize(uriLiteral.replaceAll(r'\', '/')) == canonical)
    return null;
  return canonical;
}
