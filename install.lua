--------------------------------------------------
-- BlackJack Casino - Installer
-- Запуск: lua install.lua
--------------------------------------------------

local filesystem = require("filesystem")
local shell      = require("shell")
local component  = require("component")

local REPO = "https://raw.githubusercontent.com/HellBreezMix/BlackJack/main/"
local ROOT = "/BlackJack/"

local files = {
    "config.lua",
    "main.lua"
}

print("")
print("================================")
print("  BlackJack Casino Installer")
print("================================")
print("")

-- Создаём папку
if not filesystem.exists(ROOT) then
    print("[+] Создаю папку " .. ROOT)
    filesystem.makeDirectory(ROOT)
else
    print("[=] Папка " .. ROOT .. " уже существует")
end

-- Скачиваем файлы
local ok = true
for _, file in ipairs(files) do
    local url  = REPO .. file
    local path = ROOT .. file

    print("[↓] Скачиваю " .. file .. " ...")

    -- -f = перезаписать, если файл уже есть
    local result = shell.execute('wget -f "' .. url .. '" "' .. path .. '"')

    if filesystem.exists(path) then
        print("[✓] " .. path)
    else
        print("[✗] Не удалось скачать " .. file)
        ok = false
    end
end

print("")
if ok then
    print("================================")
    print("  Установка завершена!")
    print("================================")
    print("")
    print("Запуск:")
    print("  lua /BlackJack/main.lua")
    print("")
else
    print("[!] Установка завершилась с ошибками.")
    print("    Проверь интернет и адрес репозитория.")
end
