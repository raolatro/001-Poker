-- debug.lua
local debugModule = {}
local config = require "scripts.config"

-- Store alerts as a table of { timestamp, text }
local alerts = {}

-- Add a new debug alert; each alert lasts 10 seconds.
function debugModule.addAlert(text)
  table.insert(alerts, { timestamp = love.timer.getTime(), text = text })
end

-- Draw alerts in the top-left corner, one per line.
function debugModule.draw()
  if not config.DEBUG_MODE then return end
  local font = love.graphics.newFont(12)
  love.graphics.setFont(font)
  love.graphics.setColor(1, 0, 0, 1)  -- red color
  
  local currentTime = love.timer.getTime()
  local y = 10
  for i = #alerts, 1, -1 do
    local alert = alerts[i]
    if currentTime - alert.timestamp > 10 then
      table.remove(alerts, i)
    else
      love.graphics.print(alert.text, 10, y)
      y = y + font:getHeight() + 2
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

return debugModule