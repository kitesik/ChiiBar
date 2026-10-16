# Illustrated upgrade numbers

Production numeral PNGs for the daily upgrade stamp, created with the built-in image_gen tool on 2026-10-16. Each number from 0 through 30 has its own illustration; these are not font screenshots.

- `00.png` through `30.png`: original generated transparent images, unchanged.
- `07.png`: initial style reference. Other numbers were generated individually using this reference.
- `prompts.json`: exact reference prompt and the shared prompt template, substituting NUMBER with the requested integer.
- The renderer trims transparent margins only in memory, fits the illustration inside the stamp, and caches a maximum-192px display image. The saved PNGs remain intact.
- Counts above 30 use the illustrated 0–9 digits. The saved count, progression rules, and accessibility labels remain numeric and unchanged.
- Build packaging requires all 31 images; image accuracy and 1–30 layouts are visually reviewed in the number-stamps preview.
