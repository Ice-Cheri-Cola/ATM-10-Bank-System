return {
    PROTOCOL = "atm10_bank_v1",

    -- Central bank server computer ID.
    BANK_SERVER_ID = 20,

    CURRENCY_ITEM = "minecraft:diamond",
    CURRENCY_NAME = "Diamonds",

    -- Advanced Peripherals 0.8-style relative inventory name.
    ATM_VAULT_NAME = "@back",

    -- Advanced Peripherals 0.7-style direction.
    ATM_VAULT_DIRECTION = "back",

    REQUEST_TIMEOUT = 5,
    WITHDRAW_RESERVATION_SECONDS = 30,
    MAX_TRANSACTION = 4096,

    DATA_FILE = "bank_accounts.db",
    HISTORY_LIMIT = 1000
}
