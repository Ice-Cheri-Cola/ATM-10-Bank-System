-- ATM entrypoint.
-- Uses the Advanced Monitor touchscreen interface when available,
-- and falls back to the keyboard terminal interface otherwise.

if peripheral.find("monitor") then
    shell.run("atm/touchscreen.lua")
else
    shell.run("bank_atm.lua")
end
