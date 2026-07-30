--------------------------------------------------
-- BlackJack
-- system/init.lua
--------------------------------------------------

local filesystem = require("filesystem")

local config = require("config")

local storage = require("lib.storage")
local logger = require("lib.logger")

local admin = require("admin.admin")
local items = require("admin.items")

local transposer = require("hardware.transposer")
local me = require("hardware.me_network")

local system = {}

--------------------------------------------------
-- Создание папок
--------------------------------------------------

function system.createFolders()

    local folders = {

        "/BlackJack",

        "/BlackJack/data",

        "/BlackJack/logs"

    }


    for _, path in ipairs(folders) do

        if not filesystem.exists(path) then

            filesystem.makeDirectory(path)

        end

    end

end

--------------------------------------------------
-- Создание файлов
--------------------------------------------------

function system.createFiles()

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


    if not filesystem.exists(
        config.paths.log
    ) then

        local file =
            io.open(
                config.paths.log,
                "w"
            )


        if file then

            file:close()

        end

    end

end

--------------------------------------------------
-- Загрузка модулей
--------------------------------------------------

function system.load()

    admin.load()

    items.load()

end

--------------------------------------------------
-- Подключение железа
--------------------------------------------------

function system.hardware()

    local tp =
        transposer.init(
            config.hardware.itemChestSide
        )


    local network =
        me.init()


    return {

        transposer = tp,

        me = network

    }

end

--------------------------------------------------
-- Запуск
--------------------------------------------------

function system.start()

    system.createFolders()

    system.createFiles()

    system.load()

    local hardware =
        system.hardware()


    logger.info(
        "System initialized"
    )


    return hardware

end

--------------------------------------------------

return system