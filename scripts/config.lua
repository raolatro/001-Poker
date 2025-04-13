-- config.lua
local config = {}

-- Global settings
config.DEBUG_MODE = true  -- Toggle debug overlay on/off

-- Window layout dimensions
config.WINDOW_WIDTH = 1920
config.WINDOW_HEIGHT = 1080

-- Scaling factors
config.BUTTON_SCALE = 0.3         -- Scale for buttons
config.CARD_SCALE = 2             -- Scale for cards
config.HEADER_SCALE = 0.4         -- Scale for header
config.START_OVER_SCALE = 0.5     -- Base scale for Game Over scene images

-- Animation & UI effect settings
config.HOVER_DURATION = 0.25         -- Max time for hover timer
config.HOVER_EASING_DELAY = 0.05       -- Delay for hover repel effect
config.HOVER_SCALE_INCREASE = 0.03     -- 3% scale increase when hovered
config.REPEL_OFFSET = 2                -- 2 pixels offset for the repel effect

-- Background image settings (paths and opacities)
config.BKG_MAIN = "/src/img/main/bkg_main.png"
config.BKG_GAME_OVER_OPACITY = 0.1  -- 10% opacity for Game Over screen
config.BKG_MAIN_OPACITY = 0.3       -- 30% opacity for gameplay

-- CSV database file paths
config.CARDS_CSV = "/src/db/cards.csv"
config.POINTS_CSV = "/src/db/points.csv"

-- Sound and music paths and volumes
config.CARD_DRAW_SFX = "/src/sfx/card_draw1.mp3"
config.CARD_DISCARD_SFX = "/src/sfx/card_discard.mp3"
config.BGM_PATH = "/src/music/balatro_main.mp3"
config.SFX_VOLUME = 1.0
config.MUSIC_VOLUME = 0.5

return config