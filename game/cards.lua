--------------------------------------------------
-- BlackJack
-- game/cards.lua
--------------------------------------------------

local cards = {}

--------------------------------------------------
-- Масти
--------------------------------------------------

cards.suits = {

    "hearts",
    "diamonds",
    "clubs",
    "spades"

}

--------------------------------------------------
-- Ранги
--------------------------------------------------

cards.ranks = {

    {id="A", value=11},

    {id="2", value=2},
    {id="3", value=3},
    {id="4", value=4},
    {id="5", value=5},

    {id="6", value=6},
    {id="7", value=7},
    {id="8", value=8},
    {id="9", value=9},

    {id="10", value=10},

    {id="J", value=10},
    {id="Q", value=10},
    {id="K", value=10}

}

--------------------------------------------------
-- Создать одну карту
--------------------------------------------------

function cards.createCard(rank, suit)

    local value = 0

    for _, r in ipairs(cards.ranks) do

        if r.id == rank then

            value = r.value

            break

        end

    end


    return {

        rank = rank,

        suit = suit,

        value = value,

        sprite =
            rank .. "_" .. suit

    }

end

--------------------------------------------------
-- Создание колоды
--------------------------------------------------

function cards.createDeck(deckCount)

    local deck = {}

    deckCount = deckCount or 1


    for d = 1, deckCount do


        for _, suit in ipairs(cards.suits) do


            for _, rank in ipairs(cards.ranks) do


                table.insert(

                    deck,

                    cards.createCard(

                        rank.id,

                        suit

                    )

                )


            end


        end


    end


    return deck

end

--------------------------------------------------
-- Очки руки
--------------------------------------------------

function cards.getValue(hand)

    local total = 0

    local aces = 0


    for _, card in ipairs(hand) do


        total = total + card.value


        if card.rank == "A" then

            aces = aces + 1

        end


    end


    while total > 21 and aces > 0 do


        total = total - 10

        aces = aces - 1


    end


    return total

end

--------------------------------------------------
-- Blackjack
--------------------------------------------------

function cards.isBlackjack(hand)

    return

        #hand == 2

        and

        cards.getValue(hand) == 21

end

--------------------------------------------------
-- Перебор
--------------------------------------------------

function cards.isBust(hand)

    return cards.getValue(hand) > 21

end

--------------------------------------------------
-- Можно ли разделить
--------------------------------------------------

function cards.canSplit(hand)

    if #hand ~= 2 then
        return false
    end


    return

        hand[1].rank == hand[2].rank

end

--------------------------------------------------
-- Название карты
--------------------------------------------------

function cards.getName(card)

    return

        card.rank

        .. " of "

        .. card.suit

end

--------------------------------------------------

return cards