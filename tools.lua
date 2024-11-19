return function(table, math)
   function table.map(tbl, fn)
      for i, v in ipairs(tbl) do
         tbl[i] = fn(v)
      end
      return tbl
   end

   function math.clamp(int, min, max) return math.min(math.max(int, min), max) end
end
