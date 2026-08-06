--------------------------------------------------
-- BlackJack Casino
-- config.lua
--------------------------------------------------

local config = {}

--------------------------------------------------
-- Проект
--------------------------------------------------
config.project = {
    name    = "BlackJack",
    version = "2.1.0",
    author  = "hellbreez"
}

--------------------------------------------------
-- Администраторы (видят кнопку "Админ-панель")
--------------------------------------------------
config.admins = {
    ["hellbreez"] = true,
    ["Lofland"]   = true
}

--------------------------------------------------
-- Железо (стороны относительно компьютера)
-- 0 = bottom, 1 = top, 2 = north, 3 = south, 4 = west, 5 = east
--------------------------------------------------
config.hardware = {
    -- Транспозер: левый сундук СВЕРХУ (приём предметов для пополнения)
    transposerSide = 1,   -- top

    -- ME Interface: правый сундук СВЕРХУ (выдача предметов / хранение)
    meSide = 1            -- top
}

--------------------------------------------------
-- Валюта
--------------------------------------------------
config.currency = {
    name   = "ЭМ",
    symbol = "ЭМ"
}

--------------------------------------------------
-- Ставки (можно менять в админ-панели)
--------------------------------------------------
config.bet = {
    min = 1,
    max = 1000,
    default = 10
}

--------------------------------------------------
-- Игровые правила
--------------------------------------------------
config.game = {
    decks           = 6,
    blackjackPayout = 2.5,       -- 3:2
    winPayout       = 2.0,       -- 1:1
    drawPayout      = 1.0,       -- возврат ставки
    dealerStandSoft17 = true
}

--------------------------------------------------
-- Скупка предметов
-- Можно указывать просто число или таблицу { price, label }
-- Админка всё равно перезапишет при добавлении предметов
--------------------------------------------------
config.buyPrices = {
    -- ["customnpcs:npcMoney"] = { price = 1, label = "Деньги" },
    -- ["minecraft:diamond"]   = { price = 50, label = "Алмаз" },
}

--------------------------------------------------
-- Пути данных
--------------------------------------------------
config.paths = {
    root     = "/BlackJack/",
    data     = "/BlackJack/data/",
    players  = "/BlackJack/data/players.db",
    settings = "/BlackJack/data/settings.db",
    log      = "/BlackJack/data/log.txt"
}

--------------------------------------------------
-- Цвета (тёмная тема)
--------------------------------------------------
config.colors = {
    background   = 0x0A0A0A,
    panel        = 0x141414,
    panelLight   = 0x1E1E1E,
    header       = 0x1A1A2E,

    text         = 0xE0E0E0,
    textDark     = 0x888888,
    textGold     = 0xFFD700,
    textGreen    = 0x00CC66,
    textRed      = 0xFF4444,
    textBlue     = 0x55AAFF,

    button       = 0x2A2A2A,
    buttonHover  = 0x3A3A3A,
    buttonGreen  = 0x00AA55,
    buttonRed    = 0xCC3333,
    buttonBlue   = 0x3366CC,
    buttonYellow = 0xCCAA00,

    cardFace     = 0xF5F5F5,
    cardBack     = 0x8B0000,
    tableGreen   = 0x0B5C3A,

    heart        = 0xCC0000,
    diamond      = 0xCC0000,
    club         = 0x111111,
    spade        = 0x111111
}

--------------------------------------------------
-- Размеры UI
--------------------------------------------------
config.ui = {
    sidebarWidth = 28,
    headerHeight = 1,
    cardW        = 9,
    cardH        = 7
}

return config
