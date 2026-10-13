# Walk avatar attachment correction

## Finding

The eight-direction walk cels already contain the approved windswept hair. The renderer also removed source hair and drew a second hairstyle, but its old central face keep-out treated original side locks as face pixels. A broad dark-blue color test also confused detached facial marks with hair, while the old fixed vertical cutoff missed lower connected locks. This left pieces of the approved windswept cut beside bob/curly, most visibly in diagonal views. Restoring pixels through one broad face rectangle risked putting those locks back over the replacement cut.

## Correction

Keep the full authored windswept walk silhouette for the default style. For bob and curly replacements, measure the scalp anchor and combined hair/face width from each normalized walk cel. Scale each cut against that measured width instead of a fixed canvas size. Each replacement cut measures its crown anchor from opaque pixels in its central scalp band, then aligns it to the measured source scalp.

Replacement rendering now keeps two independent masks. The source-hair mask starts at crown pixels and follows contiguous pixels with the authored hair color, within a head-height cap; this removes connected side and lower locks without treating isolated dark facial marks or the similarly colored jacket as hair. A face mask is built from the source skin pixels and a small neighborhood, excluding the source-hair mask. The renderer captures the unmodified cel before stripping, clears only the source-hair component, draws the replacement, and restores the exact original face-mask pixels. The result removes the second windswept silhouette while preserving actual face details. Diagonal hair recolors from its style-specific source palette. Hats use the same measured walk anchor; elf ears and imp horns follow head motion relative to each direction's hold pose. Anchor and width caches are keyed by direction/frame.

The renderer does not resize or warp the body. It does not change locomotion timing or claim that the authored gait is natural; those require separate source-art and native visual review.

## CPU validation

Run with Godot 4.7.2 and an isolated save path:

```powershell
$env:SNAPLAND_SAVE_PATH = "$env:TEMP\snapland-avatar-attachment.json"
godot --headless --path . --audio-driver Dummy --rendering-method gl_compatibility --script res://game/tests/test_avatar_attachment.gd
```

The SceneTree test checks all 64 walk cels across eight directions, confirms per-cel scalp/head bounds, verifies the default silhouette matches the source after palette mapping, and checks that bob/curly remain distinct and within head-scaled width/length bounds. For frame 3 in all eight directions, it requires zero connected source-hair pixels to remain visible outside the replacement cut. On front-facing cels it checks that bob/curly preserve authored face-skin and non-hair eye/mouth pixels. It also verifies ink and chestnut colors differ for each hairstyle in all eight directions, then samples hats and both species across every direction. This confirms renderer data and pixel placement, not the in-world presentation.

## Bounded synthesis caches

Cold synthesis now prepares each normalized walk cel once and retains at most 64 cel images, 64 source hair/face metric records, and 24 immutable haircut records. Source metrics include connected hair and face masks, sparse pixel indices, and their bounds. Each haircut record stores its cleaned alpha silhouette, face-opening/used bounds, and pre-tinted variants for the three supported hair colors. Runtime composition duplicates cached pixels before mutation and applies source removal/restoration through sparse indices, so it does not re-run source segmentation, face-hole detection, atlas alpha cleanup, or recolor scans per appearance/frame. Existing final-pose cache remains separately capped at 128 textures.

The CPU test synthesizes the same 64-cel by three-style grid twice, changing outfit on the second pass to force composition while keeping hair inputs fixed. On the recorded local Godot 4.7.2 run, the first pass took 8,417 ms and the warm-cache pass took 4,107 ms; it built 64 normalized source cels, 64 source metric entries, and 16 replacement cuts (windswept walk keeps its authored source cut). These timings describe that headless workload only and do not establish frame rate or native/GPU performance.

## Native visual review

Open `game/tests/native_avatar_attachment_review.tscn` in a normal desktop build. The grid presents all eight directions and three hairstyles while cycling through all eight frames, with a full-size view of the selected cell. `Space` pauses, `Q` selects quarter speed, left/right step frames, up/down select the focus direction, `Tab` selects the focus hairstyle, `H` cycles hats, and `S` cycles human/elf/imp. The status line shows playback rate, selected frame, elapsed time, hat/species and measured per-direction anchors. Review the enlarged game-scale head and accessories in the native island before claiming visual acceptance; no native/GPU result is included in the CPU checks.

## Source-cut registration follow-up

The initial correction removed duplicated windswept locks but retained a 112px whole-cut cap and aligned the central crown band to the source face centroid. The source atlas contains off-center face cutouts, especially in profiles; crown alignment alone moves curls onto the cheek while the width cap shrinks the whole head.

Replacement cuts now use their actual opaque silhouette width against the source cel's crown-connected hair bounds with one uniform scale. The 112px walk cap is removed. For front/profile cuts, the renderer measures broad transparent gaps between opaque row edges, including face openings that remain open at the chin, then registers the opening's upper center to the source face-mask upper center. Back views align the whole opaque hair silhouette to source crown-connected bounds instead of treating the face centroid as the crown center. Existing connected-source-hair removal and exact source face restoration remain in place. No body pixels are scaled or warped.

A regression case uses an intentionally off-center, open-bottom face hole and a 150px source head; it rejects crown-center registration and 112px shrinking. All native visual acceptance remains pending the new real GPU review: passing pixel assertions alone does not approve hairstyles.

## Horn and elf-ear physical attachment follow-up

The later native species grid rejected floating horns and ears even though the previous broad used-rectangle check passed. New component tests were written first: the unchanged horn renderer failed front/frame0/windswept with zero strong head contacts(exit1). The old12/13px horn placement and fixed15px/width−51px ear locations are removed from active attachment placement.

Horn preparation measures the resized source part's opaque lower base(alpha>0.63), excluding transparent padding/halo. Each base is positioned several pixels inside a dense strong-alpha region of the actual selected hairstyle's crown. It follows that cel and cut, not a fixed body offset. Complete source tips are retained within the canvas. Profile directions retain one visible horn; front/back/diagonal views retain two.

Elf ears use the measured source face eye-height region and actual selected head's strong lateral contour. Their opaque lower roots enter the left/right head boundary. Profile source parts point outward from the visible lateral attachment. Ears composite behind the complete selected hair/face, then exact selected face pixels are restored; this prevents semi-transparent source-edge blending from changing authored face marks or skin. Original body/head art does not translate to make accessories fit.

The CPU contract checks all64walkcels×3hairstyles for both species. Every visible added opaque accessory component must have at least three neighboring/overlapping strong actual head pixels; horns specifically require hair contacts. It also checks one profile/two other visible components and exact opaque source-face conservation. No halo or broad used rectangle counts as attachment. Existing64source-metric/16haircut preparation and bounded avatar texture cache checks remain unchanged. The updated normal/quarter-speed native species grids still require root visual acceptance; these CPU checks do not establish completed presentation. Prior floating-accessory screenshots remain negative evidence.

The legacy profile-ear assertions were migrated from fixed empty canvas rectangles to actual measured head contact and visible ear extension, preserving the physical attachment requirement. Root independently reran both avatar and attachment suites. Default windswept ink now preserves the exact authored hair RGB across all64 cels; alternate source-hair recoloring follows the complete connected hair mask rather than a fixed height cutoff that previously left a horizontal tint band.
