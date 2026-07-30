--------------------------------------------------
-- BlackJack
-- game/controller.lua
--------------------------------------------------

local game = require("game.game")
local payout = require("game.payout")

local controller = {}


--------------------------------------------------
-- Игрок
--------------------------------------------------

controller.playerName = "Player"



--------------------------------------------------
-- Начать игру
--------------------------------------------------

function controller.start(playerName)

    controller.playerName =
        playerName or "Player"


    game.new(
        controller.playerName
    )


    game.deal()

end



--------------------------------------------------
-- Новая партия
--------------------------------------------------

function controller.newGame()

    game.new(
        controller.playerName
    )


    game.deal()

end



--------------------------------------------------
-- HIT
--------------------------------------------------

function controller.hit()


    if game.isFinished() then

        return false

    end


    game.playerHit()


    return true

end



--------------------------------------------------
-- STAND
--------------------------------------------------

function controller.stand()


    if game.isFinished() then

        return false

    end


    game.playerStand()


    return true

end



--------------------------------------------------
-- DOUBLE
--------------------------------------------------

function controller.double()


    if game.isFinished() then

        return false

    end


    return game.playerDouble()

end



--------------------------------------------------
-- Карты игрока
--------------------------------------------------

function controller.playerCards()

    return game.getPlayerHand()

end



--------------------------------------------------
-- Карты дилера
--------------------------------------------------

function controller.dealerCards()

    return game.getDealerHand()

end



--------------------------------------------------
-- Очки игрока
--------------------------------------------------

function controller.playerPoints()

    return game.getPlayerPoints()

end



--------------------------------------------------
-- Очки дилера
--------------------------------------------------

function controller.dealerPoints()

    return game.getDealerPoints()

end



--------------------------------------------------
-- Можно играть?
--------------------------------------------------

function controller.canPlay()

    return not game.isFinished()

end



--------------------------------------------------
-- Закончена ли игра
--------------------------------------------------

function controller.finished()

    return game.isFinished()

end



--------------------------------------------------
-- Результат
--------------------------------------------------

function controller.result()


    local result =
        game.getResult()



    if result == nil then

        return "PLAYING"

    end



    return result


end



--------------------------------------------------
-- Выплата
--------------------------------------------------

function controller.calculateWin(bet)


    return payout.calculate(

        bet,

        game.getResult()

    )


end



--------------------------------------------------
-- Получить игру
--------------------------------------------------

function controller.getGame()

    return game

end



--------------------------------------------------

return controller
