local function starts_with(str, start)
   return str:sub(1, #start) == start
end

function trim(str)
   return str:gsub("^%s*(.-)%s*$", "%1")
end

function splitstring(inputstr, sep)
        if sep == nil then
                sep = "%s"
        end
        local t={}
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
                table.insert(t, str)
        end
        return t
end

local function isempty(s)
  return s == nil or s == ''
end

function parse_file(file_name)
    file = io.open(file_name, "r")
    io.input(file)
    current_section = ""
    t = {}

    for line in io.lines() do
        line = trim(line)
        if not starts_with(line, "##") then
            if starts_with(line, "[") then
                line = line:gsub("%[", "")
                line = line:gsub("%]", "")
                current_section = line
                t[current_section] = {}
            elseif string.find(line, "=") and not isempty(current_section) then
                split = splitstring(line:gsub(" ", ""), "=")
                key, value = split[1], tonumber(split[2])
                t[current_section][key] = value
            end
        end
    end

    return t
end
