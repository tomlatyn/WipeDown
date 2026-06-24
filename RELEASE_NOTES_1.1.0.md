# WipeDown 1.1.0

## What's New

- Added an optional keyboard lock toggle, so WipeDown can dim/cover the screen without intercepting keyboard input when needed.
- Added keyboard backlight controls for supported Macs, including configurable brightness during cleaning mode.
- Added preview/test overlays for screen dimming, keyboard blocking, and keyboard backlight behavior.
- Added Touch Bar locking while cleaning mode is active.

## Fixed

- Fixed FN row / top-row keys continuing to work while keyboard lock is enabled.
- Improved keyboard interception so system and media keys are blocked more reliably during cleaning mode.
- Improved left/right Shift tracking for unlock shortcuts.

## Improvements

- Reworked the lock manager into clearer sections for lock lifecycle, keyboard interception, timers, overlays, Touch Bar control, and tests.
- Added display brightness and keyboard brightness service controllers.
- Refined lock settings UI text, localization, spacing, and preview controls.
- Added project AI rules for future maintenance consistency.
