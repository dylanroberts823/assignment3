--[[
    GD50
    Match-3 Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    State in which we can actually play, moving around a grid cursor that
    can swap two tiles; when two tiles make a legal swap (a swap that results
    in a valid match), perform the swap and destroy all matched tiles, adding
    their values to the player's point score. The player can continue playing
    until they exceed the number of points needed to get to the next level
    or until the time runs out, at which point they are brought back to the
    main menu or the score entry menu if they made the top 10.
]]

PlayState = Class{__includes = BaseState}

function PlayState:init()

    -- start our transition alpha at full, so we fade in
    self.transitionAlpha = 255

    -- position in the grid which we're highlighting
    self.boardHighlightX = 0
    self.boardHighlightY = 0

    -- timer used to switch the highlight rect's color
    self.rectHighlighted = false

    -- flag to show whether we're able to process input (not swapping or clearing)
    self.canInput = true

    -- tile we're currently highlighting (preparing to swap)
    self.highlightedTile = nil

    self.score = 0
    self.timer = 60

    -- set our Timer class to turn cursor highlight on and off
    Timer.every(0.5, function()
        self.rectHighlighted = not self.rectHighlighted
    end)

    -- subtract 1 from timer every second
    Timer.every(1, function()
        self.timer = self.timer - 1

        -- play warning sound on timer if we get low
        if self.timer <= 5 then
            gSounds['clock']:play()
        end
    end)
end

function PlayState:enter(params)

    -- grab level # from the params we're passed
    self.level = params.level

    -- spawn a board and place it toward the right
    self.board = params.board or Board(VIRTUAL_WIDTH - 272, 16, self.level)

    -- grab score from params if it was passed
    self.score = params.score or 0

    -- score we have to reach to get to the next level
    self.scoreGoal = self.level * 1.25 * 1000
end

function PlayState:update(dt)
    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end

    -- go back to start if time runs out
    if self.timer <= 0 then

        -- clear timers from prior PlayStates
        Timer.clear()

        gSounds['game-over']:play()

        gStateMachine:change('game-over', {
            score = self.score
        })
    end

    -- go to next level if we surpass score goal
    if self.score >= self.scoreGoal then

        -- clear timers from prior PlayStates
        -- always clear before you change state, else next state's timers
        -- will also clear!
        Timer.clear()

        gSounds['next-level']:play()

        -- change to begin game state with new level (incremented)
        gStateMachine:change('begin-game', {
            level = self.level + 1,
            score = self.score
        })
    end

    if self.canInput then
        -- move cursor around based on bounds of grid, playing sounds
        if love.keyboard.wasPressed('up') then
            self.boardHighlightY = math.max(0, self.boardHighlightY - 1)
            gSounds['select']:play()
        elseif love.keyboard.wasPressed('down') then
            self.boardHighlightY = math.min(7, self.boardHighlightY + 1)
            gSounds['select']:play()
        elseif love.keyboard.wasPressed('left') then
            self.boardHighlightX = math.max(0, self.boardHighlightX - 1)
            gSounds['select']:play()
        elseif love.keyboard.wasPressed('right') then
            self.boardHighlightX = math.min(7, self.boardHighlightX + 1)
            gSounds['select']:play()
        end

        -- if we've pressed enter, to select or deselect a tile...
        if love.keyboard.wasPressed('enter') or love.keyboard.wasPressed('return') then

            -- if same tile as currently highlighted, deselect
            local x = self.boardHighlightX + 1
            local y = self.boardHighlightY + 1

            -- if nothing is highlighted, highlight current tile
            if not self.highlightedTile then
                self.highlightedTile = self.board.tiles[y][x]

            -- if we select the position already highlighted, remove highlight
            elseif self.highlightedTile == self.board.tiles[y][x] then
                self.highlightedTile = nil

            -- if the difference between X and Y combined of this highlighted tile
            -- vs the previous is not equal to 1, also remove highlight
            elseif math.abs(self.highlightedTile.gridX - x) + math.abs(self.highlightedTile.gridY - y) > 1 then
                gSounds['error']:play()
                self.highlightedTile = nil
            else
                --local variable to track if we have matches
                local hasMatches = false

                -- swap grid positions of tiles
                local tempX = self.highlightedTile.gridX
                local tempY = self.highlightedTile.gridY

                local newTile = self.board.tiles[y][x]

                self.highlightedTile.gridX = newTile.gridX
                self.highlightedTile.gridY = newTile.gridY
                newTile.gridX = tempX
                newTile.gridY = tempY

                -- swap tiles in the tiles table
                self.board.tiles[self.highlightedTile.gridY][self.highlightedTile.gridX] =
                    self.highlightedTile

                self.board.tiles[newTile.gridY][newTile.gridX] = newTile

                --save the highlighted tile
                local highlightedTile = self.highlightedTile

                hasMatches = self:calculateMatches()

                --since the self.highlightedTile value was reset during calculateMatches
                --reset the self.highlightedTile value to the original one
                self.highlightedTile = highlightedTile

                --only tween if it's true
                if hasMatches == true then
                  -- tween coordinates between the two so they swap
                  Timer.tween(0.1, {
                      [highlightedTile] = {x = newTile.x, y = newTile.y},
                      [newTile] = {x = highlightedTile.x, y = highlightedTile.y}
                  })

                  -- once the swap is finished, we can tween falling blocks as needed
                  :finish(function()
                      hasMatches = self:calculateMatches()
                  end)

                else
                  --since we don't have a match, double tween to pretend to check
                  -- tween coordinates between the two so they swap
                  Timer.tween(0.1, {
                      [highlightedTile] = {x = newTile.x, y = newTile.y},
                      [newTile] = {x = highlightedTile.x, y = highlightedTile.y}
                  })
                  --once that tween is finished, swap the tiles back
                  :finish(function()
                    Timer.tween(0.1, {
                      [highlightedTile] = {x = newTile.x, y = newTile.y},
                      [newTile] = {x = highlightedTile.x, y = highlightedTile.y}
                    })
                  end)

                  -- swap grid positions of tiles
                  tempX = highlightedTile.gridX
                  tempY = highlightedTile.gridY

                  highlightedTile.gridX = newTile.gridX
                  highlightedTile.gridY = newTile.gridY

                  newTile.gridX = tempX
                  newTile.gridY = tempY

                  -- swap tiles in the tiles table
                  self.board.tiles[highlightedTile.gridY][highlightedTile.gridX] =
                      highlightedTile

                  self.board.tiles[newTile.gridY][newTile.gridX] = newTile
                end
            end
        end
    end

    Timer.update(dt)
end

--[[
    Calculates whether any matches were found on the board and tweens the needed
    tiles to their new destinations if so. Also removes tiles from the board that
    have matched and replaces them with new randomized tiles, deferring most of this
    to the Board class.
]]
function PlayState:calculateMatches()
  self.highlightedTile = nil

  -- if we have any matches, remove them and tween the falling blocks that result
  local matches = self.board:calculateMatches()
  local hasMatches = false
  if matches then
    hasMatches = true
    -- adds the timer amounts
    self.timer = self.timer + 1

    --sound effects
    gSounds['match']:stop()
    gSounds['match']:play()



    -- adding score section
    for k, match in pairs(matches) do
      -- variable to track if it's a horizontal match
      local horizontalMatch = false
      local firstX = nil

      --track shiny tiles
      local shinyTiles = {}

      for l, tile in pairs(match) do
        --First, we'll check to see if our match is horizontal or vertical
        --Check if this tile's X is the last X of this match
        if tile.gridX == firstX then
          --since it is, note that this is a horizontal match
          horizontalMatch = true
        else
          firstX = tile.gridX
        end

        --Next, we'll add any shiny tiles to our shiny tiles table
        if tile.shine == true then
          --variable to track if that tile has the same row as those in shiny tiles
          local sameRow = false

          --check all the tiles in shinyTiles to be sure none have the same row
          for l, tile2 in pairs(shinyTiles) do
            if tile2.gridY == tile.gridY then
              --if they do have the same row, then add them
              sameRow = true
            end
          end

          --if they don't have the same row, add them to the table
          if sameRow == false then
            table.insert(shinyTiles, tile)
          end
        end

        --add bonus points for tiles of a higher variety
        if tile.variety > 1 then
          self.score = self.score + tile.variety * 50
        end
      end

      -- add base score for every tile matched
      self.score = self.score + #match * 50

      --if this match is horizontal
      if horizontalMatch == true then
        -- add bonus points for the FIVE remaining tiles that are eliminated in the row
        self.score = self.score + #shinyTiles * 5 * 50
      else
        -- add bonus points for the SEVEN remaining tiles that are eliminated in the row
        -- since this is a horizontal match
        self.score = self.score + #shinyTiles * 7 * 50
      end
    end




    -- remove any tiles that matched from the board, making empty spaces
    self.board:removeMatches()

    -- gets a table with tween values for tiles that should now fall
    local tilesToFall = self.board:getFallingTiles()

    -- tween new tiles that spawn from the ceiling over 0.25s to fill in
    -- the new upper gaps that exist
    Timer.tween(0.25, tilesToFall):finish(function()

        -- recursively call function in case new matches have been created
        -- as a result of falling blocks once new blocks have finished falling
        self:calculateMatches()
    end)
-- if no matches, we can continue playing
  else
    self.canInput = true
  end

  return hasMatches
end

function PlayState:render()
    -- render board of tiles
    self.board:render()

    -- render highlighted tile if it exists
    if self.highlightedTile then

        -- multiply so drawing white rect makes it brighter
        love.graphics.setBlendMode('add')

        love.graphics.setColor(255, 255, 255, 96)
        love.graphics.rectangle('fill', (self.highlightedTile.gridX - 1) * 32 + (VIRTUAL_WIDTH - 272),
            (self.highlightedTile.gridY - 1) * 32 + 16, 32, 32, 4)

        -- back to alpha
        love.graphics.setBlendMode('alpha')
    end

    -- render highlight rect color based on timer
    if self.rectHighlighted then
        love.graphics.setColor(217, 87, 99, 255)
    else
        love.graphics.setColor(172, 50, 50, 255)
    end

    -- draw actual cursor rect
    love.graphics.setLineWidth(4)
    love.graphics.rectangle('line', self.boardHighlightX * 32 + (VIRTUAL_WIDTH - 272),
        self.boardHighlightY * 32 + 16, 32, 32, 4)

    -- GUI text
    love.graphics.setColor(56, 56, 56, 234)
    love.graphics.rectangle('fill', 16, 16, 186, 116, 4)

    love.graphics.setColor(99, 155, 255, 255)
    love.graphics.setFont(gFonts['medium'])
    love.graphics.printf('Level: ' .. tostring(self.level), 20, 24, 182, 'center')
    love.graphics.printf('Score: ' .. tostring(self.score), 20, 52, 182, 'center')
    love.graphics.printf('Goal : ' .. tostring(self.scoreGoal), 20, 80, 182, 'center')
    love.graphics.printf('Timer: ' .. tostring(self.timer), 20, 108, 182, 'center')
end
