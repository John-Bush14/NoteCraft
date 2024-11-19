local types = {
   byte = 1,
   short = 2,
   int = 4,
   str = 999,
   Ubyte = 11,
}

local versionFields = {
   [0] = {
      header = {
         {"length", types.short},
	      {"layer-count", types.short},
   	   {"name", types.str},
   	   {"author", types.str},
   	   {"OG-author", types.str},
   	   {"description", types.str},
   	   {"tempo", types.short},
   	   {"auto-saving", types.byte},
   	   {"auto-saving-dur", types.byte},
   	   {"time-signature", types.byte},
   	   {"minutes-spent", types.int},
   	   {"leftclick", types.int},
   	   {"rightclick", types.int},
   	   {"noteblocks-added", types.int},
   	   {"noteblocks-removed", types.int},
   	   {"OG-filename", types.str},
      },

      notes = {
         {"jumps-tick", types.short},
         {"jumps-layer", types.short},
         {"instrument", types.byte},
         {"key", types.byte}
      },

      layers = {
         {"name", types.str},
         {"volume", types.byte},
      },

      instruments = {
         {"name", types.str},
         {"file", types.str},
         {"key", types.byte},
         {"piano", types.byte},
      }
   },
   [1] = {
      header = {
         [1] = {"classic", types.short, "replace"},
         [2] = {"NBSversion", types.byte, "push"},
         [3] = {"vanilla-instrument-count", types.byte}
      }
   },
   [2] = {
      layers = {
         [3] = {"stereo", types.Ubyte, "push"}
      }
   },
   [3] = {
      header = {
         [4] = {"length", types.short, "push"}
      },

      layers = {
         [2] = {"lock", types.byte, "push"},
      },

      notes = {
         [5] = {"velocity", types.byte, "push"},
         [6] = {"panning", types.byte, "push"},
         [7] = {"pitch", types.short, "push"}
      }
   },
   [4] = {
      header = {
         [20] = {"loop", types.byte, "push"},
         [21] = {"loop-count", types.byte, "push"},
         [22] = {"loop-start", types.short, "push"}
      }
    },
   [5] = {}
}

function table.len(tbl)
    local x = 0
    for _,_ in pairs(tbl) do x = x + 1 end
    return x
end

function table.modify(tbl, mods)
    for k, modblock in pairs(mods) do
        local min = 99999
        for i,_ in pairs(modblock) do if i < min then min = i end end
        local len = table.len(modblock)
        for I=1,len do
            local i = min + I - 1
            local mod = modblock[i]
            if mod[3] == "replace" then tbl[k][i] = mod
            else table.insert(tbl[k], i, mod) end
        end
    end
end

function bytesToInt(str, signed)
   local bytes = {}
   for char in str:gmatch(".") do table.insert(bytes, string.byte(char)) end

   local multiplier = 1
   local int = 0

   for _, byte in pairs(bytes) do
      int = int + byte * multiplier
      multiplier = multiplier * 256
   end

   local max = math.pow(2, #bytes*8-1)
   if int > max and (signed == nil or signed == false) then
        int = int - max*2
    end

   return int
end

function read(file, bytes)
    if bytes == types.str then
        local str = ""
        local len = file:read(types.int)
        if len == nil then return nil end
        for _=1,bytesToInt(len) do str = str .. file:read(types.byte) end
        return str
    elseif bytes ~= types.Ubyte then
        return bytesToInt(file:read(bytes), false)
    else
        return bytesToInt(file:read(types.byte), true)
    end
end

function readPart(fields, size, file)
   local part = {}

   local block = {}
   for _=1,size do
       for _, field in pairs(fields) do
           block[field[1]] = read(file, field[2])
           if block[field[1]] == nil then return nil end
       end
       table.insert(part, block)
       block = {}
   end

   return part
end

function table.copy(original)
	local copy = {}
	for k, v in pairs(original) do
		if type(v) == "table" then
			v = table.copy(v)
		end
		copy[k] = v
	end
	return copy
end

return function(file)
   local fields = table.copy(versionFields[0])

   print(file, " pls no nil man")

   local classic = read(file, types.short)

   print(classic)

   if classic == 0 then
       local version = read(file, types.byte)
       print(version)
       for i=1,version do
           table.modify(fields, versionFields[i])
       end
   end

   file:seek("set", 0)

   local data = {header = {}, notes = {}}

   -- header
   data.header = table.unpack(readPart(fields.header, 1, file))

   -- notes
   local i = 1
   local note = {}
   local b = file:read(types.short)

   while not (i == 1 and bytesToInt(b) == 0) do
      note[fields.notes[i][1]] = bytesToInt(b)

      if i == 1 then for _=1,bytesToInt(b) do table.insert(data.notes, "tick!") end end

      if i == 2 and bytesToInt(b) == 0 then
         i = 1
         table.insert(data.notes, "tick!")
         note = {}
      elseif i == #fields.notes then
         i = 2
         table.insert(data.notes, note)
         note = {}
      else
         i = i + 1
      end

      b = file:read(fields.notes[i][2])
   end

   print("layers!")
   data.layers = readPart(fields.layers, data.header["layer-count"], file)

   local instruments = read(file, Ubyte)

   if instruments == nil then return data end

   data.instruments = readPart(fields.instruments, instruments, file)
   data.instruments.count = instruments

   for k, instrument in pairs(data.instruments) do if type(instrument) == "table" then
      if instrument.name ~= "Tempo Changer" then
         print("Substitute for: " .. instrument.name .. " from " .. instrument.file .. ": ")
         data.instruments[k].substitute = _G.read()
      end
   end end

   return data
end
