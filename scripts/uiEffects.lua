-- uiEffects.lua
local uiEffects = {}
local config = require "scripts.config"

-- Update the hover timer based on whether the element is hovered.
function uiEffects.updateHover(dt, isHovered, hoverTimer)
  if isHovered then
    hoverTimer = math.min(hoverTimer + dt, config.HOVER_DURATION)
  else
    hoverTimer = math.max(hoverTimer - dt, 0)
  end
  return hoverTimer
end

-- Convert hover timer into an opacity value (used for tinting effect)
function uiEffects.getHoverOpacity(hoverTimer)
  return 1 - (hoverTimer / config.HOVER_DURATION) * 0.2
end

-- Apply a repel effect and slight scale increase when the mouse is over an element.
-- Returns new x, y positions and scale factor.
function uiEffects.applyHoverEffect(x, y, width, height, mx, my)
  if mx >= x and mx <= x + width and my >= y and my <= y + height then
    local centerX = x + width / 2
    local centerY = y + height / 2
    local dx = mx - centerX
    local dy = my - centerY
    local mag = math.sqrt(dx * dx + dy * dy)
    if mag ~= 0 then
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