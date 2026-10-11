# Build 11 verification (October 11, 2026, on the founder's Mac)

- Xcode 27.0 (27A266a): Release and Debug both compile for Any iOS Device with no errors.
  `Lull 1.0 (11)` archived successfully.
- All 16 `Tools/verify_*.py` pass. One log per verifier is in this folder.
- Fix: `App/Toys/Wash/WashModel.swift` now imports CoreGraphics. `verify_wash` builds the
  file with macOS `swiftc`, and there `import Foundation` alone doesn't provide
  `CGRect(x:y:width:height:)` (used by `WashBayFit.frame`). This doesn't affect the iOS app.
- `verify_mixup_stack` and `verify_sound_kit` need Pillow and NumPy, which the Mac's
  python3 doesn't have. They were run from a throwaway virtual environment
  (`python3 -m venv … && pip install pillow numpy`).
