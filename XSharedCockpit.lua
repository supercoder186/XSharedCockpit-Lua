--posx = find_dataref("sim/flightmodel/position/local_x")


ini_parser = require 'Resources.plugins.FlyWithLua.Scripts.XSharedCockpit.ini'

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

local master_address = '127.0.0.1'
local slave_address = '127.0.0.1'
local slave_port = 49001
local master_port = 49000
local running = false
local is_server = true
local is_connected = false
local socket = require "socket"
local config_file_path = AIRCRAFT_PATH .. 'smartcopilot.cfg'

local function isempty(s)
  return s == nil or s == ''
end

function split (inputstr, sep)
        if sep == nil then
            sep = "%s"
        end
        local t={}
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
                table.insert(t, str)
        end
        return t
end

function start_server()
    running = true
    master = socket.udp()
    print("Starting master broadcaster")
    master:setsockname(master_address, master_port)
    master:setpeername(slave_address, slave_port)
    is_connected = true
end

function stop_server()
    print("Stopping master broadcaster")
    broadcast_datarefs("close")
    running = false
    master:close()
end

function start_slave()
    running = true
    slave = socket.udp()
    set_array("sim/operation/override/override_planepath", 0, 1)
    print("Starting receiver")
    slave:setsockname(slave_address, slave_port)
    slave:setpeername(master_address, master_port)
    slave:settimeout(0)
    is_connected = true
end

function stop_slave()
    running = false
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
        dataref_string = dataref_string .. v .. "=" .. get(v) .. " "
    end
    broadcast_datarefs(dataref_string)
end

local function set_datarefs(s)
    --[[splitstr = split(s, " ")
    for k, v in ipairs(splitstr) do
        split_value = split(v, "=")
        dref_name, value = split_value[1], split_value[2]
        value = tonumber(value)
        if value == nil or dref_name == nil then
            return
        end
        set(dref_name, value)
    end--]]
    split = ini.parse_data(s)
    if split and #split == 2 then
        set(split[1], split[2])
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

do_every_draw("loop()")
