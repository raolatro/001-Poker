-- config.lua
local config = {}

-- Global settings
config.DEBUG_MODE = false

-- Window dimensions
config.WINDOW_WIDTH = 1920
config.WINDOW_HEIGHT = 1080

-- Scaling factors
config.BUTTON_SCALE = 0.3
config.CARD_SCALE = 2
config.HEADER_SCALE = 0.4
config.START_OVER_SCALE = 0.5

-- Animation & UI settings
config.HOVER_DURATION = 0.25
config.HOVER_EASING_DELAY = 0.05
config.HOVER_SCALE_INCREASE = 0.03
config.REPEL_OFFSET = 2

-- Background image settings
config.BKG_MAIN = "/src/img/main/bkg_main.png"
config.BKG_GAME_OVER_OPACITY = 0.1
config.BKG_MAIN_OPACITY = 0.3

-- CSV paths
config.CARDS_CSV = "/src/db/cards.csv"
config.POINTS_CSV = "/src/db/points.csv"

-- Sound and music paths/volumes
config.CARD_DRAW_SFX = "/src/sfx/card_draw1.mp3"
config.CARD_DISCARD_SFX = "/src/sfx/card_discard.mp3"
config.BGM_PATH = "/src/music/balatro_takefive.mp3"
config.SFX_VOLUME = 1.0
config.MUSIC_VOLUME = 0.3

return config