local ini = {}

--Check if a string is not empty
local function isnotempty(s)
  return not(s == nil or s == '')
end

--Removes all ini-style comments from a string
local function remove_comments(s)
    --Define regex string
    rgx = '[ ]*[#;]+.*'
    --Match all commented sections
    match = s:match(rgx)
    if isnotempty(match) then --There are comments in the string
        --Remove the commented section
        s = s:gsub(match, "")
    end
    return s
end

--Used to detect if a line is a section header
local function detect_section(s)
    --Define regex string (trust me it's not that complicated)
    rgx = '%[([^%[%]]+)%]$'
    --Match the string to the regex, to see if it is a section header
    match = s:match(rgx)
    if isnotempty(match) then --It is a section header
        return match
    end
end

--Used to parse a data line in the ini file
function parse_data(s)
    --Define regex string
    rgx = '(%S+)[ ]*=[ ]*(%S+)'
    table = {}
    --Iterate over each match
    for k, v in string.gmatch(s, rgx) do
        --Add the values to the table
        table[1] = k
        table[2] = tonumber(v)
    end
    return table
end

--Parses the dataref name and possibly index
function ini.parse_dfname(s)
    --Define regex string
    rgx = '(%S+)%[(%d+)%]'

    --Remove some smartcopilot annotations
    s = s:gsub("_FIXED_INDEX_", "")

    --Iterate over all match groups if it matches
    --If s:gmatch() gives a non-nil value, this means that it is an array dataref
    for k, v in s:gmatch(rgx) do
        return {k, tonumber(v)} --Return parsed dataref name and array index
    end
    return {s} --The dataref name is not an array dataref, return it
end

--Parses the dataref name, optionally dataref index, and dataref value
function ini.parse_data(s)
    --Define regex strings
    rgx = '(%S+)[ ]*=[ ]*(%S+)'
    array_rgx = '(%S+)[%s]*%[(%d+)%][ ]*=[ ]*(%S+)'
    table = {}
    if s:match('%[%d+%]') then --It contains square brackets, indicating that it is an array dataref
        for k, i, v in string.gmatch(s, array_rgx) do --Get the name, index and value
            table[1] = k
            table[2] = {tonumber(i), tonumber(v)}
        end
    else
        for k, v in string.gmatch(s, rgx) do --Get the name and value
            table[1] = k
            table[2] = {tonumber(v)}
        end
    end
    return table
end

--Parses the smartcopilot.cfg file to give the ini file in a table structure
function ini.parse_file(file_name)
    --Open the file
    file = io.open(file_name, "r")
    io.input(file)

    --Setup the basic variables
    current_section = ""
    t = {}

    for line in io.lines() do --Iterate over each line of the file
        --First remove the comments from the line
        line = remove_comments(line)

        --See if the line contains a section header
        section_name = detect_section(line)
        if section_name then --Line is a section header
            current_section = section_name --Update the current section
            t[current_section] = {} --Initialise the array for this section
        else
            data = parse_data(line) --Parse the dataref name
            if data and #data == 2 then
                t[current_section][data[1]] = data[2]
            end
        end
    end

    --Return the table representing the parsed file
    return t
end

--Return the ini object to be used by other programs
return ini
