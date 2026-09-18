# Solmere localization workflow

Chinese is the source language and the default locale. English is loaded at
runtime by `LocalizationSystem`; the selected locale is persisted through the
existing settings file.

## Adding or changing player-facing text

1. Keep authored source text in Chinese. Do not replace save-data values or
   gameplay identifiers with translated strings.
2. Static `Control.text` values are translated by Godot. For text assembled at
   runtime, pass the completed source string (or each authored component) to
   `LocalizationSystem.text(...)` at the display boundary.
3. Rebuild and validate the catalog:

   ```sh
   python3 tools/localization/extract_strings.py
   python3 tools/localization/validate_catalog.py
   ```

4. Add editorial corrections and stable game terminology to
   `localization/en_overrides.json`. Overrides always win over the generated
   catalog and are the preferred place for proofreading changes.

On macOS, `tools/localization/translate_with_apple.swift` can fill missing
English entries with the on-device Translation framework. It preserves format
placeholders and writes progress after each batch. Run validation afterward;
shipping catalogs must have zero missing strings, zero Chinese remnants, and
zero placeholder mismatches.

## Regression checks

```sh
godot --headless --path . --script tests/integration/test_localization.gd -- --isolated-save
godot --headless --path . --script tests/integration/test_localization_ui.gd -- --isolated-save
godot --headless --path . --script tests/integration/test_localization_script_loads.gd -- --isolated-save
```
