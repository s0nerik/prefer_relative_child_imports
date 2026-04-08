# prefer_relative_child_imports

Same as built-in [`prefer_relative_imports`](https://dart.dev/tools/linter-rules#prefer_relative_imports), but forces **relative** imports only when the path stays in the same folder or goes **deeper** (no `../`). If the target is “above” the current file, it forces a **`package:`** URI instead of a relative import.

## Setup

Add the plugin to `analysis_options.yaml` (and turn off `prefer_relative_imports`, `always_use_package_imports` if you used them):

```yaml
plugins:
  prefer_relative_child_imports: ^1.0.0

linter:
  rules:
    prefer_relative_imports: false
    always_use_package_imports: false
```
