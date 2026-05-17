local version = "1.0.0"
if fs.exists("update.lua") then shell.run("update") end

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
print("broadcasting...")

while true do
    rednet.broadcast({id = myID, name = myName}, "keycard_ping")
    sleep(1)
end
