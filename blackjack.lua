--------------------------------------------------
-- BlackJack
-- blackjack.lua
--------------------------------------------------

local component = require("component")
local computer = require("computer")
local event = require("event")
local term = require("term")
local gpu = component.gpu

local config = require("config")
local logger = require("lib.logger")
local storage = require("lib.storage")

--------------------------------------------------
-- Создание файлов данных
--------------------------------------------------

storage.create(config.paths.players, {})
storage.create(config.paths.items, {})
storage.create(config.paths.stats, {})
storage.create(config.paths.settings, {})

--------------------------------------------------
-- Очистка экрана
--------------------------------------------------

gpu.setBackground(config.colors.background)
gpu.setForeground(config.colors.text)

term.clear()

--------------------------------------------------
-- Заголовок
--------------------------------------------------

local w, h = gpu.getResolution()

gpu.set(
    math.floor((w - #config.project.name) / 2),
    2,
    config.project.name
)

gpu.set(
    math.floor((w - #("Version " .. config.project.version)) / 2),
    4,
    "Version " .. config.project.version
)

gpu.set(
    math.floor((w - #("Author: " .. config.project.author)) / 2),
    5,
    "Author: " .. config.project.author
)

--------------------------------------------------
-- Проверка компонентов
--------------------------------------------------

local required = {
    "gpu",
    "screen",
    "internet",
    "transposer",
    "adapter"
}

local y = 8

for _, name in ipairs(required) do

    gpu.set(4, y, name .. ":")

    if component.isAvailable(name) then

        gpu.setForeground(config.colors.success)
        gpu.set(22, y, "OK")

    else

        gpu.setForeground(config.colors.error)
        gpu.set(22, y, "NOT FOUND")

    end

    gpu.setForeground(config.colors.text)

    y = y + 1

end

--------------------------------------------------
-- Проверка Database Upgrade
--------------------------------------------------

gpu.set(4, y, "database:")

if component.isAvailable("database") then

    gpu.setForeground(config.colors.success)
    gpu.set(22, y, "OK")

else

    gpu.setForeground(config.colors.warning)
    gpu.set(22, y, "OPTIONAL")

end

gpu.setForeground(config.colors.text)

--------------------------------------------------
-- Лог
--------------------------------------------------

logger.info("BlackJack started.")

--------------------------------------------------
-- Ожидание
--------------------------------------------------

gpu.set(
    4,
    h - 2,
    "GUI library is not ready yet."
)

gpu.set(
    4,
    h - 1,
    "Press any key..."
)

event.pull("key_down")

term.clear()