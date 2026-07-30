--------------------------------------------------
-- BlackJack
-- installer.lua
--------------------------------------------------

local shell = require("shell")
local filesystem = require("filesystem")


--------------------------------------------------
-- Настройки
--------------------------------------------------

local repo =
    "https://raw.githubusercontent.com/HellBreezMix/BlackJack/main/"


local installPath =
    "/BlackJack/"


--------------------------------------------------
-- Файлы проекта
--------------------------------------------------

local files = {


    "main.lua",
    "config.lua",
    "blackjack.lua",
    "manifest.lua",
    "version.txt",


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


    "bank/bank.lua",


    "hardware/chest.lua",
    "hardware/me.lua",


    "system/init.lua"

}



--------------------------------------------------
-- Создать директории
--------------------------------------------------

local function makeDirectory(path)

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

local function download(file)


    local url =
        repo .. file


    local target =
        installPath .. file


    makeDirectory(target)


    print(
        "Downloading " .. file
    )


    local result =
        shell.execute(

            "wget",

            "-f",

            url,

            target

        )


    if not result then

        print(
            "FAILED: " .. file
        )

        return false

    end


    return true

end



--------------------------------------------------
-- Установка
--------------------------------------------------

print("")
print("BlackJack installer")
print("-------------------")


if not filesystem.exists(installPath) then

    filesystem.makeDirectory(
        installPath
    )

end



local failed = 0


for _, file in ipairs(files) do


    if not download(file) then

        failed = failed + 1

    end


end



--------------------------------------------------
-- Результат
--------------------------------------------------

print("")


if failed > 0 then


    print(
        "Installation failed!"
    )


    print(
        "Missing files: "
        .. failed
    )


    return


end



--------------------------------------------------
-- Создать запуск
--------------------------------------------------

local launcher =
    "/home/blackjack.lua"



local file =
    io.open(
        launcher,
        "w"
    )


if file then


    file:write(

[[
local shell = require("shell")

shell.execute(
    "cd /BlackJack"
)

shell.execute(
    "lua main.lua"
)
]]

    )


    file:close()


end



print("")
print("BlackJack installed!")
print("")
print("Run:")
print("lua /home/blackjack.lua")
