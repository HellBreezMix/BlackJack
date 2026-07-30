--------------------------------------------------
-- BlackJack
-- main.lua
--------------------------------------------------
package.path =
    "/BlackJack/?.lua;" ..
    "/BlackJack/?/init.lua;" ..
    package.path

local logger = require("lib.logger")

local storage = require("lib.storage")

local gui = require("ui.gui")

local config = require("config")

local filesystem = require("filesystem")


--------------------------------------------------
-- Версия
--------------------------------------------------

local VERSION = "1.0.0"



--------------------------------------------------
-- Запуск
--------------------------------------------------

local function boot()


    logger.info(
        "Starting BlackJack " .. VERSION
    )



    --------------------------------------------------
    -- Создание папок
    --------------------------------------------------

    if not filesystem.exists(
        "/BlackJack"
    ) then

        filesystem.makeDirectory(
            "/BlackJack"
        )

    end



    if not filesystem.exists(
        "/BlackJack/data"
    ) then

        filesystem.makeDirectory(
            "/BlackJack/data"
        )

    end



    --------------------------------------------------
    -- Создание файлов
    --------------------------------------------------

    storage.create(

        config.paths.players,

        {}

    )


    storage.create(

        config.paths.items,

        {}

    )


    storage.create(

        config.paths.stats,

        {}

    )


    storage.create(

        config.paths.settings,

        {}

    )


    storage.create(

        config.paths.bets,

        {}

    )


    storage.create(

        config.paths.admin,

        {}

    )



    --------------------------------------------------
    -- Запуск интерфейса
    --------------------------------------------------

    gui.start()


end



--------------------------------------------------
-- Защита запуска
--------------------------------------------------

local ok, err =
    pcall(boot)



if not ok then


    logger.error(err)


    error(err)


end
