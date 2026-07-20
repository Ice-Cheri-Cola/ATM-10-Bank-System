term.clear()
term.setCursorPos(1, 1)

print("ATM Deposit Diagnostic")
print("Computer ID: " .. os.getComputerID())
print()

local okConfig, config = pcall(require, "config")
if okConfig then
    print("Configured vault:")
    print("  new API: " .. tostring(config.ATM_VAULT_NAME))
    print("  old API: " .. tostring(config.ATM_VAULT_DIRECTION))
    print("  currency: " .. tostring(config.CURRENCY_ITEM))
else
    print("Could not load config.lua")
end
print()

local manager = peripheral.find("inventory_manager")
    or peripheral.find("inventoryManager")

if not manager then
    print("Inventory Manager: NOT FOUND")
    return
end

print("Inventory Manager: FOUND")
print("Peripheral name: " .. tostring(peripheral.getName(manager)))

local first, second = manager.getOwner()
local owner = second or first
print("Card owner: " .. tostring(owner))
print("New exportItem: " .. tostring(manager.exportItem ~= nil))
print("Old remove method: " .. tostring(manager.removeItemFromPlayer ~= nil))
print()

local items
if manager.list then
    items = manager.list()
elseif manager.getItems then
    items = manager.getItems()
end

local diamonds = 0
if type(items) == "table" then
    for _, item in pairs(items) do
        if type(item) == "table" and item.name == "minecraft:diamond" then
            diamonds = diamonds + (item.count or 0)
        end
    end
    print("Diamonds visible in player inventory: " .. diamonds)
else
    print("Could not read player inventory.")
end

print()
print("Connected peripherals:")
for _, name in ipairs(peripheral.getNames()) do
    local types = { peripheral.getType(name) }
    print("- " .. name .. " [" .. table.concat(types, ", ") .. "]")
end

print()
if diamonds == 0 then
    print("RESULT: The manager cannot see any diamonds")
    print("in the bound player's main inventory.")
elseif okConfig and config.ATM_VAULT_NAME ~= "@back" then
    print("RESULT: Diamonds are visible, but config")
    print("is not currently set to @back.")
else
    print("RESULT: Diamonds and config look correct.")
    print("The next likely issue is chest direction")
    print("or the Ender Chest item-handler connection.")
end
