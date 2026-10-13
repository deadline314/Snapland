# Island landscape and lighting slices

This note separates the island layout work from the later lighting pass. It describes the review snapshots in `.review/commit-slices/08-MAIN11-world.gd` and `10-ART1-world.gd`; those snapshots are intentionally based on different ticket boundaries.

## MAIN11 layout snapshot

The avenue keeps its 9×64 walkable route and the plaza footprint, with a larger, quieter coastal-stone texture scale. The regular gold inlays and continuous cream barrier rows are gone. A ten-piece irregular pebble group softens the fountain edge, and four planting pockets batch their leaves and flowers into two MultiMeshes. The lawn still uses `grass.gdshader`, which now combines broad world-space meadow variation with finer blade marks and small paper-like speckles; it is no longer the former 0.18-unit checker pattern.

The wind workshop uses separated shallow canvas slats, narrower supports, and open sightlines. The four tide pools sit in the east court between game points, with a low shared bubbler. The lighthouse lookout has a solid promenade link that meets its collision ramp and deck, including the corrected ramp overlap at the deck edge. The ride interaction is registered at `(-6.7, 0.26, 11.2)` and is configured with the matching boarding point by the separately integrated MAIN15 ride module.

The camera remains at the MAIN11 framing, avatar movement stays at the legacy 5-unit speed, and this snapshot has no avatar motion-rig dependency. District labels are visibility-managed against the player's horizontal distance so the fixed camera can remain farther back without leaving all labels visible.

## ART1 lighting snapshot

The ART1 world snapshot layers lighting work over the layout: it lowers ambient fill and exposure, adjusts the sun, and adds actor and tree shadow proxies. Lamps are enabled by time-of-day phase with a bounded active set; their shadows stay disabled. This changes the lighting contract asserted by `test_island_layout.gd`, including the noon exposure/fill check. It retains the same legacy movement speed and does not add the later avatar motion rig.

## Test ordering and evidence

`test_island_layout.gd` covers both the MAIN11 map/layout and the ART1 exposure contract. Keep every assertion. For ticket isolation, land the layout source and its layout assertions with MAIN11, then run the full layout test after ART1's lighting source is present; alternatively split only the exposure check into an ART1-specific test while retaining equivalent coverage. Do not report a MAIN11-only layout run against its pre-ART1 world as satisfying the exposure assertion.

The dedicated runner snapshots retain the HEAD M17 save-guard and M15 ride entries. `15-MAIN11-runner.py` adds the island layout suite; `16-ART1-runner.py` is identical because HEAD already registers the daylight-lighting suite. Relevant suite names are `island layout tests`, `daylight lighting tests`, `island ride tests`, and `test/review save isolation tests`.

Headless contracts can check stable IDs, district membership, collision, ramp traversal, label range policy, and configured exposure values. They do not establish that the visual composition reads as finished; that requires the separate native review.
