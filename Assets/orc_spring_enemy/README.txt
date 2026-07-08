Orc Enemy Sprite Pack

Folders:
- game_ready/: post-processed strips with exact requested canvas sizes.
  idle.png   = 6 frames, 600x100 px
  walk.png   = 8 frames, 800x100 px
  attack.png = 6 frames, 600x100 px
  hurt.png   = 3 frames, 300x100 px
  death.png  = 4 frames, 400x100 px

Each game_ready strip is arranged horizontally, 100x100 px per frame, PNG RGBA alpha.

- raw_generated/: original AI-generated strips renamed by animation. These are larger source images and may be useful if you want to manually re-cut or repaint frames.

Note: The game_ready files were post-processed from generated art: checkerboard preview background was removed algorithmically, frames were cropped/scaled into 100x100 cells, and spacing was standardized. Please inspect in-engine for any remaining edge artifacts or animation jitter.
