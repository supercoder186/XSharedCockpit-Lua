local ini = {}

local function isnotempty(s)
  return not(s == nil or s == '')
end

local function remove_comments(s)
    rgx = '[ ]*[#;]+.*'
    match = s:match(rgx)
    if isnotempty(match) then
        s = s:gsub(match, "")
    end
    return s
end

local function detect_section(s)
    rgx = '%[([^%[%]]+)%]$'
    match = s:match(rgx)
    if isnotempty(match) then
        return match
    end
end

function parse_data(s)
    rgx = '(%S+)[ ]*=[ ]*(%S+)'
    table = {}
    for k, v in string.gmatch(s, rgx) do
        table[1] = k
        table[2] = tonumber(v)
    end
    return table
end

function ini.parse_dfname(s)
    rgx = '(%S+)%[(%d+)%]'
    s = s:gsub("_FIXED_INDEX_", "")
    for k, v in s:gmatch(rgx) do
        return {k, tonumber(v)}
    end
    return {s}
end

function ini.parse_data(s)
    rgx = '(%S+)[ ]*=[ ]*(%S+)'
    array_rgx = '(%S+)[%s]*%[(%d+)%][ ]*=[ ]*(%S+)'
    table = {}
    if s:match('%[%d+%]') then
        for k, i, v in string.gmatch(s, array_rgx) do
            table[1] = k
            table[2] = {tonumber(i), tonumber(v)}
        end
    else
        for k, v in string.gmatch(s, rgx) do
            table[1] = k
            table[2] = {tonumber(v)}
        end
    end
    return table
end

function ini.parse_file(file_name)
    file = io.open(file_name, "r")
    io.input(file)
    current_section = ""
    t = {}

    for line in io.lines() do
        line = remove_comments(line)
        section_name = detect_section(line)
        if section_name then
            current_section = section_name
            t[current_section] = {}
        else
            data = parse_data(line)
            if data and #data == 2 then
                t[current_section][data[1]] = data[2]
            end
        end
    end
    return t
end

return ini
