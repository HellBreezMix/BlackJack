--------------------------------------------------
-- BlackJack
-- install.lua
--------------------------------------------------

local shell = require("shell")
local filesystem = require("filesystem")


--------------------------------------------------
-- Настройки
--------------------------------------------------

local repo =
    "https://raw.githubusercontent.com/HellBreezMix/BlackJack/main/"


local root =
    "/BlackJack/"


--------------------------------------------------
-- Файлы проекта
--------------------------------------------------

local files = {


    -- ядро

    "main.lua",
    "config.lua",
    "manifest.lua",


    -- игра

    "game/cards.lua",
    "game/deck.lua",
    "game/player.lua",
    "game/dealer.lua",
    "game/game.lua",
    "game/controller.lua",
    "game/rules.lua",


    -- интерфейс

    "ui/gui.lua",
    "ui/widgets.lua",
    "ui/renderer.lua",
    "ui/theme.lua",
    "ui/control_panel.lua",
    "ui/table.lua",
    "ui/card_renderer.lua",
    "ui/card_faces.lua",
    "ui/pixel.lua",
    "ui/sprites.lua",


    -- библиотеки

    "lib/storage.lua",
    "lib/logger.lua",
    "lib/util.lua",


    -- админ

    "admin/admin.lua",


    -- банк

    "bank/economy.lua",


    -- железо

    "hardware/me_network.lua",
    "hardware/transposer.lua",


    -- система

    "system/init.lua"

}



--------------------------------------------------
-- Создание папок
--------------------------------------------------

local function makePath(file)

    local dir =
        file:match("(.+)/[^/]+$")


    if dir then

        filesystem.makeDirectory(
            root .. dir
        )

    end

end



--------------------------------------------------
-- Загрузка файла
--------------------------------------------------

local function download(file)


    makePath(file)


    local url =
        repo .. file


    local path =
        root .. file



    print(
        "[DOWNLOAD] " .. file
    )



    local result =
        shell.execute(

            "wget -f " ..
            url ..
            " " ..
            path

        )



    if not result then

        print(
            "[FAILED] " .. file
        )

    end


end



--------------------------------------------------
-- Установка
--------------------------------------------------

print("")
print("======================")
print(" BlackJack Installer ")
print("======================")
print("")



filesystem.makeDirectory(
    root
)



for _, file in ipairs(files) do

    download(file)

end



print("")
print("======================")
print(" Installation done ")
print("======================")
print("")

print(
    "Run:"
)

print(
    "lua /BlackJack/main.lua"
)
