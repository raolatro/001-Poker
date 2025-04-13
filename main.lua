-- main.lua

-- Global game state
local deck = {}         -- remaining deck (table of card objects)
local tableCards = {}   -- cards currently shown on the table (max 10)
local handResult = ""   -- text showing the hand evaluation
local playButton = {}         -- table for the Play button (image)
local discardButton = {}      -- table for the Discard button (image)

-- Animation variables
local animationPhase = nil      -- phases: "move_to_center", "show_hand_fadein", "show_hand_hold", "slide_off", "deal_new", "discard", "game_over"
local animationTimer = 0
local movingCards = {}          -- currently animated selected cards
local handAlpha = 0             -- alpha for hand result text

local function easeInOutQuad(t)
    if t < 0.5 then
        return 2 * t * t
    else
        return -1 + (4 - 2 * t) * t
    end
end

-- Layout variables
local windowWidth, windowHeight
local cardWidth, cardHeight, cardSpacing
local tableStartY              -- y position for displayed cards (bottom center)
local deckRect                 -- deck rectangle (for deck stack)

-- Images
local headerImage              -- header image for game title
local playButtonImage          -- image for Play button (natural size)
local discardButtonImage       -- image for Discard button (natural size)
local cardBackImage            -- card back image (also used to set card dimensions)
local gameOverImage            -- game over image
local startOverButtonImage     -- restart button image

-- Score variables
local totalScore = 0
local lastHandScore = 0

-- New game system variables
local handsRemaining = 3      -- total hands the player can play
local gameOver = false
local gameOverAlpha = 0       -- for fading in the game over screen

-- Scaling factors
local buttonScale = 0.3         -- Play & Discard buttons at 30% of natural size
local cardScale = 2             -- Cards and deck at 2x natural size
local headerScale = 0.4         -- Header at 40% of natural size
local startOverScale = 0.3      -- Restart button at 30% of natural size

local startOverButton = {}      -- restart button position

-- Layout setup: reduce overall screen size by 20% from 2560x1440 => 2048x1152
local function setLayout()
    windowWidth = 2048
    windowHeight = 1152
end

function love.load()
    setLayout()
    love.window.setMode(windowWidth, windowHeight, {resizable = true})
    math.randomseed(os.time())
    cardFont = love.graphics.newFont(32)
    love.graphics.setFont(cardFont)

    -- Load header, button, and game over images
    headerImage = love.graphics.newImage("/src/img/scene/main/raolatro.png")
    playButtonImage = love.graphics.newImage("/src/img/buttons/play_hand.png")
    discardButtonImage = love.graphics.newImage("/src/img/buttons/discard.png")
    gameOverImage = love.graphics.newImage("/src/img/scene/main/game_over.png")
    startOverButtonImage = love.graphics.newImage("/src/img/scene/main/start_over.png")

    -- Load card back image for deck
    cardBackImage = love.graphics.newImage("/src/img/cards/card_back.png")
    
    -- Set card dimensions to 2x natural size
    cardWidth = cardBackImage:getWidth() * cardScale
    cardHeight = cardBackImage:getHeight() * cardScale
    cardSpacing = 5  -- reduced horizontal spacing

    -- Position displayed cards at bottom center (150 pixels above bottom)
    tableStartY = windowHeight - cardHeight - 150

    -- Setup grouped Play & Discard buttons (scaled to 30% of natural size)
    local gap = 20
    local playW = playButtonImage:getWidth() * buttonScale
    local discardW = discardButtonImage:getWidth() * buttonScale
    local groupWidth = playW + discardW + gap
    local groupX = (windowWidth - groupWidth) / 2
    local groupY = tableStartY + cardHeight + 20
    discardButton = { x = groupX, y = groupY, width = discardW, height = discardButtonImage:getHeight() * buttonScale }
    playButton = { x = groupX + discardW + gap, y = groupY, width = playW, height = playButtonImage:getHeight() * buttonScale }

    -- Position deck at bottom-right with increased margin (e.g., 50)
    local deckMargin = 50
    deckRect = {
        x = windowWidth - cardWidth - deckMargin,
        y = windowHeight - cardHeight - deckMargin,
        width = cardWidth,
        height = cardHeight
    }

    -- Build a standard 52-card deck and load images for each card
    local ranks = {"02", "03", "04", "05", "06", "07", "08", "09", "10", "J", "Q", "K", "A"}
    local suits = {"Hearts", "Diamonds", "Clubs", "Spades"}
    for _, suit in ipairs(suits) do
        for _, rank in ipairs(ranks) do
            local card = {rank = rank, suit = suit}
            local filename = "card_" .. suit:lower() .. "_" .. rank .. ".png"
            card.image = love.graphics.newImage("/src/img/cards/" .. filename)
            table.insert(deck, card)
        end
    end
    shuffle(deck)
    dealCards(10)
    handResult = ""
    
    -- Initialize hands remaining and game over variables
    handsRemaining = 3
    gameOver = false
    gameOverAlpha = 0

    -- Setup start over button position (will be used in game over scene)
    local soW = startOverButtonImage:getWidth() * startOverScale
    local soH = startOverButtonImage:getHeight() * startOverScale
    startOverButton = { x = (windowWidth - soW) / 2, y = (windowHeight)/2 + 20, width = soW, height = soH }
end

-- Fisher-Yates shuffle
function shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
end

-- Deal n cards from the deck to tableCards and update positions.
function dealCards(n)
    for i = 1, n do
        if #deck > 0 then
            local card = table.remove(deck, 1)
            card.selected = false
            table.insert(tableCards, card)
        end
    end
    updateCardPositions()
end

-- Arrange positions of displayed cards in a centered horizontal row.
function updateCardPositions()
    local n = #tableCards
    local totalWidth = n * cardWidth + (n - 1) * cardSpacing
    local startX = (windowWidth - totalWidth) / 2
    for i, card in ipairs(tableCards) do
        if not card.isAnimating and not card.animatingNew and not card.discardDelay then
            card.x = startX + (i - 1) * (cardWidth + cardSpacing)
            card.baseY = tableStartY
            if card.selected then
                card.y = card.baseY - 20
            else
                card.y = card.baseY
            end
        else
            if card.x == nil then
                card.x = startX + (i - 1) * (cardWidth + cardSpacing)
            end
        end
        card.width = cardWidth
        card.height = cardHeight
    end
end

-- Draw everything: header, hands remaining, total score, deck, cards, buttons, hand result, or game over scene.
function love.draw()
    love.graphics.setColor(1, 1, 1)
    if not gameOver then
        -- Draw header image at top center (scaled to 40%)
        local headerW = headerImage:getWidth() * headerScale
        local headerH = headerImage:getHeight() * headerScale
        local headerX = (windowWidth - headerW) / 2
        local headerY = 10
        love.graphics.draw(headerImage, headerX, headerY, 0, headerScale, headerScale)

        -- Draw Hands Remaining (left aligned to header)
        local handsText = "Hands Remaining: " .. handsRemaining
        love.graphics.print(handsText, headerX, headerY + headerH + 20)
        -- Draw Total Score (right aligned to header)
        local scoreText = "Total Score: " .. totalScore
        local scoreW = cardFont:getWidth(scoreText)
        love.graphics.print(scoreText, headerX + headerW - scoreW, headerY + headerH + 20)

        -- Draw deck as a stacked pile at bottom-right
        for i = 1, #deck do
            local offsetX = (i - 1) * 1
            local offsetY = (i - 1) * 1
            love.graphics.draw(cardBackImage, deckRect.x + offsetX, deckRect.y + offsetY, 0, cardScale, cardScale)
        end
        -- Draw number above deck with total cards remaining
        local deckCountText = tostring(#deck)
        local countWidth = cardFont:getWidth(deckCountText)
        love.graphics.print(deckCountText, deckRect.x + (cardWidth - countWidth) / 2, deckRect.y - cardFont:getHeight() - 5)

        -- Draw displayed cards (each drawn at 2x scale)
        for _, card in ipairs(tableCards) do
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(card.image, card.x, card.y, 0, cardScale, cardScale)
        end

        -- Draw grouped Play & Discard buttons (scaled to 30% of their natural size)
        love.graphics.draw(discardButtonImage, discardButton.x, discardButton.y, 0, buttonScale, buttonScale)
        love.graphics.draw(playButtonImage, playButton.x, playButton.y, 0, buttonScale, buttonScale)

        -- Draw hand result text under the played cards (centered at target position)
        if animationPhase == "show_hand_fadein" or animationPhase == "show_hand_hold" or animationPhase == "show_hand_fadeout" then
            love.graphics.setColor(1, 1, 1, handAlpha)
            local textWidth = cardFont:getWidth(handResult)
            local x = (windowWidth - textWidth) / 2
            -- Hand result appears under the played cards at center (using window center)
            local y = windowHeight/2 + cardHeight/2 + 10
            love.graphics.print(handResult, x, y)
        end
    else
        -- Game Over scene
        love.graphics.setColor(1, 1, 1, gameOverAlpha)
        local goScale = 0.7
        local goW = gameOverImage:getWidth() * goScale
        local goH = gameOverImage:getHeight() * goScale
        local goX = (windowWidth - goW) / 2
        local goY = (windowHeight - goH) / 2 - 50
        love.graphics.draw(gameOverImage, goX, goY, 0, goScale, goScale)
        -- Draw total score under game over image, right-aligned to image
        local scoreText = "Total Score: " .. totalScore
        local scoreW = cardFont:getWidth(scoreText)
        love.graphics.print(scoreText, goX + goW - scoreW, goY + goH + 20)
        -- Draw start over button below game over image
        love.graphics.draw(startOverButtonImage, startOverButton.x, startOverButton.y, 0, startOverScale, startOverScale)
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then
        if not gameOver then
            -- Check if Play button is clicked
            if x >= playButton.x and x <= playButton.x + playButton.width and
               y >= playButton.y and y <= playButton.y + playButton.height then
                playHand()
                return
            end
            -- Check if Discard button is clicked
            if x >= discardButton.x and x <= discardButton.x + discardButton.width and
               y >= discardButton.y and y <= discardButton.y + discardButton.height then
                local discardCount = 0
                for _, card in ipairs(tableCards) do
                    if card.selected then
                        discardCount = discardCount + 1
                    end
                end
                if discardCount > 0 then
                    animationPhase = "discard"
                    animationTimer = 0
                    for i, card in ipairs(tableCards) do
                        if card.selected then
                            card.discardDelay = (i - 1) * 0.07
                            card.discardStartY = card.y
                            card.selected = false
                        end
                    end
                end
                return
            end
            -- Check if a displayed card was clicked; toggle its selection.
            for _, card in ipairs(tableCards) do
                if x >= card.x and x <= card.x + card.width and
                   y >= card.y and y <= card.y + card.height then
                    toggleCard(card)
                    break
                end
            end
        else
            -- In game over scene, check if Start Over button is clicked
            if x >= startOverButton.x and x <= startOverButton.x + startOverButton.width and
               y >= startOverButton.y and y <= startOverButton.y + startOverButton.height then
                love.load()  -- restart the game
            end
        end
    end
end

function toggleCard(card)
    if card.selected then
        card.selected = false
    else
        local count = 0
        for _, c in ipairs(tableCards) do
            if c.selected then
                count = count + 1
            end
        end
        if count < 5 then
            card.selected = true
        end
    end
    updateCardPositions()
end

function playHand()
    local selectedCards = {}
    for i, card in ipairs(tableCards) do
        if card.selected then
            table.insert(selectedCards, card)
        end
    end
    if #selectedCards == 0 then
        handResult = "No cards selected!"
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
        card.targetY = windowHeight/2 - cardHeight/2
    end

    handResult = evaluateHand(selectedCards)
    animationPhase = "move_to_center"
    animationTimer = 0
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
            if vals[i] ~= vals[i-1] + 1 then
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
    cardWidth = cardBackImage:getWidth() * cardScale
    cardHeight = cardBackImage:getHeight() * cardScale
    cardSpacing = 5
    tableStartY = windowHeight - cardHeight - 150

    local gap = 20
    local playW = playButtonImage:getWidth() * buttonScale
    local discardW = discardButtonImage:getWidth() * buttonScale
    local groupWidth = playW + discardW + gap
    local groupX = (windowWidth - groupWidth) / 2
    local groupY = tableStartY + cardHeight + 20
    discardButton.x = groupX
    discardButton.y = groupY
    discardButton.width = discardW
    discardButton.height = discardButtonImage:getHeight() * buttonScale
    playButton.x = groupX + discardW + gap
    playButton.y = groupY
    playButton.width = playW
    playButton.height = playButtonImage:getHeight() * buttonScale

    local deckMargin = 50
    deckRect.x = windowWidth - cardWidth - deckMargin
    deckRect.y = windowHeight - cardHeight - deckMargin

    -- Update start over button for game over scene
    local soW = startOverButtonImage:getWidth() * startOverScale
    local soH = startOverButtonImage:getHeight() * startOverScale
    startOverButton = { x = (windowWidth - soW) / 2, y = (windowHeight)/2 + (gameOverImage:getHeight() * 0.7)/2 + 20, width = soW, height = soH }

    updateCardPositions()
end

function dealCardsAnimation(n)
    for i = 1, n do
        if #deck > 0 then
            local card = table.remove(deck, 1)
            card.selected = false
            card.animatingNew = true
            card.animationTimer = 0
            card.animationDuration = 0.5
            card.startY = windowHeight + 100
            card.targetY = tableStartY
            table.insert(tableCards, card)
        end
    end
    updateCardPositions()
end

function love.update(dt)
    if animationPhase == "move_to_center" then
        animationTimer = animationTimer + dt
        for _, card in ipairs(movingCards) do
            local delay = card.moveDelay or 0
            if animationTimer >= delay then
                local localT = math.min((animationTimer - delay) / 0.5, 1)
                local eased = easeInOutQuad(localT)
                card.x = card.startX + (card.targetX - card.startX) * eased
                card.y = card.startY + (card.targetY - card.startY) * eased
            end
        end
        local maxDelay = (movingCards[#movingCards] and movingCards[#movingCards].moveDelay) or 0
        if animationTimer >= (0.5 + maxDelay) then
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
            for i = #tableCards, 1, -1 do
                for _, mcard in ipairs(movingCards) do
                    if tableCards[i] == mcard then
                        table.remove(tableCards, i)
                    end
                end
            end
            movingCards = {}
            totalScore = totalScore + lastHandScore
            -- Reduce hands remaining by one after each played hand
            handsRemaining = handsRemaining - 1
            if handsRemaining <= 0 then
                animationPhase = "game_over"
                animationTimer = 0
            else
                animationPhase = "deal_new"
                animationTimer = 0
            end
            -- Note: if more cards are needed, deal them in "deal_new"
        end
    elseif animationPhase == "discard" then
        animationTimer = animationTimer + dt
        local allDiscarded = true
        for i, card in ipairs(tableCards) do
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
            local discardCards = {}
            for i = #tableCards, 1, -1 do
                if tableCards[i].discardDelay then
                    table.insert(discardCards, table.remove(tableCards, i))
                end
            end
            animationPhase = "deal_new"
            animationTimer = 0
            local numDiscarded = #discardCards
            if numDiscarded > 0 then
                dealCardsAnimation(numDiscarded)
            else
                animationPhase = nil
            end
        end
    elseif animationPhase == "game_over" then
        animationTimer = animationTimer + dt
        local t = math.min(animationTimer / 1.0, 1)
        gameOverAlpha = easeInOutQuad(t)
        if gameOverAlpha >= 1 then
            gameOver = true
        end
    end

    for _, card in ipairs(tableCards) do
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

    updateCardPositions()
end