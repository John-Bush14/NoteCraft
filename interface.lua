local input = {}


for _, arg in pairs({...}) do
   local equals = string.find(arg, "=")

   if equals ~= nil then input[string.sub(arg, 1, equals-1)] = input[string.sub(arg, equals)] end
end
