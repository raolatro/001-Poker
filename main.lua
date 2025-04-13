-- main.lua

-- Require our modules
local config = require "scripts.config"
local cardManager = require "scripts.cardManager"
local uiEffects = require "scripts.uiEffects"
local gameOverModule = require "scripts.gameOver"
local debugModule = require "scripts.debug"

-- Global game state variables
local windowWidth, windowHeight = config.WINDOW_WIDTH, config.WINDOW_HEIGHT
local cardWidth, cardHeight, cardSpacing
local tableStartY
local deckRect = {}
local headerImage, playButtonImage, discardButtonImage, gameOverImage, startOverButtonImage, cardBackImage, backgroundImage

local cardFont, scoreFont, deckCountFont

local playButton = {}
local discardButton = {}
local startOverButton = {}  -- used as the restart clickable area

local totalScore = 0
local lastHandScore = 0
local handsRemaining = 3
local gameOver = false

local animationPhase = nil
local animationTimer = 0
local handAlpha = 0
local movingCards = {}
local fadeAlpha = 1
local startOverBobTime = 0

-- Hover timers
local playHoverTimer = 0
local discardHoverTimer = 0
local startOverHoverTimer = 0

local MAX_DISPLAYED = 7

-- Flag to ensure a hand is processed only once.
local handProcessed = false

-- Easing function for animations
local function easeInOutQuad(t)
  if t < 0.5 then
    return 2 * t * t
  else
    return -1 + (4 - 2 * t) * t
  end
end

-- Set up layout and window
local function setLayout()
  windowWidth = config.WINDOW_WIDTH
  windowHeight = config.WINDOW_HEIGHT
  love.window.setMode(windowWidth, windowHeight, {resizable = true})
  cardSpacing = 5
  tableStartY = windowHeight - (cardBackImage:getHeight() * config.CARD_SCALE) - 150
end

function love.load()
  math.randomseed(os.time())
  
  -- Load fonts
  cardFont = love.graphics.newFont(32)
  love.graphics.setFont(cardFont)
  scoreFont = love.graphics.newFont(16)
  deckCountFont = love.graphics.newFont(12)
  
  -- Load images
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
  
  -- Initialize the startOverButton (clickable area for restart)
  local soW = startOverButtonImage:getWidth() * config.START_OVER_SCALE
  local soH = startOverButtonImage:getHeight() * config.START_OVER_SCALE
  startOverButton = { x = (windowWidth - soW) / 2, y = (windowHeight) / 2 + 100, width = soW, height = soH }
  
  cardManager.resetDeck()
  cardManager.dealCards(MAX_DISPLAYED, tableStartY, cardWidth, cardHeight, cardSpacing, windowWidth)
  
  totalScore = 0
  handsRemaining = 3
  gameOver = false
  animationPhase = nil
  fadeAlpha = 1
  
  handProcessed = false
  
  debugModule.addAlert("Game loaded\n\n----------")
end

-- Helper to draw the deck count
local function drawDeckCount()
  love.graphics.setFont(deckCountFont)
  local deckCountText = tostring(#cardManager.getDeck())
  local countWidth = deckCountFont:getWidth(deckCountText)
  love.graphics.print(deckCountText, deckRect.x + (cardWidth - countWidth) / 2, deckRect.y - deckCountFont:getHeight() - 10)
  love.graphics.setFont(cardFont)
end

function love.update(dt)
  local mx, my = love.mouse.getPosition()
  playHoverTimer = uiEffects.updateHover(dt, (mx >= playButton.x and mx <= playButton.x + playButton.width and my >= playButton.y and my <= playButton.y + playButton.height), playHoverTimer)
  discardHoverTimer = uiEffects.updateHover(dt, (mx >= discardButton.x and mx <= discardButton.x + discardButton.width and my >= discardButton.y and my <= discardButton.y + discardButton.height), discardHoverTimer)
  if gameOver then
    startOverHoverTimer = uiEffects.updateHover(dt, (mx >= startOverButton.x and mx <= startOverButton.x + startOverButton.width and my >= startOverButton.y and my <= startOverButton.y + startOverButton.height), startOverHoverTimer)
  end
  _G.playOpacity = uiEffects.getHoverOpacity(playHoverTimer)
  _G.discardOpacity = uiEffects.getHoverOpacity(discardHoverTimer)
  _G.startOverOpacity = uiEffects.getHoverOpacity(startOverHoverTimer)
  
  -- Set cursor to "hand" when hovering over clickable elements
  local hover = false
  if (mx >= playButton.x and mx <= playButton.x + playButton.width and my >= playButton.y and my <= playButton.y + playButton.height) then
    hover = true
  elseif (mx >= discardButton.x and mx <= discardButton.x + discardButton.width and my >= discardButton.y and my <= discardButton.y + discardButton.height) then
    hover = true
  elseif gameOver and (mx >= startOverButton.x and mx <= startOverButton.x + startOverButton.width and my >= startOverButton.y and my <= startOverButton.y + startOverButton.height) then
    hover = true
  else
    for _, card in ipairs(cardManager.getTableCards()) do
      if mx >= card.x and mx <= card.x + card.width and my >= card.y and my <= card.y + card.height then
        hover = true
        break
      end
    end
  end
  if hover then
    love.mouse.setCursor(love.mouse.getSystemCursor("hand"))
  else
    love.mouse.setCursor()
  end
  
  if animationPhase == "move_to_center" then
    animationTimer = animationTimer + dt
    for _, card in ipairs(cardManager.getTableCards()) do
      if card.isAnimating then
        local delay = card.moveDelay or 0
        if animationTimer >= delay then
          local localT = math.min((animationTimer - delay) / 0.5, 1)
          local eased = easeInOutQuad(localT)
          card.x = card.startX + (card.targetX - card.startX) * eased
          card.y = card.startY + (card.targetY - card.startY) * eased
        end
      end
    end
    local lastDelay = (#movingCards > 0 and movingCards[#movingCards].moveDelay) or 0
    if animationTimer >= (0.5 + lastDelay) then
      animationPhase = "show_hand_fadein"
      animationTimer = 0
      handAlpha = 0
    end
  elseif animationPhase == "show_hand_fadein" then
    animationTimer = animationTimer + dt
    local t = math.min(animationTimer / 0.5, 1)
    handAlpha = easeInOutQuad(t)
    if animationTimer >= 0.5 then
      animationPhase = "show_hand_hold"
      animationTimer = 0
    end
  elseif animationPhase == "show_hand_hold" then
    animationTimer = animationTimer + dt
    if animationTimer >= 2 then
      animationPhase = "slide_off"
      animationTimer = 0
      for i, card in ipairs(movingCards) do
        card.slideDelay = (i - 1) * 0.07
        card.slideTimer = 0
      end
    end
  elseif animationPhase == "slide_off" then
    local allDone = true
    for _, card in ipairs(movingCards) do
      card.slideTimer = card.slideTimer + dt
      if card.slideTimer >= card.slideDelay then
        local localT = math.min((card.slideTimer - card.slideDelay) / 0.5, 1)
        local eased = easeInOutQuad(localT)
        card.x = card.x + ((windowWidth + cardWidth) - card.x) * eased
      else
        allDone = false
      end
      if card.slideTimer < card.slideDelay + 0.5 then
        allDone = false
      end
    end
    if allDone then
      local tCards = cardManager.getTableCards()
      for i = #tCards, 1, -1 do
        for _, mcard in ipairs(movingCards) do
          if tCards[i] == mcard then
            table.remove(tCards, i)
          end
        end
      end
      movingCards = {}
      totalScore = totalScore + lastHandScore
      if not handProcessed then
        handsRemaining = handsRemaining - 1
        handProcessed = true
        debugModule.addAlert("Hand processed. New handsRemaining: " .. handsRemaining .. "\n\n----------")
      end
      if handsRemaining <= 0 then
        animationPhase = "final_fade_out"
        animationTimer = 0
      else
        local missing = MAX_DISPLAYED - #cardManager.getTableCards()
        if missing > 0 then
          cardManager.dealCards(missing, tableStartY, cardWidth, cardHeight, cardSpacing, windowWidth)
        end
        animationPhase = nil
        handProcessed = false
      end
    end
  elseif animationPhase == "final_fade_out" then
    animationTimer = animationTimer + dt
    fadeAlpha = 1 - math.min(animationTimer / 0.5, 1)
    if animationTimer >= 0.5 then
      animationPhase = "game_over"
      animationTimer = 0
      fadeAlpha = 1
      gameOver = true
      debugModule.addAlert("Game Over reached\n\n----------")
    end
  elseif animationPhase == "discard" then
    animationTimer = animationTimer + dt
    local allDiscarded = true
    for i, card in ipairs(cardManager.getTableCards()) do
      if card.discardDelay and card.discardStartY then
        if animationTimer >= card.discardDelay then
          local localT = math.min((animationTimer - card.discardDelay) / 0.3, 1)
          local eased = easeInOutQuad(localT)
          card.y = card.discardStartY + ((windowHeight + card.height) - card.discardStartY) * eased
          if localT < 1 then
            allDiscarded = false
          end
        else
          allDiscarded = false
        end
      end
    end
    if allDiscarded then
      local tCards = cardManager.getTableCards()
      local discardCards = {}
      for i = #tCards, 1, -1 do
        if tCards[i].discardDelay then
          table.insert(discardCards, table.remove(tCards, i))
        end
      end
      local numDiscarded = #discardCards
      debugModule.addAlert("Discard complete. numDiscarded: " .. numDiscarded .. "\n\n----------")
      if numDiscarded > 0 then
        cardManager.dealCards(numDiscarded, tableStartY, cardWidth, cardHeight, cardSpacing, windowWidth)
      end
      animationPhase = nil
      handProcessed = false
    end
  end
  
  for _, card in ipairs(cardManager.getTableCards()) do
    if card.animatingNew then
      card.animationTimer = card.animationTimer + dt
      local t = math.min(card.animationTimer / card.animationDuration, 1)
      local eased = easeInOutQuad(t)
      card.y = card.startY + (card.targetY - card.startY) * eased
      if t >= 1 then
        card.animatingNew = false
      end
    end
  end
  
  -- Update positions for non-animating cards (cards in discard animation are skipped in updatePositions).
  cardManager.updatePositions(tableStartY, cardWidth, cardHeight, cardSpacing, windowWidth)
end

function love.draw()
  if gameOver then
    love.graphics.setColor(1, 1, 1, config.BKG_GAME_OVER_OPACITY)
  else
    love.graphics.setColor(1, 1, 1, config.BKG_MAIN_OPACITY)
  end
  love.graphics.draw(backgroundImage, 0, 0, 0, windowWidth / backgroundImage:getWidth(), windowHeight / backgroundImage:getHeight())
  love.graphics.setColor(1, 1, 1, 1)
  
  if not gameOver then
    love.graphics.setColor(1, 1, 1, fadeAlpha)
    local headerW = headerImage:getWidth() * config.HEADER_SCALE
    local headerH = headerImage:getHeight() * config.HEADER_SCALE
    local headerX = (windowWidth - headerW) / 2
    local headerY = 10
    love.graphics.draw(headerImage, headerX, headerY, 0, config.HEADER_SCALE, config.HEADER_SCALE)
    
    love.graphics.setFont(scoreFont)
    local handsText = "Hands Remaining: " .. handsRemaining
    local scoreText = "Total Score: " .. totalScore
    local handsW = scoreFont:getWidth(handsText)
    local scoreW = scoreFont:getWidth(scoreText)
    local centerX = headerX + headerW / 2
    love.graphics.print(handsText, centerX - handsW / 2, headerY + headerH + 10)
    love.graphics.print(scoreText, centerX - scoreW / 2, headerY + headerH + 10 + scoreFont:getHeight() + 5)
    love.graphics.setFont(cardFont)
    
    for i = 1, #cardManager.getDeck() do
      local offsetX = (i - 1) * 1
      local offsetY = (i - 1) * 1
      love.graphics.draw(cardBackImage, deckRect.x + offsetX, deckRect.y + offsetY, 0, config.CARD_SCALE, config.CARD_SCALE)
    end
    drawDeckCount()
    
    for _, card in ipairs(cardManager.getTableCards()) do
      love.graphics.draw(card.image, card.x, card.y, 0, config.CARD_SCALE, config.CARD_SCALE)
    end
    
    love.graphics.setColor(1, 1, 1, _G.discardOpacity or 1)
    love.graphics.draw(discardButtonImage, discardButton.x, discardButton.y, 0, config.BUTTON_SCALE, config.BUTTON_SCALE)
    love.graphics.setColor(1, 1, 1, _G.playOpacity or 1)
    love.graphics.draw(playButtonImage, playButton.x, playButton.y, 0, config.BUTTON_SCALE, config.BUTTON_SCALE)
    love.graphics.setColor(1, 1, 1, 1)
    
    if animationPhase == "show_hand_fadein" or animationPhase == "show_hand_hold" or animationPhase == "show_hand_fadeout" then
      love.graphics.setColor(1, 1, 1, handAlpha * fadeAlpha)
      local text = _G.handResult or ""
      local textWidth = cardFont:getWidth(text)
      love.graphics.print(text, (windowWidth - textWidth) / 2, windowHeight / 2 + cardHeight / 2 + 10)
      love.graphics.setColor(1, 1, 1, 1)
    end
  else
    gameOverModule.draw(windowWidth, windowHeight, gameOverImage, cardFont, totalScore, startOverButton, fadeAlpha, startOverBobTime, startOverButtonImage)
  end
  
  debugModule.draw()
end

function love.mousepressed(x, y, button)
  debugModule.addAlert("Mouse pressed at (" .. x .. ", " .. y .. ")\n\n----------")
  if button == 1 then
    if not gameOver then
      if x >= playButton.x and x <= playButton.x + playButton.width and y >= playButton.y and y <= playButton.y + playButton.height then
        debugModule.addAlert("Play Button clicked\n\n----------")
        playHand()
        return
      end
      if x >= discardButton.x and x <= discardButton.x + discardButton.width and y >= discardButton.y and y <= discardButton.y + discardButton.height then
        if animationPhase then 
          debugModule.addAlert("Discard ignored: animation in progress\n\n----------")
          return 
        end
        local discardCount = 0
        for _, card in ipairs(cardManager.getTableCards()) do
          if card.selected then
            discardCount = discardCount + 1
          end
        end
        if discardCount > 0 then
          animationPhase = "discard"
          animationTimer = 0
          for i, card in ipairs(cardManager.getTableCards()) do
            if card.selected then
              card.discardDelay = (i - 1) * 0.07
              card.discardStartY = card.y
              card.selected = false
            end
          end
          debugModule.addAlert("Discard Button clicked. Discard count: " .. discardCount .. "\n\n----------")
        end
        return
      end
      for _, card in ipairs(cardManager.getTableCards()) do
        if x >= card.x and x <= card.x + card.width and y >= card.y and y <= card.y + card.height then
          debugModule.addAlert("Card clicked with rank: " .. tostring(card.rank) .. "\n\n----------")
          toggleCard(card)
          break
        end
      end
    else
      if x >= startOverButton.x and x <= startOverButton.x + startOverButton.width and y >= startOverButton.y and y <= startOverButton.y + startOverButton.height then
        debugModule.addAlert("Restart Button clicked\n\n----------")
        love.load()  -- Restart the game
      end
    end
  end
end

function toggleCard(card)
  debugModule.addAlert("toggleCard called for card rank: " .. tostring(card.rank) .. "\n\n----------")
  if card.selected then
    card.selected = false
  else
    local count = 0
    for _, c in ipairs(cardManager.getTableCards()) do
      if c.selected then
        count = count + 1
      end
    end
    if count < 5 then
      card.selected = true
    end
  end
  cardManager.updatePositions(tableStartY, cardWidth, cardHeight, cardSpacing, windowWidth)
end

function playHand()
  if animationPhase or handProcessed then 
    debugModule.addAlert("playHand aborted: animation in progress or hand already processed\n\n----------")
    return 
  end
  local selectedCards = {}
  for i, card in ipairs(cardManager.getTableCards()) do
    if card.selected then
      table.insert(selectedCards, card)
      card.selected = false  -- clear selection on play
    end
  end
  if #selectedCards == 0 then
    _G.handResult = "No cards selected!"
    return
  end
  movingCards = {}
  for i, card in ipairs(selectedCards) do
    card.isAnimating = true
    card.startX = card.x
    card.startY = card.y
    card.moveDelay = (i - 1) * 0.07
    table.insert(movingCards, card)
  end
  local count = #movingCards
  local totalWidth = count * cardWidth + (count - 1) * cardSpacing
  local targetStartX = (windowWidth - totalWidth) / 2
  for i, card in ipairs(movingCards) do
    card.targetX = targetStartX + (i - 1) * (cardWidth + cardSpacing)
    card.targetY = windowHeight / 2 - cardHeight / 2
  end
  _G.handResult = evaluateHand(selectedCards)
  animationPhase = "move_to_center"
  animationTimer = 0
  debugModule.addAlert("playHand triggered with " .. tostring(#movingCards) .. " cards\n\n----------")
end

function evaluateHand(cards)
  local count = #cards
  local handType = ""
  local score = 0
  local freq = {}
  for _, card in ipairs(cards) do
    freq[card.rank] = (freq[card.rank] or 0) + 1
  end
  local counts = {}
  for _, cnt in pairs(freq) do
    table.insert(counts, cnt)
  end
  table.sort(counts, function(a, b) return a > b end)
  if count == 5 then
    local flush = true
    local firstSuit = cards[1].suit
    for i = 2, 5 do
      if cards[i].suit ~= firstSuit then
        flush = false
        break
      end
    end
    local rankValues = { ["02"] = 2, ["03"] = 3, ["04"] = 4, ["05"] = 5, ["06"] = 6, ["07"] = 7, ["08"] = 8, ["09"] = 9, ["10"] = 10, ["J"] = 11, ["Q"] = 12, ["K"] = 13, ["A"] = 14 }
    local vals = {}
    for _, card in ipairs(cards) do
      table.insert(vals, rankValues[card.rank])
    end
    table.sort(vals)
    local straight = true
    for i = 2, #vals do
      if vals[i] ~= vals[i - 1] + 1 then
        straight = false
        break
      end
    end
    if flush and straight then
      if vals[1] == 10 then
        handType = "Royal Straight Flush"
        score = 100
      else
        handType = "Straight Flush"
        score = 90
      end
    elseif counts[1] == 4 then
      handType = "Four of a Kind"
      score = 80
    elseif counts[1] == 3 and counts[2] == 2 then
      handType = "Full House"
      score = 70
    elseif flush then
      handType = "Flush"
      score = 60
    elseif straight then
      handType = "Straight"
      score = 50
    elseif counts[1] == 3 then
      handType = "Three of a Kind"
      score = 40
    elseif counts[1] == 2 and #counts >= 2 and counts[2] == 2 then
      handType = "Two Pair"
      score = 30
    elseif counts[1] == 2 then
      handType = "Pair"
      score = 20
    else
      handType = "High Card"
      score = 10
    end
  else
    if counts[1] == 4 then
      handType = "Four of a Kind"
      score = 80
    elseif counts[1] == 3 then
      handType = "Three of a Kind"
      score = 40
    elseif counts[1] == 2 and #counts >= 2 and counts[2] == 2 then
      handType = "Two Pair"
      score = 30
    elseif counts[1] == 2 then
      handType = "Pair"
      score = 20
    else
      handType = "High Card"
      score = 10
    end
  end
  lastHandScore = score
  return handType .. " (" .. score .. " points)"
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