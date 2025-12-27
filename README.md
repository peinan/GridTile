# GridTile

**GridTile** is a [tactile](https://gitlab.com/lundal/tactile)-inspired window tiling system for **macOS**, implemented as a **Hammerspoon Spoon**.

It lets you tile the currently focused window by selecting regions on a **weighted, character-addressable grid** — using only the keyboard.
If you’ve used **tactile** on Linux, this brings the same spatial, muscle-memory–friendly workflow to macOS.

---

## Demo

A short demo video is included in this repository that shows the full workflow end-to-end:

![](demo/tiling-window.gif)

* Triggering the grid overlay
* Selecting grid cells using characters
* Tiling the focused window

👉 **Watch the demo before reading further — it explains the idea faster than text.**

---

## Core Idea

GridTile works by overlaying a grid on the screen:

* The grid has **rows and columns with configurable weights**
* Each cell is assigned a **keyboard character**
* You press **one or two characters** to define a region
* The **currently focused window** is tiled to that region

There is:

* No mouse interaction
* No window selection UI
* No automatic tiling

Everything is explicit and user-driven.

---

## How It Works

### 1. Trigger the overlay

* Tap **F3 twice**
* Works whether F3 is:

  * Used directly as a function key (Stage Manager)
  * Accessed via the Fn modifier
  * Used as a Fn key (F3)

This is handled using **Karabiner-Elements** to avoid conflicts with:

* Mission Control
* Stage Manager
* Fn / Function key mode differences

---

### 2. Select grid cells

* Each grid cell is labeled with a **normal keyboard character**

  * Examples: `a`, `s`, `d`, `1`, `2`, `Q`, `W`, `;`, `,`
* Press:

  * **One character** → tile to that single cell
  * **Two characters** → tile to the bounding rectangle formed by those cells

---

### 3. Window tiling behavior

* The **currently focused window** is always used
* If an application has **minimum size constraints**:

  * GridTile will expand the window beyond the selected region as needed
  * This is expected behavior and not considered an error

---

### 4. Exit the overlay

* Press **Escape** at any time to exit without tiling

---

## Invalid Input Handling

* Invalid or unmapped characters are **silently ignored**
* Pressing only one character is valid
* Pressing Escape always exits cleanly

---

## Configuration

GridTile is configured directly in the Spoon’s Lua file.

This is **intentional** — the grid definition is code, not UI.

### User configuration section

```lua
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
-- lua-format on", "x", "c", "v", "n", "m", ",", "."
```

### What you can change

* Number of columns → length of `columnWeights`
* Number of rows → length of `rowWeights`
* Relative sizes → values inside the weight arrays
* Cell labels → contents of `letters`

### Important notes

* Grid size is inferred as:
  **rows × columns**
* The number of entries in `letters` **must match** `rows × columns`
* Characters are assigned in **row-major order** (top-left → bottom-right)

---

## Formatting Note

The formatting of the configuration tables is intentional.

If you use **StyLua**, the config section is protected using ignore directives to prevent auto-formatting from rearranging the grid visually.

---

## Installation
### 1. Install Hammerspoon

Install Hammerspoon and grant:
* Accessibility permissions
* Screen Recording permissions (required for overlay rendering)

### 2. Install the Spoon

Clone or copy the GridTile.spoon directory into:
```bash
~/.hammerspoon/Spoons/
```

Your directory structure should look like:
```
~/.hammerspoon/
├── init.lua
└── Spoons/
    └── GridTile.spoon/
        └── init.lua
```

### 3. Load GridTile in init.lua

Add the following line to your ~/.hammerspoon/init.lua:
```lua
-- Load the GridTile spoon
hs.loadSpoon("GridTile")

-- Double tap F3 to launch GridTile

local f3Watcher
f3Watcher = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
    if event:getKeyCode() ~= hs.keycodes.map.f18 and event:getKeyCode() ~= 160 then
        return false
    end

    tapCount = 0

    spoon.GridTile:start()

    -- Restart the watcher to continue detecting double taps
    f3Watcher:start() 

    return false
end)

f3Watcher:start()
```

GridTile does not bind traditional hotkeys directly.
It is triggered via Karabiner-managed key events.

Reload Hammerspoon after making changes.

### 4. Configuration

GridTile is configured directly inside the Spoon’s Lua file.

This is intentional — the grid definition is code, not UI.
```lua
User configuration section
-- =========================
-- USER CONFIGURATION START
-- =========================

local columnWeights = { 1, 2, 3, 3, 3, 3, 2, 1 }
local rowWeights    = { 1, 2, 3, 2, 1 }

-- stylua: ignore start
local letters = {
  "1", "2", "3", "4", "7", "8", "9", "0",
  "q", "w", "e", "r", "u", "i", "o", "p",
  "Q", "W", "E", "R", "U", "I", "I", "P",
  "a", "s", "d", "f", "j", "k", "l", ";",
  "z", "x", "c", "v", "n", "m", ",", "."
}
-- stylua: ignore end
```

## Karabiner-Elements Configuration

GridTile relies on **Karabiner-Elements** to reliably detect a double-tap of the F3 key across:

* Fn mode
* Function key mode
* Mission Control / Stage Manager setups

A ready-to-use **Karabiner complex modification** is included in this repository.

### To use it:

1. Open Karabiner-Elements
2. Go to **Complex Modifications**
3. Click **Add rule**
4. Import the provided JSON file
5. Go to **Function Keys**
6. Change the **Fn + f3** to f18

This step is required.

---

## Requirements

* **macOS**
* **Hammerspoon**

  * Accessibility permissions
  * Screen Recording permission (for overlay display)
* **Karabiner-Elements**

---

## Multi-Monitor Support

Multi-monitor behavior has **not yet been fully tested**.

Currently:

* GridTile operates on the screen containing the focused window

This will be clarified and documented once multi-monitor testing is complete.

---

## Keyboard Layout Assumptions

* Designed primarily for QWERTY-style layouts
* Custom layouts and remapped keyboards may require adjusting the `letters` table

---

## Philosophy & Non-Goals

GridTile is intentionally **not**:

* A full tiling window manager
* An automatic layout engine
* A background daemon

It is:

* Explicit
* Keyboard-driven
* Spatial
* Fast

You decide **exactly** where a window goes, every time.

---

## Inspiration

GridTile is inspired by the Linux tool **tactile**, adapting its spatial, character-based region selection model to macOS using Hammerspoon.

---

## Status

This project is actively used but still evolving.

* APIs may change
* Configuration structure may improve
* Feedback and issues are welcome

---
