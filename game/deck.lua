--------------------------------------------------
-- BlackJack
-- game/deck.lua
--------------------------------------------------

local cards = require("game.cards")

local deck = {}

--------------------------------------------------
-- Колода
--------------------------------------------------

deck.cards = {}

deck.size = 1

--------------------------------------------------
-- Инициализация случайности
--------------------------------------------------

math.randomseed(
    os.time()
)

--------------------------------------------------
-- Создать колоду
--------------------------------------------------

function deck.new(deckCount)

    deck.size = deckCount or 1

    deck.cards =
        cards.createDeck(deck.size)

    deck.shuffle()

end

--------------------------------------------------
-- Перемешивание
--------------------------------------------------

function deck.shuffle()

    for i = #deck.cards, 2, -1 do

        local j =
            math.random(i)

        deck.cards[i],
        deck.cards[j] =

        deck.cards[j],
        deck.cards[i]

    end

end

--------------------------------------------------
-- Остаток
--------------------------------------------------

function deck.count()

    return #deck.cards

end

--------------------------------------------------
-- Взять карту
--------------------------------------------------

function deck.draw()

    if #deck.cards == 0 then

        return nil

    end

    return table.remove(

        deck.cards

    )

end

--------------------------------------------------
-- Добавить карту
--------------------------------------------------

function deck.push(card)

    if card then

        table.insert(

            deck.cards,

            card

        )

    end

end

--------------------------------------------------
-- Вернуть руку
--------------------------------------------------

function deck.returnCards(hand)

    for _, card in ipairs(hand) do

        deck.push(card)

    end

    deck.shuffle()

end

--------------------------------------------------
-- Пустая?
--------------------------------------------------

function deck.isEmpty()

    return #deck.cards == 0

end

--------------------------------------------------
-- Проверка остатка
--------------------------------------------------

function deck.ensure()

    local minimum =

        deck.size * 52 * 0.15


    if #deck.cards < minimum then

        deck.new(deck.size)

    end

end

--------------------------------------------------
-- Сжечь карту
--------------------------------------------------

function deck.burn()

    if #deck.cards > 0 then

        return table.remove(

            deck.cards

        )

    end

end

--------------------------------------------------
-- Получить текущую колоду
--------------------------------------------------

function deck.get()

    return deck.cards

end

--------------------------------------------------

return deck