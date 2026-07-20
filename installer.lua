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

local function downloadIfMissing(path)
    if fs.exists(path) then
        print("Keeping existing " .. path .. ".")
        return
    end

    download(path)
end

-- Preserve local settings such as the working vault direction and server ID.
-- Fresh installations still receive the repository's default config.lua.
downloadIfMissing("config.lua")

download("shared/config.lua")
download("shared/protocol.lua")
download("shared/banknet.lua")

if mode == "server" then
    download("bank_server.lua")
    download("server/server.lua")

    local startup = fs.open("startup.lua", "w")
    startup.writeLine('shell.run("server/server.lua")')
    startup.close()

    print("Server installed or updated.")
else
    download("bank_atm.lua")
    download("atm/atm.lua")
    download("atm/config.lua")
    download("atm/touchscreen.lua")

    local startup = fs.open("startup.lua", "w")
    startup.writeLine('shell.run("atm/atm.lua")')
    startup.close()

    print("ATM installed or updated.")
end

print("BankNet library installed at shared/banknet.lua.")
print("Local config.lua was preserved when already present.")
print("Reboot to start the bank program.")