-- evaluateHand.lua
local evaluateHand = {}
local config = require "scripts.config"

local pointsData = {}

local function trim(s)
  return s:match("^%s*(.-)%s*$")
end

function evaluateHand.loadPoints()
  pointsData = {}
  local data = love.filesystem.read(config.POINTS_CSV)
  for line in data:gmatch("[^\r\n]+") do
    local hand, scoreStr = line:match("([^,]+),(.+)")
    if hand and scoreStr then
      hand = trim(hand)
      scoreStr = trim(scoreStr)
      pointsData[hand] = tonumber(scoreStr)
    end
  end
end

function evaluateHand.evaluate(cards)
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
      if vals[i] ~= vals[i-1] + 1 then
        straight = false
        break
      end
    end
    if flush and straight then
      if vals[1] == 10 then
        handType = "Royal Straight Flush"
      else
        handType = "Straight Flush"
      end
    elseif counts[1] == 4 then
      handType = "Four of a Kind"
    elseif counts[1] == 3 and counts[2] == 2 then
      handType = "Full House"
    elseif flush then
      handType = "Flush"
    elseif straight then
      handType = "Straight"
    elseif counts[1] == 3 then
      handType = "Three of a Kind"
    elseif counts[1] == 2 and #counts >= 2 and counts[2] == 2 then
      handType = "Two Pair"
    elseif counts[1] == 2 then
      handType = "Pair"
    else
      handType = "High Card"
    end
  else
    if counts[1] == 4 then
      handType = "Four of a Kind"
    elseif counts[1] == 3 then
      handType = "Three of a Kind"
    elseif counts[1] == 2 and #counts >= 2 and counts[2] == 2 then
      handType = "Two Pair"
    elseif counts[1] == 2 then
      handType = "Pair"
    else
      handType = "High Card"
    end
  end

  score = pointsData[handType] or 0
  return handType .. " (" .. score .. " points)", score
end

return evaluateHand