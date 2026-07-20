local args = {...}
local mode = args[1]

if mode ~= "server" and mode ~= "atm" then
    print("Usage:")
    print("  installer.lua server")
    print("  installer.lua atm")
    return
end

local base = "https://raw.githubusercontent.com/Ice-Cheri-Cola/ATM-10-Bank-System/main/"

local function ensureParent(path)
    local parent = fs.getDir(path)
    if parent ~= "" and not fs.exists(parent) then
        fs.makeDir(parent)
    end
end

local function download(path)
    ensureParent(path)

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
download("shared/config.lua")
download("shared/protocol.lua")

if mode == "server" then
    download("bank_server.lua")
    download("server/server.lua")

    local startup = fs.open("startup.lua", "w")
    startup.writeLine('shell.run("server/server.lua")')
    startup.close()

    print("Server installed.")
    print("Configured bank server ID: 20")
else
    download("bank_atm.lua")
    download("atm/atm.lua")

    local startup = fs.open("startup.lua", "w")
    startup.writeLine('shell.run("atm/atm.lua")')
    startup.close()

    print("ATM installed.")
    print("Configured bank server ID: 20")
end

print("Reboot to start the bank program.")
