-- ATM-local configuration shim.
-- Programs inside /atm resolve require("config") relative to this folder,
-- so load the preserved root configuration explicitly.
if not fs.exists("/config.lua") then
    error("Missing /config.lua. Run the ATM installer first.")
end

return dofile("/config.lua")
