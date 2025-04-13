-- gameOver.lua
local gameOver = {}
local config = require "scripts.config"

-- Draw the Game Over scene.
-- This function draws the Game Over and Restart images side by side using new scale factors,
-- recalculates the clickable area for Restart, and displays the total score in a larger font with a rounded outline.
function gameOver.draw(windowWidth, windowHeight, gameOverImage, cardFont, totalScore, startOverButton, sceneAlpha, bobTime, restartImage)
  love.graphics.setColor(1, 1, 1, sceneAlpha)
  
  -- New scale factors:
  local gameOverScale = 0.25   -- Game Over image reduced by 50% (from a base 50% scale)
  local restartScale = 0.15    -- Restart image reduced by 70% (from a base 50% scale)
  local marginBetween = 50     -- Horizontal margin between the images
  
  local goW = gameOverImage:getWidth() * gameOverScale
  local goH = gameOverImage:getHeight() * gameOverScale
  local rsW = restartImage:getWidth() * restartScale
  local rsH = restartImage:getHeight() * restartScale
  
  local totalImagesWidth = goW + rsW + marginBetween
  local startX = (windowWidth - totalImagesWidth) / 2
  local imageY = windowHeight / 2 - math.max(goH, rsH) / 2
  
  -- Draw the Game Over image on the left.
  love.graphics.draw(gameOverImage, startX, imageY, 0, gameOverScale, gameOverScale)
  
  -- Draw the Restart image on the right.
  local restartX = startX + goW + marginBetween
  local restartY = imageY
  love.graphics.draw(restartImage, restartX, restartY, 0, restartScale, restartScale)
  
  -- Update the restart clickable area to match the drawn image.
  startOverButton.x = restartX
  startOverButton.y = restartY
  startOverButton.width = rsW
  startOverButton.height = rsH
  
  -- Increase the total score font size and draw it with a rounded outline.
  local totalScoreFont = love.graphics.newFont(48)
  love.graphics.setFont(totalScoreFont)
  local scoreText = "Total Score: " .. totalScore
  local textWidth = totalScoreFont:getWidth(scoreText)
  local textHeight = totalScoreFont:getHeight(scoreText)
  local padding = 10
  local boxWidth = textWidth + padding * 2
  local boxHeight = textHeight + padding * 2
  local boxX = (windowWidth - boxWidth) / 2
  local boxY = imageY + math.max(goH, rsH) + 30
  
  love.graphics.setLineWidth(3)
  love.graphics.setLineJoin("bevel")
  love.graphics.rectangle("line", boxX, boxY, boxWidth, boxHeight, 8, 8)
  love.graphics.print(scoreText, boxX + padding, boxY + padding)
  
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setFont(cardFont)
end

return gameOver