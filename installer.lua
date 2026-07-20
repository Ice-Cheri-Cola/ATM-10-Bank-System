local args = {...}
local mode = args[1]

if mode ~= "server" and mode ~= "atm" then
    print("Usage:")
    print("  installer.lua server")
    print("  installer.lua atm")
    return
end

local base = "https://raw.githubusercontent.com/Ice-Cheri-Cola/ATM-10-Bank-System/main/"

local function download(path)
    if fs.exists(path) then
        fs.delete(path)
    end

    print("Downloading " .. path .. "...")
    shell.run("wget", base .. path, path)

    if not fs.exists(path) then
        error("Failed to download " .. path)
    end
end

download("config.lua")

if mode == "server" then
    download("bank_server.lua")

    local startup = fs.open("startup.lua", "w")
    startup.writeLine('shell.run("bank_server.lua")')
    startup.close()

    print("Server installed.")
    print("Run 'id', then put that number into")
    print("BANK_SERVER_ID on every ATM.")
else
    download("bank_atm.lua")

    local startup = fs.open("startup.lua", "w")
    startup.writeLine('shell.run("bank_atm.lua")')
    startup.close()

    print("ATM installed.")
    print("Edit config.lua and set BANK_SERVER_ID.")
end

print("Reboot when configuration is complete.")
