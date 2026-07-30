--------------------------------------------------
-- BlackJack
-- admin/admin.lua
--------------------------------------------------

local storage = require("lib.storage")
local config = require("config")

local admin = {}

--------------------------------------------------
-- Администраторы
--------------------------------------------------

admin.players = {

    "hellbreez",

    "Lofland"

}

--------------------------------------------------
-- Настройки
--------------------------------------------------

admin.settings = nil

--------------------------------------------------
-- Загрузка
--------------------------------------------------

function admin.load()

    admin.settings =
        storage.load(
            config.paths.admin
        )


    if not admin.settings then

        admin.settings = {

            enabled = true,

            admins = admin.players

        }


        storage.save(

            config.paths.admin,

            admin.settings

        )

    end

end

--------------------------------------------------
-- Проверка администратора
--------------------------------------------------

function admin.isAdmin(player)

    if not player then
        return false
    end


    for _, name in ipairs(
        admin.settings.admins
    ) do

        if name == player then

            return true

        end

    end


    return false

end

--------------------------------------------------
-- Получить список админов
--------------------------------------------------

function admin.getAdmins()

    return admin.settings.admins

end

--------------------------------------------------
-- Добавить администратора
--------------------------------------------------

function admin.add(player)

    if admin.isAdmin(player) then

        return false

    end


    table.insert(

        admin.settings.admins,

        player

    )


    storage.save(

        config.paths.admin,

        admin.settings

    )


    return true

end

--------------------------------------------------
-- Удалить администратора
--------------------------------------------------

function admin.remove(player)

    for i, name in ipairs(
        admin.settings.admins
    ) do

        if name == player then

            table.remove(

                admin.settings.admins,

                i

            )


            storage.save(

                config.paths.admin,

                admin.settings

            )


            return true

        end

    end


    return false

end

--------------------------------------------------
-- Включение панели
--------------------------------------------------

function admin.enabled()

    return admin.settings.enabled

end


--------------------------------------------------
-- Инициализация
--------------------------------------------------

admin.load()


--------------------------------------------------

return admin