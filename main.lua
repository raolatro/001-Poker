-- main.lua
-- (Summary: Updated love.update to avoid calling updatePositions each frame for newly drawn cards)

local function easeInOutQuad(t)
  if t < 0.5 then return 2*t*t else return -1+(4-2*t)*t end
end

local config = require "scripts.config"
local cardManager = require "scripts.cardManager"
local uiEffects = require "scripts.uiEffects"
local gameOverModule = require "scripts.gameOver"
local debugModule = require "scripts.debug"
local handManager = require "scripts.handManager"
local evaluateHandModule = require "scripts.evaluateHand"
local submitScore = require "scripts.submitScore"

local windowWidth, windowHeight = config.WINDOW_WIDTH, config.WINDOW_HEIGHT
local cardWidth, cardHeight, cardSpacing
local tableStartY
local deckRect = {}
local headerImage, playButtonImage, discardButtonImage, gameOverImage, startOverButtonImage, cardBackImage, backgroundImage

local cardFont, scoreFont, deckCountFont

local playButton = {}
local discardButton = {}
local startOverButton = {}  -- restart clickable area

local sortRankButton = { x = 20, y = config.WINDOW_HEIGHT - 80, width = 120, height = 30 }
local sortSuitButton = { x = 20, y = config.WINDOW_HEIGHT - 40, width = 120, height = 30 }

if not bgm then
  bgm = love.audio.newSource(config.BGM_PATH, "stream")
  bgm:setLooping(true)
  bgm:setVolume(config.MUSIC_VOLUME)
  bgm:play()
end

_G.gameOver = false
_G.submitScoreActive = false
_G.playerNameInput = ""

local function setLayout()
  windowWidth = config.WINDOW_WIDTH
  windowHeight = config.WINDOW_HEIGHT
  love.window.setMode(windowWidth, windowHeight, {resizable = true})
  cardSpacing = 5
  tableStartY = windowHeight - (cardBackImage:getHeight() * config.CARD_SCALE) - 150
  sortRankButton.y = windowHeight - 80
  sortSuitButton.y = windowHeight - 40
end

function love.load()
  math.randomseed(os.time())
  _G.gameOver = false
  evaluateHandModule.loadPoints()

  cardFont = love.graphics.newFont(32)
  love.graphics.setFont(cardFont)
  scoreFont = love.graphics.newFont(16)
  deckCountFont = love.graphics.newFont(12)

  headerImage = love.graphics.newImage("/src/img/main/raolatro.png")
  playButtonImage = love.graphics.newImage("/src/img/buttons/play_hand.png")
  discardButtonImage = love.graphics.newImage("/src/img/buttons/discard.png")
  gameOverImage = love.graphics.newImage("/src/img/gameover/game_over.png")
  startOverButtonImage = love.graphics.newImage("/src/img/gameover/restart.png")
  cardBackImage = love.graphics.newImage("/src/img/cards/card_back.png")
  backgroundImage = love.graphics.newImage(config.BKG_MAIN)

  setLayout()
  cardWidth = cardBackImage:getWidth() * config.CARD_SCALE
  cardHeight = cardBackImage:getHeight() * config.CARD_SCALE

  local deckMargin = 50
  deckRect = {
    x = windowWidth - cardWidth - deckMargin,
    y = windowHeight - cardHeight - deckMargin,
    width = cardWidth,
    height = cardHeight
  }

  local gap = 20
  local playW = playButtonImage:getWidth() * config.BUTTON_SCALE
  local discardW = discardButtonImage:getWidth() * config.BUTTON_SCALE
  local groupWidth = playW + discardW + gap
  local groupX = (windowWidth - groupWidth) / 2
  local groupY = tableStartY + cardHeight + 20
  discardButton = { x = groupX, y = groupY, width = discardW, height = discardButtonImage:getHeight() * config.BUTTON_SCALE }
  playButton = { x = groupX + discardW + gap, y = groupY, width = playW, height = playButtonImage:getHeight() * config.BUTTON_SCALE }

  local soW = startOverButtonImage:getWidth() * config.START_OVER_SCALE
  local soH = startOverButtonImage:getHeight() * config.START_OVER_SCALE
  startOverButton = { x = (windowWidth - soW) / 2, y = (windowHeight) / 2 + 100, width = soW, height = soH }

  cardManager.resetDeck()
  cardManager.dealCards(MAX_DISPLAYED, tableStartY, cardWidth, cardHeight, cardSpacing, windowWidth, deckRect)

  handManager.totalScore = 0
  handManager.handsRemaining = 3
  _G.gameOver = false

  handManager.animationPhase = nil
  handManager.animationTimer = 0
  handManager.handAlpha = 0
  handManager.fadeAlpha = 1
  handManager.handProcessed = false

  debugModule.addAlert("Game loaded\n\n----------")
end

local function drawDeckCount()
  love.graphics.setFont(deckCountFont)
  local deckCountText = tostring(#cardManager.getDeck())
  local countWidth = deckCountFont:getWidth(deckCountText)
  love.graphics.print(deckCountText, deckRect.x + (cardWidth - countWidth) / 2, deckRect.y - deckCountFont:getHeight() - 10)
  love.graphics.setFont(cardFont)
end

function love.update(dt)
  local mx, my = love.mouse.getPosition()
  local playHover = (mx >= playButton.x and mx <= playButton.x + playButton.width and my >= playButton.y and my <= playButton.y + playButton.height)
  local discardHover = (mx >= discardButton.x and mx <= discardButton.x + discardButton.width and my >= discardButton.y and my <= discardButton.y + discardButton.height)
  local restartHover = _G.gameOver and (mx >= startOverButton.x and mx <= startOverButton.x + startOverButton.width and my >= startOverButton.y and my <= startOverButton.y + startOverButton.height)
  local sortRankHover = (mx >= sortRankButton.x and mx <= sortRankButton.x + sortRankButton.width and my >= sortRankButton.y and my <= sortRankButton.y + sortRankButton.height)
  local sortSuitHover = (mx >= sortSuitButton.x and mx <= sortSuitButton.x + sortSuitButton.width and my >= sortSuitButton.y and my <= sortSuitButton.y + sortSuitButton.height)

  playHoverTimer = uiEffects.updateHover(dt, playHover, playHoverTimer)
  discardHoverTimer = uiEffects.updateHover(dt, discardHover, discardHoverTimer)
  if _G.gameOver then
    startOverHoverTimer = uiEffects.updateHover(dt, restartHover, startOverHoverTimer)
  end
  _G.playOpacity = uiEffects.getHoverOpacity(playHoverTimer)
  _G.discardOpacity = uiEffects.getHoverOpacity(discardHoverTimer)
  _G.startOverOpacity = uiEffects.getHoverOpacity(startOverHoverTimer)

  if playHover or discardHover or restartHover or sortRankHover or sortSuitHover then
    love.mouse.setCursor(love.mouse.getSystemCursor("hand"))
  else
    love.mouse.setCursor()
  end

  -- Update draw animations for newly dealt cards
  for _, card in ipairs(cardManager.getTableCards()) do
    if card.newlyDrawn then
      card.drawAnimTimer = card.drawAnimTimer + dt
      if card.drawAnimTimer >= card.drawAnimDelay then
        local t = math.min((card.drawAnimTimer - card.drawAnimDelay) / card.drawAnimDuration, 1)
        local eased = easeInOutQuad(t)
        card.x = card.startDrawX + (card.drawTargetX - card.startDrawX) * eased
        card.y = card.startDrawY + (card.drawTargetY - card.startDrawY) * eased
        card.rotation = card.startRotation + (card.drawTargetRotation - card.startRotation) * eased
        if not card.drawPlayed then
          local sfx = cardDrawSFX:clone()
          sfx:setVolume(config.SFX_VOLUME)
          sfx:play()
          card.drawPlayed = true
        end
        if t >= 1 then
          card.newlyDrawn = false
        end
      end
    end
  end

  if handManager.animationPhase then
    handManager.updateAnimations(dt, windowWidth, windowHeight, cardWidth, tableStartY, cardSpacing)
  end
  -- (No call to updatePositions here so as not to override new cards' positions)
end

function love.draw()
  if _G.gameOver then
    love.graphics.setColor(1, 1, 1, config.BKG_GAME_OVER_OPACITY)
  else
    love.graphics.setColor(1, 1, 1, config.BKG_MAIN_OPACITY)
  end
  love.graphics.draw(backgroundImage, 0, 0, 0, windowWidth/backgroundImage:getWidth(), windowHeight/backgroundImage:getHeight())
  love.graphics.setColor(1, 1, 1, 1)
  
  if not _G.gameOver then
    love.graphics.setColor(1, 1, 1, handManager.fadeAlpha)
    local headerW = headerImage:getWidth() * config.HEADER_SCALE
    local headerH = headerImage:getHeight() * config.HEADER_SCALE
    local headerX = (windowWidth - headerW) / 2
    local headerY = 10
    love.graphics.draw(headerImage, headerX, headerY, 0, config.HEADER_SCALE, config.HEADER_SCALE)
    
    love.graphics.setFont(scoreFont)
    local handsText = "Hands Remaining: " .. handManager.handsRemaining
    local scoreText = "Total Score: " .. handManager.totalScore
    local handsW = scoreFont:getWidth(handsText)
    local scoreW = scoreFont:getWidth(scoreText)
    local centerX = headerX + headerW/2
    love.graphics.print(handsText, centerX - handsW/2, headerY + headerH + 10)
    love.graphics.print(scoreText, centerX - scoreW/2, headerY + headerH + 10 + scoreFont:getHeight() + 5)
    love.graphics.setFont(cardFont)
    
    for i = 1, #cardManager.getDeck() do
      local offsetX = (i - 1) * 1
      local offsetY = (i - 1) * 1
      love.graphics.draw(cardBackImage, deckRect.x + offsetX, deckRect.y + offsetY, 0, config.CARD_SCALE, config.CARD_SCALE)
    end
    drawDeckCount()
    
    for _, card in ipairs(cardManager.getTableCards()) do
      love.graphics.draw(card.image, card.x, card.y, card.rotation or 0, config.CARD_SCALE, config.CARD_SCALE)
    end

    love.graphics.setColor(0.4, 0.4, 0.8, 1)
    love.graphics.rectangle("fill", sortRankButton.x, sortRankButton.y, sortRankButton.width, sortRankButton.height, 4,4)
    love.graphics.rectangle("fill", sortSuitButton.x, sortSuitButton.y, sortSuitButton.width, sortSuitButton.height, 4,4)
    love.graphics.setColor(1,1,1,1)
    local rankText = "Sort by Rank"
    local suitText = "Sort by Suit"
    local font = love.graphics.getFont()
    local rankTextWidth = font:getWidth(rankText)
    local suitTextWidth = font:getWidth(suitText)
    love.graphics.print(rankText, sortRankButton.x + (sortRankButton.width - rankTextWidth)/2, sortRankButton.y + (sortRankButton.height - font:getHeight())/2)
    love.graphics.print(suitText, sortSuitButton.x + (sortSuitButton.width - suitTextWidth)/2, sortSuitButton.y + (sortSuitButton.height - font:getHeight())/2)
    
    love.graphics.setColor(1,1,1, _G.discardOpacity or 1)
    love.graphics.draw(discardButtonImage, discardButton.x, discardButton.y, 0, config.BUTTON_SCALE, config.BUTTON_SCALE)
    love.graphics.setColor(1,1,1, _G.playOpacity or 1)
    love.graphics.draw(playButtonImage, playButton.x, playButton.y, 0, config.BUTTON_SCALE, config.BUTTON_SCALE)
    love.graphics.setColor(1,1,1,1)
    
    if handManager.animationPhase == "show_hand_fadein" or handManager.animationPhase == "show_hand_hold" then
      love.graphics.setColor(1,1,1, handManager.handAlpha * handManager.fadeAlpha)
      local text = _G.handResult or ""
      local textWidth = cardFont:getWidth(text)
      love.graphics.print(text, (windowWidth - textWidth) / 2, windowHeight/2 + cardHeight/2 + 10)
      love.graphics.setColor(1,1,1,1)
    end
  else
    gameOverModule.draw(windowWidth, windowHeight, gameOverImage, cardFont, handManager.totalScore, startOverButton, handManager.fadeAlpha, 0, startOverButtonImage)
  end
  
  debugModule.draw()
end

function love.mousepressed(x, y, button)
  debugModule.addAlert("Mouse pressed at (" .. x .. ", " .. y .. ")\n\n----------")
  if button == 1 then
    if _G.gameOver then
      if x >= startOverButton.x and x <= startOverButton.x + startOverButton.width and
         y >= startOverButton.y and y <= startOverButton.y + startOverButton.height then
         debugModule.addAlert("Restart Button clicked\n\n----------")
         love.load()
      end
      return
    end

    if x >= sortRankButton.x and x <= sortRankButton.x + sortRankButton.width and 
       y >= sortRankButton.y and y <= sortRankButton.y + sortRankButton.height then
       debugModule.addAlert("Sort by Rank clicked\n\n----------")
       handManager.sortCards("rank", windowWidth, cardWidth, cardSpacing)
       return
    end
    if x >= sortSuitButton.x and x <= sortSuitButton.x + sortSuitButton.width and 
       y >= sortSuitButton.y and y <= sortSuitButton.y + sortSuitButton.height then
       debugModule.addAlert("Sort by Suit clicked\n\n----------")
       handManager.sortCards("suit", windowWidth, cardWidth, cardSpacing)
       return
    end

    if x >= playButton.x and x <= playButton.x + playButton.width and 
       y >= playButton.y and y <= playButton.y + playButton.height then
      debugModule.addAlert("Play Button clicked\n\n----------")
      handManager.playHand(tableStartY, cardWidth, cardHeight, cardSpacing, windowWidth, windowHeight, deckRect)
      return
    end
    if x >= discardButton.x and x <= discardButton.x + discardButton.width and 
       y >= discardButton.y and y <= discardButton.y + discardButton.height then
      if handManager.animationPhase then
        debugModule.addAlert("Discard ignored: animation in progress\n\n----------")
        return
      end
      local discardCount = 0
      for _, card in ipairs(cardManager.getTableCards()) do
        if card.selected then discardCount = discardCount + 1 end
      end
      if discardCount > 0 then
        handManager.discardHand(tableStartY, cardWidth, cardHeight, windowHeight, windowWidth)
        debugModule.addAlert("Discard Button clicked. Discard count: " .. discardCount .. "\n\n----------")
      end
      return
    end
    for _, card in ipairs(cardManager.getTableCards()) do
      if x >= card.x and x <= card.x + card.width and
         y >= card.y and y <= card.y + card.height then
         debugModule.addAlert("Card clicked with rank: " .. tostring(card.rank) .. "\n\n----------")
         handManager.toggleCard(card, tableStartY, cardWidth, cardHeight, cardSpacing, windowWidth)
         break
      end
    end
  end
end

function love.textinput(t)
  if _G.submitScoreActive then
    _G.playerNameInput = _G.playerNameInput .. t
  end
end

function love.keypressed(key)
  if _G.submitScoreActive then
    if key == "backspace" then
      _G.playerNameInput = _G.playerNameInput:sub(1, -2)
    elseif key == "return" then
      local response, code = submitScore.send(_G.playerNameInput, handManager.totalScore)
      debugModule.addAlert("Score submitted: " .. response .. "\n\n----------")
      _G.submitScoreActive = false
      _G.playerNameInput = ""
    end
  end
end

function love.resize(w, h)
  windowWidth = w
  windowHeight = h
  cardWidth = cardBackImage:getWidth() * config.CARD_SCALE
  cardHeight = cardBackImage:getHeight() * config.CARD_SCALE
  cardSpacing = 5
  tableStartY = windowHeight - cardHeight - 150
  local gap = 20
  local playW = playButtonImage:getWidth() * config.BUTTON_SCALE
  local discardW = discardButtonImage:getWidth() * config.BUTTON_SCALE
  local groupWidth = playW + discardW + gap
  local groupX = (windowWidth - groupWidth) / 2
  local groupY = tableStartY + cardHeight + 20
  discardButton.x = groupX
  discardButton.y = groupY
  discardButton.width = discardW
  discardButton.height = discardButtonImage:getHeight() * config.BUTTON_SCALE
  playButton.x = groupX + discardW + gap
  playButton.y = groupY
  playButton.width = playW
  playButton.height = playButtonImage:getHeight() * config.BUTTON_SCALE
  local deckMargin = 50
  deckRect.x = windowWidth - cardWidth - deckMargin
  deckRect.y = windowHeight - cardHeight - deckMargin
  local soW = startOverButtonImage:getWidth() * config.START_OVER_SCALE
  local soH = startOverButtonImage:getHeight() * config.START_OVER_SCALE
  startOverButton = { x = (windowWidth - soW) / 2, y = (windowHeight) / 2 + 100, width = soW, height = soH }
  cardManager.updatePositions(tableStartY, cardWidth, cardHeight, cardSpacing, windowWidth)
end