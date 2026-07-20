local config = require("shared.config")

return {
    NAME = config.PROTOCOL,
    ACTIONS = {
        BALANCE = "balance",
        DEPOSIT = "deposit",
        WITHDRAW_PREPARE = "withdraw_prepare",
        WITHDRAW_COMMIT = "withdraw_commit",
        WITHDRAW_CANCEL = "withdraw_cancel"
    }
}
