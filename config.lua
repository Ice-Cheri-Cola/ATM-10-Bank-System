return {
    PROTOCOL = "atm10_bank_v1",

    -- Set this on every ATM to the computer ID of bank_server.lua.
    BANK_SERVER_ID = 0,

    CURRENCY_ITEM = "minecraft:diamond",
    CURRENCY_NAME = "Diamonds",

    -- Advanced Peripherals 0.8-style relative inventory name.
    ATM_VAULT_NAME = "@up",

    -- Advanced Peripherals 0.7-style direction.
    ATM_VAULT_DIRECTION = "up",

    REQUEST_TIMEOUT = 5,
    WITHDRAW_RESERVATION_SECONDS = 30,
    MAX_TRANSACTION = 4096,

    DATA_FILE = "bank_accounts.db",
    HISTORY_LIMIT = 1000
}
