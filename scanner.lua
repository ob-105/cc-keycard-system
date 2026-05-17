-- ============================================================
--  KEY CARD SCANNER  (Computer 1)
--  Install on: Computer with Wireless Modem on the BACK
--  Redstone output goes on the side configured below.
--
--  First run: you will be prompted for the Verification
--  Server's computer ID. That is saved to "scanner.cfg".
-- ============================================================

local VERSION = "1.0.0"  -- managed by update.lua / manifest.json

-- ── Auto-update ───────────────────────────────────────────────
if fs.exists("update.lua") then shell.run("update") end

-- ── Configuration ────────────────────────────────────────────
local REDSTONE_SIDE    = "right"       -- side whose signal locks the door
local MODEM_SIDE       = "back"        -- side the wireless modem is on
local DOOR_OPEN_TIME   = 3             -- seconds the door stays open
local PING_PROTOCOL    = "keycard_ping"
local VERIFY_PROTOCOL  = "keycard_verify"
local RESPONSE_PROTOCOL = "keycard_response"
local CONFIG_FILE      = "scanner.cfg"
local LISTEN_TIMEOUT   = 2             -- seconds to wait for a ping before looping
local RESPONSE_TIMEOUT = 5             -- seconds to wait for server response

-- ── Modem & redstone setup ───────────────────────────────────
if not peripheral.isPresent(MODEM_SIDE) then
    error("No peripheral found on '" .. MODEM_SIDE .. "'. Attach a Wireless Modem.", 0)
end
rednet.open(MODEM_SIDE)
rs.setAnalogOutput(REDSTONE_SIDE, 15)   -- door starts LOCKED

-- ── Config (server ID) ───────────────────────────────────────
local config = {}
if fs.exists(CONFIG_FILE) then
    local f = fs.open(CONFIG_FILE, "r")
    config = textutils.unserialize(f.readAll()) or {}
    f.close()
end

if not config.serverID then
    print("=== SCANNER FIRST-RUN SETUP ===")
    print("Enter the Verification Server's computer ID:")
    config.serverID = tonumber(read())
    if not config.serverID then error("Invalid server ID.", 0) end
    local f = fs.open(CONFIG_FILE, "w")
    f.write(textutils.serialize(config))
    f.close()
    print("Saved. Restarting scanner...")
    sleep(1)
end

local SERVER_ID = config.serverID

-- ── Helpers ──────────────────────────────────────────────────
local function log(msg)
    print("[" .. os.date("%H:%M:%S") .. "] " .. msg)
end

local function openDoor(cardName)
    log("ACCESS GRANTED -> " .. cardName)
    rs.setAnalogOutput(REDSTONE_SIDE, 0)   -- unlock
    sleep(DOOR_OPEN_TIME)
    rs.setAnalogOutput(REDSTONE_SIDE, 15)  -- re-lock
    log("Door re-locked.")
end

-- Track recently seen cards to avoid flooding the server
-- with repeat requests from the same card within one open cycle.
local cooldowns = {}
local COOLDOWN_TIME = DOOR_OPEN_TIME + 1   -- slightly longer than door open

local function isOnCooldown(cardID)
    local expires = cooldowns[cardID]
    if expires and os.clock() < expires then
        return true
    end
    return false
end

local function setCooldown(cardID)
    cooldowns[cardID] = os.clock() + COOLDOWN_TIME
end

-- ── Main ─────────────────────────────────────────────────────
term.clear()
term.setCursorPos(1, 1)
log("Scanner active  (ID: " .. os.computerID() .. ")")
log("Server ID : " .. SERVER_ID)
log("Redstone  : ON  (locked)")

while true do
    -- Listen for a pocket computer ping
    local senderID, message, protocol = rednet.receive(PING_PROTOCOL, LISTEN_TIMEOUT)

    if senderID and type(message) == "table"
       and type(message.id) == "number"
       and type(message.name) == "string"
    then
        local cardID   = message.id
        local cardName = message.name

        if isOnCooldown(cardID) then
            -- silently skip; already processed recently
        else
            log("Card detected -> ID=" .. cardID .. "  Name=" .. cardName)

            -- Forward to verification server
            rednet.send(SERVER_ID, {
                type      = "verify",
                cardID    = cardID,
                cardName  = cardName,
                scannerID = os.computerID(),
            }, VERIFY_PROTOCOL)

            -- Wait for server response
            local respSender, response = rednet.receive(RESPONSE_PROTOCOL, RESPONSE_TIMEOUT)

            if respSender == SERVER_ID and type(response) == "table" then
                if response.allowed then
                    setCooldown(cardID)
                    openDoor(cardName)
                else
                    log("ACCESS DENIED  -> " .. cardName ..
                        "  (" .. tostring(response.reason) .. ")")
                end
            else
                log("WARNING: No response from server (timeout or wrong sender).")
            end
        end
    end
end
