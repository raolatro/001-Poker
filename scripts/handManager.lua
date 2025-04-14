-- handManager.lua
local handManager = {}
local cardManager = require "scripts.cardManager"
local evaluateHandModule = require "scripts.evaluateHand"
local config = require "scripts.config"
local debugModule = require "scripts.debug"
local MAX_DISPLAYED = 8  -- max cards displayed on table

local movingCards = {}  -- cards being animated (play/discard)

handManager.animationPhase = nil
handManager.animationTimer = 0
handManager.handAlpha = 0
handManager.fadeAlpha = 1
handManager.lastHandScore = 0
handManager.totalScore = 0
handManager.handsRemaining = 3
handManager.handProcessed = false

local function easeInOutQuad(t)
  if t < 0.5 then return 2 * t * t else return -1 + (4 - 2 * t) * t end
end

-- Toggle selection for a card.
function handManager.toggleCard(card, tableStartY, cardWidth, cardHeight, cardSpacing, windowWidth)
  debugModule.addAlert("toggleCard called for card rank: " .. tostring(card.rank) .. "\n\n----------")
  if card.selected then
    card.selected = false
  else
    local count = 0
    for _, c in ipairs(cardManager.getTableCards()) do
      if c.selected then count = count + 1 end
    end
    if count < 5 then card.selected = true end
  end
  cardManager.updatePositions(tableStartY, cardWidth, cardHeight, cardSpacing, windowWidth)
end

-- Play hand: animate selected cards from current position to center with a spin.
function handManager.playHand(tableStartY, cardWidth, cardHeight, cardSpacing, windowWidth, windowHeight, deckRect)
  if handManager.animationPhase or handManager.handProcessed then 
    debugModule.addAlert("playHand aborted: animation in progress or hand already processed\n\n----------")
    return false
  end
  local selectedCards = {}
  for _, card in ipairs(cardManager.getTableCards()) do
    if card.selected then
      table.insert(selectedCards, card)
      card.selected = false
    end
  end
  if #selectedCards == 0 then
    _G.handResult = "No cards selected!"
    return false
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
  local handResult, score = evaluateHandModule.evaluate(selectedCards)
  _G.handResult = handResult
  handManager.lastHandScore = score
  handManager.animationPhase = "move_to_center"
  handManager.animationTimer = 0
  debugModule.addAlert("playHand triggered with " .. tostring(#movingCards) .. " cards\n\n----------")
  return true
end

-- Discard hand: animate discard for selected cards.
function handManager.discardHand(tableStartY, cardWidth, cardHeight, windowHeight, windowWidth)
  if handManager.animationPhase then
    debugModule.addAlert("Discard aborted: animation in progress\n\n----------")
    return false
  end
  local discardCount = 0
  for _, card in ipairs(cardManager.getTableCards()) do
    if card.selected then discardCount = discardCount + 1 end
  end
  if discardCount > 0 then
    handManager.animationPhase = "discard"
    handManager.animationTimer = 0
    for i, card in ipairs(cardManager.getTableCards()) do
      if card.selected then
        card.discardDelay = (i - 1) * 0.07
        card.discardStartY = card.y
        card.selected = false
        card.discardPlayed = false
      end
    end
    debugModule.addAlert("Discard action triggered. Discard count: " .. discardCount .. "\n\n----------")
    return true
  end
  return false
end

-- Sorting function: rearrange cards by rank or suit.
function handManager.sortCards(criteria, windowWidth, cardWidth, cardSpacing)
  local cards = cardManager.getTableCards()
  if criteria == "rank" then
    table.sort(cards, function(a, b) return a.rank < b.rank end)
  elseif criteria == "suit" then
    table.sort(cards, function(a, b) return a.suit < b.suit end)
  end
  local totalWidth = #cards * cardWidth + (#cards - 1) * cardSpacing
  local startX = (windowWidth - totalWidth) / 2
  for i, card in ipairs(cards) do
    card.sortAnimDelay = (i - 1) * 0.05
    card.sortAnimTimer = 0
    card.sortStartX = card.x
    card.sortTargetX = startX + (i - 1) * (cardWidth + cardSpacing)
    card.sortAnimating = true
    local dsfx = love.audio.newSource(config.CARD_DISCARD_SFX, "static")
    dsfx:setVolume(config.SFX_VOLUME)
    dsfx:play()
    debugModule.addAlert("Sorting card (" .. card.rank .. ") with delay: " .. card.sortAnimDelay)
  end
end

-- Update animations (for play/discard/sort)
function handManager.updateAnimations(dt, windowWidth, windowHeight, cardWidth, tableStartY, cardSpacing)
  if handManager.animationPhase == "move_to_center" then
    handManager.animationTimer = handManager.animationTimer + dt
    for _, card in ipairs(cardManager.getTableCards()) do
      if card.isAnimating then
        local delay = card.moveDelay or 0
        if handManager.animationTimer >= delay then
          local localT = math.min((handManager.animationTimer - delay) / 0.5, 1)
          local eased = easeInOutQuad(localT)
          card.x = card.startX + (card.targetX - card.startX) * eased
          card.y = card.startY + (card.targetY - card.startY) * eased
          card.rotation = card.startRotation + (card.drawTargetRotation - card.startRotation) * eased
        end
      end
    end
    local lastDelay = (#movingCards > 0 and movingCards[#movingCards].moveDelay) or 0
    if handManager.animationTimer >= (0.5 + lastDelay) then
      handManager.animationPhase = "show_hand_fadein"
      handManager.animationTimer = 0
      handManager.handAlpha = 0
    end
  elseif handManager.animationPhase == "show_hand_fadein" then
    handManager.animationTimer = handManager.animationTimer + dt
    local t = math.min(handManager.animationTimer / 0.5, 1)
    handManager.handAlpha = easeInOutQuad(t)
    if handManager.animationTimer >= 0.5 then
      handManager.animationPhase = "show_hand_hold"
      handManager.animationTimer = 0
    end
  elseif handManager.animationPhase == "show_hand_hold" then
    handManager.animationTimer = handManager.animationTimer + dt
    if handManager.animationTimer >= 2 then
      handManager.animationPhase = "slide_off"
      handManager.animationTimer = 0
      for i, card in ipairs(movingCards) do
        card.slideDelay = (i - 1) * 0.05
        card.slideTimer = 0
      end
    end
  elseif handManager.animationPhase == "slide_off" then
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
      if card.slideTimer < card.slideDelay + 0.5 then allDone = false end
    end
    if allDone then
      local tCards = cardManager.getTableCards()
      for i = #tCards, 1, -1 do
        for _, mcard in ipairs(movingCards) do
          if tCards[i] == mcard then table.remove(tCards, i) end
        end
      end
      movingCards = {}
      handManager.totalScore = handManager.totalScore + handManager.lastHandScore
      if not handManager.handProcessed then
        handManager.handsRemaining = handManager.handsRemaining - 1
        handManager.handProcessed = true
        debugModule.addAlert("Hand processed. New handsRemaining: " .. handManager.handsRemaining .. "\n\n----------")
      end
      if handManager.handsRemaining <= 0 then
        handManager.animationPhase = "final_fade_out"
        handManager.animationTimer = 0
      else
        local missing = MAX_DISPLAYED - #cardManager.getTableCards()
        if missing > 0 then
          cardManager.dealCards(missing, tableStartY, cardWidth, cardHeight, cardSpacing, windowWidth)
        end
        handManager.animationPhase = nil
        handManager.handProcessed = false
      end
    end
  elseif handManager.animationPhase == "final_fade_out" then
    handManager.animationTimer = handManager.animationTimer + dt
    handManager.fadeAlpha = 1 - math.min(handManager.animationTimer / 0.5, 1)
    if handManager.animationTimer >= 0.5 then
      handManager.animationPhase = "game_over"
      handManager.animationTimer = 0
      handManager.fadeAlpha = 1
      _G.gameOver = true
      debugModule.addAlert("Game Over reached\n\n----------")
    end
  elseif handManager.animationPhase == "discard" then
    handManager.animationTimer = handManager.animationTimer + dt
    local allDiscarded = true
    for i, card in ipairs(cardManager.getTableCards()) do
      if card.discardDelay and card.discardStartY then
        if handManager.animationTimer >= card.discardDelay then
          local localT = math.min((handManager.animationTimer - card.discardDelay) / 0.3, 1)
          local eased = easeInOutQuad(localT)
          card.y = card.discardStartY + ((windowHeight + card.height) - card.discardStartY) * eased
          if not card.discardPlayed then
            local dsfx = love.audio.newSource(config.CARD_DISCARD_SFX, "static")
            dsfx:setVolume(config.SFX_VOLUME)
            dsfx:play()
            card.discardPlayed = true
          end
          if localT < 1 then allDiscarded = false end
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
      handManager.animationPhase = nil
      handManager.handProcessed = false
    end
  end
  
  -- Update sorting animations (if any)
  for _, card in ipairs(cardManager.getTableCards()) do
    if card.sortAnimating then
      card.sortAnimTimer = card.sortAnimTimer + dt
      if card.sortAnimTimer >= card.sortAnimDelay then
        local t = math.min((card.sortAnimTimer - card.sortAnimDelay) / 0.5, 1)
        local eased = easeInOutQuad(t)
        card.x = card.sortStartX + (card.sortTargetX - card.sortStartX) * eased
        if t >= 1 then
          card.sortAnimating = false
        end
      end
    end
  end
end

function handManager.sortCards(criteria, windowWidth, cardWidth, cardSpacing)
  local cards = cardManager.getTableCards()
  if criteria == "rank" then
    table.sort(cards, function(a, b) return a.rank < b.rank end)
  elseif criteria == "suit" then
    table.sort(cards, function(a, b) return a.suit < b.suit end)
  end
  local totalWidth = #cards * cardWidth + (#cards - 1) * cardSpacing
  local startX = (windowWidth - totalWidth) / 2
  for i, card in ipairs(cards) do
    card.sortAnimDelay = (i - 1) * 0.05
    card.sortAnimTimer = 0
    card.sortStartX = card.x
    card.sortTargetX = startX + (i - 1) * (cardWidth + cardSpacing)
    card.sortAnimating = true
    local dsfx = love.audio.newSource(config.CARD_DISCARD_SFX, "static")
    dsfx:setVolume(config.SFX_VOLUME)
    dsfx:play()
    debugModule.addAlert("Sorting card (" .. card.rank .. ") with delay: " .. card.sortAnimDelay)
  end
end

handManager.toggleCard = handManager.toggleCard
handManager.playHand = handManager.playHand
handManager.discardHand = handManager.discardHand
handManager.updateAnimations = handManager.updateAnimations
handManager.sortCards = handManager.sortCards

return handManager