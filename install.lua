--------------------------------------------------
-- BlackJack
-- install.lua
--------------------------------------------------

local shell = require("shell")
local filesystem = require("filesystem")

--------------------------------------------------
-- Репозиторий
--------------------------------------------------

local repo =
    "https://raw.githubusercontent.com/HellBreezMix/BlackJack/main/"

--------------------------------------------------
-- Файлы
--------------------------------------------------

local files = {

    "blackjack.lua",

    "main.lua",
    "config.lua",
    "manifest.lua",

    "game/cards.lua",
    "game/deck.lua",
    "game/player.lua",
    "game/dealer.lua",
    "game/game.lua",
    "game/controller.lua",
    "game/rules.lua",
    "game/payout.lua",

    "ui/gui.lua",
    "ui/widgets.lua",
    "ui/renderer.lua",
    "ui/card_renderer.lua",
    "ui/card_faces.lua",
    "ui/pixel.lua",
    "ui/sprites.lua",
    "ui/theme.lua",

    "lib/storage.lua",
    "lib/logger.lua",
    "lib/util.lua",

    "admin/admin.lua",

    "hardware/chest.lua",
    "hardware/me.lua",

    "system/init.lua"

}


--------------------------------------------------
-- Создать папку
--------------------------------------------------

local function makeDir(path)

    local dir =
        filesystem.path(path)

    if dir
    and dir ~= ""
    and not filesystem.exists(dir)
    then

        filesystem.makeDirectory(dir)

    end

end



--------------------------------------------------
-- Скачать файл
--------------------------------------------------

local function download(path)

    print("Downloading "..path)

    makeDir(path)


    local url =
        repo .. path


    local command =
        "wget -f " ..
        url ..
        " " ..
        path


    local result =
        shell.execute(command)


    if not result then

        print(
            "FAILED: "..path
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


for _, file in ipairs(files) do

    download(file)

end


print("")
print("BlackJack installed!")
print("")


--------------------------------------------------
-- Запуск
--------------------------------------------------

if filesystem.exists(
    "/home/blackjack.lua"
)
then

    print("Starting...")

    shell.execute(
        "lua /home/blackjack.lua"
    )

else

    print(
        "Launcher not found"
    )

end
