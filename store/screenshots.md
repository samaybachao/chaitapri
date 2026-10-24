# Screenshots

Play needs **at least 2 phone screenshots** (JPEG or 24-bit PNG, 16:9 or 9:16, each side 320-3840 px).
Real screenshots from your own phone or emulator are best. They cannot be made without running
the game, so take them after your first `flutter run`.

## How to take them
1. Run a release-like build: `flutter run --release --dart-define-from-file=env/test.json`.
2. Press the power + volume-down buttons (or use the emulator's camera button).
3. Take these 5 shots in this order (they tell the story of the game):
   1. **Start**: the stall with the first customers and the "Tap the stall" tip.
   2. **Upgrades**: the Upgrades tab with a few levels bought and the "Bottleneck" tag visible.
   3. **Menu**: the Menu tab with Masala chai unlocked.
   4. **Welcome back**: the "Welcome back!" popup with coins (close the game for 10 minutes with a helper bought, then open it).
   5. **Daily**: the Daily reward calendar.
4. Take the same 5 shots with the language set to Hindi for the Hindi listing (optional).

## Tips
- Use a phone with a normal 9:16 / 9:19.5 screen; do not crop away the status bar.
- No other apps' notifications in the status bar.
- Use `ADS_MODE` test builds only for screenshots (test ad labels never appear in them, ads are full-screen).
- Play shows the first 3-4 images most; put the best two first.
