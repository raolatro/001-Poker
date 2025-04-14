-- uiEffects.lua
local uiEffects = {}
local config = require "scripts.config"

function uiEffects.updateHover(dt, isHovered, hoverTimer)
  if hoverTimer == nil then
    hoverTimer = 0
  end
  if isHovered then
    hoverTimer = math.min(hoverTimer + dt, config.HOVER_DURATION)
  else
    hoverTimer = math.max(hoverTimer - dt, 0)
  end
  return hoverTimer
end

function uiEffects.getHoverOpacity(hoverTimer)
  if hoverTimer == nil then
    hoverTimer = 0
  end
  return 1 - (hoverTimer / config.HOVER_DURATION) * 0.2
end

function uiEffects.applyHoverEffect(x, y, width, height, mx, my)
  if mx >= x and mx <= x + width and my >= y and my <= y + height then
    local centerX = x + width / 2
    local centerY = y + height / 2
    local dx = mx - centerX
    local dy = my - centerY
    local mag = math.sqrt(dx * dx + dy * dy)
    if mag > 0 then
      dx = dx / mag
      dy = dy / mag
    end
    local newX = x - dx * config.REPEL_OFFSET
    local newY = y - dy * config.REPEL_OFFSET
    local scale = 1 + config.HOVER_SCALE_INCREASE
    return newX, newY, scale
  end
  return x, y, 1
end

return uiEffects