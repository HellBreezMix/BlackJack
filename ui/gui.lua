--------------------------------------------------
-- BlackJack
-- ui/gui.lua
-- russian interface + session timer
--------------------------------------------------

local event = require("event")
local computer = require("computer")
local unicode = require("unicode")


local renderer = require("ui.renderer")
local theme = require("ui.theme")

local controller = require("game.controller")
local cardRenderer = require("ui.card_renderer")

local lang = require("lang.ru")


local gui = {}



--------------------------------------------------
-- STATE
--------------------------------------------------

gui.screen = "menu"

gui.buttons = {}

gui.playerName = "Guest"

gui.authorized = false



--------------------------------------------------
-- TOP PLAYERS
--------------------------------------------------

-- Пока пустой.
-- Позже подключим data/players.lua

gui.topPlayers = {}



--------------------------------------------------
-- SESSION TIMER
--------------------------------------------------

gui.lastActivity = 0

gui.sessionTime = 60



function gui.updateActivity()


    gui.lastActivity =
        computer.uptime()


end





function gui.sessionLeft()


    if not gui.authorized then

        return 0

    end



    local passed =

        computer.uptime()
        -
        gui.lastActivity



    local left =

        gui.sessionTime
        -
        math.floor(passed)



    if left < 0 then

        left = 0

    end



    return left


end





function gui.checkTimeout()


    if not gui.authorized then

        return

    end



    if gui.sessionLeft() <= 0 then



        gui.authorized = false


        gui.playerName = "Guest"


        gui.screen = "menu"


        gui.draw()



    end



end





--------------------------------------------------
-- BUTTON SYSTEM
--------------------------------------------------

function gui.clearButtons()


    gui.buttons = {}


end





function gui.addButton(
    x,
    y,
    w,
    h,
    text,
    callback
)



    table.insert(

        gui.buttons,

        {

            x = x,

            y = y,

            w = w,

            h = h,

            text = text,

            callback = callback

        }

    )



end





function gui.drawButtons()



    for _,b in ipairs(gui.buttons) do



        renderer.panel(

            b.x,

            b.y,

            b.w,

            b.h,

            0x303030

        )



        renderer.border(

            b.x,

            b.y,

            b.w,

            b.h,

            theme.colors.gold

        )



        local tx =


            b.x +

            math.floor(

                (

                    b.w -

                    unicode.len(
                        b.text
                    )

                )
                /
                2

            )



        local ty =


            b.y +

            math.floor(

                b.h / 2

            )



        renderer.text(

            tx,

            ty,

            b.text,

            theme.colors.text

        )



    end



end
--------------------------------------------------
-- SIDE PANEL
--------------------------------------------------

function gui.drawSidePanel()


    local width,height =
        renderer.getResolution()



    local x = width - 28



    renderer.panel(

        x,

        1,

        26,

        35,

        0x101010

    )



    renderer.border(

        x,

        1,

        26,

        35,

        theme.colors.gold

    )





    renderer.center(

        3,

        lang.AUTHORIZATION,

        theme.colors.gold

    )





    if gui.authorized then



        renderer.text(

            x + 2,

            5,

            lang.PLAYER_NAME .. ":",

            theme.colors.text

        )



        renderer.text(

            x + 10,

            5,

            gui.playerName,

            theme.colors.gold

        )




        renderer.text(

            x + 2,

            7,

            lang.SESSION .. ":",

            theme.colors.text

        )



        renderer.text(

            x + 11,

            7,

            tostring(
                gui.sessionLeft()
            ),

            theme.colors.gold

        )



    else



        renderer.center(

            5,

            lang.WAITING,

            theme.colors.text

        )



    end





    renderer.center(

        11,

        lang.TOP_PLAYERS,

        theme.colors.gold

    )




    local y = 13




    for i,p in ipairs(gui.topPlayers) do



        if i > 15 then

            break

        end



        renderer.text(

            x + 2,

            y,

            i .. "." .. p.name,

            theme.colors.text

        )



        renderer.text(

            x + 17,

            y,

            tostring(
                p.money
            ),

            theme.colors.gold

        )



        y = y + 1



    end



end







--------------------------------------------------
-- MENU
--------------------------------------------------

function gui.drawMenu()


    renderer.clear()



    gui.clearButtons()





    renderer.center(

        2,

        lang.TITLE,

        theme.colors.gold

    )





    gui.addButton(

        10,

        8,

        20,

        3,

        lang.PLAY,


        function()



            if not gui.authorized then

                return

            end




            controller.start(

                gui.playerName

            )



            gui.screen = "game"



            gui.draw()



        end


    )





    gui.drawButtons()


    gui.drawSidePanel()



end
--------------------------------------------------
-- GAME SCREEN
--------------------------------------------------

function gui.drawGame()


    renderer.clear()


    gui.clearButtons()





    renderer.center(

        2,

        lang.TITLE,

        theme.colors.gold

    )





    --------------------------------------------------
    -- DEALER
    --------------------------------------------------

    renderer.text(

        3,

        4,

        lang.DEALER .. ":",

        theme.colors.text

    )



    renderer.text(

        12,

        4,

        tostring(

            controller.dealerPoints()

        ),

        theme.colors.gold

    )





    cardRenderer.drawDealer(

        controller.dealerCards(),

        3,

        6,

        not controller.finished()

    )







    --------------------------------------------------
    -- PLAYER
    --------------------------------------------------

    renderer.text(

        3,

        16,

        lang.PLAYER .. ":",

        theme.colors.text

    )



    renderer.text(

        12,

        16,

        tostring(

            controller.playerPoints()

        ),

        theme.colors.gold

    )





    cardRenderer.drawHand(

        controller.playerCards(),

        3,

        18

    )









    --------------------------------------------------
    -- GAME RESULT
    --------------------------------------------------

    if controller.finished() then



        renderer.center(

            27,

            lang.RESULT

            ..

            ": "

            ..

            tostring(

                controller.result()

            ),

            theme.colors.gold

        )







        gui.addButton(

            5,

            30,

            14,

            3,

            lang.NEW_GAME,



            function()



                controller.start(

                    gui.playerName

                )



                gui.draw()



            end


        )






        gui.addButton(

            22,

            30,

            14,

            3,

            lang.MENU,



            function()



                gui.screen = "menu"



                gui.draw()



            end


        )






    else





        gui.addButton(

            4,

            30,

            14,

            3,

            lang.HIT,



            function()



                controller.hit()



                gui.updateActivity()



                gui.draw()



            end


        )







        gui.addButton(

            21,

            30,

            14,

            3,

            lang.STAND,



            function()



                controller.stand()



                gui.updateActivity()



                gui.draw()



            end


        )





    end







    gui.drawButtons()


    gui.drawSidePanel()



end
--------------------------------------------------
-- DRAW
--------------------------------------------------

function gui.draw()


    if gui.screen == "menu" then


        gui.drawMenu()



    elseif gui.screen == "game" then


        gui.drawGame()



    end



end







--------------------------------------------------
-- TOUCH
--------------------------------------------------

function gui.touch(

    x,

    y,

    player

)



    gui.updateActivity()





    --------------------------------------------------
    -- AUTO LOGIN
    --------------------------------------------------

    if player
    and not gui.authorized then



        gui.authorized = true


        gui.playerName = player



        gui.updateActivity()



        gui.draw()



        return



    end






    gui.checkButtons(

        x,

        y

    )



end







--------------------------------------------------
-- START
--------------------------------------------------

function gui.start()



    gui.draw()





    while true do



        local data =

            {

                event.pull(1)

            }






        --------------------------------------------------
        -- TOUCH EVENT
        --------------------------------------------------

        if data[1] == "touch" then



            local x = data[3]

            local y = data[4]

            local player = data[6]



            if x and y then



                gui.touch(

                    x,

                    y,

                    player

                )



            end



        end





        --------------------------------------------------
        -- SESSION CHECK
        --------------------------------------------------

        gui.checkTimeout()



    end



end







--------------------------------------------------

return gui
