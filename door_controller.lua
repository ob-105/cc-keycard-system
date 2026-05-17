-- ============================================================
--  DOOR CONTROLLER  (Computer 3)
--  Install on: Computer with Wireless Modem on the BACK
--  Redstone output goes on the side configured below.
--
--  This computer ALWAYS outputs redstone strength 15.
--  When the Verification Server approves a card it sends an
--  "open" command here; this computer then drops the signal
--  to 0 (unlocking the door) for DOOR_OPEN_TIME seconds
--  before re-locking.
--
--  First run: you will be prompted for the Verification
--  Server's computer ID. Saved to "door.cfg".
-- ============================================================

local VERSION = "1.0.0"  -- managed by update.lua / manifest.json

-- ── Auto-update ───────────────────────────────────────────────
if fs.exists("update.lua") then shell.run("update") end

-- ── Configuration ────────────────────────────────────────────
local REDSTONE_SIDE   = "right"    -- side whose signal locks the door
local MODEM_SIDE      = "back"     -- side the wireless modem is on
local DOOR_OPEN_TIME  = 3          -- seconds the door stays unlocked
local DOOR_PROTOCOL   = "keycard_door"
local CONFIG_FILE     = "door.cfg"

-- ── Modem & redstone setup ───────────────────────────────────
if not peripheral.isPresent(MODEM_SIDE) then
    error("No peripheral found on '" .. MODEM_SIDE .. "'. Attach a Wireless Modem.", 0)
end
rednet.open(MODEM_SIDE)
rs.setAnalogOutput(REDSTONE_SIDE, 15)  -- door starts LOCKED

-- ── Config (server ID) ───────────────────────────────────────
local config = {}
if fs.exists(CONFIG_FILE) then
    local f = fs.open(CONFIG_FILE, "r")
    config = textutils.unserialize(f.readAll()) or {}
    f.close()
end

if not config.serverID then
    print("=== DOOR CONTROLLER FIRST-RUN SETUP ===")
    print("Enter the Verification Server's computer ID:")
    config.serverID = tonumber(read())
    if not config.serverID then error("Invalid server ID.", 0) end
    local f = fs.open(CONFIG_FILE, "w")
    f.write(textutils.serialize(config))
    f.close()
    print("Saved.")
    sleep(1)
end

local SERVER_ID = config.serverID

-- ── Helpers ──────────────────────────────────────────────────
local function log(msg)
    print("[" .. os.date("%H:%M:%S") .. "] " .. msg)
end

local function openDoor(cardName)
    log("Opening door for: " .. tostring(cardName))
    rs.setAnalogOutput(REDSTONE_SIDE, 0)   -- unlock
    sleep(DOOR_OPEN_TIME)
    rs.setAnalogOutput(REDSTONE_SIDE, 15)  -- re-lock
    log("Door re-locked.")
end

-- ── Main ─────────────────────────────────────────────────────
term.clear()
term.setCursorPos(1, 1)
log("Door Controller active  (ID: " .. os.computerID() .. ")")
log("Server ID  : " .. SERVER_ID)
log("Redstone   : ON  (locked)")

-- Guard flag: prevent overlapping open cycles
local doorBusy = false

while true do
    local senderID, message = rednet.receive(DOOR_PROTOCOL)

    -- Only accept "open" commands from the trusted server
    if senderID == SERVER_ID
       and type(message) == "table"
       and message.type == "open"
    then
        if doorBusy then
            log("Door already open; ignoring duplicate request.")
        else
            doorBusy = true
            openDoor(message.cardName)
            doorBusy = false
        end
    else
        -- Log unexpected messages for security auditing
        log("IGNORED message from ID=" .. tostring(senderID) ..
            "  (not the trusted server)")
    end
end
