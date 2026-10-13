# Gameplay photo originals

Successful non-practice gameplay captures keep the rendered source image at its native dimensions (up to 4 megapixels) and save a separate 320×180 PNG for the collection grid. The profile stores the existing `frames` thumbnail list unchanged and may also store `original_frames`; ordinary and devil cards from one result share each list. Original paths are optional so older saves and thumbnail-only captures remain readable.

The photo viewer loads only the selected card's first original when opened. It retains no large-image cache. Missing or rejected originals fall back to the bounded thumbnail and explain the limitation in player-facing language. Original PNG files are capped at 16 MiB and 4 megapixels before decoding; invalid IHDR dimensions and oversized files never reach the native image decoder. Capture never upscales a source image.

The time-postcard flow follows the same pair: hide the UI, capture the actual rendered viewport, save a bounded original plus thumbnail, then attach both paths to the existing postcard reward. If capture is cancelled or persistence fails, both newly written files are removed and no postcard award is recorded.

CPU coverage: `game/tests/test_photo_originals.tscn`, plus the existing `test_main_photo_thumbnails.tscn` and `test_album_photo_viewer.tscn` checks. The negative malformed-zlib thumbnail proof stays isolated in its child Godot process; it is deliberately a negative decoder test.
