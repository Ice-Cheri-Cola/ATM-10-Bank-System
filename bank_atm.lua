local config = require("config")

if config.BANK_SERVER_ID == 0 then
    error("Set BANK_SERVER_ID in config.lua before running the ATM.")
end

local modem = peripheral.find("modem")
if not modem then
    error("No modem connected to this ATM.")
end

local manager = peripheral.find("inventory_manager")
    or peripheral.find("inventoryManager")

if not manager then
    error("No Advanced Peripherals Inventory Manager found.")
end

rednet.open(peripheral.getName(modem))

local function clear()
    term.clear()
    term.setCursorPos(1, 1)
end

local function requestId()
    return tostring(os.getComputerID())
        .. "-"
        .. tostring(os.epoch("utc"))
        .. "-"
        .. tostring(math.random(100000, 999999))
end

local function getUsername()
    local first, second = manager.getOwner()

    -- Newer versions return UUID, username.
    -- Older versions return username.
    return second or first
end

local function sendRequest(message)
    rednet.send(config.BANK_SERVER_ID, message, config.PROTOCOL)

    local timer = os.startTimer(config.REQUEST_TIMEOUT)

    while true do
        local event, a, b, c = os.pullEvent()

        if event == "rednet_message" then
            local senderId, response, protocol = a, b, c

            if senderId == config.BANK_SERVER_ID
                and protocol == config.PROTOCOL
                and type(response) == "table"
                and response.requestId == message.requestId then
                return response
            end
        elseif event == "timer" and a == timer then
            return {
                ok = false,
                message = "The bank server did not respond."
            }
        end
    end
end

local function moveFromPlayer(amount)
    if manager.exportItem then
        return manager.exportItem(config.ATM_VAULT_NAME, {
            name = config.CURRENCY_ITEM,
            count = amount
        })
    end

    if manager.removeItemFromPlayer then
        return manager.removeItemFromPlayer(config.ATM_VAULT_DIRECTION, {
            name = config.CURRENCY_ITEM,
            count = amount
        })
    end

    error("This Inventory Manager has no supported deposit method.")
end

local function moveToPlayer(amount)
    if manager.importItem then
        return manager.importItem(config.ATM_VAULT_NAME, {
            name = config.CURRENCY_ITEM,
            count = amount
        })
    end

    if manager.addItemToPlayer then
        return manager.addItemToPlayer(config.ATM_VAULT_DIRECTION, {
            name = config.CURRENCY_ITEM,
            count = amount
        })
    end

    error("This Inventory Manager has no supported withdrawal method.")
end

local function readAmount(label)
    write(label .. ": ")
    local amount = tonumber(read())

    if not amount
        or amount ~= math.floor(amount)
        or amount < 1
        or amount > config.MAX_TRANSACTION then
        print("Enter a whole number from 1 to " .. config.MAX_TRANSACTION .. ".")
        return nil
    end

    return amount
end

local function pause()
    print()
    print("Press Enter to continue.")
    read()
end

local function showBalance(username)
    local id = requestId()
    local response = sendRequest({
        action = "balance",
        requestId = id,
        username = username
    })

    if response.ok then
        print("Balance: " .. response.data.balance .. " " .. config.CURRENCY_NAME)
    else
        print("Error: " .. tostring(response.message))
    end
end

local function deposit(username)
    local amount = readAmount("Deposit amount")
    if not amount then
        pause()
        return
    end

    print("Moving diamonds into the vault...")
    local moved = moveFromPlayer(amount)

    if moved <= 0 then
        print("No diamonds were deposited.")
        pause()
        return
    end

    local id = requestId()
    local response = sendRequest({
        action = "deposit",
        requestId = id,
        username = username,
        amount = moved
    })

    if response.ok then
        print("Deposited: " .. moved)
        print("New balance: " .. response.data.balance)
    else
        print("WARNING: " .. moved .. " diamonds entered the vault,")
        print("but the server did not credit the account.")
        print("Save this recovery ID: " .. id)
        print("Reason: " .. tostring(response.message))
    end

    pause()
end

local function withdraw(username)
    local amount = readAmount("Withdrawal amount")
    if not amount then
        pause()
        return
    end

    local id = requestId()
    local prepared = sendRequest({
        action = "withdraw_prepare",
        requestId = id,
        username = username,
        amount = amount
    })

    if not prepared.ok then
        print("Withdrawal denied: " .. tostring(prepared.message))
        pause()
        return
    end

    print("Moving diamonds from the vault...")
    local moved = moveToPlayer(amount)

    local committed = sendRequest({
        action = "withdraw_commit",
        requestId = id,
        username = username,
        amount = moved
    })

    if committed.ok then
        print("Withdrawn: " .. moved)
        print("New balance: " .. committed.data.balance)

        if moved < amount then
            print("Only part of the request could be delivered.")
            print("Check vault stock and player inventory space.")
        end
    else
        print("CRITICAL: Diamonds moved, but the account update failed.")
        print("Recovery ID: " .. id)
        print("Reason: " .. tostring(committed.message))
    end

    pause()
end

math.randomseed(os.epoch("utc"))

while true do
    clear()

    local username = getUsername()

    print("==============================")
    print("       ATM10 DIAMOND BANK")
    print("==============================")
    print()

    if not username then
        print("Insert a bound Memory Card into")
        print("the Inventory Manager.")
        print()
        print("The card owner must be online.")
        sleep(2)
    else
        print("Card owner: " .. username)
        print()
        print("1. Check balance")
        print("2. Deposit diamonds")
        print("3. Withdraw diamonds")
        print("4. Refresh card")
        print("5. Exit")
        print()
        write("Choose: ")

        local choice = read()

        if choice == "1" then
            showBalance(username)
            pause()
        elseif choice == "2" then
            deposit(username)
        elseif choice == "3" then
            withdraw(username)
        elseif choice == "4" then
            -- Main loop refreshes the card.
        elseif choice == "5" then
            clear()
            return
        else
            print("Invalid choice.")
            pause()
        end
    end
end
