ChiiBar original fan drawings

All images are drawn locally from the vector masters in
Sources/ChiiBar/OriginalSprites.swift. No official image, sticker, GIF,
animation frame, download, or tracing is used. Characters belong to their
respective rights holder. Unofficial fan artwork. Not affiliated with the rights holder.

Recreate: bash Scripts/draw-sprites.sh

Each friend has 12 PNGs, 640 pixels wide with transparency:
stand, sleep, happy, munch, blink, cheer, front, munch_front,
happy_front, ear_left, ear_right, face.
Whole-body frames are 640 x 760, feet at bottom center.
The face frame is 640 x 640 and is used at 18 points in the menu bar.
SpriteArt.swift selects pose variants and falls back to stand, then code.

Motion is applied to images in ActivityArt.swift. Ear variants use discrete
angles with a delayed phase; they are not a continuous skeletal animation.
