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
-- Игрок
--------------------------------------------------

gui.playerName = "Player"


--------------------------------------------------
-- Экран
--------------------------------------------------

gui.screen = "menu"

gui.buttons = {}


--------------------------------------------------
-- Очистка кнопок
--------------------------------------------------

function gui.clearButtons()

    gui.buttons = {}

end



--------------------------------------------------
-- Добавить кнопку
--------------------------------------------------

function gui.addButton(button)

    table.insert(
        gui.buttons,
        button
    )

end



--------------------------------------------------
-- Главное меню
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



    local play =
        widgets.button(
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



    if admin
    and admin.isAdmin
    and admin.isAdmin(gui.playerName)
    then


        local adminButton =
            widgets.button(
                10,
                13,
                18,
                3,
                "ADMIN",
                function()

                    gui.screen = "admin"

                    gui.draw()

                end
            )


        gui.addButton(adminButton)


    end



    for _, button in ipairs(gui.buttons) do

        button.draw()

    end


end



--------------------------------------------------
-- Игровой стол
--------------------------------------------------

function gui.drawGame()


    renderer.clear()


    tableView.draw()



    gui.clearButtons()



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


            -- пока отключено


        end,


        split = function()


            -- пока отключено


        end


    })



    controlPanel.draw()



    renderer.center(

        2,

        "BLACKJACK TABLE",

        theme.colors.gold

    )



    --------------------------------------------------
    -- Дилер
    --------------------------------------------------

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




    --------------------------------------------------
    -- Игрок
    --------------------------------------------------

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





    --------------------------------------------------
    -- Результат
    --------------------------------------------------

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
-- Админ меню
--------------------------------------------------

function gui.drawAdmin()


    renderer.clear()


    gui.clearButtons()



    renderer.center(

        3,

        "ADMIN PANEL",

        theme.colors.gold

    )



    renderer.text(

        5,

        6,

        "ITEM MANAGEMENT"

    )




    local back =
        widgets.button(

            10,

            15,

            18,

            3,

            "BACK",

            function()


                gui.screen = "menu"


                gui.draw()


            end

        )



    gui.addButton(back)




    for _, button in ipairs(gui.buttons) do

        button.draw()

    end


end



--------------------------------------------------
-- Отрисовка
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
-- Обработка касания
--------------------------------------------------

function gui.touch(x, y)



    if gui.screen == "game" then


        if controlPanel.touch(x,y) then

            return true

        end


    end




    for _, button in ipairs(gui.buttons) do


        if button.click(x,y) then


            return true

        end


    end



    return false


end



--------------------------------------------------
-- Запуск GUI
--------------------------------------------------

function gui.start()


    gui.draw()



    while true do


        local _, _, _, x, y =
            event.pull(
                "touch"
            )



        gui.touch(
            x,
            y
        )


    end


end



--------------------------------------------------

return gui