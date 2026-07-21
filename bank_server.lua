local config = require("config")

local modem = peripheral.find("modem")
if not modem then
    error("No modem connected to the bank server.")
end

local modemName = peripheral.getName(modem)
rednet.open(modemName)

local state = {
    accounts = {},
    history = {},
    processed = {},
    reservations = {}
}

local function now()
    return os.epoch("utc")
end

local function save()
    local handle = fs.open(config.DATA_FILE, "w")
    if not handle then
        error("Could not save " .. config.DATA_FILE)
    end

    handle.write(textutils.serialize(state))
    handle.close()
end

local function load()
    if not fs.exists(config.DATA_FILE) then
        save()
        return
    end

    local handle = fs.open(config.DATA_FILE, "r")
    if not handle then
        error("Could not read " .. config.DATA_FILE)
    end

    local decoded = textutils.unserialize(handle.readAll())
    handle.close()

    if type(decoded) == "table" then
        state.accounts = decoded.accounts or {}
        state.history = decoded.history or {}
        state.processed = decoded.processed or {}
        state.reservations = decoded.reservations or {}
    end
end

local function getAccount(username)
    if not state.accounts[username] then
        state.accounts[username] = {
            balance = 0,
            frozen = false,
            createdAt = now()
        }
        save()
    end

    return state.accounts[username]
end

local function addHistory(username, kind, amount, balance, requestId, counterparty, description)
    table.insert(state.history, {
        username = username,
        kind = kind,
        amount = amount,
        balance = balance,
        requestId = requestId,
        counterparty = counterparty,
        description = description,
        timestamp = now()
    })

    while #state.history > config.HISTORY_LIMIT do
        table.remove(state.history, 1)
    end
end

local function getHistory(username, limit)
    limit = math.max(1, math.min(math.floor(tonumber(limit) or 5), 20))
    local result = {}

    for i = #state.history, 1, -1 do
        local entry = state.history[i]
        if entry.username == username then
            result[#result + 1] = {
                kind = entry.kind,
                amount = entry.amount,
                balance = entry.balance,
                counterparty = entry.counterparty,
                description = entry.description,
                timestamp = entry.timestamp
            }

            if #result >= limit then break end
        end
    end

    return result
end

local function listAccounts(excludeUsername)
    local names = {}

    for username in pairs(state.accounts) do
        if username ~= excludeUsername then
            names[#names + 1] = username
        end
    end

    table.sort(names, function(a, b)
        return string.lower(a) < string.lower(b)
    end)

    return names
end

local function cleanupReservations()
    local cutoff = now() - (config.WITHDRAW_RESERVATION_SECONDS * 1000)

    for requestId, reservation in pairs(state.reservations) do
        if reservation.createdAt < cutoff then
            state.reservations[requestId] = nil
        end
    end
end

local function reservedFor(username)
    local total = 0

    for _, reservation in pairs(state.reservations) do
        if reservation.username == username then
            total = total + reservation.amount
        end
    end

    return total
end

local function validAmount(amount)
    return type(amount) == "number"
        and amount == math.floor(amount)
        and amount > 0
        and amount <= config.MAX_TRANSACTION
end

local function cleanDescription(value)
    if type(value) ~= "string" then return nil end
    value = value:gsub("[%c]", " "):sub(1, 40)
    if value == "" then return nil end
    return value
end

local function reply(senderId, requestId, ok, data, message)
    rednet.send(senderId, {
        requestId = requestId,
        ok = ok,
        data = data,
        message = message
    }, config.PROTOCOL)
end

local function process(senderId, message)
    if type(message) ~= "table" then
        return
    end

    local action = message.action
    local requestId = tostring(message.requestId or "")
    local username = tostring(message.username or "")

    if requestId == "" or username == "" then
        reply(senderId, requestId, false, nil, "Invalid request.")
        return
    end

    cleanupReservations()

    local account = getAccount(username)

    if action == "balance" then
        reply(senderId, requestId, true, {
            balance = account.balance,
            frozen = account.frozen
        })
        return
    end

    if action == "history" then
        reply(senderId, requestId, true, {
            entries = getHistory(username, message.limit)
        }, "History loaded.")
        return
    end

    if action == "list_accounts" then
        reply(senderId, requestId, true, {
            accounts = listAccounts(username)
        }, "Account directory loaded.")
        return
    end

    if account.frozen then
        reply(senderId, requestId, false, nil, "This bank account is frozen.")
        return
    end

    if action == "deposit" then
        local amount = tonumber(message.amount)

        if not validAmount(amount) then
            reply(senderId, requestId, false, nil, "Invalid deposit amount.")
            return
        end

        if state.processed[requestId] then
            reply(senderId, requestId, true, state.processed[requestId], "Already processed.")
            return
        end

        account.balance = account.balance + amount
        local result = { balance = account.balance, amount = amount }

        state.processed[requestId] = result
        addHistory(username, "deposit", amount, account.balance, requestId)
        save()

        reply(senderId, requestId, true, result, "Deposit completed.")
        return
    end

    if action == "transfer" then
        local amount = tonumber(message.amount)
        local recipientName = tostring(message.recipient or "")
        local description = cleanDescription(message.description)

        if not validAmount(amount) then
            reply(senderId, requestId, false, nil, "Invalid transfer amount.")
            return
        end

        if recipientName == "" then
            reply(senderId, requestId, false, nil, "Choose a recipient.")
            return
        end

        if recipientName == username then
            reply(senderId, requestId, false, nil, "You cannot transfer money to yourself.")
            return
        end

        local recipient = state.accounts[recipientName]
        if not recipient then
            reply(senderId, requestId, false, nil, "Recipient account was not found.")
            return
        end

        if recipient.frozen then
            reply(senderId, requestId, false, nil, "Recipient account is frozen.")
            return
        end

        if state.processed[requestId] then
            reply(senderId, requestId, true, state.processed[requestId], "Already processed.")
            return
        end

        local available = account.balance - reservedFor(username)
        if amount > available then
            reply(senderId, requestId, false, {
                balance = account.balance,
                available = available
            }, "Insufficient funds.")
            return
        end

        account.balance = account.balance - amount
        recipient.balance = recipient.balance + amount

        local result = {
            balance = account.balance,
            amount = amount,
            recipient = recipientName,
            recipientBalance = recipient.balance
        }

        state.processed[requestId] = result
        addHistory(username, "transfer_out", amount, account.balance, requestId, recipientName, description)
        addHistory(recipientName, "transfer_in", amount, recipient.balance, requestId, username, description)
        save()

        reply(senderId, requestId, true, result, "Transfer completed.")
        return
    end

    if action == "withdraw_prepare" then
        local amount = tonumber(message.amount)

        if not validAmount(amount) then
            reply(senderId, requestId, false, nil, "Invalid withdrawal amount.")
            return
        end

        if state.processed[requestId] then
            reply(senderId, requestId, false, nil, "Request ID was already used.")
            return
        end

        local available = account.balance - reservedFor(username)

        if amount > available then
            reply(senderId, requestId, false, {
                balance = account.balance,
                available = available
            }, "Insufficient funds.")
            return
        end

        state.reservations[requestId] = {
            username = username,
            amount = amount,
            createdAt = now()
        }
        save()

        reply(senderId, requestId, true, {
            approved = amount,
            balance = account.balance
        }, "Withdrawal approved.")
        return
    end

    if action == "withdraw_commit" then
        local reservation = state.reservations[requestId]
        local moved = tonumber(message.amount) or 0

        if not reservation or reservation.username ~= username then
            reply(senderId, requestId, false, nil, "Withdrawal reservation expired or was not found.")
            return
        end

        moved = math.max(0, math.min(math.floor(moved), reservation.amount))

        if moved > account.balance then
            moved = account.balance
        end

        account.balance = account.balance - moved
        state.reservations[requestId] = nil

        local result = {
            balance = account.balance,
            amount = moved
        }

        state.processed[requestId] = result
        addHistory(username, "withdrawal", moved, account.balance, requestId)
        save()

        reply(senderId, requestId, true, result, "Withdrawal completed.")
        return
    end

    if action == "withdraw_cancel" then
        state.reservations[requestId] = nil
        save()
        reply(senderId, requestId, true, nil, "Withdrawal cancelled.")
        return
    end

    reply(senderId, requestId, false, nil, "Unknown action.")
end

load()

term.clear()
term.setCursorPos(1, 1)
print("ATM10 Bank Server")
print("Computer ID: " .. os.getComputerID())
print("Protocol: " .. config.PROTOCOL)
print("Waiting for ATM requests...")

while true do
    local senderId, message = rednet.receive(config.PROTOCOL)
    local ok, err = pcall(process, senderId, message)

    if not ok then
        print("Request error: " .. tostring(err))
    end
end