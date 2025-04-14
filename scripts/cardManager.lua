-- cardManager.lua
local cardManager = {}
local config = require "scripts.config"

local deck = {}         -- holds remaining cards
local tableCards = {}   -- holds cards currently on table

local function parseCSV(data)
  local result = {}
  for line in data:gmatch("[^\r\n]+") do
    local fields = {}
    for field in line:gmatch("([^,]+)") do
      table.insert(fields, field)
    end
    table.insert(result, fields)
  end
  return result
end

function cardManager.loadDeck()
  deck = {}
  local data = love.filesystem.read(config.CARDS_CSV)
  local lines = parseCSV(data)
  for i = 2, #lines do
    local row = lines[i]
    local card = {
      filename = row[1],
      suit = row[2],
      rank = row[3],
      rarity = row[4]
    }
    card.image = love.graphics.newImage("/src/img/cards/" .. card.filename)
    table.insert(deck, card)
  end
end

function cardManager.getDeck()
  return deck
end

function cardManager.getTableCards()
  return tableCards
end

function cardManager.shuffleDeck()
  for i = #deck, 2, -1 do
    local j = math.random(i)
    deck[i], deck[j] = deck[j], deck[i]
  end
end

function cardManager.dealCards(n, tableStartY, cardWidth, cardHeight, cardSpacing, windowWidth, deckRect)
  n = tonumber(n) or 0
  local startIndex = #tableCards + 1
  for i = 1, n do
    if #deck > 0 then
      local card = table.remove(deck, 1)
      card.selected = false
      card.isAnimating = false
      card.discardDelay = nil
      card.discardStartY = nil
      -- For draw animation:
      card.newlyDrawn = true
      card.drawAnimTimer = 0
      card.drawAnimDuration = 0.5  -- increased duration for a smoother animation
      card.drawAnimDelay = (i - 1) * 0.09   -- 0.09-second stagger delay
      card.drawPlayed = false
      card.startDrawX = deckRect.x
      card.startDrawY = deckRect.y
      card.startRotation = math.pi       -- 180º start rotation
      card.drawTargetRotation = 0
      card.rotation = card.startRotation
      table.insert(tableCards, card)
    end
  end
  cardManager.updatePositions(tableStartY, cardWidth, cardHeight, cardSpacing, windowWidth)
  -- For newly drawn cards, preserve their target positions but do not overwrite their current (animated) position.
  for i, card in ipairs(tableCards) do
    if card.newlyDrawn then
      card.drawTargetX = card.x
      card.drawTargetY = card.y
      -- Leave card.x and card.y as set from the deck (startDrawX,startDrawY)
    end
  end
end

function cardManager.updatePositions(tableStartY, cardWidth, cardHeight, cardSpacing, windowWidth)
  local n = #tableCards
  local totalWidth = n * cardWidth + (n - 1) * cardSpacing
  local startX = (windowWidth - totalWidth) / 2
  for i, card in ipairs(tableCards) do
    local posX = startX + (i - 1) * (cardWidth + cardSpacing)
    local posY = tableStartY
    if card.newlyDrawn then
      card.drawTargetX = posX
      card.drawTargetY = posY
      -- Do NOT modify card.x, so the draw animation continues.
    else
      card.x = posX
      card.y = posY
    end
    card.baseY = posY
    if card.selected and not card.newlyDrawn then
      card.y = posY - 20
    end
    card.width = cardWidth
    card.height = cardHeight
  end
end

function cardManager.resetDeck()
  cardManager.loadDeck()
  cardManager.shuffleDeck()
  tableCards = {}
end

return cardManager