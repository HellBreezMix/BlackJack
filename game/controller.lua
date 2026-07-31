--------------------------------------------------
-- BlackJack
-- game/controller.lua
--------------------------------------------------

local game = require("game.game")
local payout = require("game.payout")

local controller = {}



--------------------------------------------------
-- STATE
--------------------------------------------------

controller.playerName = "Player"

controller.state = {

    dealerCards = {},
    playerCards = {},

    dealerPoints = 0,
    playerPoints = 0,

    result = nil,
    finished = false

}



--------------------------------------------------
-- UPDATE STATE
--------------------------------------------------

local function updateState()


    controller.state.playerCards =
        game.getPlayerHand() or {}



    controller.state.dealerCards =
        game.getDealerHand() or {}



    controller.state.playerPoints =
        game.getPlayerPoints() or 0



    controller.state.dealerPoints =
        game.getDealerPoints() or 0



    controller.state.finished =
        game.isFinished()



    controller.state.result =
        game.getResult()



end





--------------------------------------------------
-- GET STATE
--------------------------------------------------

function controller.getState()


    updateState()


    return controller.state


end





--------------------------------------------------
-- START GAME
--------------------------------------------------

function controller.start(playerName)


    controller.playerName =
        playerName or "Player"



    game.new(

        controller.playerName

    )


    game.deal()



    updateState()



    return true


end





--------------------------------------------------
-- NEW ROUND
--------------------------------------------------

function controller.newGame()


    game.new(

        controller.playerName

    )


    game.deal()



    updateState()



end





--------------------------------------------------
-- HIT
--------------------------------------------------

function controller.hit()



    if game.isFinished() then

        return false

    end



    game.playerHit()



    updateState()



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



    updateState()



    return true


end





--------------------------------------------------
-- DOUBLE
--------------------------------------------------

function controller.double()



    if game.isFinished() then

        return false

    end



    local result =
        game.playerDouble()



    updateState()



    return result


end





--------------------------------------------------
-- PLAYER CARDS
--------------------------------------------------

function controller.playerCards()


    return game.getPlayerHand()


end





--------------------------------------------------
-- DEALER CARDS
--------------------------------------------------

function controller.dealerCards()


    return game.getDealerHand()


end





--------------------------------------------------
-- POINTS
--------------------------------------------------

function controller.playerPoints()


    return game.getPlayerPoints()


end



function controller.dealerPoints()


    return game.getDealerPoints()


end





--------------------------------------------------
-- STATUS
--------------------------------------------------

function controller.canPlay()


    return not game.isFinished()


end



function controller.finished()


    return game.isFinished()


end





--------------------------------------------------
-- RESULT
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
-- PAYOUT
--------------------------------------------------

function controller.calculateWin(bet)



    return payout.calculate(

        bet,

        game.getResult()

    )


end





--------------------------------------------------
-- RAW GAME
--------------------------------------------------

function controller.getGame()


    return game


end





return controller
