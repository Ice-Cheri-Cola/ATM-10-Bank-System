term.clear()
term.setCursorPos(1, 1)

print("ATM Vault Direction Test")
print("This will move exactly ONE diamond")
print("into the first adjacent inventory found.")
print()

local manager = peripheral.find("inventory_manager")
    or peripheral.find("inventoryManager")

if not manager then
    error("Inventory Manager not found.")
end

if not manager.removeItemFromPlayer then
    error("Old removeItemFromPlayer API not available.")
end

local owner = manager.getOwner()
if not owner then
    error("Insert a bound Memory Card and keep its owner online.")
end

local directions = {
    "front",
    "back",
    "left",
    "right",
    "top",
    "bottom",
    "north",
    "south",
    "east",
    "west",
    "up",
    "down"
}

for _, direction in ipairs(directions) do
    write("Testing " .. direction .. "... ")

    local ok, moved = pcall(
        manager.removeItemFromPlayer,
        direction,
        {
            name = "minecraft:diamond",
            count = 1
        }
    )

    if ok and type(moved) == "number" and moved > 0 then
        print("SUCCESS")
        print()
        print("Correct vault direction: " .. direction)
        print("One diamond was moved into the chest.")
        print()
        print("Set ATM_VAULT_DIRECTION to \"" .. direction .. "\"")
        print("and ATM_VAULT_NAME to \"@" .. direction .. "\"")
        return
    end

    if ok then
        print("no move")
    else
        print("not an inventory")
    end
end

print()
print("No adjacent inventory accepted the diamond.")
print("Check that the chest directly touches the Inventory Manager")
print("and that the chest exposes a normal item-handler connection.")
