local config = require("config")

if config.BANK_SERVER_ID == 0 then
    error("Set BANK_SERVER_ID in config.lua before running the ATM.")
end

local monitor = peripheral.find("monitor")
if not monitor then error("No Advanced Monitor connected.") end

local modem = peripheral.find("modem")
if not modem then error("No modem connected to this ATM.") end

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
local currentUsername = nil
local currentBalance = nil
local statusText = nil
local statusColor = colors.white

local THEME = {
    background = colors.black,
    header = colors.blue,
    panel = colors.gray,
    text = colors.white,
    muted = colors.lightGray,
    success = colors.lime,
    warning = colors.yellow,
    error = colors.red,
    deposit = colors.green,
    withdraw = colors.orange,
    button = colors.blue
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
    x1 = math.max(1, x1)
    y1 = math.max(1, y1)
    x2 = math.min(W, x2)
    y2 = math.min(H, y2)
    if x2 < x1 or y2 < y1 then return end

    monitor.setBackgroundColor(bg)
    local width = x2 - x1 + 1
    for y = y1, y2 do
        monitor.setCursorPos(x1, y)
        monitor.write(string.rep(" ", width))
    end
end

local function writeAt(x, y, text, fg, bg)
    text = tostring(text or "")
    if y < 1 or y > H or x > W then return end
    x = math.max(1, x)
    if #text > W - x + 1 then
        text = text:sub(1, W - x + 1)
    end
    if bg then monitor.setBackgroundColor(bg) end
    monitor.setTextColor(fg or THEME.text)
    monitor.setCursorPos(x, y)
    monitor.write(text)
end

local function center(y, text, fg, bg)
    text = tostring(text or "")
    if #text > W then text = text:sub(1, W) end
    local x = math.floor((W - #text) / 2) + 1
    writeAt(x, y, text, fg, bg)
end

local function clearButtons()
    buttons = {}
end

local function addButton(id, label, x1, y1, x2, y2, bg, fg)
    fill(x1, y1, x2, y2, bg or THEME.button)
    local y = math.floor((y1 + y2) / 2)
    local x = math.floor((x1 + x2 - #label) / 2) + 1
    writeAt(x, y, label, fg or THEME.text, bg or THEME.button)
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
end

local function requestId()
    return tostring(os.getComputerID()) .. "-"
        .. tostring(os.epoch("utc")) .. "-"
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
            if a == config.BANK_SERVER_ID
                and c == config.PROTOCOL
                and type(b) == "table"
                and b.requestId == message.requestId then
                return b
            end
        elseif event == "timer" and a == timer then
            return {ok = false, message = "Bank server timeout"}
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

    error("No supported deposit method.")
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

    error("No supported withdrawal method.")
end

local function drawFrame(title)
    monitor.setBackgroundColor(THEME.background)
    monitor.setTextColor(THEME.text)
    monitor.clear()
    clearButtons()

    fill(1, 1, W, 2, THEME.header)
    center(1, "ATM-10 BANK", THEME.text, THEME.header)
    center(2, title or "TOUCH ATM", THEME.text, THEME.header)
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

local function drawCardRequired()
    drawFrame("CARD REQUIRED")
    center(5, "INSERT CARD", THEME.warning)
    center(7, "IN INV MANAGER", THEME.text)
end

local function drawMenu()
    drawFrame("TOUCH ATM")

    center(3, currentUsername or "Unknown", THEME.text)
    center(4, "BAL: " .. tostring(currentBalance or 0),
        currentBalance and THEME.success or THEME.warning)

    addButton("deposit", "DEPOSIT", 1, 6, W, 6, THEME.deposit)
    addButton("withdraw", "WITHDRAW", 1, 7, W, 7, THEME.withdraw, colors.black)
    addButton("refresh", "REFRESH", 1, 8, W, 8, THEME.button)
    addButton("exit", "EXIT", 1, 9, W, 9, THEME.error)

    if statusText then
        center(10, statusText, statusColor)
    else
        center(10, "SELECT OPTION", THEME.muted)
    end
end

local function drawMessage(title, lines, color)
    drawFrame(title)
    local list = {}
    for line in tostring(lines):gmatch("[^\n]+") do
        list[#list + 1] = line
    end

    local startY = 4
    for i, line in ipairs(list) do
        if startY + i - 1 <= 8 then
            center(startY + i - 1, line, color or THEME.text)
        end
    end

    addButton("back", "BACK", 1, 10, W, 10, THEME.button)
end

local function amountKeypad(mode)
    local amountText = ""
    local title = mode == "deposit" and "DEPOSIT" or "WITHDRAW"

    local function draw()
        drawFrame(title)
        center(3, "AMT: " .. (amountText == "" and "0" or amountText), THEME.success)

        local keys = {
            {"1", "1"}, {"2", "2"}, {"3", "3"},
            {"4", "4"}, {"5", "5"}, {"6", "6"},
            {"7", "7"}, {"8", "8"}, {"9", "9"},
            {"clear", "CLR"}, {"0", "0"}, {"go", "OK"}
        }

        for i, key in ipairs(keys) do
            local row = math.floor((i - 1) / 3)
            local col = (i - 1) % 3
            local x1 = col * 5 + 1
            local x2 = math.min(W, x1 + 4)
            local y = 4 + row
            local bg = THEME.button
            if key[1] == "clear" then bg = THEME.error end
            if key[1] == "go" then bg = THEME.deposit end
            addButton(key[1], key[2], x1, y, x2, y, bg)
        end

        addButton("cancel", "CANCEL", 1, 9, W, 10, THEME.panel)
    end

    draw()

    while true do
        local event, _, x, y = os.pullEvent()
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
                sound("error")
                center(8, "ENTER 1-" .. config.MAX_TRANSACTION, THEME.error)
            end
        end
    end
end

local function waitForBack()
    while true do
        local event, _, x, y = os.pullEvent()
        if event == "monitor_touch" and hitButton(x, y) == "back" then
            sound("touch")
            return
        end
    end
end

local function doDeposit()
    local amount = amountKeypad("deposit")
    if not amount then return end

    drawFrame("DEPOSITING")
    center(6, "MOVING ITEMS", THEME.warning)

    local moved = moveFromPlayer(amount)
    if moved <= 0 then
        sound("error")
        drawMessage("FAILED", "NO DIAMONDS\nCHECK VAULT", THEME.error)
        waitForBack()
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
        drawMessage("DEPOSIT OK", "+" .. moved .. " DIAMONDS\nBAL: " .. currentBalance, THEME.success)
    else
        sound("error")
        drawMessage("RECOVERY", moved .. " NOT CREDITED\nID SAVED", THEME.error)
    end
    waitForBack()
end

local function doWithdraw()
    local amount = amountKeypad("withdraw")
    if not amount then return end

    drawFrame("WITHDRAWING")
    center(6, "CONTACT SERVER", THEME.warning)

    local id = requestId()
    local prepared = sendRequest({
        action = "withdraw_prepare",
        requestId = id,
        username = currentUsername,
        amount = amount
    })

    if not prepared.ok then
        sound("error")
        drawMessage("DENIED", tostring(prepared.message), THEME.error)
        waitForBack()
        return
    end

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
        drawMessage("WITHDRAW OK", "-" .. moved .. " DIAMONDS\nBAL: " .. currentBalance, THEME.success)
    else
        sound("error")
        drawMessage("ERROR", "ITEMS MOVED\nID SAVED", THEME.error)
    end
    waitForBack()
end

math.randomseed(os.epoch("utc"))

while true do
    local username = getUsername()

    if not username then
        currentUsername = nil
        currentBalance = nil
        drawCardRequired()
        sleep(2)
    else
        if username ~= currentUsername then
            currentUsername = username
            statusText = nil
            refreshBalance()
        end

        drawMenu()
        local event, _, x, y = os.pullEvent()
        if event == "monitor_touch" then
            local id = hitButton(x, y)
            if id then sound("touch") end

            if id == "deposit" then
                doDeposit()
            elseif id == "withdraw" then
                doWithdraw()
            elseif id == "refresh" then
                statusText = "REFRESHING"
                statusColor = THEME.warning
                if refreshBalance() then
                    statusText = "REFRESHED"
                    statusColor = THEME.success
                    sound("success")
                else
                    sound("error")
                end
            elseif id == "exit" then
                drawFrame("SESSION END")
                center(6, "THANK YOU", THEME.success)
                sleep(2)
                currentUsername = nil
                currentBalance = nil
            end
        end
    end
end
