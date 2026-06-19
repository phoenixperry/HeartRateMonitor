# Adding Space Grotesk + DM Sans to the app

The new design system in `Theme.swift` references custom fonts via PostScript names:

- `SpaceGrotesk-Regular`
- `SpaceGrotesk-Medium`
- `SpaceGrotesk-Bold`
- `DMSans-Regular`
- `DMSans-Medium`
- `DMSans-Bold`

If these aren't registered with the app bundle, SwiftUI silently falls back to San Francisco. Nothing breaks — it just looks like system. Here's how to register them properly.

## 1. Download the fonts

Both are free on Google Fonts:

- https://fonts.google.com/specimen/Space+Grotesk
- https://fonts.google.com/specimen/DM+Sans

Click **Get font → Download all** for each. You'll get two ZIP files. Unzip them.

You'll find subfolders called `static/` inside each. The `.ttf` files we need are in there. The exact filenames you want (move all of these into a single working folder so you can drag them into Xcode in one go):

```
SpaceGrotesk-Regular.ttf
SpaceGrotesk-Medium.ttf
SpaceGrotesk-Bold.ttf
DMSans-Regular.ttf
DMSans-Medium.ttf
DMSans-Bold.ttf
```

(You can include more weights if you want — Light, SemiBold, etc. — and add them to the registration step below.)

## 2. Add a Fonts group to the Xcode project

1. In Xcode, open `HeartRateMonitor.xcodeproj`.
2. Right-click the **HeartRateMonitor** folder in the project navigator → **New Group** → name it `Fonts`.
3. Drag the six `.ttf` files into the new `Fonts` group.
4. In the dialog that appears:
   - ✅ "Copy items if needed"
   - ✅ "Create groups"
   - ✅ Add to target: **HeartRateMonitor**
5. Confirm. The files should now show under the `Fonts` group with the small red `T` icon.

## 3. Register the fonts in `info.plist`

Open `HeartRateMonitor/info.plist`. Add a new key:

- **Key**: `Application fonts resource path` (raw key `ATSApplicationFontsPath`)
- **Type**: String
- **Value**: `.`

This tells the app to look inside the app bundle itself for font files. (`Fonts/` would also work if you'd rather scope it.)

If you'd prefer the more explicit per-file approach (works on iOS too):

- **Key**: `Fonts provided by application` (raw key `ATSApplicationFontsPath` on macOS; `UIAppFonts` on iOS)
- **Type**: Array
- **Items** (one String per file):
  ```
  SpaceGrotesk-Regular.ttf
  SpaceGrotesk-Medium.ttf
  SpaceGrotesk-Bold.ttf
  DMSans-Regular.ttf
  DMSans-Medium.ttf
  DMSans-Bold.ttf
  ```

For this macOS app, the `ATSApplicationFontsPath = "."` form is simplest. Just one entry.

## 4. Verify

Build & run. You should see Space Grotesk on the big numerics ("Resonance", BPM number, sync %) and DM Sans on labels/buttons.

If anything still looks like San Francisco, run this once in your app delegate to dump every font your bundle has registered:

```swift
import AppKit
for family in NSFontManager.shared.availableFontFamilies.sorted() {
    print(family, NSFontManager.shared.availableMembers(ofFontFamily: family) ?? [])
}
```

Look for "Space Grotesk" and "DM Sans" in the list. If they're missing, the bundle didn't pick them up — most often because the `info.plist` key isn't set or the target membership got missed when dragging in. Re-check step 2 and step 3.

## 5. Adjust weight names if your font files differ

Some Google Fonts downloads use slightly different PostScript names than the filename. If you want to be exact, you can inspect a `.ttf` with **Font Book.app** (open the file → click ⓘ → "PostScript name") and update the constants in `Theme.swift`:

```swift
enum Typeface {
    static let displayRegular = "SpaceGrotesk-Regular"   // ← swap if needed
    static let displayMedium  = "SpaceGrotesk-Medium"
    static let displayBold    = "SpaceGrotesk-Bold"
    static let sansRegular    = "DMSans-Regular"
    static let sansMedium     = "DMSans-Medium"
    static let sansBold       = "DMSans-Bold"
}
```

That's it. Once the fonts are in, every screen pulls them through the helpers in `Theme.swift` automatically.
