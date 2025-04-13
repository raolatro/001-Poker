-- cardManager.lua
local cardManager = {}
local config = require "scripts.config"

local deck = {}         -- holds remaining cards
local tableCards = {}   -- holds cards currently on table

-- A very simple CSV parser to split lines and commas
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

-- Load cards from the CSV file
function cardManager.loadDeck()
  deck = {}
  local data = love.filesystem.read(config.CARDS_CSV)
  local lines = parseCSV(data)
  -- Assume first line is header: filename,suit,rank,rarity
  for i = 2, #lines do
    local row = lines[i]
    local card = {
      filename = row[1],
      suit = row[2],
      rank = row[3],
      rarity = row[4] or "common"
    }
    -- Load the card image; file path relative to project root
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

-- Fisher–Yates shuffle
function cardManager.shuffleDeck()
  for i = #deck, 2, -1 do
    local j = math.random(i)
    deck[i], deck[j] = deck[j], deck[i]
  end
end

-- Deal n cards from the deck into tableCards and update positions
function cardManager.dealCards(n, tableStartY, cardWidth, cardHeight, cardSpacing, windowWidth)
  for i = 1, n do
    if #deck > 0 then
      local card = table.remove(deck, 1)
      card.selected = false
      card.isAnimating = false
      card.discardDelay = nil
      card.discardStartY = nil
      table.insert(tableCards, card)
    end
  end
  cardManager.updatePositions(tableStartY, cardWidth, cardHeight, cardSpacing, windowWidth)
end

-- Update positions of cards in tableCards only if they are not animating or discarding.
function cardManager.updatePositions(tableStartY, cardWidth, cardHeight, cardSpacing, windowWidth)
  local n = #tableCards
  local totalWidth = n * cardWidth + (n - 1) * cardSpacing
  local startX = (windowWidth - totalWidth) / 2
  for i, card in ipairs(tableCards) do
    -- Only update if the card is not animating AND not in a discard animation.
    if not card.isAnimating and not card.discardDelay then
      card.x = startX + (i - 1) * (cardWidth + cardSpacing)
      card.baseY = tableStartY
      if card.selected then
        card.y = card.baseY - 20
      else
        card.y = card.baseY
      end
      card.width = cardWidth
      card.height = cardHeight
    end
  end
end

-- Reset the deck (reload from CSV, shuffle) and clear tableCards.
function cardManager.resetDeck()
  cardManager.loadDeck()
  cardManager.shuffleDeck()
  tableCards = {}
end

return cardManager