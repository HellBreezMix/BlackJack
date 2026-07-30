--------------------------------------------------
-- BlackJack
-- ui/gui.lua
--------------------------------------------------

local controlPanel = require("ui.control_panel")
local event = require("event")

local tableView = require("ui.table")
local renderer = require("ui.renderer")
local widgets = require("ui.widgets")
local theme = require("ui.theme")

local admin = require("admin.admin")

local controller = require("game.controller")
local cardRenderer = require("ui.card_renderer")


local gui = {}


--------------------------------------------------
-- Player
--------------------------------------------------

gui.playerName = "Player"


--------------------------------------------------
-- State
--------------------------------------------------

gui.screen = "menu"

gui.buttons = {}



--------------------------------------------------
-- Buttons
--------------------------------------------------

function gui.clearButtons()

    gui.buttons = {}

end



function gui.addButton(button)

    if button then

        table.insert(
            gui.buttons,
            button
        )

    end

end



--------------------------------------------------
-- Menu
--------------------------------------------------

function gui.drawMenu()

    renderer.clear()

    gui.clearButtons()



    renderer.center(
        3,
        "BLACKJACK",
        theme.colors.gold
    )


    renderer.center(
        5,
        "OpenComputers Casino",
        theme.colors.text
    )



    local play = widgets.button(

        10,
        8,
        18,
        3,

        "PLAY",

        function()

            controller.start(
                gui.playerName
            )


            gui.screen = "game"

            gui.draw()

        end

    )


    gui.addButton(play)



    for _, button in ipairs(gui.buttons) do

        button.draw()

    end


end



--------------------------------------------------
-- Game
--------------------------------------------------

function gui.drawGame()


    renderer.clear()

    gui.clearButtons()


    tableView.draw()



    controlPanel.create({

        hit = function()

            controller.hit()

            gui.draw()

        end,


        stand = function()

            controller.stand()

            gui.draw()

        end,


        double = function()

        end,


        split = function()

        end

    })



    controlPanel.draw()



    renderer.center(
        2,
        "BLACKJACK TABLE",
        theme.colors.gold
    )



    renderer.text(
        3,
        4,
        "DEALER: "
        ..
        tostring(
            controller.dealerPoints()
        )
    )



    cardRenderer.drawDealer(

        controller.dealerCards(),

        3,
        5,

        not controller.finished()

    )



    renderer.text(

        3,
        13,

        "PLAYER: "
        ..
        tostring(
            controller.playerPoints()
        )

    )



    cardRenderer.drawHand(

        controller.playerCards(),

        3,
        14

    )



    if controller.finished() then


        renderer.center(

            18,

            "RESULT: "
            ..
            tostring(
                controller.result()
            ),

            theme.colors.gold

        )


    end


end



--------------------------------------------------
-- Admin
--------------------------------------------------

function gui.drawAdmin()


    renderer.clear()

    gui.clearButtons()



    renderer.center(

        3,

        "ADMIN PANEL",

        theme.colors.gold

    )


end



--------------------------------------------------
-- Draw
--------------------------------------------------

function gui.draw()


    if gui.screen == "menu" then


        gui.drawMenu()


    elseif gui.screen == "game" then


        gui.drawGame()


    elseif gui.screen == "admin" then


        gui.drawAdmin()


    end


end



--------------------------------------------------
-- Touch
--------------------------------------------------

function gui.touch(x,y)


    print(
        "TOUCH:",
        x,
        y
    )



    if gui.screen == "game" then


        if controlPanel.touch(
            x,
            y
        ) then

            return true

        end


    end



    for _, button in ipairs(gui.buttons) do


        if button.click then


            if button.click(
                x,
                y
            ) then


                return true


            end


        end


    end



    return false


end



--------------------------------------------------
-- Start
--------------------------------------------------

function gui.start()


    gui.draw()



    while true do


        local e = {
            event.pull()
        }



        if e[1] == "touch" then


            local x = e[4]

            local y = e[5]



            gui.touch(
                x,
                y
            )


        end


    end


end



return gui
