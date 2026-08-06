--------------------------------------------------
-- BlackJack Casino v2.2
-- main.lua
-- Автор: hellbreez + Grok
--------------------------------------------------

package.path = "/BlackJack/?.lua;" .. package.path

local component     = require("component")
local event         = require("event")
local filesystem    = require("filesystem")
local serialization = require("serialization")
local term          = require("term")
local unicode       = require("unicode")
local keyboard      = require("keyboard")
local gpu           = component.gpu
local computer      = require("computer")

local config = require("config")

--------------------------------------------------
-- УТИЛИТЫ
--------------------------------------------------
local function ensureDir(path)
    local dir = filesystem.path(path)
    if dir and dir ~= "" and not filesystem.exists(dir) then
        filesystem.makeDirectory(dir)
    end
end

local function loadDB(path)
    if not filesystem.exists(path) then return nil end
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    if not content or content == "" then return nil end
    local ok, data = pcall(serialization.unserialize, content)
    return ok and data or nil
end

local function saveDB(path, data)
    ensureDir(path)
    local f = io.open(path, "w")
    if not f then return false end
    f:write(serialization.serialize(data))
    f:close()
    return true
end

local function deepCopy(t)
    if type(t) ~= "table" then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = deepCopy(v) end
    return r
end

--------------------------------------------------
-- ЛОГИ
--------------------------------------------------
local Logs = { entries = {} }

local function log(kind, player, text)
    local entry = {
        time   = os.time(),
        kind   = kind or "INFO",
        player = player or "-",
        text   = text or ""
    }
    table.insert(Logs.entries, 1, entry)
    while #Logs.entries > 80 do table.remove(Logs.entries) end
    ensureDir(config.paths.log)
    local f = io.open(config.paths.log, "a")
    if f then
        local ts = os.date("%Y-%m-%d %H:%M:%S", entry.time)
        f:write(string.format("[%s] %s | %s | %s\n", ts, entry.kind, entry.player, entry.text))
        f:close()
    end
end

local function loadLogsFromFile()
    if not filesystem.exists(config.paths.log) then return end
    local f = io.open(config.paths.log, "r")
    if not f then return end
    local lines = {}
    for line in f:lines() do table.insert(lines, line) end
    f:close()
    local start = math.max(1, #lines - 49)
    for i = #lines, start, -1 do
        local line = lines[i]
        local ts, kind, player, text = line:match("%[(.-)%] (.-) | (.-) | (.+)")
        if ts and kind then
            table.insert(Logs.entries, {
                time = 0, kind = kind, player = player or "-", text = text or line, raw = line
            })
        end
    end
end

--------------------------------------------------
-- ИГРОКИ
--------------------------------------------------
local Players = { data = {} }

function Players.load()
    Players.data = loadDB(config.paths.players) or {}
end

function Players.save()
    saveDB(config.paths.players, Players.data)
end

function Players.get(name)
    if not name then return nil end
    if not Players.data[name] then
        Players.data[name] = { balance = 0, totalPlayed = 0, totalWon = 0, games = 0, wins = 0 }
        Players.save()
    end
    local p = Players.data[name]
    p.totalPlayed = p.totalPlayed or 0
    p.totalWon = p.totalWon or 0
    return p
end

function Players.addBalance(name, amount)
    local p = Players.get(name)
    p.balance = math.max(0, (p.balance or 0) + amount)
    if amount > 0 then p.totalWon = (p.totalWon or 0) + amount end
    Players.save()
    return p.balance
end

function Players.addPlayed(name, amount)
    local p = Players.get(name)
    p.totalPlayed = (p.totalPlayed or 0) + amount
    Players.save()
end

function Players.getTop(n)
    n = n or 15
    local list = {}
    for name, data in pairs(Players.data) do
        table.insert(list, { name = name, total = data.totalPlayed or 0, balance = data.balance or 0 })
    end
    table.sort(list, function(a, b) return a.total > b.total end)
    local result = {}
    for i = 1, math.min(n, #list) do result[i] = list[i] end
    return result
end

--------------------------------------------------
-- НАСТРОЙКИ
--------------------------------------------------
local Settings = { data = {} }

local function normalizeBuyPrices(raw)
    local result = {}
    if not raw then return result end
    for k, v in pairs(raw) do
        if type(v) == "number" then
            local short = k:match("([^:]+)$") or k
            result[k] = { price = v, label = short }
        elseif type(v) == "table" then
            result[k] = {
                price = tonumber(v.price) or 1,
                label = v.label or (k:match("([^:]+)$") or k)
            }
        end
    end
    return result
end

function Settings.load()
    local def = {
        minBet = config.bet.min,
        maxBet = config.bet.max,
        buyPrices = normalizeBuyPrices(config.buyPrices),
        payoutItem = nil
    }
    local loaded = loadDB(config.paths.settings)
    if loaded then
        Settings.data = loaded
        Settings.data.minBet = Settings.data.minBet or config.bet.min
        Settings.data.maxBet = Settings.data.maxBet or config.bet.max
        Settings.data.buyPrices = normalizeBuyPrices(Settings.data.buyPrices or config.buyPrices)
    else
        Settings.data = def
    end
end

function Settings.save()
    saveDB(config.paths.settings, Settings.data)
end

function Settings.getPrice(itemId)
    local e = Settings.data.buyPrices and Settings.data.buyPrices[itemId]
    return e and e.price or nil
end

function Settings.getLabel(itemId)
    local e = Settings.data.buyPrices and Settings.data.buyPrices[itemId]
    if e and e.label then return e.label end
    return itemId:match("([^:]+)$") or itemId
end

--------------------------------------------------
-- ЖЕЛЕЗО
--------------------------------------------------
local Hardware = { transposer = nil, me = nil }

function Hardware.init()
    if component.isAvailable("transposer") then Hardware.transposer = component.transposer end
    if component.isAvailable("me_interface") then Hardware.me = component.me_interface end
end

function Hardware.getDepositItem()
    if not Hardware.transposer then return nil end
    local ok, stack = pcall(Hardware.transposer.getStackInSlot, config.hardware.transposerSide, 1)
    if ok and stack and stack.size and stack.size > 0 then
        return { name = stack.name, label = stack.label or stack.name, damage = stack.damage or 0, size = stack.size }
    end
    return nil
end

function Hardware.consumeDeposit(count)
    if not Hardware.transposer then return false end
    count = count or 64
    if Hardware.me and Hardware.me.importItem then
        local ok = pcall(Hardware.me.importItem, config.hardware.transposerSide, 1, count)
        if ok then return true end
    end
    local ok = pcall(Hardware.transposer.transferItem, config.hardware.transposerSide, 0, count, 1)
    return ok
end

function Hardware.exportPayout(itemName, count)
    if not Hardware.me then return 0, "ME Interface не найден" end
    if not itemName or count <= 0 then return 0, "Нет предмета" end
    count = math.floor(count)
    local filter = { name = itemName }

    local ok, items = pcall(function() return Hardware.me.getItemsInNetwork(filter) end)
    if not ok or not items or #items == 0 then
        return 0, "В ME сети нет: " .. tostring(itemName)
    end
    local available = 0
    for _, it in ipairs(items) do available = available + (it.size or 0) end
    if available < count then
        return 0, string.format("В ME только %d шт, нужно %d", available, count)
    end

    local ok2, moved = pcall(Hardware.me.exportItem, filter, config.hardware.meSide, count)
    if not ok2 then return 0, "Ошибка exportItem: " .. tostring(moved) end
    moved = moved or 0
    if moved < count then return moved, string.format("Выдано только %d из %d", moved, count) end
    return moved, nil
end

--------------------------------------------------
-- КАРТЫ (масти строго внутри рамки)
--------------------------------------------------
local Cards = {}
Cards.suits = { "♠", "♥", "♦", "♣" }
Cards.suitColors = {
    ["♠"] = config.colors.spade, ["♥"] = config.colors.heart,
    ["♦"] = config.colors.diamond, ["♣"] = config.colors.club
}
Cards.ranks = {
    {id="A", v=11}, {id="2", v=2}, {id="3", v=3}, {id="4", v=4},
    {id="5", v=5}, {id="6", v=6}, {id="7", v=7}, {id="8", v=8},
    {id="9", v=9}, {id="10", v=10}, {id="J", v=10}, {id="Q", v=10}, {id="K", v=10}
}

-- x:1..7  y:1..5  (внутри рамки карты 9x7)
local faceLayout = {
    ["A"]  = {{4,3}},
    ["2"]  = {{4,1},{4,5}},
    ["3"]  = {{4,1},{4,3},{4,5}},
    ["4"]  = {{2,1},{6,1},{2,5},{6,5}},
    ["5"]  = {{2,1},{6,1},{4,3},{2,5},{6,5}},
    ["6"]  = {{2,1},{6,1},{2,3},{6,3},{2,5},{6,5}},
    ["7"]  = {{4,1},{2,2},{6,2},{2,3},{6,3},{2,5},{6,5}},
    ["8"]  = {{2,1},{6,1},{2,2},{6,2},{2,4},{6,4},{2,5},{6,5}},
    ["9"]  = {{2,1},{6,1},{2,2},{6,2},{4,3},{2,4},{6,4},{2,5},{6,5}},
    ["10"] = {{2,1},{6,1},{2,2},{6,2},{2,3},{6,3},{2,4},{6,4},{2,5},{6,5}},
    ["J"] = "J", ["Q"] = "Q", ["K"] = "K"
}

function Cards.createDeck(count)
    count = count or 6
    local deck = {}
    for d = 1, count do
        for _, s in ipairs(Cards.suits) do
            for _, r in ipairs(Cards.ranks) do
                table.insert(deck, { rank = r.id, suit = s, value = r.v })
            end
        end
    end
    for i = #deck, 2, -1 do
        local j = math.random(i)
        deck[i], deck[j] = deck[j], deck[i]
    end
    return deck
end

function Cards.handValue(hand)
    local total, aces = 0, 0
    for _, c in ipairs(hand) do
        total = total + c.value
        if c.rank == "A" then aces = aces + 1 end
    end
    while total > 21 and aces > 0 do total = total - 10; aces = aces - 1 end
    return total
end

function Cards.isBlackjack(hand) return #hand == 2 and Cards.handValue(hand) == 21 end
function Cards.isBust(hand) return Cards.handValue(hand) > 21 end

--------------------------------------------------
local Game = {
    deck = {}, player = { hand = {}, standing = false },
    dealer = { hand = {}, standing = false },
    finished = false, result = nil, bet = 0, state = "idle"
}

function Game.reset()
    Game.deck = Cards.createDeck(config.game.decks)
    Game.player = { hand = {}, standing = false }
    Game.dealer = { hand = {}, standing = false }
    Game.finished = false; Game.result = nil; Game.bet = 0; Game.state = "idle"
end

function Game.deal()
    if #Game.deck < 4 then Game.deck = Cards.createDeck(config.game.decks) end
    Game.player.hand = { table.remove(Game.deck), table.remove(Game.deck) }
    Game.dealer.hand = { table.remove(Game.deck), table.remove(Game.deck) }
    Game.finished = false; Game.result = nil; Game.state = "playing"
    if Cards.isBlackjack(Game.player.hand) then
        if Cards.isBlackjack(Game.dealer.hand) then Game.finish("DRAW") else Game.finish("BLACKJACK") end
    elseif Cards.isBlackjack(Game.dealer.hand) then Game.finish("LOSE") end
end

function Game.hit()
    if Game.finished or Game.state ~= "playing" then return end
    table.insert(Game.player.hand, table.remove(Game.deck))
    if Cards.isBust(Game.player.hand) then Game.finish("LOSE") end
end

function Game.stand()
    if Game.finished or Game.state ~= "playing" then return end
    Game.player.standing = true
    while Cards.handValue(Game.dealer.hand) < 17 do
        table.insert(Game.dealer.hand, table.remove(Game.deck))
    end
    local p = Cards.handValue(Game.player.hand)
    local d = Cards.handValue(Game.dealer.hand)
    if Cards.isBust(Game.dealer.hand) then Game.finish("WIN")
    elseif p > d then Game.finish("WIN")
    elseif p < d then Game.finish("LOSE")
    else Game.finish("DRAW") end
end

function Game.finish(result) Game.finished = true; Game.result = result; Game.state = "result" end

function Game.payoutMultiplier()
    if Game.result == "BLACKJACK" then return config.game.blackjackPayout end
    if Game.result == "WIN" then return config.game.winPayout end
    if Game.result == "DRAW" then return config.game.drawPayout end
    return 0
end

--------------------------------------------------
-- UI
--------------------------------------------------
local UI = {
    w = 0, h = 0, screen = "main",
    playerName = nil, authorized = false,
    sessionLeft = 120, timerId = nil,
    betAmount = config.bet.default,
    buttons = {}, message = nil, messageColor = config.colors.text, messageUntil = 0,
    adminTab = "bets", logScroll = 0,
    editItem = { name = nil, label = "", price = "1", mode = "add", target = "buy" },
    input = { active = false, title = "", value = "", callback = nil, maxLen = 40 }
}

function UI.setMessage(text, color, seconds)
    UI.message = text
    UI.messageColor = color or config.colors.text
    UI.messageUntil = computer.uptime() + (seconds or 4)
end

function UI.clearButtons() UI.buttons = {} end

function UI.addButton(x, y, w, h, text, bg, fg, callback)
    table.insert(UI.buttons, { x=x, y=y, w=w, h=h, text=text, bg=bg, fg=fg or config.colors.text, cb=callback })
end

function UI.drawButton(b)
    gpu.setBackground(b.bg); gpu.setForeground(b.fg)
    gpu.fill(b.x, b.y, b.w, b.h, " ")
    local tx = b.x + math.floor((b.w - unicode.len(b.text)) / 2)
    local ty = b.y + math.floor((b.h - 1) / 2)
    gpu.set(tx, ty, b.text)
end

function UI.checkButtons(x, y)
    for _, b in ipairs(UI.buttons) do
        if x >= b.x and x < b.x + b.w and y >= b.y and y < b.y + b.h then
            if b.cb then b.cb() end
            return true
        end
    end
    return false
end

local function fill(x, y, w, h, color)
    gpu.setBackground(color); gpu.fill(x, y, w, h, " ")
end

local function text(x, y, str, fg, bg)
    if bg then gpu.setBackground(bg) end
    if fg then gpu.setForeground(fg) end
    gpu.set(x, y, tostring(str))
end

local function centerText(y, str, fg, bg, width)
    width = width or UI.w
    local x = math.floor((width - unicode.len(tostring(str))) / 2) + 1
    text(x, y, str, fg, bg)
end

local function drawBox(x, y, w, h, borderColor, fillColor)
    fill(x, y, w, h, fillColor or config.colors.panel)
    gpu.setForeground(borderColor or config.colors.textBlue)
    gpu.setBackground(fillColor or config.colors.panel)
    for i = 0, w - 1 do
        gpu.set(x + i, y, "─"); gpu.set(x + i, y + h - 1, "─")
    end
    for i = 0, h - 1 do
        gpu.set(x, y + i, "│"); gpu.set(x + w - 1, y + i, "│")
    end
    gpu.set(x, y, "┌"); gpu.set(x + w - 1, y, "┐")
    gpu.set(x, y + h - 1, "└"); gpu.set(x + w - 1, y + h - 1, "┘")
end

local function drawCard(x, y, card, hidden)
    local cw, ch = 9, 7
    if hidden then
        fill(x, y, cw, ch, config.colors.cardBack)
        gpu.setForeground(0x4A2020); gpu.setBackground(config.colors.cardBack)
        for dy = 1, ch - 2 do
            for dx = 1, cw - 2 do
                if (dx + dy) % 2 == 0 then gpu.set(x + dx, y + dy, "░") end
            end
        end
        return
    end
    fill(x, y, cw, ch, config.colors.cardFace)
    gpu.setForeground(0x444444); gpu.setBackground(config.colors.cardFace)
    for i = 0, cw - 1 do gpu.set(x + i, y, "─"); gpu.set(x + i, y + ch - 1, "─") end
    for i = 0, ch - 1 do gpu.set(x, y + i, "│"); gpu.set(x + cw - 1, y + i, "│") end
    gpu.set(x, y, "┌"); gpu.set(x + cw - 1, y, "┐")
    gpu.set(x, y + ch - 1, "└"); gpu.set(x + cw - 1, y + ch - 1, "┘")

    local col = Cards.suitColors[card.suit] or 0x111111
    local layout = faceLayout[card.rank]
    if type(layout) == "string" then
        text(x + 1, y + 1, card.rank, col, config.colors.cardFace)
        text(x + 1, y + 2, card.suit, col, config.colors.cardFace)
        text(x + cw - 2, y + ch - 2, card.rank, col, config.colors.cardFace)
    else
        text(x + 1, y + 1, card.rank, col, config.colors.cardFace)
        if card.rank == "10" then
            text(x + cw - 3, y + ch - 2, "10", col, config.colors.cardFace)
        else
            text(x + cw - 2, y + ch - 2, card.rank, col, config.colors.cardFace)
        end
        if layout then
            for _, pos in ipairs(layout) do
                local px, py = pos[1], pos[2]
                if px >= 1 and px <= 7 and py >= 1 and py <= 5 then
                    text(x + px, y + py, card.suit, col, config.colors.cardFace)
                end
            end
        end
    end
end

local function drawHand(x, y, hand, hideFirst)
    for i, c in ipairs(hand) do
        drawCard(x + (i - 1) * 10, y, c, hideFirst and i == 1)
    end
end

--------------------------------------------------
-- ВВОД (Unicode / кириллица)
--------------------------------------------------
function UI.openInput(title, default, callback, maxLen)
    UI.input.active = true
    UI.input.title = title or "Ввод"
    UI.input.value = tostring(default or "")
    UI.input.callback = callback
    UI.input.maxLen = maxLen or 40
    UI.draw()
end

function UI.closeInput(submit)
    local val, cb = UI.input.value, UI.input.callback
    UI.input.active = false; UI.input.callback = nil
    if cb then if submit then cb(val) else cb(nil) end end
end

function UI.drawInputModal()
    local mw = UI.w - config.ui.sidebarWidth
    local boxW = math.min(52, mw - 4)
    local boxH = 10
    local bx = math.floor((mw - boxW) / 2) + 1
    local by = math.floor((UI.h - boxH) / 2)
    fill(1, 2, mw, UI.h - 1, 0x050505)
    drawBox(bx, by, boxW, boxH, config.colors.textBlue, config.colors.panel)
    centerText(by + 1, UI.input.title, config.colors.textBlue, config.colors.panel, mw)
    local fieldX, fieldW = bx + 2, boxW - 4
    fill(fieldX, by + 3, fieldW, 1, 0x1A1A1A)
    local display = UI.input.value
    if unicode.len(display) > fieldW - 2 then display = unicode.sub(display, -(fieldW - 2)) end
    text(fieldX + 1, by + 3, display .. "▌", config.colors.textGold, 0x1A1A1A)
    text(bx + 2, by + 5, "Enter — ОК  |  Esc — отмена", config.colors.textDark, config.colors.panel)
    text(bx + 2, by + 6, "Поддерживается русский язык", config.colors.textDark, config.colors.panel)
    UI.addButton(bx + 2, by + 7, 12, 2, "ОК", config.colors.buttonGreen, 0xFFFFFF, function() UI.closeInput(true) end)
    UI.addButton(bx + 16, by + 7, 12, 2, "ОТМЕНА", config.colors.button, config.colors.text, function() UI.closeInput(false) end)
end

function UI.handleKey(char, code)
    if not UI.input.active then return false end
    if code == keyboard.keys.enter then UI.closeInput(true); UI.draw(); return true end
    if code == keyboard.keys.escape then UI.closeInput(false); UI.draw(); return true end
    if code == keyboard.keys.back then
        if unicode.len(UI.input.value) > 0 then
            UI.input.value = unicode.sub(UI.input.value, 1, -2); UI.draw()
        end
        return true
    end
    if char and char > 0 and char ~= 127 then
        local ch
        if char < 128 then
            if char < 32 then return true end
            ch = string.char(char)
        else
            local ok, res = pcall(unicode.char, char)
            ch = ok and res or nil
        end
        if ch and unicode.len(UI.input.value) < UI.input.maxLen then
            UI.input.value = UI.input.value .. ch; UI.draw()
        end
    end
    return true
end

--------------------------------------------------
-- САЙДБАР
--------------------------------------------------
function UI.drawHeader()
    fill(1, 1, UI.w, 1, config.colors.header)
    centerText(1, "КАЗИНО  •  BLACKJACK", config.colors.textBlue, config.colors.header)
end

function UI.drawSidebar()
    local sx = UI.w - config.ui.sidebarWidth + 1
    local sw = config.ui.sidebarWidth
    fill(sx, 2, sw, UI.h - 1, config.colors.panel)

    if not UI.authorized then
        UI.addButton(sx + 1, 3, sw - 2, 3, "АВТОРИЗАЦИЯ", config.colors.buttonGreen, 0xFFFFFF, function() end)
        text(sx + 2, 7, "Войдите для игры", config.colors.textDark, config.colors.panel)
    else
        UI.addButton(sx + 1, 3, sw - 2, 3, "ВЫХОД", config.colors.buttonRed, 0xFFFFFF, function() UI.logout() end)
        text(sx + 2, 7, UI.playerName or "?", config.colors.textGreen, config.colors.panel)
        local p = Players.get(UI.playerName)
        text(sx + 2, 8, string.format("%s %s", tostring(p.balance or 0), config.currency.symbol), config.colors.textGold, config.colors.panel)
        text(sx + 2, 9, "Выход через: " .. UI.sessionLeft .. "с", config.colors.textDark, config.colors.panel)

        UI.addButton(sx + 1, 11, sw - 2, 3, "ПОПОЛНИТЬ СЧЁТ", config.colors.buttonGreen, 0xFFFFFF, function() UI.doDeposit() end)
        UI.addButton(sx + 1, 15, sw - 2, 3, "ВЫВЕСТИ", config.colors.buttonYellow or 0xCCAA00, 0x000000, function() UI.doWithdraw() end)

        if config.admins[UI.playerName] then
            UI.addButton(sx + 1, 19, sw - 2, 3, "АДМИН ПАНЕЛЬ", config.colors.buttonBlue, 0xFFFFFF, function()
                UI.screen = "admin"; UI.adminTab = "bets"; UI.draw()
            end)
        end
    end

    local y = UI.authorized and (config.admins[UI.playerName] and 23 or 19) or 10
    if y > UI.h - 10 then y = UI.h - 10 end

    text(sx + 1, y, "СКУПКА ПРЕДМЕТОВ:", config.colors.textBlue, config.colors.panel); y = y + 1
    local sorted = {}
    for id, info in pairs(Settings.data.buyPrices or {}) do
        table.insert(sorted, { label = info.label or id, price = info.price or 0 })
    end
    table.sort(sorted, function(a, b) return a.label < b.label end)
    local count = 0
    for _, entry in ipairs(sorted) do
        count = count + 1
        if count > 6 or y >= UI.h - 8 then break end
        local short = entry.label
        if unicode.len(short) > 14 then short = unicode.sub(short, 1, 12) .. ".." end
        text(sx + 1, y, string.format("%s - %s", short, entry.price), config.colors.text, config.colors.panel)
        y = y + 1
    end
    if count == 0 then text(sx + 1, y, "Нет предметов", config.colors.textDark, config.colors.panel); y = y + 1 end

    y = y + 1
    text(sx + 1, y, "ТОП 15 (наиграно):", config.colors.textBlue, config.colors.panel); y = y + 1
    for i, entry in ipairs(Players.getTop(15)) do
        if y >= UI.h - 1 then break end
        local name = entry.name
        if unicode.len(name) > 11 then name = unicode.sub(name, 1, 9) .. ".." end
        local bal = entry.total
        local balStr = bal >= 1000 and string.format("%.1fk", bal / 1000) or tostring(bal)
        text(sx + 1, y, string.format("%d. %s", i, name), config.colors.text, config.colors.panel)
        text(sx + sw - unicode.len(balStr) - 3, y, balStr, config.colors.textGold, config.colors.panel)
        y = y + 1
    end
end

--------------------------------------------------
function UI.drawWelcomeArt(mw)
    local cx = math.floor(mw / 2)
    fill(cx - 18, 6, 36, 14, config.colors.tableGreen or 0x0B5C3A)
    centerText(7, "♠  BLACKJACK  ♥", config.colors.textGold, config.colors.tableGreen or 0x0B5C3A, mw)
    centerText(8, "♦              ♣", 0xCCCCCC, config.colors.tableGreen or 0x0B5C3A, mw)
    drawCard(cx - 14, 10, { rank = "A", suit = "♠" }, false)
    drawCard(cx - 4,  10, { rank = "K", suit = "♥" }, false)
    drawCard(cx + 6,  10, { rank = "Q", suit = "♦" }, false)
    centerText(19, "Касайся экрана для входа", config.colors.text, config.colors.background, mw)
    centerText(20, "Авторизация по нику игрока", config.colors.textDark, config.colors.background, mw)
end

function UI.drawMainArea()
    local mw = UI.w - config.ui.sidebarWidth
    fill(1, 2, mw, UI.h - 1, config.colors.background)
    if UI.input.active then UI.drawInputModal(); return end

    if UI.screen == "main" then
        if UI.authorized then
            centerText(4, "BLACKJACK", config.colors.textGold, config.colors.background, mw)
            centerText(6, "Ваш баланс: " .. Players.get(UI.playerName).balance .. " " .. config.currency.symbol, config.colors.text, config.colors.background, mw)
            centerText(9, "СТАВКА", config.colors.textBlue, config.colors.background, mw)
            centerText(11, tostring(UI.betAmount) .. " " .. config.currency.symbol, config.colors.textGold, config.colors.background, mw)
            local cx = math.floor(mw / 2)
            UI.addButton(cx - 12, 13, 5, 3, "◄", config.colors.button, config.colors.text, function()
                UI.betAmount = math.max(Settings.data.minBet, UI.betAmount - 1); UI.draw() end)
            UI.addButton(cx - 6, 13, 5, 3, "◄◄", config.colors.button, config.colors.text, function()
                UI.betAmount = math.max(Settings.data.minBet, UI.betAmount - 10); UI.draw() end)
            UI.addButton(cx + 2, 13, 5, 3, "►►", config.colors.button, config.colors.text, function()
                UI.betAmount = math.min(Settings.data.maxBet, UI.betAmount + 10); UI.draw() end)
            UI.addButton(cx + 8, 13, 5, 3, "►", config.colors.button, config.colors.text, function()
                UI.betAmount = math.min(Settings.data.maxBet, UI.betAmount + 1); UI.draw() end)
            text(cx - 10, 17, "Мин: " .. Settings.data.minBet, config.colors.textDark, config.colors.background)
            text(cx + 4, 17, "Макс: " .. Settings.data.maxBet, config.colors.textDark, config.colors.background)
            UI.addButton(cx - 10, 20, 20, 3, "ИГРАТЬ", config.colors.buttonGreen, 0xFFFFFF, function() UI.startGame() end)
        else
            UI.drawWelcomeArt(mw)
        end

    elseif UI.screen == "playing" or UI.screen == "result" then
        local hideDealer = (UI.screen == "playing" and not Game.finished)
        text(4, 3, "ДИЛЕР", config.colors.text, config.colors.background)
        text(12, 3, hideDealer and "?" or tostring(Cards.handValue(Game.dealer.hand)), config.colors.textGold, config.colors.background)
        drawHand(4, 5, Game.dealer.hand, hideDealer)
        text(4, 13, "ВЫ", config.colors.text, config.colors.background)
        text(10, 13, tostring(Cards.handValue(Game.player.hand)), config.colors.textGold, config.colors.background)
        drawHand(4, 15, Game.player.hand, false)
        text(4, 23, "Ставка: " .. Game.bet .. " " .. config.currency.symbol, config.colors.text, config.colors.background)
        if UI.screen == "playing" and not Game.finished then
            UI.addButton(4, 25, 12, 3, "ВЗЯТЬ", config.colors.buttonGreen, 0xFFFFFF, function()
                Game.hit(); if Game.finished then UI.resolveGame() end; UI.draw() end)
            UI.addButton(18, 25, 12, 3, "СТОП", config.colors.buttonRed, 0xFFFFFF, function()
                Game.stand(); UI.resolveGame(); UI.draw() end)
        elseif UI.screen == "result" then
            local resText = ({ WIN="ПОБЕДА!", LOSE="ПОРАЖЕНИЕ", DRAW="НИЧЬЯ", BLACKJACK="BLACKJACK!" })[Game.result] or Game.result
            local resCol = ({ WIN=config.colors.textGreen, LOSE=config.colors.textRed, DRAW=config.colors.textGold, BLACKJACK=config.colors.textGold })[Game.result] or config.colors.text
            centerText(24, resText, resCol, config.colors.background, mw)
            local winAmount = math.floor(Game.bet * Game.payoutMultiplier() + 0.5)
            if winAmount > 0 then centerText(25, "+" .. winAmount .. " " .. config.currency.symbol, config.colors.textGreen, config.colors.background, mw) end
            UI.addButton(math.floor(mw/2) - 8, 27, 16, 3, "ЕЩЁ РАЗ", config.colors.buttonGreen, 0xFFFFFF, function()
                UI.screen = "main"; Game.reset(); UI.draw() end)
        end

    elseif UI.screen == "admin" then UI.drawAdmin(mw)
    elseif UI.screen == "admin_add_item" then UI.drawAdminAddItem(mw)
    elseif UI.screen == "admin_edit_item" then UI.drawAdminEditItem(mw)
    end

    if UI.message and computer.uptime() < UI.messageUntil then
        centerText(UI.h - 1, UI.message, UI.messageColor, config.colors.background, mw)
    end
end

--------------------------------------------------
-- АДМИН
--------------------------------------------------
function UI.drawAdmin(mw)
    fill(1, 2, mw, UI.h - 1, config.colors.background)
    centerText(3, "АДМИН-ПАНЕЛЬ", config.colors.textBlue, config.colors.background, mw)

    local tabs = {
        { id = "bets", title = "СТАВКИ" },
        { id = "buy", title = "СКУПКА" },
        { id = "payout", title = "ВЫПЛАТА" },
        { id = "logs", title = "ЛОГИ" },
    }
    local tx = 3
    for _, tab in ipairs(tabs) do
        local tw = unicode.len(tab.title) + 2
        UI.addButton(tx, 5, tw, 2, tab.title,
            UI.adminTab == tab.id and config.colors.buttonBlue or config.colors.button, 0xFFFFFF, function()
                UI.adminTab = tab.id; UI.logScroll = 0; UI.draw() end)
        tx = tx + tw + 1
    end

    if UI.adminTab == "bets" then UI.drawAdminBets(mw)
    elseif UI.adminTab == "buy" then UI.drawAdminBuy(mw)
    elseif UI.adminTab == "payout" then UI.drawAdminPayout(mw)
    elseif UI.adminTab == "logs" then UI.drawAdminLogs(mw) end

    UI.addButton(4, UI.h - 3, 14, 2, "◄ НАЗАД", config.colors.button, config.colors.text, function()
        UI.screen = "main"; UI.adminTab = "bets"; UI.draw() end)
end

function UI.drawAdminBets(mw)
    text(4, 9, "Минимальная ставка (нажми на поле):", config.colors.textDark, config.colors.background)
    drawBox(4, 10, 22, 3, config.colors.textGold, config.colors.panelLight)
    text(6, 11, tostring(Settings.data.minBet) .. " " .. config.currency.symbol, config.colors.textGold, config.colors.panelLight)
    UI.addButton(4, 10, 22, 3, "", 0x000000, 0x000000, function()
        UI.openInput("Мин. ставка", tostring(Settings.data.minBet), function(val)
            local n = tonumber(val)
            if n and n >= 1 then
                Settings.data.minBet = math.floor(n)
                if Settings.data.minBet > Settings.data.maxBet then Settings.data.maxBet = Settings.data.minBet end
                Settings.save()
            end
            UI.draw()
        end, 8)
    end)

    text(4, 14, "Максимальная ставка (нажми на поле):", config.colors.textDark, config.colors.background)
    drawBox(4, 15, 22, 3, config.colors.textGold, config.colors.panelLight)
    text(6, 16, tostring(Settings.data.maxBet) .. " " .. config.currency.symbol, config.colors.textGold, config.colors.panelLight)
    UI.addButton(4, 15, 22, 3, "", 0x000000, 0x000000, function()
        UI.openInput("Макс. ставка", tostring(Settings.data.maxBet), function(val)
            local n = tonumber(val)
            if n and n >= Settings.data.minBet then
                Settings.data.maxBet = math.floor(n); Settings.save()
            end
            UI.draw()
        end, 8)
    end)
end

function UI.drawAdminBuy(mw)
    text(4, 8, "Предметы для скупки:", config.colors.textBlue, config.colors.background)
    local y, list = 10, {}
    for name, info in pairs(Settings.data.buyPrices or {}) do
        table.insert(list, { name = name, label = info.label or name, price = info.price or 0 })
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    for _, entry in ipairs(list) do
        if y > UI.h - 8 then break end
        local short = entry.label
        if unicode.len(short) > 20 then short = unicode.sub(short, 1, 18) .. ".." end
        text(4, y, short, config.colors.text, config.colors.background)
        text(28, y, tostring(entry.price) .. " " .. config.currency.symbol, config.colors.textGold, config.colors.background)
        UI.addButton(42, y, 3, 1, "×", config.colors.buttonRed, 0xFFFFFF, function()
            Settings.data.buyPrices[entry.name] = nil; Settings.save(); UI.draw() end)
        y = y + 1
    end
    if #list == 0 then text(4, 10, "Список пуст", config.colors.textDark, config.colors.background) end
    UI.addButton(4, UI.h - 6, 22, 2, "+ ДОБАВИТЬ ПРЕДМЕТ", config.colors.buttonGreen, 0xFFFFFF, function()
        UI.screen = "admin_add_item"
        UI.editItem = { name = nil, label = "", price = "1", mode = "add", target = "buy" }
        UI.draw()
    end)
end

function UI.drawAdminPayout(mw)
    text(4, 8, "Предмет выигрыша / вывода:", config.colors.textBlue, config.colors.background)
    text(4, 9, "(выдаётся из ME в правый сундук)", config.colors.textDark, config.colors.background)
    local pi = Settings.data.payoutItem
    if pi and pi.name then
        text(4, 12, "Предмет: " .. (pi.label or pi.name), config.colors.text, config.colors.background)
        text(4, 13, "ID: " .. pi.name, config.colors.textDark, config.colors.background)
        text(4, 14, "1 шт = " .. tostring(pi.value or 1) .. " " .. config.currency.symbol, config.colors.textGold, config.colors.background)
        UI.addButton(4, 17, 18, 2, "ИЗМЕНИТЬ", config.colors.buttonBlue, 0xFFFFFF, function()
            UI.screen = "admin_add_item"
            UI.editItem = { name = pi.name, label = pi.label or pi.name, price = tostring(pi.value or 1), mode = "edit", target = "payout" }
            UI.draw()
        end)
        UI.addButton(24, 17, 14, 2, "УДАЛИТЬ", config.colors.buttonRed, 0xFFFFFF, function()
            Settings.data.payoutItem = nil; Settings.save(); UI.draw() end)
    else
        text(4, 12, "Не настроен", config.colors.textRed, config.colors.background)
        text(4, 13, "Без него выигрыш только на балансе", config.colors.textDark, config.colors.background)
        UI.addButton(4, 17, 24, 2, "+ НАСТРОИТЬ ПРЕДМЕТ", config.colors.buttonGreen, 0xFFFFFF, function()
            UI.screen = "admin_add_item"
            UI.editItem = { name = nil, label = "", price = "1", mode = "add", target = "payout" }
            UI.draw()
        end)
    end
end

function UI.drawAdminLogs(mw)
    text(4, 8, "Последние действия:", config.colors.textBlue, config.colors.background)
    local y = 10
    local maxLines = UI.h - 14
    local start = 1 + (UI.logScroll or 0)
    for i = start, math.min(start + maxLines - 1, #Logs.entries) do
        local e = Logs.entries[i]
        if not e then break end
        local ts = e.raw and e.raw:match("^%[(.-)%]") or (e.time > 0 and os.date("%m-%d %H:%M", e.time) or "")
        local kindCol = config.colors.text
        if e.kind == "ВЫИГРЫШ" then kindCol = config.colors.textGreen
        elseif e.kind == "ПРОИГРЫШ" then kindCol = config.colors.textRed
        elseif e.kind == "ПОПОЛНЕНИЕ" then kindCol = config.colors.textGold
        elseif e.kind == "ВЫВОД" then kindCol = config.colors.textBlue
        elseif e.kind == "ОШИБКА" then kindCol = config.colors.textRed end
        local line = string.format("%s %s | %s", ts, e.kind, e.player)
        if unicode.len(line) > mw - 6 then line = unicode.sub(line, 1, mw - 8) .. ".." end
        text(4, y, line, kindCol, config.colors.background); y = y + 1
        if e.text and e.text ~= "" then
            local t2 = "  " .. e.text
            if unicode.len(t2) > mw - 6 then t2 = unicode.sub(t2, 1, mw - 8) .. ".." end
            text(4, y, t2, config.colors.textDark, config.colors.background); y = y + 1
        end
        if y > UI.h - 5 then break end
    end
    if #Logs.entries == 0 then text(4, 10, "Логов пока нет", config.colors.textDark, config.colors.background) end
    if #Logs.entries > maxLines then
        UI.addButton(4, UI.h - 5, 8, 2, "▲", config.colors.button, config.colors.text, function()
            UI.logScroll = math.max(0, (UI.logScroll or 0) - 3); UI.draw() end)
        UI.addButton(14, UI.h - 5, 8, 2, "▼", config.colors.button, config.colors.text, function()
            UI.logScroll = math.min(#Logs.entries - 1, (UI.logScroll or 0) + 3); UI.draw() end)
    end
end

function UI.drawAdminAddItem(mw)
    fill(1, 2, mw, UI.h - 1, config.colors.background)
    local title = UI.editItem.target == "payout" and "ПРЕДМЕТ ВЫПЛАТЫ" or "ДОБАВЛЕНИЕ ПРЕДМЕТА"
    centerText(5, title, config.colors.textBlue, config.colors.background, mw)
    centerText(9, "Положи предмет в левый сундук", config.colors.text, config.colors.background, mw)
    centerText(10, "(транспозер сверху) и нажми ОК", config.colors.textDark, config.colors.background, mw)
    UI.addButton(math.floor(mw/2) - 8, 14, 16, 3, "ОК", config.colors.buttonGreen, 0xFFFFFF, function()
        local item = Hardware.getDepositItem()
        if not item then UI.setMessage("Сундук пуст!", config.colors.textRed, 4); UI.draw(); return end
        UI.editItem.name = item.name
        UI.editItem.label = item.label or item.name  -- русское имя из игры
        UI.editItem.price = UI.editItem.price or "1"
        UI.screen = "admin_edit_item"; UI.draw()
    end)
    UI.addButton(math.floor(mw/2) - 8, 18, 16, 3, "ОТМЕНА", config.colors.button, config.colors.text, function()
        UI.screen = "admin"
        UI.adminTab = UI.editItem.target == "payout" and "payout" or "buy"
        UI.draw()
    end)
end

function UI.drawAdminEditItem(mw)
    fill(1, 2, mw, UI.h - 1, config.colors.background)
    centerText(4, "НАСТРОЙКА ПРЕДМЕТА", config.colors.textBlue, config.colors.background, mw)
    text(4, 7, "ID: " .. (UI.editItem.name or "?"), config.colors.textDark, config.colors.background)

    text(4, 10, "Отображаемое имя (можно на русском):", config.colors.textDark, config.colors.background)
    drawBox(4, 11, 44, 3, config.colors.textGold, config.colors.panelLight)
    text(6, 12, UI.editItem.label, config.colors.textGold, config.colors.panelLight)
    UI.addButton(4, 11, 44, 3, "", 0x000000, 0x000000, function()
        UI.openInput("Имя предмета", UI.editItem.label, function(val)
            if val and val ~= "" then UI.editItem.label = val end; UI.draw()
        end, 40)
    end)

    local priceLabel = UI.editItem.target == "payout"
        and ("Ценность 1 шт в " .. config.currency.symbol .. ":")
        or ("Цена скупки в " .. config.currency.symbol .. ":")
    text(4, 15, priceLabel, config.colors.textDark, config.colors.background)
    drawBox(4, 16, 20, 3, config.colors.textGold, config.colors.panelLight)
    text(6, 17, UI.editItem.price, config.colors.textGold, config.colors.panelLight)
    UI.addButton(4, 16, 20, 3, "", 0x000000, 0x000000, function()
        UI.openInput("Цена", UI.editItem.price, function(val)
            if val and tonumber(val) and tonumber(val) >= 0 then UI.editItem.price = val end; UI.draw()
        end, 12)
    end)

    UI.addButton(4, 21, 16, 3, "СОХРАНИТЬ", config.colors.buttonGreen, 0xFFFFFF, function()
        local price = tonumber(UI.editItem.price)
        if not price or price < 0 then UI.setMessage("Некорректная цена", config.colors.textRed, 3); UI.draw(); return end
        if not UI.editItem.name then UI.setMessage("Нет предмета", config.colors.textRed, 3); UI.draw(); return end
        if UI.editItem.target == "payout" then
            Settings.data.payoutItem = { name = UI.editItem.name, label = UI.editItem.label, value = price }
            Settings.save()
            UI.setMessage("Предмет выплаты сохранён", config.colors.textGreen, 3)
            UI.screen = "admin"; UI.adminTab = "payout"
        else
            Settings.data.buyPrices = Settings.data.buyPrices or {}
            Settings.data.buyPrices[UI.editItem.name] = { price = price, label = UI.editItem.label }
            Settings.save()
            UI.setMessage("Добавлено: " .. UI.editItem.label, config.colors.textGreen, 3)
            UI.screen = "admin"; UI.adminTab = "buy"
        end
        UI.draw()
    end)
    UI.addButton(22, 21, 14, 3, "ОТМЕНА", config.colors.button, config.colors.text, function()
        UI.screen = "admin"
        UI.adminTab = UI.editItem.target == "payout" and "payout" or "buy"
        UI.draw()
    end)
end

function UI.draw()
    UI.clearButtons()
    gpu.setBackground(config.colors.background)
    gpu.fill(1, 1, UI.w, UI.h, " ")
    UI.drawHeader(); UI.drawSidebar(); UI.drawMainArea()
    for _, b in ipairs(UI.buttons) do UI.drawButton(b) end
end

--------------------------------------------------
-- ДЕЙСТВИЯ
--------------------------------------------------
function UI.login(name)
    if not name or name == "" then return end
    UI.playerName = name; UI.authorized = true; UI.sessionLeft = 120
    UI.betAmount = math.max(Settings.data.minBet, math.min(Settings.data.maxBet, config.bet.default))
    UI.screen = "main"; Players.get(name)
    UI.setMessage("Добро пожаловать, " .. name, config.colors.textGreen, 3)
    UI.startSessionTimer(); UI.draw()
    log("ВХОД", name, "Авторизация")
end

function UI.logout()
    UI.stopSessionTimer()
    if UI.playerName then log("ВЫХОД", UI.playerName, "Выход") end
    UI.authorized = false; UI.playerName = nil; UI.screen = "main"
    Game.reset(); UI.draw()
end

function UI.startSessionTimer()
    UI.stopSessionTimer()
    UI.timerId = event.timer(1, function()
        if not UI.authorized then return end
        UI.sessionLeft = UI.sessionLeft - 1
        if UI.sessionLeft <= 0 then UI.logout(); return end
        UI.draw()
    end, math.huge)
end

function UI.stopSessionTimer()
    if UI.timerId then event.cancel(UI.timerId); UI.timerId = nil end
end

function UI.doDeposit()
    if not UI.authorized then return end
    local item = Hardware.getDepositItem()
    if not item then UI.setMessage("Положите предмет в левый сундук", config.colors.textRed, 4); UI.draw(); return end
    local price = Settings.getPrice(item.name)
    if not price then UI.setMessage("Не скупается: " .. (item.label or item.name), config.colors.textRed, 4); UI.draw(); return end
    local total = price * item.size
    Hardware.consumeDeposit(item.size)
    Players.addBalance(UI.playerName, total)
    local label = Settings.getLabel(item.name)
    UI.setMessage("+" .. total .. " " .. config.currency.symbol, config.colors.textGreen, 4)
    log("ПОПОЛНЕНИЕ", UI.playerName, string.format("Сдано: %s(x%d) Зачислено: %s %s", label, item.size, total, config.currency.symbol))
    UI.draw()
end

function UI.doWithdraw()
    if not UI.authorized then return end
    local pi = Settings.data.payoutItem
    if not pi or not pi.name then
        UI.setMessage("Предмет выплаты не настроен (админ)", config.colors.textRed, 4); UI.draw(); return
    end
    UI.openInput("Сумма вывода в " .. config.currency.symbol, "10", function(val)
        local amount = tonumber(val)
        if not amount or amount <= 0 then UI.setMessage("Некорректная сумма", config.colors.textRed, 3); UI.draw(); return end
        local p = Players.get(UI.playerName)
        if (p.balance or 0) < amount then UI.setMessage("Недостаточно средств", config.colors.textRed, 3); UI.draw(); return end
        local value = pi.value or 1
        local count = math.floor(amount / value)
        if count < 1 then UI.setMessage("Сумма слишком мала", config.colors.textRed, 3); UI.draw(); return end
        local realAmount = count * value
        local moved, err = Hardware.exportPayout(pi.name, count)
        if moved < count then
            UI.setMessage(err or "Ошибка выдачи из ME", config.colors.textRed, 5)
            log("ОШИБКА", UI.playerName, "Вывод: " .. (err or "ME пусто")); UI.draw(); return
        end
        Players.addBalance(UI.playerName, -realAmount)
        UI.setMessage("Выведено " .. realAmount .. " " .. config.currency.symbol, config.colors.textGreen, 5)
        log("ВЫВОД", UI.playerName, string.format("%s(x%d) = %s %s", pi.label or pi.name, count, realAmount, config.currency.symbol))
        UI.draw()
    end, 10)
end

function UI.startGame()
    if not UI.authorized then return end
    local p = Players.get(UI.playerName)
    if (p.balance or 0) < UI.betAmount then UI.setMessage("Недостаточно средств", config.colors.textRed, 3); UI.draw(); return end
    if UI.betAmount < Settings.data.minBet or UI.betAmount > Settings.data.maxBet then
        UI.setMessage("Ставка вне лимитов", config.colors.textRed, 3); UI.draw(); return end
    Players.addBalance(UI.playerName, -UI.betAmount)
    Players.addPlayed(UI.playerName, UI.betAmount)
    Game.reset(); Game.bet = UI.betAmount; Game.deal()
    UI.screen = Game.finished and "result" or "playing"
    if Game.finished then UI.resolveGame() end
    UI.draw()
end

function UI.resolveGame()
    local mult = Game.payoutMultiplier()
    local win = math.floor(Game.bet * mult + 0.5)

    if win > 0 then
        local pi = Settings.data.payoutItem
        if pi and pi.name then
            local value = pi.value or 1
            local count = math.floor(win / value)
            if count >= 1 then
                local moved, err = Hardware.exportPayout(pi.name, count)
                if moved > 0 then
                    local paid = moved * value
                    local rest = win - paid
                    if rest > 0 then Players.addBalance(UI.playerName, rest) end
                    log("ВЫИГРЫШ", UI.playerName, string.format("%s(x%d) в сундук | ставка %d", pi.label or pi.name, moved, Game.bet))
                    if err then UI.setMessage("Частично: " .. err, config.colors.textGold, 4) end
                else
                    Players.addBalance(UI.playerName, win)
                    log("ВЫИГРЫШ", UI.playerName, string.format("+%d %s на баланс (ME: %s)", win, config.currency.symbol, err or "?"))
                    UI.setMessage("Выигрыш на баланс — " .. (err or "ME пусто"), config.colors.textGold, 5)
                end
            else
                Players.addBalance(UI.playerName, win)
                log("ВЫИГРЫШ", UI.playerName, string.format("+%d %s на баланс | ставка %d", win, config.currency.symbol, Game.bet))
            end
        else
            Players.addBalance(UI.playerName, win)
            log("ВЫИГРЫШ", UI.playerName, string.format("+%d %s на баланс | ставка %d", win, config.currency.symbol, Game.bet))
        end
    else
        if Game.result == "LOSE" then
            log("ПРОИГРЫШ", UI.playerName, string.format("Ставка %d %s", Game.bet, config.currency.symbol))
        elseif Game.result == "DRAW" then
            log("НИЧЬЯ", UI.playerName, string.format("Возврат %d %s", win, config.currency.symbol))
        end
    end

    local p = Players.get(UI.playerName)
    p.games = (p.games or 0) + 1
    if Game.result == "WIN" or Game.result == "BLACKJACK" then p.wins = (p.wins or 0) + 1 end
    Players.save()
    UI.screen = "result"
end

--------------------------------------------------
local function boot()
    local maxW, maxH = gpu.maxResolution()
    local targetW = math.min(160, maxW)
    local targetH = math.min(50, maxH)
    if targetW < 80 then targetW = maxW end
    if targetH < 25 then targetH = maxH end
    pcall(gpu.setResolution, targetW, targetH)
    UI.w, UI.h = gpu.getResolution()

    ensureDir(config.paths.data)
    Players.load(); Settings.load(); Hardware.init(); loadLogsFromFile()
    math.randomseed(computer.uptime() * 1000 + (computer.address():byte(1) or 0))
    log("СИСТЕМА", "-", "BlackJack 2.2 @ " .. UI.w .. "x" .. UI.h)
    UI.draw()

    while true do
        local ev = { event.pull(0.5) }
        local e = ev[1]
        if e == "key_down" then
            UI.handleKey(ev[3], ev[4])
        elseif e == "touch" then
            local x, y, _, player = ev[3], ev[4], ev[5], ev[6]
            if UI.input.active then UI.checkButtons(x, y)
            elseif not UI.authorized then
                if player and player ~= "" then UI.login(player) end
            else
                UI.sessionLeft = 120; UI.checkButtons(x, y)
            end
        elseif e == "interrupted" then break end
    end
end

local ok, err = pcall(boot)
if not ok then
    pcall(term.clear)
    print("Ошибка BlackJack:"); print(err)
    log("ОШИБКА", "-", tostring(err))
end
