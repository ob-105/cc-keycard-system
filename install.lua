local baseURL = "https://raw.githubusercontent.com/ob-105/cc-keycard-system/main/"

local scripts = {
    {name = "Pocket Computer (streamed companion)", file = "companion_app.lua", role = "pocket"},
    {name = "Scanner", file = "scanner.lua", role = "scanner"},
    {name = "Verification Server", file = "server.lua", role = "server"},
    {name = "Legacy Door Controller (optional)", file = "door_controller.lua", role = "door"},
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
io.write("network id (example 1): ")
local netID = read()
if not netID or netID == "" then netID = "1" end

print("")
print("downloading " .. target.file .. "...")

if target.role == "pocket" then
    local f = fs.open("startup.lua", "w")
    f.write("local url = \"" .. baseURL .. "companion_app.lua\"\n")
    f.write("if fs.exists(\"companion_app.lua\") then fs.delete(\"companion_app.lua\") end\n")
    f.write("if fs.exists(\"update.lua\") then fs.delete(\"update.lua\") end\n")
    f.write("if not http then print(\"http disabled\") return end\n")
    f.write("local ok, res = pcall(http.get, url)\n")
    f.write("if (not ok) or (not res) then print(\"fetch failed\") return end\n")
    f.write("local src = res.readAll()\n")
    f.write("res.close()\n")
    f.write("local fn, err = load(src, \"@companion_app\", \"t\", _ENV)\n")
    f.write("if not fn then print(err) return end\n")
    f.write("fn()\n")
    f.close()
    print("set startup to stream companion app at runtime")
else
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
end

local nf = fs.open("net.cfg", "w")
nf.write(textutils.serialize({net = tostring(netID)}))
nf.close()
print("saved network id: " .. tostring(netID))

print("")
print("done! reboot to start")
io.write("reboot now? (y/n): ")
local ans = read()
if ans == "y" or ans == "Y" then
    os.reboot()
end
