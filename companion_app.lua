-- ============================================================
--  KEY CARD COMPANION APP
--  Install on: Pocket Computer (with Wireless Modem upgrade)
--  Purpose:    Broadcasts this computer's ID and label so the
--              key card scanner can detect it nearby.
-- ============================================================

local BROADCAST_PROTOCOL = "keycard_ping"
local BROADCAST_INTERVAL = 1  -- seconds between broadcasts

local VERSION = "1.0.0"  -- managed by update.lua / manifest.json

-- ── Auto-update ───────────────────────────────────────────────
-- If update.lua exists and finds a newer version it will reboot;
-- if not, execution continues normally here.
if fs.exists("update.lua") then shell.run("update") end

-- ── Modem setup ─────────────────────────────────────────────
local modem = peripheral.find("modem", function(_, m) return m.isWireless() end)
if not modem then
    error("No wireless modem found. Attach a Wireless Modem upgrade to this pocket computer.", 0)
end
rednet.open(peripheral.getName(modem))

-- ── Identity ─────────────────────────────────────────────────
local cardID   = os.computerID()
local cardName = os.computerLabel()
if not cardName or cardName == "" then
    cardName = "Card-" .. cardID
end

-- ── Display ──────────────────────────────────────────────────
term.clear()
term.setCursorPos(1, 1)
print("=== KEY CARD ACTIVE ===")
print("ID   : " .. cardID)
print("Name : " .. cardName)
print("")
print("Broadcasting to nearby")
print("scanners every " .. BROADCAST_INTERVAL .. "s.")
print("")
print("Keep this app running")
print("to use as your key card.")

-- ── Broadcast loop ───────────────────────────────────────────
while true do
    rednet.broadcast({
        id   = cardID,
        name = cardName,
    }, BROADCAST_PROTOCOL)
    sleep(BROADCAST_INTERVAL)
end
