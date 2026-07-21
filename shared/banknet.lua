local config = require("config")

local banknet = {}
local openedByBanknet = false

local function ensureOpen()
    if rednet.isOpen() then return true end

    local modem = peripheral.find("modem")
    if not modem then
        return false, "No modem connected."
    end

    rednet.open(peripheral.getName(modem))
    openedByBanknet = true
    return true
end

local function requestId()
    return tostring(os.getComputerID())
        .. "-" .. tostring(os.epoch("utc"))
        .. "-" .. tostring(math.random(100000, 999999))
end

local function validName(username)
    return type(username) == "string" and username ~= ""
end

local function validAmount(amount)
    return type(amount) == "number"
        and amount == math.floor(amount)
        and amount > 0
        and amount <= config.MAX_TRANSACTION
end

function banknet.request(action, username, fields)
    if type(action) ~= "string" or action == "" then
        return {ok = false, message = "Invalid bank action."}
    end

    if not validName(username) then
        return {ok = false, message = "Invalid username."}
    end

    local ok, err = ensureOpen()
    if not ok then
        return {ok = false, message = err}
    end

    local message = fields or {}
    message.action = action
    message.username = username
    message.requestId = message.requestId or requestId()

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

function banknet.getBalance(username)
    local response = banknet.request("balance", username)
    if response.ok and response.data then
        return response.data.balance, nil, response
    end
    return nil, response.message, response
end

function banknet.getHistory(username, limit)
    limit = math.max(1, math.min(math.floor(tonumber(limit) or 5), 20))
    local response = banknet.request("history", username, {limit = limit})
    if response.ok and response.data then
        return response.data.entries or {}, nil, response
    end
    return nil, response.message, response
end

function banknet.listAccounts(username)
    local response = banknet.request("list_accounts", username)
    if response.ok and response.data then
        return response.data.accounts or {}, nil, response
    end
    return nil, response.message, response
end

function banknet.transfer(fromUsername, toUsername, amount, description, requestIdOverride)
    if not validName(fromUsername) then
        return {ok = false, message = "Invalid sender username."}
    end

    if not validName(toUsername) then
        return {ok = false, message = "Invalid recipient username."}
    end

    if fromUsername == toUsername then
        return {ok = false, message = "You cannot transfer money to yourself."}
    end

    if not validAmount(amount) then
        return {ok = false, message = "Invalid transfer amount."}
    end

    return banknet.request("transfer", fromUsername, {
        recipient = toUsername,
        amount = amount,
        description = description,
        requestId = requestIdOverride
    })
end

function banknet.deposit(username, amount, requestIdOverride)
    if not validAmount(amount) then
        return {ok = false, message = "Invalid deposit amount."}
    end

    return banknet.request("deposit", username, {
        amount = amount,
        requestId = requestIdOverride
    })
end

function banknet.prepareWithdrawal(username, amount, requestIdOverride)
    if not validAmount(amount) then
        return {ok = false, message = "Invalid withdrawal amount."}
    end

    return banknet.request("withdraw_prepare", username, {
        amount = amount,
        requestId = requestIdOverride
    })
end

function banknet.commitWithdrawal(username, amountMoved, reservationId)
    if type(reservationId) ~= "string" or reservationId == "" then
        return {ok = false, message = "Missing withdrawal reservation ID."}
    end

    amountMoved = tonumber(amountMoved) or 0
    amountMoved = math.max(0, math.floor(amountMoved))

    return banknet.request("withdraw_commit", username, {
        amount = amountMoved,
        requestId = reservationId
    })
end

function banknet.cancelWithdrawal(username, reservationId)
    if type(reservationId) ~= "string" or reservationId == "" then
        return {ok = false, message = "Missing withdrawal reservation ID."}
    end

    return banknet.request("withdraw_cancel", username, {
        requestId = reservationId
    })
end

function banknet.newRequestId()
    return requestId()
end

function banknet.close()
    if openedByBanknet then
        local modem = peripheral.find("modem")
        if modem then rednet.close(peripheral.getName(modem)) end
        openedByBanknet = false
    end
end

math.randomseed(os.epoch("utc"))

return banknet