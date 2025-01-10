require("tools").extend(table, math)


local input = {}

local target = ""


for _, arg in pairs({...}) do
   local equals = string.find(arg, "=")

   if equals ~= nil then input[string.sub(arg, 1, equals-1)] = string.sub(arg, equals)
   else target = arg end
end


target = target or error("no target provided")


local songs = {target}

if fs.isDir(target) then
---@diagnostic disable-next-line: undefined-field -- table.map from tools.lua extend but lsp doesn't know
   songs = table.map(fs.list(target), function(file) return fs.combine(target, file) end)
end

require("audioPlayer")(songs[1], songs, input)
