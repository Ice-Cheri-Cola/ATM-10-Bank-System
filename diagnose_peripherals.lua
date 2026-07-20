term.clear()
term.setCursorPos(1, 1)

print("ATM Peripheral Diagnostic")
print("Computer ID: " .. os.getComputerID())
print()

local names = peripheral.getNames()

if #names == 0 then
    print("No peripherals detected.")
    return
end

for _, name in ipairs(names) do
    local types = { peripheral.getType(name) }
    print(name)
    print("  type: " .. table.concat(types, ", "))

    local wrapped = peripheral.wrap(name)
    if wrapped and wrapped.getOwner then
        print("  getOwner: yes")
    end
    if wrapped and (wrapped.exportItem or wrapped.removeItemFromPlayer) then
        print("  deposit method: yes")
    end
    if wrapped and (wrapped.importItem or wrapped.addItemToPlayer) then
        print("  withdrawal method: yes")
    end
end
