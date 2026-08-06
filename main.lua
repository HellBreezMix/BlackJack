--------------------------------------------------
-- BlackJack Casino v2.4
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

-- Сукно стола (жёстко, не зависит от config)
config.colors.background  = 0x0D6B3F
config.colors.feltDark    = 0x0A5532
config.colors.feltPattern = 0x14905A
config.colors.panel       = 0x084028
config.colors.panelLight  = 0x0C5A3A
config.colors.header      = 0x063020
config.colors.textDark    = 0xB8D4C0
config.colors.button      = 0x1A6B42
config.colors.tableGreen  = 0x0D6B3F

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
-- ВРЕМЯ (Москва, UTC+3)
--------------------------------------------------
local function moscowNow()
    -- real-time unix; Москва UTC+3
    local t = os.time()
    if type(t) ~= "number" or t < 100000 then
        -- fallback если os.time недоступен
        t = math.floor(computer.uptime() + 1700000000)
    end
    return t + 3 * 3600
end

local function moscowDate(fmt, t)
    fmt = fmt or "%Y-%m-%d %H:%M:%S"
    t = t or moscowNow()
    local ok, s = pcall(os.date, "!" .. fmt, t)
    if ok and s then return s end
    ok, s = pcall(os.date, fmt, t)
    if ok and s then return s end
    return "?"
end

--------------------------------------------------
-- ЛОГИ
--------------------------------------------------
local Logs = { entries = {} }

local LOG_KEEP = {
    ["ПОПОЛНЕНИЕ"] = true,
    ["ВЫИГРЫШ"] = true,
    ["ПРОИГРЫШ"] = true,
    ["ОШИБКА"] = true,
}

local function log(kind, player, text)
    kind = kind or "INFO"
    -- в UI/файл только важные события
    if not LOG_KEEP[kind] then return end
    local entry = {
        time   = moscowNow(),
        kind   = kind,
        player = player or "-",
        text   = text or ""
    }
    table.insert(Logs.entries, 1, entry)
    while #Logs.entries > 100 do table.remove(Logs.entries) end
    ensureDir(config.paths.log)
    local f = io.open(config.paths.log, "a")
    if f then
        local ts = moscowDate("%Y-%m-%d %H:%M:%S", entry.time)
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
    local start = math.max(1, #lines - 80)
    for i = #lines, start, -1 do
        local line = lines[i]
        local ts, kind, player, text = line:match("%[(.-)%] (.-) | (.-) | (.+)")
        if ts and kind and LOG_KEEP[kind] then
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

local function roundMoney(v)
    v = tonumber(v) or 0
    -- до 4 знаков, убираем float-хвосты (0.099999999)
    return math.floor(v * 10000 + 0.5) / 10000
end

local function fmtMoney(v)
    v = roundMoney(v)
    if math.abs(v - math.floor(v + 1e-9)) < 1e-9 then
        return tostring(math.floor(v + 1e-9))
    end
    local s = string.format("%.4f", v):gsub("0+$", ""):gsub("%.$", "")
    return s
end

function Players.addBalance(name, amount)
    local p = Players.get(name)
    p.balance = math.max(0, roundMoney((p.balance or 0) + (tonumber(amount) or 0)))
    if amount and amount > 0 then p.totalWon = roundMoney((p.totalWon or 0) + amount) end
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
        payoutItem = nil,
        bjPayout = config.game.blackjackPayout or 2.5,
        winPayout = config.game.winPayout or 2.0,
        decks = config.game.decks or 6
    }
    local loaded = loadDB(config.paths.settings)
    if loaded then
        Settings.data = loaded
        Settings.data.minBet = Settings.data.minBet or config.bet.min
        Settings.data.maxBet = Settings.data.maxBet or config.bet.max
        Settings.data.buyPrices = normalizeBuyPrices(Settings.data.buyPrices or config.buyPrices)
        Settings.data.bjPayout = Settings.data.bjPayout or config.game.blackjackPayout or 2.5
        Settings.data.winPayout = Settings.data.winPayout or config.game.winPayout or 2.0
        Settings.data.decks = Settings.data.decks or config.game.decks or 6
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

-- Все предметы в сундуке ставки (все слоты), сгруппированные по name
function Hardware.getDepositItems()
    if not Hardware.transposer then return {} end
    local side = config.hardware.transposerSide
    local size = 27
    local okS, invSize = pcall(Hardware.transposer.getInventorySize, side)
    if okS and invSize then size = invSize end

    local groups = {}  -- name -> {name, label, damage, size, slots={}}
    for slot = 1, size do
        local ok, stack = pcall(Hardware.transposer.getStackInSlot, side, slot)
        if ok and stack and stack.size and stack.size > 0 then
            local n = stack.name
            if not groups[n] then
                groups[n] = {
                    name = n,
                    label = stack.label or n,
                    damage = stack.damage or 0,
                    size = 0,
                    slots = {}
                }
            end
            groups[n].size = groups[n].size + stack.size
            table.insert(groups[n].slots, { slot = slot, size = stack.size })
        end
    end
    local list = {}
    for _, g in pairs(groups) do table.insert(list, g) end
    return list
end

-- совместимость: первый стак
function Hardware.getDepositItem()
    local list = Hardware.getDepositItems()
    if #list == 0 then return nil end
    -- предпочитаем предмет из скупки
    for _, g in ipairs(list) do
        if Settings.getPrice(g.name) then return g end
    end
    return list[1]
end

-- Забрать count предметов name из всех слотов сундука
function Hardware.consumeDeposit(itemName, count)
    if not Hardware.transposer then return 0 end
    local side = config.hardware.transposerSide
    count = math.floor(count or 0)
    if count <= 0 then return 0 end

    local taken = 0
    local size = 27
    local okS, invSize = pcall(Hardware.transposer.getInventorySize, side)
    if okS and invSize then size = invSize end

    for slot = 1, size do
        if taken >= count then break end
        local ok, stack = pcall(Hardware.transposer.getStackInSlot, side, slot)
        if ok and stack and stack.name == itemName and stack.size and stack.size > 0 then
            local need = math.min(stack.size, count - taken)
            -- в ME
            local moved = false
            if Hardware.me and Hardware.me.importItem then
                local ok2 = pcall(Hardware.me.importItem, side, slot, need)
                if ok2 then moved = true; taken = taken + need end
            end
            if not moved then
                local ok3 = pcall(Hardware.transposer.transferItem, side, 0, need, slot)
                if ok3 then taken = taken + need end
            end
        end
    end
    return taken
end

function Hardware.exportPayout(itemName, count)
    if not Hardware.me then return 0, "ME Interface не найден" end
    if not itemName or count <= 0 then return 0, "Нет предмета" end
    count = math.floor(count)
    local side = config.hardware.meSide

    local function countInNetwork()
        local total = 0
        local list = nil
        local ok, res = pcall(function()
            return Hardware.me.getItemsInNetwork({ name = itemName })
        end)
        if ok and res and #res > 0 then
            list = res
        else
            ok, res = pcall(function() return Hardware.me.getItemsInNetwork() end)
            list = {}
            if ok and res then
                for _, it in ipairs(res) do
                    local n = it.name or it.id
                    if tostring(n) == tostring(itemName) then table.insert(list, it) end
                end
            end
        end
        for _, it in ipairs(list or {}) do
            total = total + (tonumber(it.size) or tonumber(it.qty) or 0)
        end
        return total, list
    end

    local available, items = countInNetwork()
    if available < 1 or not items or #items == 0 then
        return 0, "В ME сети нет: " .. tostring(itemName)
    end
    if count > available then count = available end

    local stack = items[1]
    local name = tostring(stack.name or stack.id or itemName)
    local dmg = tonumber(stack.damage) or 0
    local fingerprint = { id = name, name = name, damage = dmg, dmg = dmg }
    if stack.id ~= nil then fingerprint.id = stack.id end

    -- Выдаём пачками по 64 (лимит стака), пока не наберём всю сумму
    local totalMoved = 0
    local lastErr = nil
    while totalMoved < count do
        local batch = math.min(64, count - totalMoved)
        local before = countInNetwork()

        local ok, result = pcall(function()
            return Hardware.me.exportItem(fingerprint, side, batch)
        end)
        if not ok then
            ok, result = pcall(function()
                return Hardware.me.exportItem(fingerprint, "UP", batch)
            end)
        end

        local after = countInNetwork()
        local moved = before - after
        if moved < 0 then moved = 0 end
        if moved > batch then moved = batch end

        if moved <= 0 then
            lastErr = (not ok) and tostring(result) or "не удалось выдать пачку"
            break
        end
        totalMoved = totalMoved + moved
    end

    if totalMoved > 0 then
        return totalMoved, (totalMoved < count) and ("частично " .. totalMoved .. "/" .. count) or nil
    end
    return 0, lastErr or "export не удался"
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

-- Пипы только в центре (x:2..6, y:2..4), ранги в углах отдельно
local faceLayout = {
    ["A"]  = {{4,3}},
    ["2"]  = {{4,2},{4,4}},
    ["3"]  = {{4,2},{4,3},{4,4}},
    ["4"]  = {{2,2},{6,2},{2,4},{6,4}},
    ["5"]  = {{2,2},{6,2},{4,3},{2,4},{6,4}},
    ["6"]  = {{2,2},{6,2},{2,3},{6,3},{2,4},{6,4}},
    ["7"]  = {{2,2},{6,2},{4,2},{2,3},{6,3},{2,4},{6,4}},
    ["8"]  = {{2,2},{6,2},{2,3},{6,3},{2,4},{6,4},{4,2},{4,4}},
    ["9"]  = {{2,2},{6,2},{2,3},{4,3},{6,3},{2,4},{6,4},{4,2},{4,4}},
    ["10"] = {{2,2},{6,2},{2,3},{6,3},{2,4},{6,4},{3,2},{5,2},{3,4},{5,4}},
    ["J"] = "face", ["Q"] = "face", ["K"] = "face"
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
    Game.deck = Cards.createDeck(Settings.data.decks or config.game.decks or 6)
    Game.player = { hand = {}, standing = false }
    Game.dealer = { hand = {}, standing = false }
    Game.finished = false; Game.result = nil; Game.bet = 0; Game.state = "idle"
end

function Game.deal()
    if #Game.deck < 4 then Game.deck = Cards.createDeck(Settings.data.decks or config.game.decks or 6) end
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
    if Game.result == "BLACKJACK" then return tonumber(Settings.data.bjPayout) or config.game.blackjackPayout or 2.5 end
    if Game.result == "WIN" then return tonumber(Settings.data.winPayout) or config.game.winPayout or 2.0 end
    if Game.result == "DRAW" then return config.game.drawPayout or 1.0 end
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
    adminTab = "bets", logScroll = 0, pendingAuth = false, alert = nil,
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
    table.insert(UI.buttons, {
        x = x, y = y, w = w, h = h,
        text = text, bg = bg, fg = fg or config.colors.text,
        cb = callback,
        -- невидимая зона клика (не перерисовывает фон)
        hitbox = (text == "" or text == nil) and (bg == 0x000000 or bg == 0)
    })
end

function UI.drawButton(b)
    if b.hitbox then return end  -- только клик, без заливки
    gpu.setBackground(b.bg); gpu.setForeground(b.fg)
    gpu.fill(b.x, b.y, b.w, b.h, " ")
    local label = b.text or ""
    local tx = b.x + math.floor((b.w - unicode.len(label)) / 2)
    local ty = b.y + math.floor((b.h - 1) / 2)
    gpu.set(tx, ty, label)
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
    gpu.setBackground(color)
    gpu.fill(x, y, w, h, " ")
end

-- Фон сукна стола
local FELT_BASE = 0x0D6B3F
local FELT_PAT  = 0x1A9A5C
local _screenBuf = nil

local function drawFelt(x, y, w, h)
    -- только заливка (узор убран — он давал лаги и мигание)
    fill(x, y, w, h, FELT_BASE)
end

local function drawFeltPattern(x, y, w, h)
    -- лёгкий узор только для экрана ожидания (рисуется 1 раз вместе с контентом)
    fill(x, y, w, h, FELT_BASE)
    gpu.setBackground(FELT_BASE)
    gpu.setForeground(FELT_PAT)
    local suits = { "♠", "♥", "♦", "♣" }
    local si = 1
    for row = y, y + h - 1, 4 do
        local shift = (math.floor((row - y) / 4) % 2) * 2
        for col = x + shift, x + w - 1, 6 do
            gpu.set(col, row, suits[si])
            si = si % 4 + 1
        end
    end
end

local function drawScreen()
    UI.clearButtons()

    -- буфер переиспользуем, не создаём каждый кадр
    local useBuf = false
    if gpu.allocateBuffer and gpu.setActiveBuffer and gpu.bitblt then
        if not _screenBuf then
            local ok, id = pcall(gpu.allocateBuffer, UI.w, UI.h)
            if ok and id then _screenBuf = id end
        end
        if _screenBuf and pcall(gpu.setActiveBuffer, _screenBuf) then
            useBuf = true
        end
    end

    drawFelt(1, 1, UI.w, UI.h)
    UI.drawHeader()
    UI.drawSidebar()
    UI.drawMainArea()
    if UI.alert then UI.drawAlert() end
    for _, b in ipairs(UI.buttons) do UI.drawButton(b) end

    if useBuf and _screenBuf then
        pcall(gpu.setActiveBuffer, 0)
        pcall(gpu.bitblt, 0, 1, 1, UI.w, UI.h, _screenBuf)
    end
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
        gpu.setForeground(0x4A2020)
        gpu.setBackground(config.colors.cardBack)
        for dy = 1, ch - 2 do
            for dx = 1, cw - 2 do
                if (dx + dy) % 2 == 0 then gpu.set(x + dx, y + dy, "░") end
            end
        end
        return
    end

    fill(x, y, cw, ch, config.colors.cardFace)
    gpu.setForeground(0x444444)
    gpu.setBackground(config.colors.cardFace)
    for i = 0, cw - 1 do
        gpu.set(x + i, y, "─")
        gpu.set(x + i, y + ch - 1, "─")
    end
    for i = 0, ch - 1 do
        gpu.set(x, y + i, "│")
        gpu.set(x + cw - 1, y + i, "│")
    end
    gpu.set(x, y, "┌")
    gpu.set(x + cw - 1, y, "┐")
    gpu.set(x, y + ch - 1, "└")
    gpu.set(x + cw - 1, y + ch - 1, "┘")

    local col = Cards.suitColors[card.suit] or 0x111111
    local rank = card.rank
    local layout = faceLayout[rank]

    if layout == "face" then
        -- J/Q/K: крупный ранг + масть по центру
        text(x + 1, y + 1, rank, col, config.colors.cardFace)
        text(x + 4, y + 3, card.suit, col, config.colors.cardFace)
        text(x + cw - 2, y + ch - 2, rank, col, config.colors.cardFace)
    else
        -- Ранг в углах
        if rank == "10" then
            -- "10" занимает 2 символа — рисуем аккуратно
            text(x + 1, y + 1, "10", col, config.colors.cardFace)
            text(x + cw - 3, y + ch - 2, "10", col, config.colors.cardFace)
        else
            text(x + 1, y + 1, rank, col, config.colors.cardFace)
            text(x + cw - 2, y + ch - 2, rank, col, config.colors.cardFace)
        end
        -- Пипы строго внутри, не на рамке и не на углах с рангом
        if type(layout) == "table" then
            for _, pos in ipairs(layout) do
                local px, py = pos[1], pos[2]
                if px >= 2 and px <= 6 and py >= 2 and py <= 4 then
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
    fill(1, 2, mw, UI.h - 1, 0x042818)
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
    centerText(1, "CASINO BLACKJACK", config.colors.textBlue, config.colors.header)
end

function UI.drawSidebar()
    local sx = UI.w - config.ui.sidebarWidth + 1
    local sw = config.ui.sidebarWidth
    fill(sx, 2, sw, UI.h - 1, config.colors.panel)

    if not UI.authorized then
        UI.addButton(sx + 1, 3, sw - 2, 4, "АВТОРИЗАЦИЯ", config.colors.buttonGreen, 0xFFFFFF, function()
            UI.pendingAuth = true
            UI.setMessage("Коснитесь экрана своим ником", config.colors.textGold, 5)
            UI.draw()
        end)
        text(sx + 2, 8, "Нажмите кнопку,", config.colors.textDark, config.colors.panel)
        text(sx + 2, 9, "затем коснитесь", config.colors.textDark, config.colors.panel)
    else
        UI.addButton(sx + 1, 3, sw - 2, 3, "ВЫХОД", config.colors.buttonRed, 0xFFFFFF, function() UI.logout() end)
        text(sx + 2, 7, UI.playerName or "?", config.colors.textGreen, config.colors.panel)
        local p = Players.get(UI.playerName)
        text(sx + 2, 8, string.format("%s %s", fmtMoney(p.balance or 0), config.currency.symbol), config.colors.textGold, config.colors.panel)
        text(sx + 2, 9, "Выход через: " .. UI.sessionLeft .. "с", config.colors.textDark, config.colors.panel)

        UI.addButton(sx + 1, 11, sw - 2, 3, "ПОПОЛНИТЬ СЧЁТ", config.colors.buttonGreen, 0xFFFFFF, function() UI.doDeposit() end)

        if config.admins[UI.playerName] then
            UI.addButton(sx + 1, 15, sw - 2, 3, "АДМИН ПАНЕЛЬ", config.colors.buttonBlue, 0xFFFFFF, function()
                UI.screen = "admin"; UI.adminTab = "bets"; UI.draw()
            end)
        end
    end

    local y = UI.authorized and (config.admins[UI.playerName] and 19 or 15) or 12
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
        local priceStr = tostring(entry.price)
        local line = string.format("%s 1 шт - %s %s", short, priceStr, config.currency.symbol)
        if unicode.len(line) > sw - 2 then
            line = string.format("%s - %s %s", short, priceStr, config.currency.symbol)
        end
        text(sx + 1, y, line, config.colors.text, config.colors.panel)
        y = y + 1
    end
    if count == 0 then text(sx + 1, y, "Нет предметов", config.colors.textDark, config.colors.panel); y = y + 1 end

    y = y + 1
    text(sx + 1, y, "ТОП 15:", config.colors.textBlue, config.colors.panel); y = y + 1
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
function UI.drawRules(mw, startY)
    local y = startY or 22
    local winX = tonumber(Settings.data.winPayout) or 2.0
    local bjX  = tonumber(Settings.data.bjPayout) or 2.5
    local winStr = (winX == math.floor(winX)) and tostring(math.floor(winX)) or string.format("%.2f", winX):gsub("0+$", ""):gsub("%.$", "")
    local bjStr  = (bjX == math.floor(bjX)) and tostring(math.floor(bjX)) or string.format("%.2f", bjX):gsub("0+$", ""):gsub("%.$", "")
    centerText(y, "ПРАВИЛА", config.colors.textBlue, config.colors.background, mw); y = y + 1
    centerText(y, "Цель: набрать больше дилера, не больше 21", config.colors.text, config.colors.background, mw); y = y + 1
    centerText(y, "Победа: x" .. winStr .. "   |   Blackjack: x" .. bjStr, config.colors.textGold, config.colors.background, mw); y = y + 1
    centerText(y, "Ничья: ставка возвращается на баланс", config.colors.text, config.colors.background, mw); y = y + 1
    centerText(y, "Перебор (>21): проигрыш", config.colors.textDark, config.colors.background, mw)
end

function UI.drawWelcomeArt(mw)
    -- хаотично разбросанные карты по столу (без зелёной подложки)
    local scatter = {
        -- x, y, rank, suit, hidden (рубашка)
        {  3,  3, "A", "♠", false },
        { 14,  4, "7", "♥", true  },
        { 28,  3, "K", "♦", false },
        { 42,  5, "3", "♣", false },
        {  6, 11, "Q", "♥", false },
        { 20, 10, "10","♠", true  },
        { 35, 12, "J", "♣", false },
        { 48,  9, "5", "♦", true  },
        {  4, 18, "9", "♦", false },
        { 18, 17, "2", "♣", true  },
        { 40, 18, "A", "♥", false },
        { 52, 15, "8", "♠", false },
        { 30, 20, "4", "♥", true  },
        { 12, 22, "K", "♠", false },
        { 45, 23, "6", "♣", false },
    }
    for _, c in ipairs(scatter) do
        if c[1] + 9 < mw - 1 and c[2] + 7 < UI.h - 1 then
            drawCard(c[1], c[2], { rank = c[3], suit = c[4] }, c[5])
        end
    end
    -- заголовок поверх
    centerText(8, "♠  BLACKJACK  ♥", config.colors.textGold, config.colors.background, mw)
    UI.drawRules(mw, 26)
    centerText(math.min(UI.h - 2, 32), "Нажмите «АВТОРИЗАЦИЯ» справа", config.colors.text, config.colors.background, mw)
end

function UI.drawMainArea()
    local mw = UI.w - config.ui.sidebarWidth
    if UI.input.active then UI.drawInputModal(); return end

    if UI.screen == "main" then
        if UI.authorized then
                    local cx = math.floor(mw / 2)
            centerText(10, "BLACKJACK", config.colors.textGold, config.colors.background, mw)
            local bal = fmtMoney(Players.get(UI.playerName).balance)
            centerText(12, "Ваш баланс: " .. bal .. " " .. config.currency.symbol, config.colors.text, config.colors.background, mw)

            centerText(15, "СТАВКА (нажми чтобы ввести)", config.colors.textBlue, config.colors.background, mw)
            drawBox(cx - 10, 16, 20, 3, config.colors.textGold, config.colors.panelLight)
            text(cx - 8, 17, tostring(UI.betAmount) .. " " .. config.currency.symbol, config.colors.textGold, config.colors.panelLight)
            UI.addButton(cx - 10, 16, 20, 3, "", 0x000000, 0x000000, function()
                UI.openInput("Ставка (целое число)", tostring(UI.betAmount), function(val)
                    if not val then UI.draw(); return end
                    local n = tonumber(val)
                    if not n then UI.setMessage("Только число", config.colors.textRed, 3); UI.draw(); return end
                    n = math.floor(n + 1e-9)
                    if n < Settings.data.minBet or n > Settings.data.maxBet then
                        UI.setMessage("Лимит " .. Settings.data.minBet .. "–" .. Settings.data.maxBet, config.colors.textRed, 3)
                        UI.draw(); return
                    end
                    UI.betAmount = n
                    UI.draw()
                end, 8)
            end)
            text(cx - 10, 20, "Мин: " .. Settings.data.minBet .. "   Макс: " .. Settings.data.maxBet, config.colors.textDark, config.colors.background)
            UI.addButton(cx - 10, 22, 20, 3, "ИГРАТЬ", config.colors.buttonGreen, 0xFFFFFF, function() UI.startGame() end)
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
    centerText(3, "АДМИН-ПАНЕЛЬ", config.colors.textBlue, config.colors.background, mw)

    local tabs = {
        { id = "bets", title = "СТАВКИ" },
        { id = "buy", title = "СКУПКА" },
        { id = "payout", title = "ВЫПЛАТА" },
        { id = "logs", title = "ЛОГИ" },
        { id = "odds", title = "ВЕРОЯТН." },
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
    elseif UI.adminTab == "logs" then UI.drawAdminLogs(mw)
    elseif UI.adminTab == "odds" then UI.drawAdminOdds(mw) end

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
    local start = 1 + (UI.logScroll or 0)
    local shown = 0
    for i = start, #Logs.entries do
        local e = Logs.entries[i]
        if e and LOG_KEEP[e.kind] then
            local ts
            if e.time and e.time > 100000 then
                ts = moscowDate("%Y-%m-%d %H:%M:%S", e.time)
            elseif e.raw then
                ts = e.raw:match("^%[(.-)%]") or ""
            else
                ts = ""
            end
            local kindCol = config.colors.text
            if e.kind == "ВЫИГРЫШ" then kindCol = config.colors.textGreen
            elseif e.kind == "ПРОИГРЫШ" then kindCol = config.colors.textRed
            elseif e.kind == "ПОПОЛНЕНИЕ" then kindCol = config.colors.textGold
            elseif e.kind == "ОШИБКА" then kindCol = config.colors.textRed end

            local line = string.format("[%s] %s | %s", ts, e.kind, e.player)
            if unicode.len(line) > mw - 6 then line = unicode.sub(line, 1, mw - 8) .. ".." end
            text(4, y, line, kindCol, config.colors.background)
            y = y + 1
            if e.text and e.text ~= "" then
                local t2 = "  " .. e.text
                if unicode.len(t2) > mw - 6 then t2 = unicode.sub(t2, 1, mw - 8) .. ".." end
                text(4, y, t2, config.colors.textDark, config.colors.background)
                y = y + 1
            end
            shown = shown + 1
            if y > UI.h - 5 then break end
        end
    end
    if shown == 0 then
        text(4, 10, "Логов пока нет", config.colors.textDark, config.colors.background)
    end
    -- стрелки справа от кнопки «НАЗАД»
    UI.addButton(20, UI.h - 3, 5, 2, "▲", config.colors.button, config.colors.text, function()
        UI.logScroll = math.max(0, (UI.logScroll or 0) - 2); UI.draw()
    end)
    UI.addButton(26, UI.h - 3, 5, 2, "▼", config.colors.button, config.colors.text, function()
        UI.logScroll = math.min(math.max(0, #Logs.entries - 1), (UI.logScroll or 0) + 2); UI.draw()
    end)
end


function UI.drawAdminOdds(mw)
    text(4, 8, "Настройка выплат и колоды:", config.colors.textBlue, config.colors.background)

    text(4, 11, "Blackjack выплата (3:2 = 2.5):", config.colors.textDark, config.colors.background)
    drawBox(4, 12, 18, 3, config.colors.textGold, config.colors.panelLight)
    text(6, 13, tostring(Settings.data.bjPayout or 2.5), config.colors.textGold, config.colors.panelLight)
    UI.addButton(4, 12, 18, 3, "", 0x000000, 0x000000, function()
        UI.openInput("Blackjack множитель", tostring(Settings.data.bjPayout or 2.5), function(val)
            local n = tonumber(val)
            if n and n >= 1 and n <= 10 then
                Settings.data.bjPayout = n
                Settings.save()
            end
            UI.draw()
        end, 6)
    end)
    text(24, 13, "× ставка  (2.5 = 3:2)", config.colors.textDark, config.colors.background)

    text(4, 16, "Обычная победа (1:1 = 2.0):", config.colors.textDark, config.colors.background)
    drawBox(4, 17, 18, 3, config.colors.textGold, config.colors.panelLight)
    text(6, 18, tostring(Settings.data.winPayout or 2.0), config.colors.textGold, config.colors.panelLight)
    UI.addButton(4, 17, 18, 3, "", 0x000000, 0x000000, function()
        UI.openInput("Множитель победы", tostring(Settings.data.winPayout or 2.0), function(val)
            local n = tonumber(val)
            if n and n >= 1 and n <= 10 then
                Settings.data.winPayout = n
                Settings.save()
            end
            UI.draw()
        end, 6)
    end)
    text(24, 18, "× ставка  (2.0 = 1:1)", config.colors.textDark, config.colors.background)

    text(4, 21, "Число колод (1–8):", config.colors.textDark, config.colors.background)
    drawBox(4, 22, 18, 3, config.colors.textGold, config.colors.panelLight)
    text(6, 23, tostring(Settings.data.decks or 6), config.colors.textGold, config.colors.panelLight)
    UI.addButton(4, 22, 18, 3, "", 0x000000, 0x000000, function()
        UI.openInput("Колод", tostring(Settings.data.decks or 6), function(val)
            local n = tonumber(val)
            if n then
                n = math.floor(n)
                if n >= 1 and n <= 8 then
                    Settings.data.decks = n
                    Settings.save()
                end
            end
            UI.draw()
        end, 2)
    end)
end

function UI.drawAdminAddItem(mw)
    local title = UI.editItem.target == "payout" and "ПРЕДМЕТ ВЫПЛАТЫ" or "ДОБАВЛЕНИЕ ПРЕДМЕТА"
    centerText(5, title, config.colors.textBlue, config.colors.background, mw)
    centerText(9, "Положи предмет в левый сундук", config.colors.text, config.colors.background, mw)
    centerText(10, "(транспозер сверху) и нажми ОК", config.colors.textDark, config.colors.background, mw)
    UI.addButton(math.floor(mw/2) - 8, 14, 16, 3, "ОК", config.colors.buttonGreen, 0xFFFFFF, function()
        local item = Hardware.getDepositItem()
        if not item then UI.setMessage("Сундук пуст!", config.colors.textRed, 4); UI.draw(); return end
        UI.editItem.name = item.name
        UI.editItem.label = tostring(item.label or item.name or "")  -- русское имя из игры
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
    centerText(4, "НАСТРОЙКА ПРЕДМЕТА", config.colors.textBlue, config.colors.background, mw)
    text(4, 7, "ID: " .. (UI.editItem.name or "?"), config.colors.textDark, config.colors.background)

    text(4, 10, "Отображаемое имя (можно на русском):", config.colors.textDark, config.colors.background)
    drawBox(4, 11, 44, 3, config.colors.textGold, config.colors.panelLight)
    local lbl = UI.editItem.label
    if not lbl or lbl == "" then lbl = "(нажми чтобы ввести)" end
    text(6, 12, lbl, config.colors.textGold, config.colors.panelLight)
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
    local pr = UI.editItem.price
    if not pr or pr == "" then pr = "1" end
    text(6, 17, pr, config.colors.textGold, config.colors.panelLight)
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
    drawScreen()
end

--------------------------------------------------
-- ДЕЙСТВИЯ
--------------------------------------------------
function UI.login(name)
    if not name or name == "" then return end
    UI.pendingAuth = false
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

function UI.updateSessionLabel()
    if not UI.authorized or not UI.playerName then return end
    if UI.input.active or UI.alert then return end
    local sx = UI.w - config.ui.sidebarWidth + 1
    local sw = config.ui.sidebarWidth
    -- только строка таймера, без полной перерисовки (убирает мигание)
    gpu.setBackground(config.colors.panel)
    gpu.fill(sx + 1, 9, sw - 2, 1, " ")
    gpu.setForeground(config.colors.textDark)
    gpu.set(sx + 2, 9, "Выход через: " .. tostring(UI.sessionLeft) .. "с")
end

function UI.startSessionTimer()
    UI.stopSessionTimer()
    UI.timerId = event.timer(1, function()
        if not UI.authorized then return end
        UI.sessionLeft = UI.sessionLeft - 1
        if UI.sessionLeft <= 0 then UI.logout(); return end
        UI.updateSessionLabel()
    end, math.huge)
end

function UI.stopSessionTimer()
    if UI.timerId then event.cancel(UI.timerId); UI.timerId = nil end
end

function UI.doDeposit()
    if not UI.authorized then return end
    local groups = Hardware.getDepositItems()
    if #groups == 0 then
        UI.setMessage("Положите предметы в левый сундук", config.colors.textRed, 4)
        UI.draw(); return
    end

    local totalCredit = 0
    local details = {}
    for _, g in ipairs(groups) do
        local price = Settings.getPrice(g.name)
        if price then
            local taken = Hardware.consumeDeposit(g.name, g.size)
            if taken > 0 then
                local sum = price * taken
                totalCredit = totalCredit + sum
                table.insert(details, string.format("%s(x%d)", Settings.getLabel(g.name), taken))
            end
        end
    end

    if totalCredit <= 0 then
        UI.setMessage("Нет скупаемых предметов в сундуке", config.colors.textRed, 4)
        UI.draw(); return
    end

    Players.addBalance(UI.playerName, totalCredit)
    UI.setMessage("+" .. fmtMoney(totalCredit) .. " " .. config.currency.symbol, config.colors.textGreen, 4)
    log("ПОПОЛНЕНИЕ", UI.playerName, string.format("Сдано: %s Зачислено: %s %s",
        table.concat(details, ", "), fmtMoney(totalCredit), config.currency.symbol))
    UI.draw()
end

function UI.showAlert(title, callback)
    UI.alert = { title = title or "Сообщение", cb = callback }
    UI.draw()
end

function UI.drawAlert()
    if not UI.alert then return end
    local mw = UI.w - config.ui.sidebarWidth
    local boxW, boxH = 36, 9
    local bx = math.floor((mw - boxW) / 2) + 1
    local by = math.floor((UI.h - boxH) / 2)
    fill(1, 2, mw, UI.h - 1, 0x042818)
    drawBox(bx, by, boxW, boxH, config.colors.textRed, config.colors.panel)
    centerText(by + 2, UI.alert.title, config.colors.textRed, config.colors.panel, mw)
    UI.addButton(bx + math.floor((boxW - 12) / 2), by + 5, 12, 3, "ОК", config.colors.buttonGreen, 0xFFFFFF, function()
        local cb = UI.alert and UI.alert.cb
        UI.alert = nil
        if cb then cb() end
        UI.draw()
    end)
end

function UI.startGame()
    if not UI.authorized then return end
    local p = Players.get(UI.playerName)
    if roundMoney(p.balance or 0) < UI.betAmount then
        UI.showAlert("Недостаточно средств")
        return
    end
    if UI.betAmount < Settings.data.minBet or UI.betAmount > Settings.data.maxBet then
        UI.showAlert("Ставка вне лимитов " .. Settings.data.minBet .. "–" .. Settings.data.maxBet)
        return
    end
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

    if Game.result == "DRAW" then
        -- Возврат ставки на баланс
        local refund = math.floor(Game.bet * (config.game.drawPayout or 1) + 0.5)
        if refund > 0 then Players.addBalance(UI.playerName, refund) end
        log("НИЧЬЯ", UI.playerName, string.format("Возврат %d %s", refund, config.currency.symbol))
    elseif win > 0 then
        -- Выигрыш: только в правый сундук из ME (не на баланс)
        local pi = Settings.data.payoutItem
        if pi and pi.name then
            local value = tonumber(pi.value) or 1
            if value <= 0 then value = 1 end
            local count = math.max(1, math.floor(win / value + 1e-9))

            local moved, err = Hardware.exportPayout(pi.name, count)
            if moved and moved > 0 then
                log("ВЫИГРЫШ", UI.playerName, string.format(
                    "Выдал %s(x%d) в сундук | ставка %d | выигрыш %d %s",
                    pi.label or pi.name, moved, Game.bet, win, config.currency.symbol
                ))
                if moved < count then
                    UI.setMessage("Выдано " .. moved .. "/" .. count .. " из ME", config.colors.textGold, 5)
                end
            else
                -- Если ME пуст/ошибка — не оставляем игрока без выигрыша
                Players.addBalance(UI.playerName, win)
                log("ОШИБКА", UI.playerName, "Выигрыш в сундук: " .. (err or "ME") .. " | +" .. win .. " на баланс")
                UI.setMessage("ME не выдал (" .. (err or "?") .. ") → на баланс", config.colors.textRed, 6)
            end
        else
            Players.addBalance(UI.playerName, win)
            log("ВЫИГРЫШ", UI.playerName, string.format("+%d %s на баланс (нет предмета выплаты)", win, config.currency.symbol))
            UI.setMessage("Настройте предмет выплаты в админке", config.colors.textGold, 5)
        end
    elseif Game.result == "LOSE" then
        log("ПРОИГРЫШ", UI.playerName, string.format("Ставка %d %s", Game.bet, config.currency.symbol))
    end

    local p = Players.get(UI.playerName)
    p.games = (p.games or 0) + 1
    if Game.result == "WIN" or Game.result == "BLACKJACK" then p.wins = (p.wins or 0) + 1 end
    Players.save()
    UI.screen = "result"
end

--------------------------------------------------
local function boot()
    -- максимальная глубина цвета (иначе зелёный может стать чёрным)
    pcall(function()
        local d = gpu.maxDepth and gpu.maxDepth() or 8
        gpu.setDepth(d)
    end)

    local maxW, maxH = gpu.maxResolution()
    local targetW = math.min(160, maxW)
    local targetH = math.min(50, maxH)
    if targetW < 80 then targetW = maxW end
    if targetH < 25 then targetH = maxH end
    pcall(gpu.setResolution, targetW, targetH)
    UI.w, UI.h = gpu.getResolution()

    -- сразу заливаем сукно
    pcall(gpu.setBackground, FELT_BASE)
    pcall(gpu.fill, 1, 1, UI.w, UI.h, " ")

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
            if UI.alert then
                UI.checkButtons(x, y)
            elseif UI.input.active then
                UI.checkButtons(x, y)
            elseif not UI.authorized then
                -- сначала кнопки (АВТОРИЗАЦИЯ)
                UI.checkButtons(x, y)
                -- логин только после нажатия АВТОРИЗАЦИЯ
                if UI.pendingAuth and player and player ~= "" then
                    UI.pendingAuth = false
                    UI.login(player)
                end
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
