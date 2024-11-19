return function(table, math)
   function table.map(tbl, fn)
      local result = {}
      for i, v in ipairs(tbl) do
         result[i] = fn(v)
      end
      return result
   end

   function math.clamp(int, min, max) return math.min(math.max(int, min), max) end
end
