--------------------------------------------------
-- BlackJack Installer
--------------------------------------------------

local shell = require("shell")
local filesystem = require("filesystem")

local repo =
    "https://raw.githubusercontent.com/HellBreezMix/BlackJack/main/"


local files = {

    -- core
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
    "ui/control_panel.lua",
    "ui/animation.lua",
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



local root = "/BlackJack/"


print("====================")
print("BlackJack installer")
print("====================")


if not filesystem.exists(root) then
    filesystem.makeDirectory(root)
end



for _, file in ipairs(files) do


    local path =
        root .. file


    local dir =
        filesystem.path(path)


    if not filesystem.exists(dir) then

        filesystem.makeDirectory(dir)

    end



    print("Downloading " .. file)


    local url =
        repo .. file



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



print("====================")
print("BlackJack installed")
print("====================")

print(
    "Run:"
)

print(
    "lua /BlackJack/main.lua"
)
