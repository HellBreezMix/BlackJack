local players = {}


function players.load(name)

    if not players[name] then

        players[name] = {

            money = 0,
            wins = 0,
            loses = 0,
            games = 0

        }

    end


    return players[name]

end



function players.addWin(name)

    local p = players.load(name)

    p.wins = p.wins + 1

end



function players.addLose(name)

    local p = players.load(name)

    p.loses = p.loses + 1

end



function players.top()


    local result = {}


    for name,data in pairs(players) do


        table.insert(

            result,

            {

                name=name,

                money=data.money

            }

        )


    end



    table.sort(

        result,

        function(a,b)

            return a.money>b.money

        end

    )


    return result


end



return players
