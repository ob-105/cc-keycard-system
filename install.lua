local baseURL = "https://raw.githubusercontent.com/ob-105/cc-keycard-system/main/"

local scripts = {
    {name = "Pocket Computer (companion app)", file = "companion_app.lua"},
    {name = "Scanner (computer 1)",            file = "scanner.lua"},
    {name = "Verification Server (computer 2)", file = "server.lua"},
    {name = "Door Controller (computer 3)",    file = "door_controller.lua"},
}

local function download(fname)
    local ok, res = pcall(http.get, baseURL .. fname)
    if not ok or not res then return false end
    local body = res.readAll()
    res.close()
    if body == "" then return false end
    local f = fs.open(fname, "w")
    f.write(body)
    f.close()
    return true
end

term.clear()
term.setCursorPos(1,1)
print("=== keycard installer ===")
print("")
print("which computer is this?")
print("")
for i, s in ipairs(scripts) do
    print(i .. ". " .. s.name)
end
print("")
io.write("pick a number: ")
local choice = tonumber(read())

if not choice or not scripts[choice] then
    print("invalid choice, quitting")
    return
end

local target = scripts[choice]
print("")
print("downloading " .. target.file .. "...")

if not download(target.file) then
    print("failed to download " .. target.file)
    print("check your internet and try again")
    return
end
print("got " .. target.file)

print("downloading update.lua...")
if not download("update.lua") then
    print("warning: couldnt get update.lua, auto-updates wont work")
else
    print("got update.lua")
end

local f = fs.open("startup.lua", "w")
f.write("shell.run(\"" .. target.file .. "\")\n")
f.close()
print("set startup to run " .. target.file)

print("")
print("done! reboot to start")
io.write("reboot now? (y/n): ")
local ans = read()
if ans == "y" or ans == "Y" then
    os.reboot()
end
