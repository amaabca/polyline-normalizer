# Changelog

All notable changes to this project will be documented in this file.

## [1.1.0] — Polyline normalizer improvements

Adds a multi-layer cleaning pipeline that runs before the nearest-neighbour reordering step, addressing five classes of encoding defects found in real Alberta511 segment data.

### Added

- **`needs_reorder?` guard** — skips nearest-neighbour reordering when no consecutive point pair exceeds the distance threshold, preventing curved/arc-shaped roads from being scrambled by axis-sort.
- **"Do no harm" reorder check** — after reordering, falls back to the cleaned-but-unsorted input if the reordered result produces a larger maximum jump than the original.
- **`remove_duplicate_passes`** — splits the point sequence at gaps > 5 km and discards sub-segments whose bounding boxes overlap ≥ 80% with an earlier sub-segment, eliminating routes encoded twice in one polyline.
- **Tiny-segment filter** — inside `remove_duplicate_passes`, drops any sub-segment smaller than `max(10 points, 5% of total)` to remove stray trailing artefacts that would otherwise trigger a false reorder.
- **Bookend duplicate detection** — when no gap ≥ 5 km exists, splits on the largest internal gap (> 3 km) and discards the second half if its endpoints land within 200 m of the first half's endpoints, catching duplicate passes with a sub-threshold seam gap.
- **`trim_out_and_back`** — detects divided highways encoded as an out-and-back sequence (turnaround point in the middle 30–70% of the sequence with ≥ 70% bounding-box overlap between outbound and return legs) and discards the return leg.
