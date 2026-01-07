local obj = {}
obj.__index = obj

local canvas = nil
local menuBarHeight = nil
local screenOffset = { x = 0, y = 0 }
local isActive = false

obj.gridMode = nil

local selectionStart = {
    x1 = nil,
    x2 = nil,
    y1 = nil,
    y2 = nil,
    isSet = false
}
local selectionEnd = {
    x1 = nil,
    x2 = nil,
    y1 = nil,
    y2 = nil,
    isSet = false
}

local function sum(t)
    local s = 0
    for _, v in ipairs(t) do
        s = s + v
    end
    return s
end

local function hasNoNilValues(t)
    for k, v in pairs(t) do
        if v == nil then
            return false
        end
    end
    return true
end

local function getRect(a, b)
    local minX = math.min(a.x1, b.x1)
    local minY = math.min(a.y1, b.y1)
    local maxX = math.max(a.x2, b.x2)
    local maxY = math.max(a.y2, b.y2)

    return {
        x1 = minX,
        y1 = minY,
        x2 = maxX,
        y2 = maxY,
        w = maxX - minX,
        h = maxY - minY
    }
end

local function exitGridTile()
    if not isActive then return end

    canvas:hide()
    canvas:delete()
    canvas = nil

    obj.gridMode:exit()
    obj.gridMode = nil

    selectionStart = {
        isSet = false
    }
    selectionEnd = {
        isSet = false
    }

    isActive = false
    print("[GridTile] Exited")

    -- Restart the eventtap watcher to fix the issue where it stops working
    hs.timer.doAfter(0.1, function()
        if restartGridTileWatcher then
            restartGridTileWatcher()
        end
    end)
end

local function handleSelection(startCell, endCell)
    local rect = getRect(startCell, endCell)

    local win = hs.window.focusedWindow()
    if not win then
        return
    end

    win:setFrame({
        x = rect.x1 + screenOffset.x,
        y = rect.y1 + screenOffset.y,
        w = rect.w,
        h = rect.h
    })

    -- Close the GridTile Extension
    exitGridTile()

end

function obj:start()
    -- Prevent multiple activations
    if isActive then
        print("[GridTile] Already active, ignoring start()")
        return
    end
    isActive = true
    print("[GridTile] Started")

    -- Create a fresh modal each time to avoid duplicate bindings
    obj.gridMode = hs.hotkey.modal.new()

    local screen = hs.screen.mainScreen()

    local fullFrame = screen:fullFrame()
    local frame = screen:frame()

    menuBarHeight = frame.y - fullFrame.y

    obj.gridMode:bind({}, "escape", function()
        exitGridTile()
    end)

    local win = hs.window.focusedWindow()
    local screen = win and win:screen() or hs.screen.mainScreen()

    -- Draw a canvas on the screen
    local frame = screen:frame()

    -- Save screen offset for multi-monitor support
    screenOffset.x = frame.x
    screenOffset.y = frame.y

    canvas = hs.canvas.new(frame)
    canvas:show()

    -- Define the grid weights
    -- =========================
    -- USER CONFIGURATION START
    -- =========================
    local columnWeights = {1, 2, 3, 3, 3, 3, 2, 1}
    local rowWeights = {1, 2, 3, 2, 1}

    -- lua-format off
    local letters = {
      "1", "2", "3", "4", "7", "8", "9", "0", 
      "q", "w", "e", "r", "u", "i", "o", "p", 
      "Q", "W", "E", "R", "U", "I", "I", "P", 
      "a", "s", "d", "f", "j", "k", "l", ";", 
      "z", "x", "c", "v", "n", "m", ",", "."
    }
    -- lua-format on

    -- Padding between grid cells
    local padding = 10

    -- Calculate the size of each grid cell
    local dWidth = (frame.w - (padding * (#columnWeights - 1 + 2))) / (sum(columnWeights)) -- extra 2 for left and right padding
    local dHeight = (frame.h - (padding * (#rowWeights - 1 + 2))) / (sum(rowWeights)) -- extra 2 for top and bottom padding

    local columnSizes = {}
    local rowSizes = {}

    -- Calculate the grid sizes
    for i, weight in ipairs(columnWeights) do
        columnSizes[i] = weight * dWidth
    end

    for i, weight in ipairs(rowWeights) do
        rowSizes[i] = weight * dHeight
    end

    local letterIndex = 1

    -- Draw the grid
    local y = padding
    for i, rowSize in ipairs(rowSizes) do
        local x = padding
        for j, colSize in ipairs(columnSizes) do
            canvas:appendElements({
                type = "rectangle",
                action = "strokeAndFill",
                strokeColor = {
                    red = 1,
                    green = 1,
                    blue = 1,
                    alpha = 0.5
                },
                fillColor = {
                    red = 0,
                    green = 0,
                    blue = 0,
                    alpha = 0.3
                },
                roundedRectRadii = {
                    xRadius = 10,
                    yRadius = 10
                },
                strokeWidth = 1,
                frame = {
                    x = x,
                    y = y,
                    w = colSize,
                    h = rowSize
                }
            }, {
                -- Text
                type = "text",
                text = letters[letterIndex],

                textSize = 32,
                textColor = {
                    white = 1,
                    alpha = 0.9
                },

                textAlignment = "center",
                frame = {
                    x = x,
                    y = y + rowSize / 2.5,
                    w = colSize,
                    h = rowSize
                }
            })

            -- bind key with captured coordinates
            local cellX1 = x
            local cellX2 = x + colSize
            local cellY1 = y
            local cellY2 = y + rowSize
            local key = letters[letterIndex]
            -- Each cell has 2 canvas elements (rectangle + text)
            local rectIndex = (letterIndex - 1) * 2 + 1

            local fn = function()
                -- Highlight selected cell
                canvas[rectIndex].fillColor = {
                    red = 0.2,
                    green = 0.5,
                    blue = 1,
                    alpha = 0.5
                }

                if not selectionStart.isSet then
                    selectionStart = {
                        x1 = cellX1,
                        x2 = cellX2,
                        y1 = cellY1,
                        y2 = cellY2,
                        isSet = true
                    }
                else
                    selectionEnd = {
                        x1 = cellX1,
                        x2 = cellX2,
                        y1 = cellY1,
                        y2 = cellY2
                    }
                    handleSelection(selectionStart, selectionEnd)
                end
            end

            if key:match("%u") then
                obj.gridMode:bind({"shift"}, key:lower(), fn)
            else
                obj.gridMode:bind({}, key, fn)
            end

            x = x + colSize + padding
            letterIndex = letterIndex + 1
        end
        y = y + rowSize + padding

    end

    obj.gridMode:enter()
end

return obj
