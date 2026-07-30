--------------------------------------------------
-- BlackJack Installer
--------------------------------------------------

local shell = require("shell")
local filesystem = require("filesystem")


local repo =
"https://raw.githubusercontent.com/HellBreezMix/BlackJack/main/"


local target =
"/BlackJack/"


--------------------------------------------------
-- Файлы
--------------------------------------------------

local files = {

    "main.lua",
    "config.lua",
    "blackjack.lua",
    "manifest.lua",
    "version.txt",

    -- game
    "game/cards.lua",
    "game/deck.lua",
    "game/player.lua",
    "game/dealer.lua",
    "game/game.lua",
    "game/controller.lua",
    "game/rules.lua",
    "game/payout.lua",

    -- ui
    "ui/gui.lua",
    "ui/widgets.lua",
    "ui/renderer.lua",
    "ui/card_renderer.lua",
    "ui/card_faces.lua",
    "ui/pixel.lua",

    -- lib
    "lib/storage.lua",
    "lib/logger.lua",
    "lib/util.lua",

    -- admin
    "admin/admin.lua",

    -- bank
    "bank/economy.lua",

    -- hardware
    "hardware/me_network.lua",
    "hardware/transposer.lua",

    -- system
    "system/init.lua"

}


--------------------------------------------------
-- Создание папок
--------------------------------------------------

local function makeDir(path)

    local dir =
        filesystem.path(path)

    if dir and not filesystem.exists(dir) then

        filesystem.makeDirectory(dir)

    end

end



--------------------------------------------------
-- Скачать файл
--------------------------------------------------

local function download(file)

    local url =
        repo .. file


    local path =
        target .. file


    makeDir(path)


    print(
        "Downloading " .. file
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
            "FAILED: " .. file
        )

    end


end



--------------------------------------------------
-- Старт
--------------------------------------------------

print(
"Installing BlackJack..."
)


if not filesystem.exists(target) then

    filesystem.makeDirectory(target)

end



for _, file in ipairs(files) do

    download(file)

end



--------------------------------------------------
-- Запускатель
--------------------------------------------------

local launcher =
[[
#!/bin/sh
lua /BlackJack/main.lua
]]


local f =
io.open(
    "/BlackJack/start",
    "w"
)

if f then

    f:write(launcher)

    f:close()

end



print("")
print("====================")
print("BlackJack installed")
print("")
print("Run:")
print("lua /BlackJack/main.lua")
print("====================")
