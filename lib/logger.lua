--------------------------------------------------
-- BlackJack
-- lib/logger.lua
--------------------------------------------------

local config = require("config")

local storage = require("lib.storage")
local util = require("lib.util")

local logger = {}

--------------------------------------------------
-- Запись строки
--------------------------------------------------

local function write(level, message)

    local line = string.format(

        "[%s %s] [%s] %s\n",

        util.date(),

        util.time(),

        level,

        tostring(message)

    )


    storage.append(

        config.paths.log,

        line

    )

end

--------------------------------------------------
-- Информация
--------------------------------------------------

function logger.info(message)

    write(

        "INFO",

        message

    )

end

--------------------------------------------------
-- Предупреждение
--------------------------------------------------

function logger.warning(message)

    write(

        "WARNING",

        message

    )

end

--------------------------------------------------
-- Ошибка
--------------------------------------------------

function logger.error(message)

    write(

        "ERROR",

        message

    )

end

--------------------------------------------------
-- Игрок
--------------------------------------------------

function logger.player(player, message)

    write(

        "PLAYER",

        "[" ..

        tostring(player) ..

        "] " ..

        tostring(message)

    )

end

--------------------------------------------------
-- Администратор
--------------------------------------------------

function logger.admin(player, message)

    write(

        "ADMIN",

        "[" ..

        tostring(player) ..

        "] " ..

        tostring(message)

    )

end

--------------------------------------------------
-- Ставка
--------------------------------------------------

function logger.bet(player, amount, item)

    write(

        "BET",

        string.format(

            "[%s] %d x %s",

            tostring(player),

            tonumber(amount) or 0,

            tostring(item)

        )

    )

end

--------------------------------------------------
-- Победа
--------------------------------------------------

function logger.win(player, amount, item)

    write(

        "WIN",

        string.format(

            "[%s] %d x %s",

            tostring(player),

            tonumber(amount) or 0,

            tostring(item)

        )

    )

end

--------------------------------------------------
-- Проигрыш
--------------------------------------------------

function logger.lose(player, amount, item)

    write(

        "LOSE",

        string.format(

            "[%s] %d x %s",

            tostring(player),

            tonumber(amount) or 0,

            tostring(item)

        )

    )

end

--------------------------------------------------
-- Отладка
--------------------------------------------------

function logger.debug(message)

    write(

        "DEBUG",

        message

    )

end

--------------------------------------------------

return logger