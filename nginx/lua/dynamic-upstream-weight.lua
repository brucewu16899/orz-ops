
local string2array = function (str)
    local arr = {}
    for field in string.gmatch(str, "([^, ]+)") do
        table.insert(arr, field)
    end
    return arr
end


local update_server_res_time = function (addr, time, dict, passed_weight, current_weight)
    local passed_time = dict:get(addr) or 0
    local current_time = tonumber(time)
    if current_time == nil then
        current_time = passed_time
    end
    local new_time = passed_time * passed_weight + current_time * current_weight
    dict:set(addr, new_time)
    return new_time, passed_time
end


--check if we need to update the weights, with some strategy
local check_if_update_weight = function (addr, new_time, old_time, dict)
    local diff = math.abs((new_time - old_time) / old_time)
    local threshold = 0.2
    if diff > threshold then
        ngx.log(ngx.ALERT, "need to update upstream weight because diff " .. diff .. " greater than ".. threshold .. " on " .. addr)
        return true
    end

    local ever_max = dict:get("max") or -math.huge
    if new_time > ever_max then
        ngx.log(ngx.ALERT, "need to update upstream weight because max value outdated")
        return true
    end

    local ever_min = dict:get("min") or math.huge
    if new_time < ever_min then
        ngx.log(ngx.ALERT, "need to update upstream weight because min value outdated")
        return true
    end

    return false
end


local check_if_weight_changed_unexpected = function (ups, upsteam_name, dict)
    local servers, err = ups.get_primary_peers(upsteam_name)
    if not servers then
        ngx.log(ngx.ALERT, "get upstream " .. upsteam_name .. " fail, " .. err)
        return false
    end
    for _, server in ipairs(servers) do
        local server_name = server["name"]
        local actual = server["weight"]
        local expect = dict:get(server_name) or 1
        if actual ~= expect then
            ngx.log(ngx.ALERT, "need to update upstream weight because different config found " .. server_name .. "~" .. expect .. "~" .. actual)
            return true
        end
    end
    return false
end


local gen_server_time_map = function(dict)
    local keys = dict:get_keys(100)
    local map = {}
    for _, key in ipairs(keys) do
        local time = dict:get(key)
        map[key] = time
    end
    return map
end


local min_max = function (t)
    local max = -math.huge
    local min = math.huge
    for k, v in pairs(t) do
        max = math.max(max, v)
        min = math.min(min, v)
    end
    return min, max
end


local update_server_weight = function (ups, upsteam_name, dict, server_time_map, max_time)
    local servers, err = ups.get_primary_peers(upsteam_name)
    if not servers then
        ngx.log(ngx.ALERT, "get upstream " .. upsteam_name .. " fail, " .. err)
        return
    end
    for _, server in ipairs(servers) do
        local server_name = server["name"]
        local id = server["id"]
        local fails = server["fails"]
        local time = server_time_map[server_name]
        local weight = 0

        if fails > 0 then
            weight = 1
            ngx.log(ngx.ALERT, "down grade " .. server_name .. " because it fail " .. fails .. " times")
        elseif time ~= nil and time > 0 then
            weight = math.ceil(max_time / time)
        end

        if weight > 0 then
            ups.set_peer_weight(upsteam_name, false, id, weight)
            ups.set_peer_effective_weight(upsteam_name, false, id, weight)

            dict:set(server_name, weight)
        end
    end
end


local res_time_dict = ngx.shared.upstream_res_time_dict
local weight_dict = ngx.shared.upstream_weight_dict
local upstream = require "ngx.upstream"

local ups_identity = "backend_blog_jamespan_me"
--it may have multi address and times if nginx tried more than 1 upstream servers
--but most of the time, there's only one address and time
local addrs = string2array(ngx.var.upstream_addr)
local times = string2array(ngx.var.upstream_response_time)

local need_update_weight = false
for idx, addr in ipairs(addrs) do
    local time = times[idx]
    local new_time, old_time = update_server_res_time(addr, time, res_time_dict, 0.3, 0.7)
    need_update_weight = check_if_update_weight(addr, new_time, old_time, res_time_dict)
end

if not need_update_weight then
    need_update_weight = check_if_weight_changed_unexpected(upstream, ups_identity, weight_dict)
end

if need_update_weight then
    local server_time_map = gen_server_time_map(res_time_dict)
    local min_time, max_time = min_max(server_time_map)

    res_time_dict:set("max", max_time)
    res_time_dict:set("min", min_time)

    update_server_weight(upstream, ups_identity, weight_dict, server_time_map, max_time)
end


