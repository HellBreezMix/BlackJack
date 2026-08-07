--------------------------------------------------
-- BlackJack Casino v2.4
-- main.lua
-- Автор: hellbreez + Grok
--------------------------------------------------

-- пути поиска config.lua
package.path = "/BlackJack/?.lua;/home/BlackJack/?.lua;" .. (package.path or "")

local function safeRequire(name)
    local ok, mod = pcall(require, name)
    if ok then return mod end
    error("Не найден модуль: " .. tostring(name) .. " (" .. tostring(mod) .. ")")
end

local component     = safeRequire("component")
local event         = safeRequire("event")
local filesystem    = safeRequire("filesystem")
local serialization = safeRequire("serialization")
local term          = safeRequire("term")
local unicode       = safeRequire("unicode")
local keyboard      = safeRequire("keyboard")
local computer      = safeRequire("computer")

-- GPU: primary или первый доступный
local gpu = nil
if component.isAvailable and component.isAvailable("gpu") then
    gpu = component.getPrimary and component.getPrimary("gpu") or component.gpu
else
    for addr in component.list("gpu") do
        gpu = component.proxy(addr)
        break
    end
end
if not gpu then
    print("ОШИБКА: GPU не найден. Подключите монитор и видеокарту.")
    return
end


local okCfg, config = pcall(require, "config")
if not okCfg or not config then
    print("ОШИБКА config.lua: " .. tostring(config))
    print("Положи config.lua в /BlackJack/config.lua")
    return
end

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
        decks = config.game.decks or 6,
        hitSoft17 = true,
        reshuffleAt = 40,
        shuffleEvery = false,
        houseEdge = 0,
        dealerProtect = 0,
        lessBJ = false
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
        if Settings.data.hitSoft17 == nil then Settings.data.hitSoft17 = true end
        Settings.data.reshuffleAt = Settings.data.reshuffleAt or 40
        if Settings.data.shuffleEvery == nil then Settings.data.shuffleEvery = false end
        Settings.data.houseEdge = tonumber(Settings.data.houseEdge) or 0
        Settings.data.dealerProtect = tonumber(Settings.data.dealerProtect) or 0
        if Settings.data.lessBJ == nil then Settings.data.lessBJ = false end
        Settings.data.pushLoses = nil  -- убрано
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

    local sidesLib = nil
    pcall(function() sidesLib = require("sides") end)

    local function countInNetwork()
        local total, list = 0, {}
        local ok, res = pcall(function()
            return Hardware.me.getItemsInNetwork({ name = itemName })
        end)
        if not ok or not res or #res == 0 then
            ok, res = pcall(function() return Hardware.me.getItemsInNetwork() end)
            res = (ok and res) or {}
            local f = {}
            for _, it in ipairs(res) do
                if tostring(it.name or it.id) == tostring(itemName) then table.insert(f, it) end
            end
            res = f
        end
        for _, it in ipairs(res or {}) do
            total = total + (tonumber(it.size) or tonumber(it.qty) or 0)
            table.insert(list, it)
        end
        return total, list
    end

    local available, items = countInNetwork()
    if available < 1 then
        return 0, "В ME нет: " .. tostring(itemName)
    end
    if count > available then count = available end

    local stack = items[1]
    local name = tostring(stack.name or itemName)
    local dmg = tonumber(stack.damage) or 0

    -- варианты fingerprint
    local fingerprints = {
        { id = name, name = name, damage = dmg, dmg = dmg },
        { id = name, damage = dmg },
        { name = name, damage = dmg },
        { name = name },
        { id = name },
    }
    if type(stack.fingerprint) == "table" then
        table.insert(fingerprints, 1, stack.fingerprint)
    end
    -- иногда AE2 принимает сам объект из сети (без size)
    local clean = {}
    for k, v in pairs(stack) do
        if k ~= "size" and k ~= "isCraftable" and k ~= "qty" then
            clean[k] = v
        end
    end
    if not clean.id then clean.id = name end
    if not clean.name then clean.name = name end
    table.insert(fingerprints, 1, clean)

    -- стороны: сундук СВЕРХУ интерфейса
    local sideList = {}
    if sidesLib then
        table.insert(sideList, sidesLib.top or sidesLib.up or 1)
    end
    for _, s in ipairs({ 1, "UP", "up", "top", 0, "DOWN" }) do
        table.insert(sideList, s)
    end
    if config.hardware.meSide then
        table.insert(sideList, 1, config.hardware.meSide)
    end

    local function tryExport(fp, side, batch)
        local ok, result = pcall(function()
            return Hardware.me.exportItem(fp, side, batch)
        end)
        if not ok then return 0, tostring(result) end
        local n = tonumber(result)
        if n and n > 0 then return n, nil end
        -- некоторые версии возвращают true
        if result == true then return batch, nil end
        return 0, "return=" .. tostring(result)
    end

    local totalMoved = 0
    local lastErr = "неизвестно"
    local successSide = nil
    local successFp = nil

    while totalMoved < count do
        local batch = math.min(64, count - totalMoved)
        local before = countInNetwork()
        local moved = 0

        -- если уже нашли рабочую пару side+fp — используем её
        if successSide and successFp then
            local m, err = tryExport(successFp, successSide, batch)
            if m > 0 then
                moved = m
            else
                -- проверяем по факту в сети
                local after = countInNetwork()
                moved = math.max(0, before - after)
                if moved <= 0 then lastErr = err or lastErr; break end
            end
        else
            -- поиск рабочей комбинации
            for _, fp in ipairs(fingerprints) do
                if moved > 0 then break end
                for _, side in ipairs(sideList) do
                    local m, err = tryExport(fp, side, batch)
                    lastErr = err or lastErr
                    if m > 0 then
                        moved = m
                        successSide = side
                        successFp = fp
                        break
                    end
                    -- дельта в сети
                    local after = countInNetwork()
                    local delta = before - after
                    if delta > 0 then
                        moved = delta
                        successSide = side
                        successFp = fp
                        break
                    end
                    before = after -- на случай частичного
                end
            end
        end

        if moved <= 0 then
            -- финальная проверка
            local after = countInNetwork()
            moved = math.max(0, before - after)
        end

        if moved <= 0 then
            if lastErr and lastErr:find("fingerprint") then
                lastErr = "fingerprint: " .. lastErr
            elseif lastErr == "return=0" or lastErr == "return=nil" then
                lastErr = "сундук полон или неверная сторона ME"
            end
            break
        end
        totalMoved = totalMoved + moved
    end

    if totalMoved > 0 then
        if totalMoved < count then
            return totalMoved, "частично " .. totalMoved .. "/" .. count
        end
        return totalMoved, nil
    end
    return 0, lastErr or "не удалось выдать"
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

-- Пипы для карты 15x11
local faceLayout = {
    ["A"]  = {{7,5}},
    ["2"]  = {{7,3},{7,8}},
    ["3"]  = {{7,3},{7,5},{7,8}},
    ["4"]  = {{4,3},{10,3},{4,8},{10,8}},
    ["5"]  = {{4,3},{10,3},{7,5},{4,8},{10,8}},
    ["6"]  = {{4,3},{10,3},{4,5},{10,5},{4,8},{10,8}},
    ["7"]  = {{4,3},{10,3},{7,4},{4,5},{10,5},{4,8},{10,8}},
    ["8"]  = {{4,3},{10,3},{4,5},{10,5},{4,7},{10,7},{4,8},{10,8}},
    ["9"]  = {{4,3},{10,3},{4,5},{7,5},{10,5},{4,7},{10,7},{4,8},{10,8}},
    ["10"] = {{4,3},{10,3},{4,4},{10,4},{4,5},{10,5},{4,7},{10,7},{4,8},{10,8}},
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
    -- меньше BJ: убираем ~25% тузов и десяток (J/Q/K/10)
    if Settings.data and Settings.data.lessBJ then
        local filtered, hi = {}, 0
        for _, c in ipairs(deck) do
            local high = (c.rank == "A" or c.value == 10)
            if high then
                hi = hi + 1
                if hi % 4 ~= 0 then table.insert(filtered, c) end
            else
                table.insert(filtered, c)
            end
        end
        deck = filtered
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

-- Blackjack (колода 52): ровно 2 карты на 21 = туз + 10/J/Q/K (два туза = 12, не BJ)
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

function Game.dealInit()
    if Settings.data.shuffleEvery then
        Game.deck = Cards.createDeck(Settings.data.decks or config.game.decks or 6)
    else
        local need = tonumber(Settings.data.reshuffleAt) or 40
        if #Game.deck < need then Game.deck = Cards.createDeck(Settings.data.decks or config.game.decks or 6) end
    end
    Game.player.hand = {}
    Game.dealer.hand = {}
    Game.finished = false; Game.result = nil; Game.state = "dealing"
end

function Game.drawOne(to)
    if #Game.deck < 1 then
        Game.deck = Cards.createDeck(Settings.data.decks or config.game.decks or 6)
    end

    local function takeAt(i)
        return table.remove(Game.deck, i)
    end

    local function cardEffValue(c)
        -- для оценки перебора туз считаем как 1
        if c.rank == "A" then return 1 end
        return c.value
    end

    local card = nil
    local edge = tonumber(Settings.data.houseEdge) or 0
    local protect = tonumber(Settings.data.dealerProtect) or 0

    -- Защита дилера: на 12–16 с шансом protect% взять карту без перебора
    if to == "dealer" and protect > 0 and #Game.dealer.hand > 0 then
        local d = Cards.handValue(Game.dealer.hand)
        if d >= 12 and d <= 16 and math.random(100) <= protect then
            local needMax = 21 - d
            for i = #Game.deck, 1, -1 do
                if cardEffValue(Game.deck[i]) <= needMax then
                    card = takeAt(i)
                    break
                end
            end
        end
    end

    -- Перевес дома: при доборе игрока с шансом edge% подсунуть «плохую» карту
    if not card and to == "player" and edge > 0 and #Game.player.hand > 0 then
        if math.random(100) <= edge then
            local p = Cards.handValue(Game.player.hand)
            if p >= 12 then
                -- ищем карту, которая даст перебор
                local needMin = 22 - p
                for i = #Game.deck, 1, -1 do
                    local c = Game.deck[i]
                    if c.rank ~= "A" and c.value >= needMin then
                        card = takeAt(i)
                        break
                    end
                end
            else
                -- на низких руках — мелкая карта (сложнее собрать 20/21)
                for i = #Game.deck, 1, -1 do
                    local c = Game.deck[i]
                    if c.value <= 6 and c.rank ~= "A" then
                        card = takeAt(i)
                        break
                    end
                end
            end
        end
    end

    -- Перевес дома при раздаче дилеру: слегка лучше карты
    if not card and to == "dealer" and edge > 0 and math.random(100) <= math.floor(edge / 2) then
        for i = #Game.deck, 1, -1 do
            local c = Game.deck[i]
            if c.value >= 8 or c.rank == "A" then
                card = takeAt(i)
                break
            end
        end
    end

    if not card then card = table.remove(Game.deck) end

    if to == "player" then
        table.insert(Game.player.hand, card)
    else
        table.insert(Game.dealer.hand, card)
    end
    return card
end

function Game.checkInitialBlackjack()
    if #Game.player.hand < 2 or #Game.dealer.hand < 2 then return end
    if Cards.isBlackjack(Game.player.hand) then
        if Cards.isBlackjack(Game.dealer.hand) then Game.finish("DRAW") else Game.finish("BLACKJACK") end
    elseif Cards.isBlackjack(Game.dealer.hand) then
        Game.finish("LOSE")
    else
        Game.state = "playing"
    end
end

function Game.hit()
    if Game.finished or Game.state ~= "playing" then return end
    Game.drawOne("player")
    if Cards.isBust(Game.player.hand) then Game.finish("LOSE") end
end

function Game.isSoft(hand)
    local total, aces = 0, 0
    for _, c in ipairs(hand) do
        total = total + c.value
        if c.rank == "A" then aces = aces + 1 end
    end
    while total > 21 and aces > 0 do total = total - 10; aces = aces - 1 end
    -- soft = есть туз, считающийся как 11
    return aces > 0 and total <= 21
end

function Game.dealerShouldHit()
    local d = Cards.handValue(Game.dealer.hand)
    if d < 17 then return true end
    -- soft 17: туз+6 = 17 «мягкие» — бить если включено в настройках
    if d == 17 and Game.isSoft(Game.dealer.hand) then
        return Settings.data.hitSoft17 and true or false
    end
    return false
end

function Game.standResolve()
    local p = Cards.handValue(Game.player.hand)
    local d = Cards.handValue(Game.dealer.hand)
    if Cards.isBust(Game.dealer.hand) then Game.finish("WIN")
    elseif p > d then Game.finish("WIN")
    elseif p < d then Game.finish("LOSE")
    else
        Game.finish("DRAW")
    end
end

function Game.stand()
    if Game.finished or Game.state ~= "playing" then return end
    Game.player.standing = true
    Game.state = "dealer_turn"
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
    adminTab = "bets", logScroll = 0, pendingAuth = false, alert = nil, animTimer = nil,
    anim = nil,  -- {fx,fy,tx,ty,card,hidden,step,steps,onDone}
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

function fill(x, y, w, h, color)
    gpu.setBackground(color)
    gpu.fill(x, y, w, h, " ")
end

function text(x, y, str, fg, bg)
    if bg then gpu.setBackground(bg) end
    if fg then gpu.setForeground(fg) end
    gpu.set(x, y, tostring(str))
end

function centerText(y, str, fg, bg, width)
    width = width or UI.w
    local x = math.floor((width - unicode.len(tostring(str))) / 2) + 1
    text(x, y, str, fg, bg)
end

function drawBox(x, y, w, h, borderColor, fillColor)
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

-- Фон сукна стола
local FELT_BASE = 0x0D6B3F
local FELT_PAT  = 0x1A9A5C
local TABLE_RAIL = 0x5C3A1E
local TABLE_RAIL_DARK = 0x3D2510
local _screenBuf = nil
local _feltBuf = nil
local _feltReady = false
local _welcomeReady = false

function paintFeltToActive(w, h)
    fill(1, 1, w, h, FELT_BASE)
    gpu.setBackground(FELT_BASE)
    gpu.setForeground(FELT_PAT)
    local suits = { "♠", "♥", "♦", "♣" }
    local si = 1
    for row = 2, h - 1, 2 do
        local shift = (math.floor((row - 2) / 2) % 2) * 2
        for col = 2 + shift, w - 1, 4 do
            gpu.set(col, row, suits[si])
            si = si % 4 + 1
        end
    end
end

-- узор в прямоугольнике (fallback без буфера)
function paintFeltRegion(x, y, w, h)
    fill(x, y, w, h, FELT_BASE)
    gpu.setBackground(FELT_BASE)
    gpu.setForeground(FELT_PAT)
    local suits = { "♠", "♥", "♦", "♣" }
    local si = 1
    for row = y, y + h - 1, 2 do
        local shift = (math.floor((row - y) / 2) % 2) * 2
        for col = x + shift, x + w - 1, 4 do
            if col >= x and col < x + w and row >= y and row < y + h then
                gpu.set(col, row, suits[si])
                si = si % 4 + 1
            end
        end
    end
end

function ensureFeltCache()
    if _feltReady and _feltBuf then return true end
    if not (gpu.allocateBuffer and gpu.setActiveBuffer and gpu.bitblt) then
        return false
    end
    -- сукно важнее double-buffer: выделяем первым
    if not _feltBuf then
        local ok, id = pcall(gpu.allocateBuffer, UI.w, UI.h)
        if not ok or not id then return false end
        _feltBuf = id
    end
    if pcall(gpu.setActiveBuffer, _feltBuf) then
        paintFeltToActive(UI.w, UI.h)
        pcall(gpu.setActiveBuffer, 0)
        _feltReady = true
        return true
    end
    return false
end

local _inFrame = false

function blitFeltArea(mw)
    mw = mw or (UI.w - (config.ui.sidebarWidth or 28))
    if ensureFeltCache() and _feltBuf then
        local dst = (_inFrame and _screenBuf) or 0
        pcall(gpu.bitblt, dst, 1, 1, mw, UI.h, _feltBuf, 1, 1)
        return true
    end
    -- нет буфера — рисуем узор напрямую
    paintFeltRegion(1, 1, mw, UI.h)
    return false
end

function ensureScreenBuf()
    -- только если сукно уже в буфере (не забираем единственный слот)
    if not _feltBuf then ensureFeltCache() end
    if _screenBuf then return true end
    if not (gpu.allocateBuffer and gpu.bitblt) then return false end
    local ok, id = pcall(gpu.allocateBuffer, UI.w, UI.h)
    if ok and id then
        _screenBuf = id
        return true
    end
    return false
end

function present()
    if _inFrame and _screenBuf then
        pcall(gpu.setActiveBuffer, 0)
        pcall(gpu.bitblt, 0, 1, 1, UI.w, UI.h, _screenBuf, 1, 1)
    end
    _inFrame = false
    pcall(gpu.setActiveBuffer, 0)
end

function beginFrame()
    -- double-buffer только при наличии ВТОРОГО буфера
    if _feltBuf and ensureScreenBuf() and _screenBuf then
        if pcall(gpu.setActiveBuffer, _screenBuf) then
            _inFrame = true
            return true
        end
    end
    _inFrame = false
    pcall(gpu.setActiveBuffer, 0)
    return false
end

local _lastFeltPaint = 0


-- окантовка игрового стола (слева от сайдбара)
function drawTableRail(mw)
    if mw < 10 then return end
    fill(1, 2, mw, 1, TABLE_RAIL)
    fill(1, UI.h, mw, 1, TABLE_RAIL)
    fill(1, 2, 1, UI.h - 1, TABLE_RAIL)
    fill(mw, 2, 1, UI.h - 1, TABLE_RAIL)
    fill(2, 3, mw - 2, 1, TABLE_RAIL_DARK)
    fill(2, UI.h - 1, mw - 2, 1, TABLE_RAIL_DARK)
    fill(2, 3, 1, UI.h - 3, TABLE_RAIL_DARK)
    fill(mw - 1, 3, 1, UI.h - 3, TABLE_RAIL_DARK)
end

function drawScreen()
    UI.clearButtons()
    local mw = UI.w - (config.ui.sidebarWidth or 28)

    local welcomeMode = (UI.screen == "main" and not UI.authorized
        and not UI.alert and not UI.input.active)

    if welcomeMode then
        if not _welcomeReady then
            beginFrame()
            if not blitFeltArea(UI.w) then paintFeltToActive(UI.w, UI.h) end
            drawTableRail(mw)
            pcall(UI.drawWelcomeArt, mw)
            fill(1, 1, UI.w, 1, config.colors.header)
            centerText(1, "CASINO BLACKJACK", config.colors.textBlue, config.colors.header)
            UI.drawSidebar()
            for _, b in ipairs(UI.buttons) do UI.drawButton(b) end
            present()
            _welcomeReady = true
        else
            -- только сайдбар на реальном экране — карты не трогаем
            if gpu.setActiveBuffer then pcall(gpu.setActiveBuffer, 0) end
            UI.drawSidebar()
            for _, b in ipairs(UI.buttons) do UI.drawButton(b) end
        end
        return
    end

    _welcomeReady = false
    beginFrame()

    -- сукно только на игровой зоне; место сайдбара зальём в drawSidebar
    blitFeltArea(mw)
    -- фон сайдбара
    local sx = mw + 1
    fill(sx, 1, UI.w - mw, UI.h, config.colors.panel)

    drawTableRail(mw)
    UI.drawHeader()
    UI.drawSidebar()

    if UI.alert then
        UI.drawAlert()
    elseif UI.input.active then
        UI.drawInputModal()
    else
        UI.drawMainArea()
    end

    for _, b in ipairs(UI.buttons) do UI.drawButton(b) end

    if UI.message and computer.uptime() < (UI.messageUntil or 0) then
        local msg = tostring(UI.message)
        local barW = math.min(mw - 4, math.max(30, unicode.len(msg) + 4))
        local bx = math.floor((mw - barW) / 2) + 1
        fill(bx, UI.h - 1, barW, 1, 0x083528)
        centerText(UI.h - 1, msg, UI.messageColor or config.colors.text, 0x083528, mw)
    end

    present()
end



local CARD_W, CARD_H = 15, 11
local CARD_STEP = 16

function drawCardFrame(x, y, cw, ch, fg, bg)
    gpu.setForeground(fg)
    gpu.setBackground(bg)
    for i = 1, cw - 2 do
        gpu.set(x + i, y, "─")
        gpu.set(x + i, y + ch - 1, "─")
    end
    for i = 1, ch - 2 do
        gpu.set(x, y + i, "│")
        gpu.set(x + cw - 1, y + i, "│")
    end
    gpu.set(x, y, "┌")
    gpu.set(x + cw - 1, y, "┐")
    gpu.set(x, y + ch - 1, "└")
    gpu.set(x + cw - 1, y + ch - 1, "┘")
end

function drawCard(x, y, card, hidden)
    local cw, ch = CARD_W, CARD_H
    if hidden then
        fill(x, y, cw, ch, config.colors.cardBack)
        gpu.setForeground(0x5A2828)
        gpu.setBackground(config.colors.cardBack)
        for dy = 1, ch - 2 do
            for dx = 1, cw - 2 do
                if (dx + dy) % 2 == 0 then gpu.set(x + dx, y + dy, "░") end
            end
        end
        drawCardFrame(x, y, cw, ch, 0x3A1818, config.colors.cardBack)
        return
    end

    fill(x, y, cw, ch, config.colors.cardFace)
    drawCardFrame(x, y, cw, ch, 0x222222, config.colors.cardFace)

    local col = Cards.suitColors[card.suit] or 0x111111
    local rank = card.rank
    local layout = faceLayout[rank]
    local face = config.colors.cardFace

    if layout == "face" then
        -- очень крупные ранг + масть
        text(x + 2, y + 1, rank, col, face)
        text(x + 2, y + 2, card.suit, col, face)
        text(x + 7, y + 4, rank, col, face)
        text(x + 7, y + 5, card.suit, col, face)
        text(x + cw - 3, y + ch - 3, rank, col, face)
        text(x + cw - 3, y + ch - 2, card.suit, col, face)
    else
        if rank == "10" then
            text(x + 1, y + 1, "10", col, face)
            text(x + 2, y + 2, card.suit, col, face)
            text(x + cw - 3, y + ch - 3, "10", col, face)
            text(x + cw - 2, y + ch - 2, card.suit, col, face)
        else
            text(x + 2, y + 1, rank, col, face)
            text(x + 2, y + 2, card.suit, col, face)
            text(x + cw - 3, y + ch - 3, rank, col, face)
            text(x + cw - 3, y + ch - 2, card.suit, col, face)
        end
        if type(layout) == "table" then
            for _, pos in ipairs(layout) do
                local px, py = pos[1], pos[2]
                if px >= 3 and px <= cw - 4 and py >= 3 and py <= ch - 3 then
                    text(x + px, y + py, card.suit, col, face)
                end
            end
        end
    end
end

-- крупный блок счёта справа от карт
function drawScoreBadge(x, y, label, score, accent)
    accent = accent or config.colors.textGold
    local sw, sh = 12, 5
    fill(x, y, sw, sh, 0x083528)
    gpu.setForeground(0x1A7A4A)
    gpu.setBackground(0x083528)
    for i = 0, sw - 1 do
        gpu.set(x + i, y, "─"); gpu.set(x + i, y + sh - 1, "─")
    end
    for i = 0, sh - 1 do
        gpu.set(x, y + i, "│"); gpu.set(x + sw - 1, y + i, "│")
    end
    gpu.set(x, y, "┌"); gpu.set(x + sw - 1, y, "┐")
    gpu.set(x, y + sh - 1, "└"); gpu.set(x + sw - 1, y + sh - 1, "┘")
    local lab = tostring(label)
    local sc = tostring(score)
    text(x + math.floor((sw - unicode.len(lab)) / 2), y + 1, lab, config.colors.text, 0x083528)
    text(x + math.floor((sw - unicode.len(sc)) / 2), y + 3, sc, accent, 0x083528)
end

function drawHand(x, y, hand, hideFirst)
    for i, c in ipairs(hand) do
        drawCard(x + (i - 1) * CARD_STEP, y, c, hideFirst and i == 1)
    end
end

function drawShoe(mw)
    local sx = math.max(3, mw - CARD_W - 3)
    local sy = 6
    -- стопка колоды
    drawCard(sx + 1, sy + 1, { rank = "A", suit = "♠" }, true)
    drawCard(sx, sy, { rank = "A", suit = "♠" }, true)
    text(sx, sy + CARD_H, "КОЛОДА", config.colors.textDark, config.colors.background)
    return sx, sy
end

function handSlotPos(mw, who, index)
    local n = math.max(1, index)
    local hw = (n - 1) * CARD_STEP + CARD_W
    -- карты левее центра, справа место под счёт
    local hx = math.max(3, math.floor((mw - hw) / 2) - 6)
    local x = hx + (index - 1) * CARD_STEP
    local y = (who == "player") and 24 or 7
    return x, y
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
        text(sx + 1, 8, "Нажмите кнопку", config.colors.textDark, config.colors.panel)
        text(sx + 1, 9, "для авторизации", config.colors.textDark, config.colors.panel)
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
    local minX, maxX = 4, mw - CARD_W - 2
    local minY, maxY = 4, UI.h - CARD_H - 2

    -- разброс по столу, не только у стен; центр под правила свободнее
    local scatter = {
        {  8,  5, "A", "♠", false },
        { 26,  4, "K", "♦", false },
        { 44,  6, "7", "♥", true  },
        { maxX - 4, 5, "3", "♣", false },
        { maxX - 2, 16, "8", "♠", false },
        { maxX - 6, 28, "6", "♣", false },
        { 10, 16, "Q", "♥", false },
        {  6, 28, "9", "♦", false },
        { 14, maxY - 1, "K", "♠", false },
        { 32, maxY, "2", "♣", true  },
        { 50, maxY - 2, "A", "♥", false },
        { 22, 20, "10", "♠", true },
        { 40, 18, "4", "♥", true },
        { 30, 12, "J", "♠", true },
        { 18,  8, "5", "♦", false },
    }
    for _, c in ipairs(scatter) do
        local x, y = c[1], c[2]
        if x < minX then x = minX end
        if y < minY then y = minY end
        if x > maxX then x = maxX end
        if y > maxY then y = maxY end
        if x + CARD_W <= mw - 1 and y + CARD_H <= UI.h - 1 then
            drawCard(x, y, { rank = c[3], suit = c[4] }, c[5])
        end
    end

    local winX = tonumber(Settings.data.winPayout) or 2.0
    local bjX  = tonumber(Settings.data.bjPayout) or 2.5
    local winStr = (winX == math.floor(winX)) and tostring(math.floor(winX)) or string.format("%.1f", winX)
    local bjStr  = (bjX == math.floor(bjX)) and tostring(math.floor(bjX)) or string.format("%.1f", bjX)

    local lines = {
        { "♠  BLACKJACK  ♥", config.colors.textGold },
        { "ПРАВИЛА", config.colors.textBlue },
        { "Цель: набрать больше дилера, не больше 21", config.colors.text },
        { "Победа: x" .. winStr .. "  |  Blackjack: x" .. bjStr, config.colors.textGold },
        { "Ничья: ставка возвращается", config.colors.text },
        { "Перебор (>21): проигрыш", config.colors.textDark },
        { "Нажмите кнопку для авторизации", config.colors.text },
    }
    local maxLen = 0
    for _, L in ipairs(lines) do
        local ln = unicode.len(L[1])
        if ln > maxLen then maxLen = ln end
    end
    local boxW = maxLen + 4
    local boxH = #lines + 2
    local bx = math.floor((mw - boxW) / 2) + 1
    local by = 12
    fill(bx, by, boxW, boxH, 0x083528)
    for i, L in ipairs(lines) do
        local tx = bx + math.floor((boxW - unicode.len(L[1])) / 2)
        text(tx, by + i, L[1], L[2], 0x083528)
    end
end

function UI.drawMainArea()
    local mw = UI.w - config.ui.sidebarWidth

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
        local hideDealer = (UI.screen == "playing" and not Game.finished and Game.state ~= "dealer_turn")
        local function handWidth(n)
            n = math.max(1, n)
            return (n - 1) * CARD_STEP + CARD_W
        end
        local function handX(n)
            -- сдвиг влево, справа место под бейдж счёта
            return math.max(3, math.floor((mw - handWidth(n)) / 2) - 6)
        end

        local ly = UI.h - 6
        text(3, ly,     "Карта      Очки", config.colors.textBlue, config.colors.background)
        text(3, ly + 1, "2-9        номинал", config.colors.textDark, config.colors.background)
        text(3, ly + 2, "10/J/Q/K   10", config.colors.textDark, config.colors.background)
        text(3, ly + 3, "Туз (A)    1 или 11", config.colors.textDark, config.colors.background)

        -- ДИЛЕР: карты + крупный счёт справа
        local dCount = math.max(1, #Game.dealer.hand)
        local dHx = handX(dCount)
        local dHy = 7
        drawHand(dHx, dHy, Game.dealer.hand, hideDealer)
        local dScore = hideDealer and "?" or tostring(Cards.handValue(Game.dealer.hand))
        drawScoreBadge(dHx + handWidth(dCount) + 3, dHy + 1, "ДИЛЕР", dScore, config.colors.textGold)

        -- ВЫ: ниже, больше зазор
        local pCount = math.max(1, #Game.player.hand)
        local pHx = handX(pCount)
        local pHy = 24
        drawHand(pHx, pHy, Game.player.hand, false)
        local pScore = tostring(Cards.handValue(Game.player.hand))
        drawScoreBadge(pHx + handWidth(pCount) + 3, pHy + 1, "ВЫ", pScore, config.colors.textGold)

        if Game.state == "dealing" or Game.state == "dealer_turn" or (UI.anim and UI.anim.card) then
            drawShoe(mw)
        end
        if UI.anim and UI.anim.card then
            drawCard(UI.anim.x, UI.anim.y, UI.anim.card, UI.anim.hidden ~= false)
        end

        centerText(36, "Ставка: " .. Game.bet .. " " .. config.currency.symbol, config.colors.text, config.colors.background, mw)

        local btnY = 38
        local cx = math.floor(mw / 2)
        if UI.h < 42 then btnY = UI.h - 5 end

        if UI.screen == "playing" and not Game.finished and Game.state == "playing" then
            UI.addButton(cx - 14, btnY, 12, 3, "ВЗЯТЬ", config.colors.buttonGreen, 0xFFFFFF, function()
                if Game.state ~= "playing" or UI.anim then return end
                Game.drawOne("player")
                local card = table.remove(Game.player.hand)
                UI.flyCard("player", card, false, function()
                    if Cards.isBust(Game.player.hand) then
                        Game.finish("LOSE")
                        UI.schedule(0.45, function() UI.resolveGame(); UI.draw() end)
                    else
                        UI.draw()
                    end
                end)
            end)
            UI.addButton(cx + 2, btnY, 12, 3, "СТОП", config.colors.buttonRed, 0xFFFFFF, function()
                if Game.state ~= "playing" or UI.anim then return end
                UI.startDealerAnim()
            end)
        elseif UI.screen == "playing" and Game.state == "dealing" then
            centerText(btnY, "Раздача...", config.colors.textGold, config.colors.background, mw)
        elseif UI.screen == "playing" and Game.state == "dealer_turn" then
            centerText(btnY, "Ход дилера...", config.colors.textGold, config.colors.background, mw)
        elseif UI.screen == "result" then
            local resText = ({ WIN="ПОБЕДА!", LOSE="ПОРАЖЕНИЕ", DRAW="НИЧЬЯ", BLACKJACK="BLACKJACK!" })[Game.result] or Game.result
            local resCol = ({ WIN=config.colors.textGreen, LOSE=config.colors.textRed, DRAW=config.colors.textGold, BLACKJACK=config.colors.textGold })[Game.result] or config.colors.text
            centerText(btnY - 1, resText, resCol, config.colors.background, mw)
            local winAmount = math.floor(Game.bet * Game.payoutMultiplier() + 0.5)
            if winAmount > 0 then
                centerText(btnY, "+" .. winAmount .. " " .. config.currency.symbol, config.colors.textGreen, config.colors.background, mw)
            end
            UI.addButton(cx - 8, btnY + 2, 16, 3, "ЕЩЁ РАЗ", config.colors.buttonGreen, 0xFFFFFF, function()
                UI.screen = "main"; Game.reset(); UI.draw()
            end)
        end

    elseif UI.screen == "admin" then UI.drawAdmin(mw)
    elseif UI.screen == "admin_add_item" then UI.drawAdminAddItem(mw)
    elseif UI.screen == "admin_edit_item" then UI.drawAdminEditItem(mw)
    end

    if UI.message and computer.uptime() < UI.messageUntil then
        -- полоска по центру, не режет крайние карты
        local barW = math.min(mw - 4, math.max(30, unicode.len(UI.message) + 4))
        local bx = math.floor((mw - barW) / 2) + 1
        fill(bx, UI.h - 1, barW, 1, 0x083528)
        centerText(UI.h - 1, UI.message, UI.messageColor, 0x083528, mw)
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
    local function onOff(x, y, isOn, onCb, offCb)
        local onBg  = isOn and config.colors.buttonGreen or config.colors.button
        local offBg = (not isOn) and config.colors.buttonRed or config.colors.button
        local onFg  = isOn and 0xFFFFFF or config.colors.textDark
        local offFg = (not isOn) and 0xFFFFFF or config.colors.textDark
        UI.addButton(x, y, 8, 2, "ВКЛ", onBg, onFg, onCb)
        UI.addButton(x + 9, y, 8, 2, "ВЫКЛ", offBg, offFg, offCb)
    end

    text(4, 7, "Выплаты:", config.colors.textBlue, config.colors.background)

    text(4, 9, "Blackjack x:", config.colors.textDark, config.colors.background)
    drawBox(4, 10, 12, 3, config.colors.textGold, config.colors.panelLight)
    text(6, 11, tostring(Settings.data.bjPayout or 2.5), config.colors.textGold, config.colors.panelLight)
    UI.addButton(4, 10, 12, 3, "", 0x000000, 0x000000, function()
        UI.openInput("Blackjack x", tostring(Settings.data.bjPayout or 2.5), function(val)
            local n = tonumber(val)
            if n and n >= 1 and n <= 10 then Settings.data.bjPayout = n; Settings.save() end
            UI.draw()
        end, 6)
    end)

    text(20, 9, "Победа x:", config.colors.textDark, config.colors.background)
    drawBox(20, 10, 12, 3, config.colors.textGold, config.colors.panelLight)
    text(22, 11, tostring(Settings.data.winPayout or 2.0), config.colors.textGold, config.colors.panelLight)
    UI.addButton(20, 10, 12, 3, "", 0x000000, 0x000000, function()
        UI.openInput("Победа x", tostring(Settings.data.winPayout or 2.0), function(val)
            local n = tonumber(val)
            if n and n >= 1 and n <= 10 then Settings.data.winPayout = n; Settings.save() end
            UI.draw()
        end, 6)
    end)

    text(4, 14, "Колода:", config.colors.textBlue, config.colors.background)

    text(4, 16, "Число колод (1-8):", config.colors.textDark, config.colors.background)
    drawBox(24, 15, 10, 3, config.colors.textGold, config.colors.panelLight)
    text(26, 16, tostring(Settings.data.decks or 6), config.colors.textGold, config.colors.panelLight)
    UI.addButton(24, 15, 10, 3, "", 0x000000, 0x000000, function()
        UI.openInput("Колод", tostring(Settings.data.decks or 6), function(val)
            local n = tonumber(val)
            if n then n = math.floor(n); if n >= 1 and n <= 8 then Settings.data.decks = n; Settings.save() end end
            UI.draw()
        end, 2)
    end)

    text(4, 19, "Дилер берёт soft 17:", config.colors.textDark, config.colors.background)
    onOff(34, 19, Settings.data.hitSoft17 == true,
        function() Settings.data.hitSoft17 = true; Settings.save(); UI.draw() end,
        function() Settings.data.hitSoft17 = false; Settings.save(); UI.draw() end)

    text(4, 22, "Мешать каждую раздачу:", config.colors.textDark, config.colors.background)
    onOff(34, 22, Settings.data.shuffleEvery == true,
        function() Settings.data.shuffleEvery = true; Settings.save(); UI.draw() end,
        function() Settings.data.shuffleEvery = false; Settings.save(); UI.draw() end)

    if not Settings.data.shuffleEvery then
        text(4, 25, "Остаток карт → shuffle:", config.colors.textDark, config.colors.background)
        drawBox(24, 24, 10, 3, config.colors.textGold, config.colors.panelLight)
        text(26, 25, tostring(Settings.data.reshuffleAt or 40), config.colors.textGold, config.colors.panelLight)
        UI.addButton(24, 24, 10, 3, "", 0x000000, 0x000000, function()
            UI.openInput("Карт до shuffle", tostring(Settings.data.reshuffleAt or 40), function(val)
                local n = tonumber(val)
                if n then n = math.floor(n); if n >= 10 and n <= 200 then Settings.data.reshuffleAt = n; Settings.save() end end
                UI.draw()
            end, 4)
        end)
    end

    text(4, 28, "Перевес казино:", config.colors.textRed, config.colors.background)

    text(4, 30, "Перевес дома % (0-15):", config.colors.textDark, config.colors.background)
    drawBox(28, 29, 10, 3, config.colors.textGold, config.colors.panelLight)
    text(30, 30, tostring(Settings.data.houseEdge or 0), config.colors.textGold, config.colors.panelLight)
    UI.addButton(28, 29, 10, 3, "", 0x000000, 0x000000, function()
        UI.openInput("Перевес %", tostring(Settings.data.houseEdge or 0), function(val)
            local n = tonumber(val)
            if n then n = math.floor(n); if n >= 0 and n <= 15 then Settings.data.houseEdge = n; Settings.save() end end
            UI.draw()
        end, 2)
    end)

    text(4, 33, "Защита дилера % (0-20):", config.colors.textDark, config.colors.background)
    drawBox(28, 32, 10, 3, config.colors.textGold, config.colors.panelLight)
    text(30, 33, tostring(Settings.data.dealerProtect or 0), config.colors.textGold, config.colors.panelLight)
    UI.addButton(28, 32, 10, 3, "", 0x000000, 0x000000, function()
        UI.openInput("Защита дилера %", tostring(Settings.data.dealerProtect or 0), function(val)
            local n = tonumber(val)
            if n then n = math.floor(n); if n >= 0 and n <= 20 then Settings.data.dealerProtect = n; Settings.save() end end
            UI.draw()
        end, 2)
    end)

    text(4, 36, "Меньше Blackjack:", config.colors.textDark, config.colors.background)
    onOff(34, 36, Settings.data.lessBJ == true,
        function() Settings.data.lessBJ = true; Settings.save(); UI.draw() end,
        function() Settings.data.lessBJ = false; Settings.save(); UI.draw() end)
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
    UI.playerName = name
    UI.authorized = true
    UI.sessionLeft = 120
    UI.screen = "main"
    _welcomeReady = false
    if gpu.setActiveBuffer then pcall(gpu.setActiveBuffer, 0) end

    local minB = tonumber(Settings.data.minBet) or config.bet.min or 1
    local maxB = tonumber(Settings.data.maxBet) or config.bet.max or 1000
    local defB = tonumber(config.bet.default) or minB
    UI.betAmount = math.max(minB, math.min(maxB, defB))

    pcall(Players.get, name)
    UI.setMessage("Добро пожаловать, " .. tostring(name), config.colors.textGreen, 3)
    pcall(UI.startSessionTimer)

    local ok, err = pcall(UI.draw)
    if not ok then
                pcall(log, "ОШИБКА", name, "login draw: " .. tostring(err))
    end
    pcall(log, "ВХОД", name, "Авторизация")
end

function UI.logout()
    UI.stopAnim()
    UI.stopSessionTimer()
    -- кэш welcome валиден — карты снова без мигания
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
    -- затемнение игровой зоны
    fill(1, 2, mw, UI.h - 1, 0x042818)
    local boxW, boxH = 40, 11
    local bx = math.floor((mw - boxW) / 2) + 1
    local by = math.floor((UI.h - boxH) / 2)
    drawBox(bx, by, boxW, boxH, config.colors.textRed, config.colors.panel)
    -- заголовок
    local title = UI.alert.title or "Сообщение"
    local tx = bx + math.floor((boxW - unicode.len(title)) / 2)
    text(tx, by + 3, title, config.colors.textRed, config.colors.panel)
    -- кнопка ОК по центру окна
    local bw = 14
    local bxbtn = bx + math.floor((boxW - bw) / 2)
    UI.addButton(bxbtn, by + 6, bw, 3, "ОК", config.colors.buttonGreen, 0xFFFFFF, function()
        local cb = UI.alert and UI.alert.cb
        UI.alert = nil
        if cb then cb() end
        UI.draw()
    end)
end

function UI.stopAnim()
    if UI.animTimer then
        pcall(event.cancel, UI.animTimer)
        UI.animTimer = nil
    end
end

function UI.schedule(delay, fn)
    UI.stopAnim()
    UI.animTimer = event.timer(delay, function()
        UI.animTimer = nil
        fn()
    end, 1)
end

-- Полёт карты из колоды в руку
function UI.flyCard(who, card, faceDown, onDone)
    local mw = UI.w - config.ui.sidebarWidth
    local shoeX = math.max(3, mw - CARD_W - 3)
    local shoeY = 6
    local hand = (who == "player") and Game.player.hand or Game.dealer.hand
    local idx = #hand + 1
    local tx, ty = handSlotPos(mw, who, idx)
    local steps = (_screenBuf or ensureScreenBuf()) and 8 or 5
    local step = 0

    ensureFeltCache()
    if #Game.player.hand == 0 and #Game.dealer.hand == 0 and idx == 1 then
        UI.anim = nil
        UI.draw()
    end

    UI.anim = { card = card, hidden = true, x = shoeX, y = shoeY, who = who }

    local function hw(n)
        n = math.max(1, n)
        return (n - 1) * CARD_STEP + CARD_W
    end
    local function hx(n)
        return math.max(3, math.floor((mw - hw(n)) / 2) - 6)
    end

    local function paintFrame(fx, fy)
        beginFrame()
        -- только игровая зона — правый столбец не трогаем в буфере... 
        -- но screenBuf содержит всё: сначала копируем сукно на mw, сайдбар рисуем
        blitFeltArea(mw)
        local sx = mw + 1
        fill(sx, 1, UI.w - mw, UI.h, config.colors.panel)
        drawTableRail(mw)
        fill(1, 1, UI.w, 1, config.colors.header)
        centerText(1, "CASINO BLACKJACK", config.colors.textBlue, config.colors.header)

        -- сайдбар (визуал + кнопки)
        UI.clearButtons()
        UI.drawSidebar()

        if #Game.dealer.hand > 0 then
            local hide = (Game.state == "dealing" or Game.state == "playing")
                and not Game.finished and Game.state ~= "dealer_turn"
            local dN = #Game.dealer.hand
            drawHand(hx(dN), 7, Game.dealer.hand, hide)
            local sc = tostring(Cards.handValue(Game.dealer.hand))
            if hide and dN >= 2 then sc = "?" end
            drawScoreBadge(hx(dN) + hw(dN) + 3, 8, "ДИЛЕР", sc, config.colors.textGold)
        end
        if #Game.player.hand > 0 then
            local pN = #Game.player.hand
            drawHand(hx(pN), 24, Game.player.hand, false)
            drawScoreBadge(hx(pN) + hw(pN) + 3, 25, "ВЫ",
                tostring(Cards.handValue(Game.player.hand)), config.colors.textGold)
        end
        drawShoe(mw)
        if fx then drawCard(fx, fy, card, true) end
        centerText(36, "Ставка: " .. tostring(Game.bet) .. " " .. config.currency.symbol,
            config.colors.text, config.colors.background, mw)
        centerText(38, "Раздача...", config.colors.textGold, config.colors.background, mw)

        for _, b in ipairs(UI.buttons) do UI.drawButton(b) end
        present()  -- один показ кадра — без мигания
    end

    local function frame()
        step = step + 1
        local t = step / steps
        local e = t * t * (3 - 2 * t)
        local nx = math.floor(shoeX + (tx - shoeX) * e + 0.5)
        local ny = math.floor(shoeY + (ty - shoeY) * e + 0.5)
        UI.anim.x, UI.anim.y = nx, ny
        paintFrame(nx, ny)
        if step < steps then
            UI.schedule(0.05, frame)
        else
            table.insert(hand, card)
            UI.anim = nil
            paintFrame(nil, nil)
            if onDone then onDone() end
        end
    end
    UI.schedule(0.03, frame)
end

-- Анимация раздачи: игрок, дилер, игрок, дилер (с полётом)
function UI.startDealAnim()
    Game.dealInit()
    Game.bet = UI.betAmount
    UI.screen = "playing"
    UI.anim = nil
    _welcomeReady = false  -- больше не welcome
    UI.draw()  -- один раз пустой стол

    -- очередь: who, faceDown (дыра дилера)
    local queue = {
        { "player", false },
        { "dealer", false },
        { "player", false },
        { "dealer", true  },
    }
    local qi = 0

    local function nextDeal()
        qi = qi + 1
        if qi > #queue then
            Game.checkInitialBlackjack()
            UI.draw()
            if Game.finished then
                UI.schedule(0.7, function()
                    UI.resolveGame()
                    UI.draw()
                end)
            end
            return
        end
        local who, faceDown = queue[qi][1], queue[qi][2]
        -- берём карту с учётом перевеса (drawOne без вставки)
        local savedP = #Game.player.hand
        local savedD = #Game.dealer.hand
        Game.drawOne(who)
        local hand = (who == "player") and Game.player.hand or Game.dealer.hand
        local card = table.remove(hand)  -- вынули для анимации
        UI.flyCard(who, card, faceDown, nextDeal)
    end

    UI.schedule(0.25, nextDeal)
end

-- Анимация добора дилера после «Стоп»
function UI.startDealerAnim()
    Game.stand()
    UI.anim = nil
    UI.draw()

    local function dealerHit()
        if Game.finished then return end
        if Game.dealerShouldHit() then
            Game.drawOne("dealer")
            local card = table.remove(Game.dealer.hand)
            UI.flyCard("dealer", card, false, dealerHit)
        else
            Game.standResolve()
            UI.schedule(0.4, function()
                UI.resolveGame()
                UI.draw()
            end)
        end
    end
    -- сначала открываем дыру дилера (если была)
    UI.schedule(0.3, dealerHit)
end

function UI.startGame()
    if not UI.authorized then return end
    if Game.state == "dealing" or Game.state == "dealer_turn" then return end
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
    Game.reset()
    UI.startDealAnim()
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
        pcall(function()
        if gpu.maxDepth then gpu.setDepth(gpu.maxDepth()) end
    end)

    local maxW, maxH = 80, 25
    pcall(function()
        maxW, maxH = gpu.maxResolution()
    end)
    local targetW = math.min(160, maxW or 80)
    local targetH = math.min(50, maxH or 25)
    if targetW < 60 then targetW = maxW or 80 end
    if targetH < 20 then targetH = maxH or 25 end
    pcall(gpu.setResolution, targetW, targetH)

    UI.w, UI.h = 80, 25
    pcall(function()
        UI.w, UI.h = gpu.getResolution()
    end)
    if not UI.w or UI.w < 1 then UI.w = 80 end
    if not UI.h or UI.h < 1 then UI.h = 25 end

    _feltReady = false
    _feltBuf = nil
    _screenBuf = nil
    _welcomeReady = false
    _inFrame = false

    pcall(gpu.setBackground, FELT_BASE or 0x0D6B3F)
    pcall(gpu.fill, 1, 1, UI.w, UI.h, " ")
    -- сразу создаём снимок сукна (приоритет над screenBuf)
    pcall(ensureFeltCache)

        ensureDir(config.paths.data)
    Players.load()
    Settings.load()
    Hardware.init()
    pcall(loadLogsFromFile)

    local seed = computer.uptime() * 1000
    pcall(function()
        local a = computer.address()
        if a and a.byte then seed = seed + (a:byte(1) or 0) end
    end)
    math.randomseed(math.floor(seed))

    pcall(log, "СИСТЕМА", "-", "BlackJack start " .. UI.w .. "x" .. UI.h)

        local okDraw, drawErr = pcall(UI.draw)
    if not okDraw then
        error("UI.draw: " .. tostring(drawErr))
    end
    
    while true do
        local okEv, ev1, ev2, ev3, ev4, ev5, ev6 = pcall(event.pull, 0.5)
        if not okEv then
            -- игнорируем сбои event
        else
            local e = ev1
            if e == "key_down" then
                pcall(UI.handleKey, ev3, ev4)
            elseif e == "touch" then
                local x, y, player = ev3, ev4, ev6
                local okTouch, tErr = pcall(function()
                    if UI.alert then
                        UI.checkButtons(x, y)
                    elseif UI.input.active then
                        UI.checkButtons(x, y)
                    elseif not UI.authorized then
                        UI.checkButtons(x, y)
                        if UI.pendingAuth and player and player ~= "" then
                            UI.pendingAuth = false
                            UI.login(player)
                        end
                    else
                        UI.sessionLeft = 120
                        UI.checkButtons(x, y)
                    end
                end)
                if not okTouch then
                    pcall(log, "ОШИБКА", "-", "touch: " .. tostring(tErr))
                end
            elseif e == "interrupted" then
                -- Ctrl+C отключён: игроки не могут выключить программу
            end
        end
    end
end

local ok, err = pcall(boot)
if not ok then
    pcall(function()
        if term and term.clear then term.clear() end
    end)
    print("========================================")
    print("Ошибка BlackJack:")
    print(tostring(err))
    print("========================================")
    pcall(log, "ОШИБКА", "-", tostring(err))
end
