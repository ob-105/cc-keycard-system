local version = "1.0.0"
if fs.exists("update.lua") then shell.run("update") end

local netID = "1"
if fs.exists("net.cfg") then
    local f = fs.open("net.cfg", "r")
    local n = textutils.unserialize(f.readAll()) or {}
    f.close()
    if n.net and tostring(n.net) ~= "" then netID = tostring(n.net) end
end

local function netNum(s)
    local n = tonumber(s)
    if n then return math.floor(math.abs(n)) end
    local h = 0
    for i = 1, #s do
        h = (h * 31 + string.byte(s, i)) % 1000
    end
    return h
end

local pingChannel = 43000 + (netNum(netID) % 1000)

local modem = peripheral.find("modem", function(_, m) return m.isWireless() end)
if not modem then
    error("no wireless modem found", 0)
end
modem.open(pingChannel)

local myID = os.computerID()
local myName = os.computerLabel()
if not myName or myName == "" then
    myName = "card-" .. myID
end

term.clear()
term.setCursorPos(1, 1)
print("keycard app running")
print("id: " .. myID)
print("name: " .. myName)
print("network: " .. netID)
print("chan: " .. pingChannel)
print("broadcasting...")

while true do
    modem.transmit(pingChannel, pingChannel, {id = myID, name = myName})
    sleep(1)
end
