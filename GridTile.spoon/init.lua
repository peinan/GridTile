local obj = {}
obj.__index = obj

local canvas = nil
local menuBarHeight = nil
local screenOffset = { x = 0, y = 0 }
local isActive = false

obj.gridMode = nil

-- Layout definitions
local layouts = {
    default = {
        columns = {1, 2, 3, 3, 3, 3, 2, 1},
        rows = {1, 2, 3, 2, 1},
        keys = {
            "1", "2", "3", "4", "7", "8", "9", "0",
            "q", "w", "e", "r", "u", "i", "o", "p",
            "Q", "W", "E", "R", "U", "I", "O", "P",
            "a", "s", "d", "f", "j", "k", "l", ";",
            "z", "x", "c", "v", "n", "m", ",", "."
        }
    },
    vim = {
        columns = {1, 2, 3, 3, 3, 3, 2, 1},
        rows = {1, 2, 3, 2, 1},
        keys = {
            "Q", "W", "E", "R", "U", "I", "O", "P",
            "q", "w", "e", "r", "u", "i", "o", "p",
            "a", "s", "d", "f", "j", "k", "l", ";",
            "z", "x", "c", "v", "m", ",", ".", "/",
            "Z", "X", "C", "V", "M", "<", ">", "?"
        }
    },
    vim2 = {
        columns = {1, 2, 3, 3, 3, 3, 2, 1},
        rows = {1, 2, 3, 2, 1},
        keys = {
            "q", "w", "e", "r", "u", "i", "o", "p",
            "Q", "W", "E", "R", "U", "I", "O", "P",
            "a", "s", "d", "f", "j", "k", "l", ";",
            "Z", "X", "C", "V", "M", "<", ">", "?",
            "z", "x", "c", "v", "m", ",", ".", "/"
        }
    }
}

-- Current layout (can be changed via obj:setLayout())
obj.currentLayout = "vim"

-- Gap settings: 0 = none, 1 = small, 2 = normal
local gapSizes = {
    [0] = 0,
    [1] = 5,
    [2] = 10
}
obj.gap = 2

-- Font settings
obj.font = "Menlo"
obj.fontSize = nil  -- nil = auto (40% of row height, max 64)

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
    obj.gridMode:bind({"ctrl"}, "[", function()
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

    -- Get current layout
    local layout = layouts[obj.currentLayout] or layouts.vim
    local columnWeights = layout.columns
    local rowWeights = layout.rows
    local letters = layout.keys

    -- Get gap size
    local padding = gapSizes[obj.gap] or gapSizes[2]

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
            local cornerRadius = padding > 0 and 12 or 0
            canvas:appendElements({
                type = "rectangle",
                action = "fill",
                fillColor = {
                    red = 0.1,
                    green = 0.1,
                    blue = 0.15,
                    alpha = 0.75
                },
                roundedRectRadii = {
                    xRadius = cornerRadius,
                    yRadius = cornerRadius
                },
                frame = {
                    x = x,
                    y = y,
                    w = colSize,
                    h = rowSize
                },
                shadow = {
                    blurRadius = 8,
                    offset = { h = 2, w = 2 },
                    color = { black = 1, alpha = 0.3 }
                }
            })

            local fontSize = obj.fontSize or math.min(rowSize * 0.4, 64)
            canvas:appendElements({
                type = "text",
                text = letters[letterIndex],
                textFont = obj.font,
                textSize = fontSize,
                textColor = {
                    white = 1,
                    alpha = 0.85
                },
                textAlignment = "center",
                frame = {
                    x = x,
                    y = y + (rowSize - fontSize) / 2 - fontSize * 0.1,
                    w = colSize,
                    h = fontSize * 1.2
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
                    red = 0.3,
                    green = 0.6,
                    blue = 1,
                    alpha = 0.9
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

            -- Handle key bindings (uppercase and special shift characters)
            local shiftKeys = {
                ["<"] = ",", [">"] = ".", ["?"] = "/",
                [":"] = ";", ['"'] = "'", ["{"] = "[", ["}"] = "]",
                ["!"] = "1", ["@"] = "2", ["#"] = "3", ["$"] = "4",
                ["%"] = "5", ["^"] = "6", ["&"] = "7", ["*"] = "8",
                ["("] = "9", [")"] = "0", ["_"] = "-", ["+"] = "="
            }

            if key:match("%u") then
                obj.gridMode:bind({"shift"}, key:lower(), fn)
            elseif shiftKeys[key] then
                obj.gridMode:bind({"shift"}, shiftKeys[key], fn)
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

function obj:setLayout(name)
    if layouts[name] then
        obj.currentLayout = name
        print("[GridTile] Layout set to: " .. name)
    else
        print("[GridTile] Unknown layout: " .. name .. ". Available: default, vim")
    end
end

function obj:setGap(level)
    if gapSizes[level] then
        obj.gap = level
        print("[GridTile] Gap set to: " .. level .. " (" .. gapSizes[level] .. "px)")
    else
        print("[GridTile] Unknown gap level: " .. level .. ". Available: 0, 1, 2")
    end
end

function obj:setFont(name, size)
    if name then
        obj.font = name
        print("[GridTile] Font set to: " .. name)
    end
    if size then
        obj.fontSize = size
        print("[GridTile] Font size set to: " .. size)
    elseif size == nil and not name then
        obj.fontSize = nil
        print("[GridTile] Font size set to: auto")
    end
end

function obj:getLayouts()
    local names = {}
    for name, _ in pairs(layouts) do
        table.insert(names, name)
    end
    return names
end

return obj
