# Sharing an image to Instagram Stories (iOS)

Research for issue #4. Sources checked 2026-10-28.

## Question

What does it take to share Paceline's rendered 1080×1920 story card straight to Instagram Stories from an iOS 17+ SwiftUI app, and what is the fallback?

## Short answer

- Instagram Stories direct share uses the `instagram-stories://share?source_application=<FacebookAppID>` URL scheme. The image goes on the **general pasteboard** under `com.instagram.sharedSticker.backgroundImage`. [M1]
- **A Facebook (Meta) App ID is mandatory.** It has been required since January 2023. Without one, Instagram shows "The app you shared from doesn't currently support sharing to Stories." [M1][M2] You need a registered app on developers.facebook.com, but the Facebook SDK does not have to be bundled: the ID is just a string in the URL.
- Our 1080×1920 (9:16) card fits the **background image** layer exactly. A background image must be at least 720×1280 and Meta recommends a 9:16 or 9:18 ratio. [M1]
- Add `instagram-stories` to `LSApplicationQueriesSchemes` in Info.plist if you use `canOpenURL(_:)`. Note that `canOpenURL(_:)` is **deprecated as of iOS 27** in favor of "attempting to open URLs and handling any failures". [A1]
- Fallback: the system share sheet (`ShareLink` on iOS 16+, or `UIActivityViewController`). It works without any Meta setup or Info.plist entries. [A3][A4]

## Details

### 1. The direct `instagram-stories://` flow (Meta)

From Meta's "Sharing to Stories" page [M1]:

- **URL:** `instagram-stories://share?source_application=%@`, where `%@` is your Facebook App ID.
- **Pasteboard keys** (one item dictionary passed to `UIPasteboard.general.setItems(_:options:)`):
  - `com.instagram.sharedSticker.backgroundImage`: `NSData` (JPG/PNG)
  - `com.instagram.sharedSticker.stickerImage`: `NSData` (JPG/PNG, recommended size 640×480)
  - `com.instagram.sharedSticker.backgroundTopColor` / `backgroundBottomColor`: hex `NSString`s, used when there is no background asset
  - A background **video** asset is also supported (H.264/H.265/WebM, 1080p, ≤20 s, under 50 MB recommended). The docs table lists it but the iOS samples don't name its pasteboard key, so it isn't relevant to us.
  - You must send a background asset, a sticker asset, or both.
- **Expiration:** Meta's sample sets `UIPasteboardOptionExpirationDate` to now + 5 minutes. The page says "This call is iOS 10+".
- **Info.plist:** "Add `instagram-stories` to the `LSApplicationQueriesSchemes` key in your app's `Info.plist`."
- **Not installed:** the sample checks `canOpenURL:` and leaves the else branch as `// Handle error cases`. Meta specifies no fallback, so the app has to provide one.
- Meta publishes Objective-C samples only, with no Swift sample. The page shows no last-updated date. The App ID warning on it reads "Beginning in January 2023…".

**App ID history** [M2] (Meta blog, 2022-10-10): a Facebook App ID linked to a registered Facebook app became a required field. Developers had until 2022-11-30, after which users of non-compliant apps lost the ability to share to Stories. An existing App ID can be reused. The post doesn't say whether App Review or Live mode is needed, and I found no primary source saying so. Stories sharing isn't a Graph API permission, so presumably no review is needed, but **verify on a device with a Development-mode app**.

Swift equivalent (derived from [M1]'s Objective-C, not from Meta):

```swift
func shareToInstagramStories(png: Data, appID: String) async -> Bool {
    guard let url = URL(string: "instagram-stories://share?source_application=\(appID)") else { return false }
    UIPasteboard.general.setItems(
        [["com.instagram.sharedSticker.backgroundImage": png]],
        options: [.expirationDate: Date().addingTimeInterval(5 * 60)]
    )
    return await UIApplication.shared.open(url)   // false => Instagram not installed → fall back
}
```

### 2. Background vs sticker for our card

- Our card is a finished 1080×1920 composition with photo, route and metrics, so it belongs in the **background image** layer. 9:16 and above the 720×1280 minimum are both what Meta recommends. [M1]
- The **sticker** layer is for a small movable overlay (recommended 640×480) on top of a background or color gradient. [M1] A possible later variant: send only the route and metrics as a transparent PNG sticker so the user can place it over their own photo. That isn't needed for v1.
- Use PNG to keep the route line and text crisp. JPG is an option if pasteboard size becomes an issue. Meta states no size limit for images.

### 3. Detecting Instagram / `LSApplicationQueriesSchemes` (Apple)

From Apple's `canOpenURL(_:)` documentation [A1]:

- Apps linked on iOS 9+ must declare schemes in `LSApplicationQueriesSchemes`. Otherwise `canOpenURL` always returns `false`.
- The key is capped at 50 entries (iOS 15+ SDK) and 25 entries (iOS 27+ SDK). One entry is fine for us.
- `open(_:options:completionHandler:)` **does not** need the scheme declared. If no app handles the URL, the completion reports `false`.
- **`canOpenURL(_:)` is deprecated in iOS 27.0**, with the message "Prefer attempting to open URLs and handling any failures".

So we can skip `canOpenURL` and the Info.plist entry. Call `open(url)` and fall back to the share sheet when it returns `false`. The catch: we'd write to the pasteboard before knowing that Instagram is installed. That's harmless because the item expires after 5 minutes, but it's a small wart. If we want to show or hide an "Instagram Stories" button up front, we still need `canOpenURL` plus the plist entry. That works while targeting iOS 17 but gives deprecation warnings when building with the iOS 27 SDK.

### 4. Standard share sheet (`ShareLink` / `UIActivityViewController`)

- `ShareLink` (SwiftUI, iOS 16+) shares any `Transferable`. `Image` and `URL` work, and Apple suggests adding a `FileRepresentation` if a share target doesn't show up. It takes a `SharePreview`. [A3]
- `UIActivityViewController` (iOS 6+) is the UIKit equivalent. On iPhone it must be presented modally. [A4]
- Neither needs an App ID or Info.plist entries. Instagram appears only if the user has it installed and enabled as a share extension.
- **Unverified (no primary source):** Instagram's share extension lets the user choose Feed, Story or Messages. It may crop or letterbox the image instead of placing it as a full-bleed Story background. Check on a device.

## Comparison

| | `instagram-stories://` | Share sheet |
|---|---|---|
| Lands directly in Stories composer | Yes | No, the user picks Instagram and then Story (unverified UX) |
| Meta App ID / developer account | Required | Not needed |
| Info.plist | `LSApplicationQueriesSchemes` only if using `canOpenURL` | None |
| Works without Instagram | No | Yes (Photos, Messages, other apps) |
| Background + sticker layers | Yes | No, flat image only |
| Risk | Meta can change or gate it (it did in 2022) | Stable Apple API |

## Recommendation

Offer two actions on the share screen:

1. **Primary: "Share to Instagram Stories."** Render the card as a 1080×1920 PNG, put it on the pasteboard as `backgroundImage`, and open `instagram-stories://share?source_application=<AppID>`. This requires registering a free Meta developer app to get an App ID (no Facebook SDK) and putting the ID in build config. If `open` returns `false`, fall back to the share sheet. Prefer the open-and-handle-failure pattern over `canOpenURL` given the iOS 27 deprecation. Add the `LSApplicationQueriesSchemes` entry only if we decide to hide the button when Instagram isn't installed.
2. **Always available: `ShareLink`** with the PNG as a `Transferable` file representation. This covers Save to Photos, Messages, and other apps, and is the fallback when Instagram isn't installed.

Before relying on (1), do a quick on-device check that a Development-mode Meta app ID is accepted, since no primary source confirms it either way.

## Sources

- [M1] Meta for Developers, "Sharing to Stories", Instagram Platform. https://developers.facebook.com/docs/instagram-platform/sharing-to-stories/ (markdown: https://developers.facebook.com/documentation/instagram-platform/sharing-to-stories.md). Accessed 2026-10-28; no last-updated date on the page.
- [M2] Meta for Developers blog, "Introducing an important update to Instagram Sharing to Stories", 2022-10-10. https://developers.facebook.com/blog/post/2022/10/10/introducing-important-update-to-Instagram-sharing-to-stories/
- [A1] Apple Developer Documentation, `UIApplication.canOpenURL(_:)`. https://developer.apple.com/documentation/uikit/uiapplication/canopenurl(_:). Accessed 2026-10-28; shows deprecation in iOS 27.0.
- [A2] Apple Developer Documentation, `LSApplicationQueriesSchemes`. https://developer.apple.com/documentation/bundleresources/information-property-list/lsapplicationqueriesschemes (limits quoted via [A1]).
- [A3] Apple Developer Documentation, `ShareLink` (iOS 16.0+). https://developer.apple.com/documentation/swiftui/sharelink
- [A4] Apple Developer Documentation, `UIActivityViewController` (iOS 6.0+). https://developer.apple.com/documentation/uikit/uiactivityviewcontroller
