--------------------------------------------------
-- BlackJack
-- ui/control_panel.lua
--------------------------------------------------

local widgets = require("ui.widgets")

local renderer = require("ui.renderer")

local theme = require("ui.theme")


local panel = {}

panel.buttons = {}


--------------------------------------------------
-- Создать панель
--------------------------------------------------

function panel.create(callbacks)


    callbacks = callbacks or {}



    local width, height =
        renderer.getResolution()



    local y =
        height - 4



    panel.buttons = {


        widgets.button(

            3,

            y,

            10,

            3,

            "HIT",

            callbacks.hit

        ),



        widgets.button(

            15,

            y,

            10,

            3,

            "STAND",

            callbacks.stand

        ),



        widgets.button(

            27,

            y,

            10,

            3,

            "DOUBLE",

            callbacks.double

        ),



        widgets.button(

            39,

            y,

            10,

            3,

            "SPLIT",

            callbacks.split

        )


    }


end


--------------------------------------------------
-- Рисование
--------------------------------------------------

function panel.draw()


    local width, height =
        renderer.getResolution()



    renderer.panel(

        1,

        height - 5,

        width,

        5,

        theme.colors.panel

    )



    renderer.border(

        1,

        height - 5,

        width,

        5,

        theme.colors.gold

    )



    for _, button in ipairs(panel.buttons) do

        button.draw()

    end


end


--------------------------------------------------
-- Нажатие
--------------------------------------------------

function panel.touch(x, y)


    for _, button in ipairs(panel.buttons) do


        if button.click(x, y) then

            return true

        end


    end


    return false

end


--------------------------------------------------

return panel