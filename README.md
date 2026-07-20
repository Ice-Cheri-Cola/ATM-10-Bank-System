# ATM10 Bank System

A central CC:Tweaked banking system for **All the Mods 10**, using physical diamonds as currency.

## First working version

- Advanced Peripherals **Memory Card** identifies the player.
- An **Inventory Manager** reads the card owner.
- Players deposit and withdraw `minecraft:diamond`.
- A central computer stores persistent account balances.
- ATMs communicate with the central server over Rednet.
- Withdrawal reservations reduce accidental double spending.
- The ATM supports both older and newer Inventory Manager transfer method names.

## Physical design

### Bank server

- Advanced Computer
- Wired or wireless modem

### ATM

- Advanced Computer
- Modem
- Advanced Peripherals Inventory Manager
- A shared vault inventory directly beside the Inventory Manager
- Bound Memory Cards for players
- Advanced Monitor is optional for this terminal-menu version

A shared inventory such as an **EnderStorage Ender Chest** is recommended. Use the same protected channel at every ATM and inside the main vault. This lets the diamonds physically enter and leave one shared vault inventory while account balances remain on the bank server.

## Placement

By default, the shared vault inventory should be **above the Inventory Manager**.

The defaults in `config.lua` are:

```lua
ATM_VAULT_NAME = "@up"
ATM_VAULT_DIRECTION = "up"
```

Change both settings if the inventory is on another side.

## Install the server

Run this on the bank server computer:

```lua
wget run https://raw.githubusercontent.com/Ice-Cheri-Cola/ATM-10-Bank-System/main/installer.lua server
```

Run:

```lua
id
```

Write down the bank server computer ID.

## Install an ATM

Run this on the ATM computer:

```lua
wget run https://raw.githubusercontent.com/Ice-Cheri-Cola/ATM-10-Bank-System/main/installer.lua atm
```

Edit the ATM configuration:

```lua
edit config.lua
```

Change:

```lua
BANK_SERVER_ID = 0
```

to the actual bank server computer ID.

Reboot the server and ATM.

## Memory Card

1. Craft an Advanced Peripherals Memory Card.
2. Bind it to the player.
3. Insert it into the ATM's Inventory Manager.
4. The card owner must be online.

## Test order

1. Start the server.
2. Start one ATM.
3. Insert a bound card.
4. Deposit one diamond.
5. Check the balance.
6. Withdraw one diamond.
7. Restart both computers and confirm the balance persists.

## Files

- `config.lua` — shared settings
- `bank_server.lua` — accounts, reservations, persistence, and Rednet server
- `bank_atm.lua` — card reading and deposit/withdraw menu
- `installer.lua` — downloads the correct files and creates `startup.lua`

## Next upgrades

- Touchscreen monitor interface
- Admin computer
- Account freezing and manual recovery tools
- Printed transaction receipts
- Multiple currencies
- Daily withdrawal limits
- Better vault stock monitoring
