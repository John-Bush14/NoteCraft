local input = {}

local target = nil


for _, arg in pairs({...}) do
   local equals = string.find(arg, "=")

   if equals ~= nil then input[string.sub(arg, 1, equals-1)] = string.sub(arg, equals)
   else target = arg end
end


require("audioPlayer")(target, input)
