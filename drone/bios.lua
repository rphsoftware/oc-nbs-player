local url = "http://nocf.rph.space/dronesong/boot.lua"
local internet = component.proxy(component.list("internet")())
 
local request = internet.request(url)
request:finishConnect()
 
local code = ""
repeat
  local s = request.read(1024)
  if s ~= nil then
    code = code .. s
  end
until ( not s )
 
load(code)()
