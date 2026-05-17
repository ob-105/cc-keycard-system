local version = "1.0.0"
if fs.exists("update.lua") then shell.run("update") end

local netID = "1"
if fs.exists("net.cfg") then
    local f = fs.open("net.cfg", "r")
    local n = textutils.unserialize(f.readAll()) or {}
    f.close()
    if n.net and tostring(n.net) ~= "" then netID = tostring(n.net) end
end

local pingProto = "keycard_ping_" .. netID

local modem = peripheral.find("modem", function(_, m) return m.isWireless() end)
if not modem then
    error("no wireless modem found", 0)
end
rednet.open(peripheral.getName(modem))

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
print("broadcasting...")

while true do
    rednet.broadcast({id = myID, name = myName}, pingProto)
    sleep(1)
end
