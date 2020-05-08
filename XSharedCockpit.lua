--require the ini parser file (ini.lua) and the default lua sockets library
local ini = require 'Resources.plugins.FlyWithLua.Scripts.XSharedCockpit.ini'
local socket = require 'socket'

--define the datarefs arrays and add the basic flight path datarefs
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

--define all the basic variables required
local master_address = '127.0.0.1'
local master_port = 49000
local running = false
local is_server = true
local is_connected = false
local config_file_path = AIRCRAFT_PATH .. 'smartcopilot.cfg'

local config = ini.parse_file(config_file_path)

local master_overrides = {}
local slave_overrides = {}

--pretty self-explanatory
function write_to_file(text, filename)
    local file = io.open(filename, 'r')
    io.output(file)
    io.write(text)
    io.flush()
    io.close()
    print("file written")
end

--split a string by the separator
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

--(Checks if number has check as one of its addition factors)
local function number_contains(number, check)
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

--Add all the required datarefs to drefs and slow_drefs

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

--Add overrides to their respective arrays
local override = config["OVERRIDE"]
if override then
    for k, v in pairs(override) do
        if number_contains(v, 1) then --It is a master override
            master_overrides[#master_overrides + 1] = k
        end
        if number_contains(v, 8) then --It is a slave override
            slave_overrides[#slave_overrides + 1] = k
        end
    end
end

--check if a string is empty
local function isempty(s)
  return s == nil or s == ''
end

function start_server()
    --tell the program that the server is running
    running = true

    --set all the master overrides
    for k,v in ipairs(master_overrides) do
        --parse the dataref name and possibly index
        dfname = ini.parse_dfname(v)
        if #dfname == 2 then --it is an array dataref
            set_array(dfname[1], dfname[2], 1)
        else if #dfname == 1 then --it is a float dataref
            set(dfname[1], 1)
        end
    end

    print("Starting master broadcaster")
    --bind the server to the address and port
    server = assert(socket.bind(master_address, master_port))
    --accept a client connection
    master = server:accept()
    print("Slave connection accepted")
    --tell the program that the server is connected to a client and that broadcasts can be made
    is_connected = true
end

function stop_server()
    print("Stopping master broadcaster")
    --tell the slave that the server is turning off
    broadcast_datarefs("close")
    --tell the program that the server is no longer connected to a client
    is_connected = false

    --Disable all the master overrides
    for k,v in ipairs(master_overrides) do
        dfname = ini.parse_dfname(v)
        if #dfname == 2 then
            set_array(dfname[1], dfname[2], 0)
        end
    end

    --tell the program that the server is no longer running
    running = false
    master:close()
end

function start_slave()
    --tell the program that the slave is running
    running = true

    --set all the slave overrides
    for k,v in ipairs(slave_overrides) do
        --parse the dataref name and possibly index
        dfname = ini.parse_dfname(v)
        if #dfname == 2 then --it is an array dataref
            set_array(dfname[1], dfname[2], 1)
        else if #dfname == 1 then --it is a float dataref
            set(dfname[1], 1)
        end
    end

    --override the xplane flight model
    set_array("sim/operation/override/override_planepath", 0, 1)

    --initialise the slave
    slave = assert(socket.tcp())

    --connect to the server
    slave:connect(master_address, master_port)
    print("Starting receiver")
    slave:settimeout(0)

    --Notify the program that the slave is connected to the server
    is_connected = true
end

function stop_slave()
    --Notify the program that the slave is no longer connected
    is_connected = false

    --Notify the program that the slave has stopped running
    running = false

    --Disable all the slave overrides
    for k,v in ipairs(slave_overrides) do
        dfname = ini.parse_dfname(v)
        if #dfname == 2 then
            set_array(dfname[1], dfname[2], 0)
        end
    end

    --Re-enable the flight model
    set_array("sim/operation/override/override_planepath", 0, 0)
    print("Stopping receiver")

    --Close the slave connection
    slave:close()
end

--Pretty much self-explanatory
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

--Pretty much self-explanatory
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

--Broadcast the data inside the input parameter
function broadcast_datarefs(data)
    master:send(data)
end

function send_datarefs()
    --Check if the server is connected to a slave
    if not is_connected then
        return
    end
    dataref_string = ""
    for k, v in ipairs(drefs) do
        --Parse the dataref name and possibly the index
        parsed = ini.parse_dfname(v)
        if #parsed == 2 then --It is an array dataref
            value = get(parsed[1], parsed[2]) --Get the dataref value
            if value then
                dataref_string = dataref_string .. k .. "=" .. value .. " "
            end
        elseif #parsed == 1 then --It is a float dataref
            value = get(parsed[1]) --Get the dataref value
            if value then
                dataref_string = dataref_string .. k .. "=" .. value .. " "
            end
        end
    end
    --Append new line so that the receiver knows that the dataref transmission for this cycle is complete
    dataref_string = dataref_string..'\n'

    --Broadcast dataref string
    broadcast_datarefs(dataref_string)
end

function send_slow_datarefs()
    --Check if the server is connected to a slave
    if not is_connected then
        return
    end
    dataref_string = ""
    for k, v in ipairs(slow_drefs) do
        --Parse the dataref name and possibly the index
        parsed = ini.parse_dfname(v)
        if #parsed == 2 then --It is an array dataref
            value = get(parsed[1], parsed[2]) --Get the dataref value
            if value then
                dataref_string = dataref_string .. k .. "=" .. value .. " "
            end
        elseif #parsed == 1 then --It is a float dataref
            value = get(parsed[1]) --Get the dataref value
            if value then
                dataref_string = dataref_string .. k .. "=" .. value .. " "
            end
        end
    end
    --Append new line so that the receiver knows that the dataref transmission for this cycle is complete
    dataref_string = dataref_string..'\n'

    --Broadcast dataref string
    broadcast_datarefs(dataref_string)
end

local function set_datarefs(s)
    s = split(s, " ") --make an array of all the datarefs
    for k, v in ipairs(s) do
        -- Parse the index number
        idx = v:match('(%S+)%s*=')
        --Convert it to a number
        idx_n = tonumber(idx)
        if idx then
            --Replace the index number with the dataref name
            v = v:gsub(idx, drefs[idx_n], 1)

            --Parse the dataref value
            data = ini.parse_data(v)

            if #data[2] == 2 then --it is an array dataref
                set_array(data[1], data[2][1], data[2][2])
            elseif #data[2] == 1 then --it is a float dataref
                set(data[1], data[2][1])
            end
        end
    end
end

function sync_datarefs()
    --Check if the slave is connected
    if not is_connected then
        return
    end

    --Receive the server's transmissions
    received, error = slave:receive('*l')

    --Check if received data is valid
    if isempty(received) or error == 'closed' then
        return
    end

    --Check if the server is calling for a close
    if received == 'close' then
        toggle_slave()
        return
    end

    --Set the datarefs according to the received message
    set_datarefs(received)
end

--register X-Plane commands to toggle master and slave
create_command("XSharedCockpit/toggle_master", "Toggle XSharedCockpit as Master","toggle_master()", "", "")
create_command("XSharedCockpit/toggle_slave", "Toggle XSharedCockpit as Slave", "toggle_slave()", "", "")

--register FlyWithLua macros to toggle master and slave
add_macro("Toggle XSharedCockpit as Master", "toggle_master()")
add_macro("Toggle XSharedCockpit as Slave", "toggle_slave()")

count = 0

function loop()
    --check if something is running
    if running then
        if is_master then --master is running
            send_datarefs() --broadcast datarefs
        else --slave is running
            sync_datarefs() --sync the datarefs with master
        end
        if count % 10 == 0 then
            --often()
        end
        count += 1
    end
end

function often()
    if running and is_master then --master is running
        send_slow_datarefs() --send the datarefs under SLOW and WEATHER
    end
end

--do_often("often()")
do_every_draw("loop()") --tell FlyWithLua to run loop() every time X-Plane draws
