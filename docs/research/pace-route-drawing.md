# Drawing a pace-colored Route on a map and over a photo

Research for issue #3. Target: SwiftUI, iOS 17+, iPhone only.

**Question:** How do we draw a Route as a pace-colored line (green `#4AE27A` → yellow `#FFE055` → red `#FF4D4D`, colored per segment, round caps, ~18% white halo, red start dot, green end dot) both on a dark map (the live screen) and over a user photo (the Summary/share card)?

Sources are Apple's developer documentation, read through its JSON endpoints (`developer.apple.com/tutorials/data/documentation/...`), and the WWDC23 session 10043 transcript. Claims marked **(inference)** are my reasoning from those docs and are not stated by Apple.

---

## 1. What SwiftUI `Map` can draw (iOS 17)

- MapKit for SwiftUI's overlay and annotation content types are `Annotation`, `MapCircle`, `MapPolygon`, `MapPolyline`, `Marker` and `UserAnnotation`. You compose them inside `Map { ... }` using `MapContentBuilder`. [MapKit for SwiftUI](https://developer.apple.com/documentation/mapkit/mapkit-for-swiftui), [MapContentBuilder](https://developer.apple.com/documentation/mapkit/mapcontentbuilder)
- `MapPolyline` (iOS 17.0+) is "an open polygon overlay consisting of one or more connected line segments." You can create it from `MKPolyline`, from `MKRoute`, or with `init(coordinates:contourStyle:)` (`.straight` by default, or `.geodesic`). [MapPolyline](https://developer.apple.com/documentation/mapkit/mappolyline), [init(coordinates:contourStyle:)](https://developer.apple.com/documentation/mapkit/mappolyline/init(coordinates:contourstyle:))
- Its styling modifiers are `stroke(_:lineWidth:)`, `stroke(_:style:)`, `stroke(lineWidth:)` and `strokeStyle(style:)`. The style parameter accepts **any `ShapeStyle`** (so a color or a gradient), and you can pass a SwiftUI `StrokeStyle`, which includes `lineCap: .round` and `lineJoin: .round`. [stroke(_:style:)](https://developer.apple.com/documentation/mapkit/mapcontent/stroke(_:style:)), [stroke(_:lineWidth:)](https://developer.apple.com/documentation/mapkit/mapcontent/stroke(_:linewidth:))
- `mapOverlayLevel(level:)` places overlays relative to the map's labels (`.aboveRoads` or `.aboveLabels`). [mapOverlayLevel(level:)](https://developer.apple.com/documentation/mapkit/mapcontent/mapoverlaylevel(level:)), WWDC23 10043
- WWDC23 "Meet MapKit for SwiftUI" says: "You can also use MapPolyline to show your own location data. You can use StrokeStyle to deliver some pretty fancy stuff, such as dashes and a gradient." [WWDC23 10043](https://developer.apple.com/videos/play/wwdc2023/10043/)

### Can a `MapPolyline` gradient follow pace along the line?

**No. You can't map an arbitrary color to each point along one `MapPolyline`.**

- The `ShapeStyle` you pass is a SwiftUI gradient such as `LinearGradient`, `RadialGradient` or `AngularGradient`. These gradients are positioned geometrically, by start and end points in the shape's bounds. They are not positioned by distance along the path. Apple's MapKit docs do not describe any "along the line" semantics for `MapPolyline` strokes. **(inference)** A `LinearGradient` on a Route that loops back on itself therefore colors by screen position, not by where the runner was in the Run. That is the wrong result for pace.
- The only Apple API that documents a gradient laid **along the line's distance** is `MKGradientPolylineRenderer` (iOS 14+). Its `setColors(_:locations:)` method pairs colors with "unit distance values". In those values, `0` is the start of the polyline, `1` is the end, and "a gradient may have any number of steps along the length of the polyline." [MKGradientPolylineRenderer](https://developer.apple.com/documentation/mapkit/mkgradientpolylinerenderer), [setColors(_:locations:)](https://developer.apple.com/documentation/mapkit/mkgradientpolylinerenderer/setcolors(_:locations:)-3xrou)
- `MKGradientPolylineRenderer` is an `MKOverlayRenderer`. It is vended by `MKMapViewDelegate.mapView(_:rendererFor:)`, so it only works with UIKit's `MKMapView`. SwiftUI `Map` has no API for supplying an overlay renderer: it only offers the content types listed above. Using it means wrapping `MKMapView` in `UIViewRepresentable`. [mapView(_:rendererFor:)](https://developer.apple.com/documentation/mapkit/mkmapviewdelegate/mapview(_:rendererfor:))

### Options for the live screen

| Option | Per-segment pace color | Pure SwiftUI | Notes |
|---|---|---|---|
| A. One `MapPolyline` with a `LinearGradient` | No: the gradient is spatial, not along the path | Yes | Not suitable |
| B. **Many short `MapPolyline`s**, one per pace bucket run, each `.stroke(color, style: StrokeStyle(lineWidth:, lineCap: .round, lineJoin: .round))` | Yes (hard color steps) | Yes | Simple. Round caps hide the joins between pieces. **(inference)** Overlay count should be kept down by merging consecutive samples in the same color bucket, rather than drawing one overlay per GPS fix. |
| C. `MKMapView` + `MKGradientPolylineRenderer` via `UIViewRepresentable` | Yes (smooth, distance-based) | No | The only first-party smooth gradient along the path. `lineCap` on `MKOverlayPathRenderer` already defaults to `.round`. [lineCap](https://developer.apple.com/documentation/mapkit/mkoverlaypathrenderer/linecap) |
| D. SwiftUI `Canvas` over the `Map`, projecting with `MapReader`/`MapProxy.convert(_:to:)` | Yes | Yes | `convert(_:to:)` returns a `CGPoint?` for a coordinate. [MapProxy.convert(_:to:)](https://developer.apple.com/documentation/mapkit/mapproxy/convert(_:to:)) **(inference)** You would have to redraw on every camera change (`onMapCameraChange`). The line would lag behind the map during pan and zoom. Not worth it. |

**Halo:** draw the whole Route once more as one `MapPolyline` underneath the colored pieces, using `.stroke(.white.opacity(0.18), style: StrokeStyle(lineWidth: w + halo, lineCap: .round, lineJoin: .round))`. Content declared earlier in the `Map` builder sits beneath later content. **(inference: draw order follows declaration order)**

**Start/end dots:** `Annotation(coordinate:anchor:content:)` takes any SwiftUI view, such as a `Circle().fill(.red)` with a stroke, and keeps a constant on-screen size. `MapCircle` would also work, but its radius is in metres, so the dot would scale with zoom. [Annotation](https://developer.apple.com/documentation/mapkit/annotation), [MapCircle](https://developer.apple.com/documentation/mapkit/mapcircle)

## 2. Getting the dark map look

### Live SwiftUI `Map`
- `.mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))` gives a flat, quiet map. Apple says `.muted` "deemphasizes the map's imagery … to highlight content you place on the map", and `.flat` "renders a flat, 2D map". [MapStyle.standard(...)](https://developer.apple.com/documentation/mapkit/mapstyle/standard(elevation:emphasis:pointsofinterest:showstraffic:)), [StandardEmphasis.muted](https://developer.apple.com/documentation/mapkit/mapstyle/standardemphasis/muted), [Elevation.flat](https://developer.apple.com/documentation/mapkit/mapstyle/elevation/flat)
- `MapStyle` has **no "dark" variant**. The map follows the view's light or dark appearance. To force dark, set the color scheme on the `Map` with `.environment(\.colorScheme, .dark)` or put the screen in `.preferredColorScheme(.dark)`. **(inference: the MapStyle docs don't state this; it matches the snapshotter appearance rules below)** Custom tile colors (a fully bespoke palette) are not available in iOS 17 SwiftUI MapKit. The closest you get is dark + muted.

### Off-screen image: `MKMapSnapshotter`
- `MKMapSnapshotter` "captur[es] a map and its content into an image". It waits for map tiles to load before capturing. [MKMapSnapshotter](https://developer.apple.com/documentation/mapkit/mkmapsnapshotter)
- **It does not draw your overlays or annotations.** "Snapshotter objects don't capture the visual representations of any overlays or annotations that your app creates … you must draw them on the resulting snapshot image." To place them, use `Snapshot.point(for:)`, which converts a coordinate into the image's coordinate space. [Snapshot](https://developer.apple.com/documentation/mapkit/mkmapsnapshotter/snapshot), [point(for:)](https://developer.apple.com/documentation/mapkit/mkmapsnapshotter/snapshot/point(for:))
- These `Options` cover our needs:
  - `mapRect` or `region`: the area to capture.
  - `size`: defaults to 256×256 pt.
  - `scale`
  - `preferredConfiguration` (iOS 17+): takes an `MKMapConfiguration` subclass, such as `MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)`, which matches the live map.
  - `pointOfInterestFilter`
  - `traitCollection`: set `UITraitCollection(userInterfaceStyle: .dark)` to get a dark snapshot on iOS.

  [Options](https://developer.apple.com/documentation/mapkit/mkmapsnapshotter/options), [preferredConfiguration](https://developer.apple.com/documentation/mapkit/mkmapsnapshotter/options/preferredconfiguration), [MKStandardMapConfiguration](https://developer.apple.com/documentation/mapkit/mkstandardmapconfiguration), [traitCollection](https://developer.apple.com/documentation/mapkit/mkmapsnapshotter/options/traitcollection), [UITraitCollection(userInterfaceStyle:)](https://developer.apple.com/documentation/uikit/uitraitcollection/init(userinterfacestyle:)), [size](https://developer.apple.com/documentation/mapkit/mkmapsnapshotter/options/size)
- Caveats:
  - The user can force maps to a light appearance in the Maps app, and that overrides your requested appearance. Apple documents this on the macOS `appearance` property. [appearance](https://developer.apple.com/documentation/mapkit/mkmapsnapshotter/options/appearance)
  - The snapshot is only delivered while the app is **in the foreground**. A snapshot started in the background is delayed until the app returns. It has an `async throws` variant: `start(with:)`. [start(with:completionHandler:)](https://developer.apple.com/documentation/mapkit/mkmapsnapshotter/start(with:completionhandler:))
- `ImageRenderer` **cannot** rasterize a live `Map`. It does not include "views whose contents are composited by Core Animation layers … and most types of UIKit and AppKit views". To get a map image you must use `MKMapSnapshotter`. [ImageRenderer](https://developer.apple.com/documentation/swiftui/imagerenderer)

## 3. Drawing the Route over a plain rectangle (photo card)

The share card has no map underneath, so we project the coordinates ourselves.

1. Convert each coordinate with `MKMapPoint(coordinate)`. This is MapKit's flat 2D map projection, "used primarily to simplify computations that are complex to do using coordinate values on a curved surface." It is the same projection the map draws with, so the Route's shape matches what the user saw on the map. [MKMapPoint](https://developer.apple.com/documentation/mapkit/mkmappoint), [MKMapPoint.init(_:)](https://developer.apple.com/documentation/mapkit/mkmappoint/init(_:))
2. Take the bounding box of the map points, as an `MKMapRect` or plain min/max values. Aspect-fit that box into the card's drawing rect with padding, using one uniform scale so the shape isn't distorted. **(inference)** MKMapPoint `y` grows southward, the same direction as screen `y`, so no flip is needed. This is the standard Web-Mercator convention MapKit uses, but the docs page doesn't state it outright, so verify it with a quick test. [MKMapRect](https://developer.apple.com/documentation/mapkit/mkmaprect)
3. Draw in a SwiftUI `Canvas`, which "supports immediate mode drawing" and is recommended for performance-heavy, non-interactive drawing. The steps:
   - Stroke the full path once in `white.opacity(0.18)` at a larger width to make the halo.
   - Stroke each pace piece as its own `Path` in its color with `StrokeStyle(lineCap: .round, lineJoin: .round)`.
   - Fill circles at the first and last points.

   For a smooth gradient instead of steps, stroke each short segment with a `.linearGradient` from its start color to its end color. A gradient is correct when applied to a single short segment. [Canvas](https://developer.apple.com/documentation/swiftui/canvas)
4. Export the card, meaning photo + `Canvas` + text, with `ImageRenderer`. This works because the card is pure SwiftUI: an image, shapes and text. [ImageRenderer](https://developer.apple.com/documentation/swiftui/imagerenderer)

The same `Canvas` drawing code also renders a Route on top of an `MKMapSnapshotter` image. In that case you take points from `snapshot.point(for:)` instead of the custom fit. So one drawing routine serves both the "dark map image" and the "photo" variants of the Summary card. Only the projection function changes.

## Recommendation

- **Live screen:** use a SwiftUI `Map` with `.mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))` and a forced dark color scheme. Draw the Route as follows:
  - One wide `MapPolyline` underneath for the halo, stroked `white @ 18%`.
  - **Many short `MapPolyline`s** on top, one per consecutive run of samples in the same pace color bucket, with round caps and joins.
  - `Annotation` circles for the start (red) and end (green) dots.

  Do not rely on a `LinearGradient` on one `MapPolyline`: it is spatial, not along the path. Fall back to an `MKMapView` + `MKGradientPolylineRenderer` wrapper only if the design truly needs smooth color blending along the line.
- **Summary/share card:** don't snapshot the live `Map`. Project the coordinates with `MKMapPoint`, aspect-fit them into the card rect, and draw the halo, pace pieces and dots in a SwiftUI `Canvas` over the user's photo. Export with `ImageRenderer`. If a map background is wanted instead of a photo, get it from `MKMapSnapshotter` (dark `traitCollection`, muted `preferredConfiguration`) and draw the same `Canvas` routine using `snapshot.point(for:)`.
- Put the pace → color mapping and the "split the Route into same-color pieces" step in one pure function that both renderers share, so the map and the card always agree.
