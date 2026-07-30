--------------------------------------------------
-- BlackJack
-- config.lua
--------------------------------------------------

local config = {}

--------------------------------------------------
-- Информация проекта
--------------------------------------------------

config.project = {

    name = "BlackJack",

    version = "1.0",

    author = "OpenCasino Team"

}

--------------------------------------------------
-- Игровые настройки
--------------------------------------------------

config.game = {

    deckCount = 6,

    maxBet = 64,

    animation = true

}

--------------------------------------------------
-- Администраторы
--------------------------------------------------

config.admins = {

    "hellbreez",

    "Lofland"

}

--------------------------------------------------
-- Оборудование
--------------------------------------------------

config.hardware = {

    betChestSide = 0,

    itemChestSide = 0,

    meSide = 0

}

--------------------------------------------------
-- Пути
--------------------------------------------------

config.paths = {

    root =
        "/BlackJack/",


    config =
        "/BlackJack/data/config.db",


    players =
        "/BlackJack/data/players.db",


    items =
        "/BlackJack/data/items.db",


    stats =
        "/BlackJack/data/stats.db",


    settings =
        "/BlackJack/data/settings.db",


    bets =
        "/BlackJack/data/bets.db",


    admin =
        "/BlackJack/data/admin.db",


    log =
        "/BlackJack/data/log.txt"

}

--------------------------------------------------
-- Цвета
--------------------------------------------------

config.colors = {

    background = 0x202020,

    text = 0xFFFFFF,

    success = 0x00CC66,

    warning = 0xFFCC00,

    error = 0xCC3333,

    gold = 0xFFD700,

    table = 0x0E5F3A

}

--------------------------------------------------
-- Ставки
--------------------------------------------------

config.bet = {

    enabled = true,

    minimum = 1,

    maximum = 64

}

--------------------------------------------------
-- Карты
--------------------------------------------------

config.cards = {

    animation = true,

    showDealerCard = false

}

--------------------------------------------------

return config