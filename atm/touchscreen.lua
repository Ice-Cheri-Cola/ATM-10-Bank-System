local config = require("config")

if config.BANK_SERVER_ID == 0 then
    error("Set BANK_SERVER_ID in config.lua before running the ATM.")
end

local monitor = peripheral.find("monitor")
if not monitor then
    error("No Advanced Monitor connected.")
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

local speaker = peripheral.find("speaker")
rednet.open(peripheral.getName(modem))
monitor.setTextScale(0.5)

local W, H = monitor.getSize()
local buttons = {}
local currentScreen = "menu"
local currentUsername = nil
local currentBalance = nil
local statusText = nil
local statusColor = colors.white

local THEME = {
    background = colors.black,
    panel = colors.gray,
    header = colors.blue,
    accent = colors.cyan,
    text = colors.white,
    muted = colors.lightGray,
    success = colors.lime,
    warning = colors.yellow,
    error = colors.red,
    deposit = colors.green,
    withdraw = colors.orange,
    button = colors.blue,
    buttonText = colors.white
}

local function sound(kind)
    if not speaker then return end
    if kind == "success" then
        speaker.playNote("bell", 1, 14)
    elseif kind == "error" then
        speaker.playNote("bass", 1, 4)
    elseif kind == "touch" then
        speaker.playNote("hat", 0.4, 12)
    end
end

local function fill(x1, y1, x2, y2, bg)
    monitor.setBackgroundColor(bg)
    local width = math.max(0, x2 - x1 + 1)
    for y = y1, y2 do
        monitor.setCursorPos(x1, y)
        monitor.write(string.rep(" ", width))
    end
end

local function writeAt(x, y, text, fg, bg)
    if bg then monitor.setBackgroundColor(bg) end
    monitor.setTextColor(fg or THEME.text)
    monitor.setCursorPos(x, y)
    monitor.write(tostring(text or ""))
end

local function center(y, text, fg, bg)
    text = tostring(text or "")
    local x = math.floor((W - #text) / 2) + 1
    writeAt(math.max(1, x), y, text, fg, bg)
end

local function clearButtons()
    buttons = {}
end

local function addButton(id, label, x1, y1, x2, y2, bg, fg)
    fill(x1, y1, x2, y2, bg or THEME.button)
    local y = math.floor((y1 + y2) / 2)
    local x = math.floor((x1 + x2 - #label) / 2) + 1
    writeAt(x, y, label, fg or THEME.buttonText, bg or THEME.button)
    buttons[#buttons + 1] = {
        id = id,
        x1 = x1,
        y1 = y1,
        x2 = x2,
        y2 = y2
    }
end

local function hitButton(x, y)
    for _, button in ipairs(buttons) do
        if x >= button.x1 and x <= button.x2
            and y >= button.y1 and y <= button.y2 then
            return button.id
        end
    end
    return nil
end

local function requestId()
    return tostring(os.getComputerID())
        .. "-" .. tostring(os.epoch("utc"))
        .. "-" .. tostring(math.random(100000, 999999))
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
            if a == config.BANK_SERVER_ID
                and c == config.PROTOCOL
                and type(b) == "table"
                and b.requestId == message.requestId then
                return b
            end
        elseif event == "timer" and a == timer then
            return {ok = false, message = "Bank server did not respond."}
        end
    end
end

local function getBalance(username)
    return sendRequest({
        action = "balance",
        requestId = requestId(),
        username = username
    })
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

local function drawFrame(subtitle)
    monitor.setBackgroundColor(THEME.background)
    monitor.setTextColor(THEME.text)
    monitor.clear()
    clearButtons()

    fill(1, 1, W, 3, THEME.header)
    center(2, "ATM-10 DIAMOND BANK", THEME.text, THEME.header)
    center(4, subtitle or "SECURE TOUCH TERMINAL", THEME.muted, THEME.background)
end

local function drawCardRequired()
    currentScreen = "card"
    drawFrame("CARD REQUIRED")
    center(math.floor(H / 2) - 2, "INSERT BOUND MEMORY CARD", THEME.warning)
    center(math.floor(H / 2), "Place the card in the Inventory Manager.", THEME.text)
    center(math.floor(H / 2) + 2, "The card owner must be online.", THEME.muted)
end

local function refreshBalance()
    if not currentUsername then
        currentBalance = nil
        return false
    end

    local response = getBalance(currentUsername)
    if response.ok then
        currentBalance = response.data.balance
        return true
    end

    currentBalance = nil
    statusText = tostring(response.message)
    statusColor = THEME.error
    return false
end

local function drawMenu()
    currentScreen = "menu"
    drawFrame("SECURE TOUCH TERMINAL")

    writeAt(3, 6, "WELCOME", THEME.muted)
    writeAt(3, 7, currentUsername or "Unknown", THEME.text)

    local balanceText = currentBalance and tostring(currentBalance) or "Unavailable"
    center(10, "AVAILABLE BALANCE", THEME.muted)
    center(12, balanceText .. " " .. config.CURRENCY_NAME, currentBalance and THEME.success or THEME.warning)

    local margin = 3
    local gap = 2
    local buttonWidth = math.floor((W - margin * 2 - gap) / 2)
    local leftX1 = margin
    local leftX2 = leftX1 + buttonWidth - 1
    local rightX1 = leftX2 + gap + 1
    local rightX2 = W - margin
    local topY = math.max(15, math.floor(H / 2))

    addButton("deposit", "DEPOSIT", leftX1, topY, leftX2, topY + 3, THEME.deposit)
    addButton("withdraw", "WITHDRAW", rightX1, topY, rightX2, topY + 3, THEME.withdraw, colors.black)
    addButton("refresh", "REFRESH", leftX1, topY + 5, leftX2, topY + 8, THEME.button)
    addButton("exit", "EXIT", rightX1, topY + 5, rightX2, topY + 8, colors.red)

    if statusText then
        center(H - 1, statusText, statusColor)
    else
        center(H - 1, "Touch an option to continue", THEME.muted)
    end
end

local function drawMessage(title, message, color)
    currentScreen = "message"
    drawFrame(title)

    local lines = {}
    for line in tostring(message):gmatch("[^\n]+") do
        lines[#lines + 1] = line
    end

    local startY = math.max(7, math.floor(H / 2) - math.floor(#lines / 2) - 2)
    for i, line in ipairs(lines) do
        center(startY + i - 1, line, color or THEME.text)
    end

    addButton("back", "BACK TO MENU", 4, H - 5, W - 3, H - 2, THEME.button)
end

local function amountKeypad(mode)
    currentScreen = "keypad"
    local amountText = ""
    local title = mode == "deposit" and "DEPOSIT DIAMONDS" or "WITHDRAW DIAMONDS"

    local function draw()
        drawFrame(title)
        center(6, "ENTER AMOUNT", THEME.muted)
        fill(4, 8, W - 3, 11, THEME.panel)
        center(9, amountText == "" and "0" or amountText, THEME.text, THEME.panel)

        local keypadWidth = math.min(27, W - 6)
        local keyWidth = math.floor((keypadWidth - 2) / 3)
        local startX = math.floor((W - (keyWidth * 3 + 2)) / 2) + 1
        local startY = 13
        local keys = {
            {"1", "1"}, {"2", "2"}, {"3", "3"},
            {"4", "4"}, {"5", "5"}, {"6", "6"},
            {"7", "7"}, {"8", "8"}, {"9", "9"},
            {"clear", "CLEAR"}, {"0", "0"}, {"go", "ENTER"}
        }

        for i, key in ipairs(keys) do
            local row = math.floor((i - 1) / 3)
            local col = (i - 1) % 3
            local x1 = startX + col * (keyWidth + 1)
            local y1 = startY + row * 3
            local bg = THEME.button
            if key[1] == "clear" then bg = colors.red end
            if key[1] == "go" then bg = colors.green end
            addButton(key[1], key[2], x1, y1, x1 + keyWidth - 1, y1 + 1, bg)
        end

        addButton("cancel", "CANCEL", 4, H - 3, W - 3, H - 1, colors.gray)
    end

    draw()

    while true do
        local event, side, x, y = os.pullEvent()
        if event == "monitor_touch" then
            local id = hitButton(x, y)
            if id then sound("touch") end

            if tonumber(id) then
                if #amountText < 6 then
                    amountText = amountText .. id
                    draw()
                end
            elseif id == "clear" then
                amountText = ""
                draw()
            elseif id == "cancel" then
                return nil
            elseif id == "go" then
                local amount = tonumber(amountText)
                if amount and amount >= 1 and amount <= config.MAX_TRANSACTION then
                    return math.floor(amount)
                end
                statusText = "Enter 1 to " .. config.MAX_TRANSACTION
                statusColor = THEME.error
                sound("error")
                draw()
                center(12, statusText, THEME.error)
            end
        end
    end
end

local function doDeposit()
    local amount = amountKeypad("deposit")
    if not amount then return end

    drawFrame("DEPOSIT IN PROGRESS")
    center(math.floor(H / 2), "Moving diamonds into the vault...", THEME.warning)

    local moved = moveFromPlayer(amount)
    if moved <= 0 then
        sound("error")
        drawMessage("DEPOSIT FAILED",
            "No diamonds could be moved.\nCheck your inventory and vault connection.",
            THEME.error)
        return
    end

    local id = requestId()
    local response = sendRequest({
        action = "deposit",
        requestId = id,
        username = currentUsername,
        amount = moved
    })

    if response.ok then
        currentBalance = response.data.balance
        sound("success")
        local note = "Deposited " .. moved .. " diamonds.\nNew balance: " .. currentBalance
        if moved < amount then
            note = note .. "\nOnly part of the requested amount was accepted."
        end
        drawMessage("DEPOSIT COMPLETE", note, THEME.success)
    else
        sound("error")
        drawMessage("RECOVERY REQUIRED",
            moved .. " diamonds entered the vault,\nbut the account was not credited.\nRecovery ID: " .. id,
            THEME.error)
    end
end

local function doWithdraw()
    local amount = amountKeypad("withdraw")
    if not amount then return end

    drawFrame("VERIFYING WITHDRAWAL")
    center(math.floor(H / 2), "Contacting bank server...", THEME.warning)

    local id = requestId()
    local prepared = sendRequest({
        action = "withdraw_prepare",
        requestId = id,
        username = currentUsername,
        amount = amount
    })

    if not prepared.ok then
        sound("error")
        drawMessage("WITHDRAWAL DENIED", tostring(prepared.message), THEME.error)
        return
    end

    drawFrame("WITHDRAWAL IN PROGRESS")
    center(math.floor(H / 2), "Moving diamonds from the vault...", THEME.warning)
    local moved = moveToPlayer(amount)

    local committed = sendRequest({
        action = "withdraw_commit",
        requestId = id,
        username = currentUsername,
        amount = moved
    })

    if committed.ok then
        currentBalance = committed.data.balance
        sound("success")
        local note = "Withdrawn " .. moved .. " diamonds.\nNew balance: " .. currentBalance
        if moved < amount then
            note = note .. "\nVault stock or inventory space limited delivery."
        end
        drawMessage("WITHDRAWAL COMPLETE", note, THEME.success)
    else
        sound("error")
        drawMessage("TRANSACTION ERROR",
            "Diamonds moved, but account update failed.\nRecovery ID: " .. id,
            THEME.error)
    end
end

math.randomseed(os.epoch("utc"))

while true do
    local username = getUsername()

    if not username then
        currentUsername = nil
        currentBalance = nil
        drawCardRequired()
        local timer = os.startTimer(2)
        while true do
            local event, a = os.pullEvent()
            if event == "timer" and a == timer then break end
        end
    else
        if username ~= currentUsername then
            currentUsername = username
            statusText = nil
            refreshBalance()
        end

        drawMenu()
        local event, side, x, y = os.pullEvent()

        if event == "monitor_touch" then
            local id = hitButton(x, y)
            if id then sound("touch") end

            if id == "deposit" then
                doDeposit()
            elseif id == "withdraw" then
                doWithdraw()
            elseif id == "refresh" then
                statusText = "Refreshing account..."
                statusColor = THEME.warning
                drawMenu()
                if refreshBalance() then
                    statusText = "Account refreshed"
                    statusColor = THEME.success
                    sound("success")
                else
                    sound("error")
                end
            elseif id == "exit" then
                drawFrame("SESSION ENDED")
                center(math.floor(H / 2), "Thank you for banking with ATM-10.", THEME.success)
                sleep(2)
                currentUsername = nil
                currentBalance = nil
            end
        end
    end
end
