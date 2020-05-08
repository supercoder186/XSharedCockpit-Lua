ini = require 'Resources.plugins.FlyWithLua.Scripts.XSharedCockpit.ini'

local drefs = {}
drefs[1] = "sim/flightmodel/position/local_x"
drefs[2] = "sim/flightmodel/position/local_y"
drefs[3] = "sim/flightmodel/position/local_z"
drefs[4] = "sim/flightmodel/position/psi"
drefs[5] = "sim/flightmodel/position/theta"
drefs[6] = "sim/flightmodel/position/phi"
drefs[7] = "sim/flightmodel/position/P"
drefs[8] = "sim/flightmodel/position/Q"
drefs[9] = "sim/flightmodel/position/R"
drefs[10] = "sim/flightmodel/position/local_vx"
drefs[11] = "sim/flightmodel/position/local_vy"
drefs[12] = "sim/flightmodel/position/local_vz"


slow_drefs = {}

local master_address = '127.0.0.1'
local slave_address = '127.0.0.1'
local slave_port = 49001
local master_port = 49000
local running = false
local is_server = true
local is_connected = false
local socket = require "socket"
local config_file_path = AIRCRAFT_PATH .. 'smartcopilot.cfg'
local written = false

ini.parse_data("")
local config = ini.parse_file(config_file_path)

local master_overrides = {}
local slave_overrides = {}

function write_to_file(text, filename)
    local file = io.open(filename, 'r')
    io.output(file)
    io.write(text)
    io.flush()
    io.close()
    print("file written")
end

function split (inputstr, sep)
        if sep == nil then
                sep = "%s"
        end
        local t={}
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
            t[#t+1] = str
        end
        return t
end

local function number_contains(number, check)
    --(Checks if number has check as one of its addition factors)
    i = 16
    while i >= 1 do
        if number > i then
            --number contains i
            if i == check then
                return true
            end
        end
        i = i / 2
    end
    return false
end

local triggers = config["TRIGGERS"]
if triggers then
    for k, v in pairs(triggers) do
        drefs[#drefs + 1] = k
    end
end

local clicks = config["CLICKS"]
if clicks then
    for k, v in pairs(clicks) do
        drefs[#drefs + 1] = k .. "_scp"
    end
end

local continued = config["CONTINUED"]
if continued then
    for k, v in pairs(continued) do
        drefs[#drefs + 1] = k
    end
end

local sendback = config["SEND_BACK"]
if sendback then
    for k, v in pairs(sendback) do
        drefs[#drefs + 1] = k
    end
end

local override = config["OVERRIDE"]
if override then
    for k, v in pairs(override) do
        if number_contains(v, 1) then
            master_overrides[#master_overrides + 1] = k
        end
        if number_contains(v, 8) then
            slave_overrides[#slave_overrides + 1] = k
        end
    end
end

local slow = config["SLOW"]
if slow then
    for k, v in pairs(slow) do
        slow_drefs[#slow_drefs + 1] = k
    end
end

local weather = config["WEATHER"]
if weather then
    for k, v in pairs(weather) do
        slow_drefs[#slow_drefs + 1] = k
    end
end

local transponder = config["TRANSPONDER"]
if transponder then
    for k, v in pairs(transponder) do
        drefs[#drefs + 1] = k
    end
end

local radios = config["RADIOS"]
if radios then
    for k, v in pairs(radios) do
        drefs[#drefs + 1] = k
    end
end

local function isempty(s)
  return s == nil or s == ''
end

function start_server()
    running = true
    master = socket.udp()
    master:setsockname(master_address, master_port)
    master:setpeername(slave_address, slave_port)
    print("Starting master broadcaster")
    --[[for k, v in pairs(master_overrides) do
        set(v, 1)
    end--]]
    is_connected = true
end

function stop_server()
    print("Stopping master broadcaster")
    broadcast_datarefs("close")
    running = false
    --[[for k, v in pairs(master_overrides) do
        set(v, 0)
    end-]]
    master:close()
end

function start_slave()
    running = true
    for k, v in pairs(slave_overrides) do
        set(v, 1)
    end
    set_array("sim/operation/override/override_planepath", 0, 1)
    slave = socket.udp()
    print("Starting receiver")
    slave:setsockname(slave_address, slave_port)
    slave:setpeername(master_address, master_port)
    slave:settimeout(0)
    is_connected = true
end

function stop_slave()
    running = false
    for k, v in pairs(slave_overrides) do
        set(v, 0)
    end
    set_array("sim/operation/override/override_planepath", 0, 0)
    print("Stopping receiver")
    slave:close()
end

function toggle_master()
    if ((not(is_master)) and (running)) then
        print("Invalid! Slave is already running")
    elseif not running then
        is_master = true
        start_server()
    else
        stop_server()
    end
end

function toggle_slave()
    if is_master and running then
        print("Invalid! Master is already running")
    elseif not running then
        is_master = false
        start_slave()
    else
        stop_slave()
    end
end

function broadcast_datarefs(data)
    master:send(data)
end

function send_datarefs()
    if not is_connected then
        return
    end
    dataref_string = ""
    for k, v in ipairs(drefs) do
        parsed = ini.parse_dfname(v)
        if #parsed == 2 then
            value = get(parsed[1], parsed[2])
            if value then
                dataref_string = dataref_string .. k .. "=" .. value .. " "
            end
        elseif #parsed == 1 then
            if value then
                dataref_string = dataref_string .. k .. "=" .. value .. " "
            end
        end
    end
    broadcast_datarefs(dataref_string)
end

function send_slow_datarefs()
    if not is_connected then
        return
    end
    dataref_string = ""
    for k, v in ipairs(slow_drefs) do
        parsed = ini.parse_dfname(v)
        if #parsed == 2 then
            value = get(parsed[1], parsed[2])
            if value then
                dataref_string = dataref_string .. v .. "=" .. value .. " "
            end
        elseif #parsed == 1 then
            value = get(parsed[1])
            if value then
                dataref_string = dataref_string .. v .. "=" .. value .. " "
            end
        end
    end
    broadcast_datarefs(dataref_string)
end

local function set_datarefs(s)
    s = split(s, " ")
    for k, v in ipairs(s) do
        idx = v:match('(%S+)%s*=')
        idx_n = tonumber(idx)
        if idx then
            v = v:gsub(idx, drefs[idx_n], 1)
            data = ini.parse_data(v)
            --[[for k, val in pairs(data) do
                print(val)
                if #val[2] == 2 then
                    set_array(val[1], val[2][1], val[2][2])
                elseif #val[2] == 1 then
                    set(val[1], val[2][1])
                end
            end--]]
            if #data[2] == 2 then
                set_array(data[1], data[2][1], data[2][2])
            elseif #data[2] == 1 then
                set(data[1], data[2][1])
            end
        end
    end
end

function sync_datarefs()
    if(not(is_connected)) then
        return
    end
    received = slave:receive()
    if(isempty(received)) then
        return
    end

    set_datarefs(received)
end

create_command("XSharedCockpit/toggle_master", "Toggle XSharedCockpit as Master","toggle_master()", "", "")
create_command("XSharedCockpit/toggle_slave", "Toggle XSharedCockpit as Slave", "toggle_slave()", "", "")
add_macro("Toggle XSharedCockpit as Master", "toggle_master()")
add_macro("Toggle XSharedCockpit as Slave", "toggle_slave()")

function loop()
    if running then
        if is_master then
            send_datarefs()
        else
            sync_datarefs()
        end
    end
end

function often()
    if running and is_master then
        send_slow_datarefs()
    end
end

--do_often("often()")
do_every_draw("loop()")
