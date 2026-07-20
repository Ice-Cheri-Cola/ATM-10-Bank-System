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

local hasColor = term.isColor and term.isColor()
local width, height = term.getSize()

local COLORS = {
    background = colors.black,
    title = colors.cyan,
    text = colors.white,
    muted = colors.lightGray,
    success = colors.lime,
    warning = colors.yellow,
    error = colors.red,
    accent = colors.blue
}

local function setText(color)
    if hasColor then
        term.setTextColor(color)
    end
end

local function setBackground(color)
    if hasColor then
        term.setBackgroundColor(color)
    end
end

local function clear()
    setBackground(COLORS.background)
    setText(COLORS.text)
    term.clear()
    term.setCursorPos(1, 1)
end

local function center(y, text)
    text = tostring(text or "")
    local x = math.floor((width - #text) / 2) + 1
    if x < 1 then x = 1 end
    term.setCursorPos(x, y)
    write(text)
end

local function line(y, char)
    char = char or "-"
    term.setCursorPos(1, y)
    write(string.rep(char, width))
end

local function drawHeader(subtitle)
    clear()
    setText(COLORS.title)
    center(1, "ATM-10 DIAMOND BANK")
    setText(COLORS.muted)
    center(2, subtitle or "SECURE BANKING TERMINAL")
    line(3, "=")
    setText(COLORS.text)
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

local function pause()
    print()
    setText(COLORS.muted)
    print("Press Enter to return to the menu.")
    setText(COLORS.text)
    read()
end

local function readAmount(label)
    print()
    setText(COLORS.title)
    write(label .. ": ")
    setText(COLORS.text)

    local amount = tonumber(read())

    if not amount
        or amount ~= math.floor(amount)
        or amount < 1
        or amount > config.MAX_TRANSACTION then
        setText(COLORS.error)
        print("Enter a whole number from 1 to " .. config.MAX_TRANSACTION .. ".")
        setText(COLORS.text)
        return nil
    end

    return amount
end

local function getBalance(username)
    return sendRequest({
        action = "balance",
        requestId = requestId(),
        username = username
    })
end

local function showBalance(username)
    drawHeader("ACCOUNT BALANCE")
    print()
    print("Account: " .. username)
    print()

    local response = getBalance(username)

    if response.ok then
        setText(COLORS.success)
        center(8, tostring(response.data.balance) .. " " .. config.CURRENCY_NAME)
        setText(COLORS.text)
    else
        setText(COLORS.error)
        print("Error: " .. tostring(response.message))
        setText(COLORS.text)
    end

    pause()
end

local function deposit(username)
    drawHeader("DEPOSIT DIAMONDS")
    print()
    print("Account: " .. username)

    local amount = readAmount("Deposit amount")
    if not amount then
        pause()
        return
    end

    print()
    setText(COLORS.muted)
    print("Moving diamonds into the vault...")
    setText(COLORS.text)

    local moved = moveFromPlayer(amount)

    if moved <= 0 then
        setText(COLORS.error)
        print()
        print("VAULT ERROR")
        setText(COLORS.text)
        print("No diamonds could be moved.")
        print("Check that:")
        print("- Diamonds are in your inventory")
        print("- A supported chest is connected")
        print("- The vault direction is correct")
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

    print()

    if response.ok then
        setText(COLORS.success)
        print("DEPOSIT COMPLETE")
        setText(COLORS.text)
        print("Deposited:   " .. moved)
        print("New balance: " .. response.data.balance)

        if moved < amount then
            setText(COLORS.warning)
            print("Only " .. moved .. " of " .. amount .. " diamonds were accepted.")
            setText(COLORS.text)
        end
    else
        setText(COLORS.error)
        print("RECOVERY REQUIRED")
        setText(COLORS.text)
        print(moved .. " diamonds entered the vault,")
        print("but the account was not credited.")
        print("Recovery ID: " .. id)
        print("Reason: " .. tostring(response.message))
    end

    pause()
end

local function withdraw(username)
    drawHeader("WITHDRAW DIAMONDS")
    print()
    print("Account: " .. username)

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
        print()
        setText(COLORS.error)
        print("WITHDRAWAL DENIED")
        setText(COLORS.text)
        print(tostring(prepared.message))
        pause()
        return
    end

    print()
    setText(COLORS.muted)
    print("Moving diamonds from the vault...")
    setText(COLORS.text)

    local moved = moveToPlayer(amount)

    local committed = sendRequest({
        action = "withdraw_commit",
        requestId = id,
        username = username,
        amount = moved
    })

    print()

    if committed.ok then
        setText(COLORS.success)
        print("WITHDRAWAL COMPLETE")
        setText(COLORS.text)
        print("Withdrawn:   " .. moved)
        print("New balance: " .. committed.data.balance)

        if moved < amount then
            setText(COLORS.warning)
            print("Only part of the request could be delivered.")
            setText(COLORS.text)
            print("Check vault stock and inventory space.")
        end
    else
        setText(COLORS.error)
        print("CRITICAL TRANSACTION ERROR")
        setText(COLORS.text)
        print("Diamonds moved, but the account update failed.")
        print("Recovery ID: " .. id)
        print("Reason: " .. tostring(committed.message))
    end

    pause()
end

local function drawMenu(username)
    drawHeader("SECURE BANKING TERMINAL")

    setText(COLORS.muted)
    print("Card owner:")
    setText(COLORS.text)
    print(username)
    print()

    local response = getBalance(username)
    if response.ok then
        setText(COLORS.muted)
        print("Available balance:")
        setText(COLORS.success)
        print(tostring(response.data.balance) .. " " .. config.CURRENCY_NAME)
    else
        setText(COLORS.warning)
        print("Balance unavailable")
    end

    setText(COLORS.text)
    print()
    line(select(2, term.getCursorPos()), "-")
    print()
    print("1  Check balance")
    print("2  Deposit diamonds")
    print("3  Withdraw diamonds")
    print("4  Refresh card")
    print("5  Exit")
    print()
    setText(COLORS.title)
    write("Select an option: ")
    setText(COLORS.text)
end

math.randomseed(os.epoch("utc"))

while true do
    local username = getUsername()

    if not username then
        drawHeader("CARD REQUIRED")
        print()
        setText(COLORS.warning)
        center(6, "INSERT BOUND MEMORY CARD")
        setText(COLORS.text)
        center(8, "Place the card in the")
        center(9, "Inventory Manager.")
        setText(COLORS.muted)
        center(11, "The card owner must be online.")
        setText(COLORS.text)
        sleep(2)
    else
        drawMenu(username)
        local choice = read()

        if choice == "1" then
            showBalance(username)
        elseif choice == "2" then
            deposit(username)
        elseif choice == "3" then
            withdraw(username)
        elseif choice == "4" then
            -- Main loop refreshes the card and balance.
        elseif choice == "5" then
            clear()
            setText(COLORS.title)
            center(math.floor(height / 2), "Thank you for banking with ATM-10.")
            setText(COLORS.text)
            sleep(1)
            clear()
            return
        else
            setText(COLORS.error)
            print("Invalid selection.")
            setText(COLORS.text)
            sleep(1)
        end
    end
end
