--------------------------------------------------
-- BlackJack
-- game/rules.lua
--------------------------------------------------

local rules = {}

--------------------------------------------------
-- Результаты
--------------------------------------------------

rules.RESULT = {

    WIN = "WIN",

    LOSE = "LOSE",

    DRAW = "DRAW",

    BLACKJACK = "BLACKJACK"

}

--------------------------------------------------
-- Определение результата
--------------------------------------------------

function rules.getResult(player, dealer)


    if player:isBust() then

        return rules.RESULT.LOSE

    end



    if dealer:isBust() then

        return rules.RESULT.WIN

    end



    local playerBJ =
        player:isBlackjack()


    local dealerBJ =
        dealer:isBlackjack()



    if playerBJ and dealerBJ then

        return rules.RESULT.DRAW

    end



    if playerBJ then

        return rules.RESULT.BLACKJACK

    end



    if dealerBJ then

        return rules.RESULT.LOSE

    end



    local p =
        player:points()


    local d =
        dealer:points()



    if p > d then

        return rules.RESULT.WIN

    end



    if p < d then

        return rules.RESULT.LOSE

    end



    return rules.RESULT.DRAW

end

--------------------------------------------------
-- Множитель выплаты
--------------------------------------------------

function rules.getMultiplier(result)


    if result == rules.RESULT.BLACKJACK then

        return 2.5

    end



    if result == rules.RESULT.WIN then

        return 2.0

    end



    if result == rules.RESULT.DRAW then

        return 1.0

    end



    return 0.0

end

--------------------------------------------------
-- Название
--------------------------------------------------

function rules.getName(result)


    if result == rules.RESULT.WIN then

        return "WIN"

    end



    if result == rules.RESULT.LOSE then

        return "LOSE"

    end



    if result == rules.RESULT.DRAW then

        return "DRAW"

    end



    if result == rules.RESULT.BLACKJACK then

        return "BLACKJACK"

    end



    return "UNKNOWN"

end

--------------------------------------------------

return rules