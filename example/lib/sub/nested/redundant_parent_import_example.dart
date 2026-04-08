// ignore_for_file: unused_import

// Relative import whose URI still contains `../` even though the canonical
// relative path has no parent segments (`sibling_target.dart` in this folder).
import '../../sub/nested/sibling_target.dart'; // ❌ BAD — prefer `sibling_target.dart`
