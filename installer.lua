local args = {...}
local mode = args[1]

if mode ~= "server" and mode ~= "atm" then
    print("Usage:")
    print("  installer.lua server")
    print("  installer.lua atm")
    return
end

local base = "https://raw.githubusercontent.com/Ice-Cheri-Cola/ATM-10-Bank-System/main/"
local cacheBuster = tostring(os.epoch("utc"))

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
    local url = base .. path .. "?v=" .. cacheBuster
    local ok = shell.run("wget", url, path)

    if not ok or not fs.exists(path) then
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

local function rewriteFile(path, transform, label)
    local handle = fs.open(path, "r")
    if not handle then
        error("Could not open " .. path .. " for " .. label .. ".")
    end

    local content = handle.readAll()
    handle.close()

    local updated = transform(content)

    handle = fs.open(path, "w")
    if not handle then
        error("Could not save " .. label .. " to " .. path)
    end

    handle.write(updated)
    handle.close()
end

local function patchTransferFields(path)
    rewriteFile(path, function(content)
        content = content:gsub("toUsername%s*=%s*recipient", "recipient = recipient")
        content = content:gsub('reason%s*=%s*"ATM transfer"', 'description = "ATM transfer"')
        return content
    end, "transfer patch")
end

local function patchWirelessModemSelection(path)
    rewriteFile(path, function(content)
        local replacement = [[local modem = peripheral.find("modem", function(_, wrapped)
    return wrapped.isWireless and wrapped.isWireless()
end)
if not modem then
    error("No wireless modem connected to this ATM.")
end]]

        content = content:gsub(
            'local modem = peripheral%.find%("modem"%)\nif not modem then error%("No modem connected to this ATM%."%) end',
            replacement,
            1
        )

        content = content:gsub(
            'local modem = peripheral%.find%("modem"%)\nif not modem then\n    error%("No modem connected to this ATM%."%)\nend',
            replacement,
            1
        )

        return content
    end, "wireless modem patch")
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
    patchTransferFields("atm/touchscreen.lua")
    patchWirelessModemSelection("bank_atm.lua")
    patchWirelessModemSelection("atm/touchscreen.lua")

    local startup = fs.open("startup.lua", "w")
    startup.writeLine('shell.run("atm/atm.lua")')
    startup.close()

    print("ATM installed or updated.")
end

print("BankNet library installed at shared/banknet.lua.")
print("Local config.lua was preserved when already present.")
print("Wired inventory peripherals are supported; BankNet uses the wireless modem.")
print("Reboot to start the bank program.")