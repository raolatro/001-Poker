-- config.lua
local config = {}

-- Global settings
config.DEBUG_MODE = true  -- Toggle debug overlay on/off

-- Window layout dimensions
config.WINDOW_WIDTH = 2048
config.WINDOW_HEIGHT = 1152

-- Scaling factors
config.BUTTON_SCALE = 0.3         -- Play & Discard buttons at 30% of natural size
config.CARD_SCALE = 2             -- Cards/deck scaled 2x
config.HEADER_SCALE = 0.4         -- Header at 40%
config.START_OVER_SCALE = 0.2     -- Start Over button at 20%

-- Animation & UI effect settings
config.HOVER_DURATION = 0.25         -- Max time for hover timer
config.HOVER_EASING_DELAY = 0.05       -- Delay for hover repel effect
config.HOVER_SCALE_INCREASE = 0.03     -- 3% scale increase when hovered
config.REPEL_OFFSET = 2                -- 2 pixels offset for the repel effect

-- Background image settings (paths and opacities)
config.BKG_MAIN = "/src/img/main/bkg_main.png"
config.BKG_MAIN_OPACITY = 0.3       -- 30% opacity for normal gameplay
config.BKG_GAME_OVER_OPACITY = 0.1  -- 10% opacity for Game Over screen

-- CSV database file paths
config.CARDS_CSV = "/src/db/cards.csv"
config.POINTS_CSV = "/src/db/points.csv"

return config