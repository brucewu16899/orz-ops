local res_time_dict = ngx.shared.upstream_res_time_dict
local weight_dict = ngx.shared.upstream_weight_dict
local upstream = require "ngx.upstream"

local ever_max = res_time_dict:get("max") or 0
local ever_min = res_time_dict:get("min") or 99999
local need_update_weight = false

local idx_addr = 1;
for addr in string.gmatch(ngx.var.upstream_addr, "([^, ]+)") do
    local idx_time = 1;
    for time in string.gmatch(ngx.var.upstream_response_time, "([^, ]+)") do
        if idx_addr == idx_time then
            local passed_time = res_time_dict:get(addr) or 0
            local new_time = passed_time * 0.5 + tonumber(time)
            res_time_dict:set(addr, new_time)
            if new_time > ever_max then
                need_update_weight = true
                ngx.log(ngx.ALERT, "need to update upstream weight because max value outdated")
            end
            if new_time < ever_min then
                need_update_weight = true
                ngx.log(ngx.ALERT, "need to update upstream weight because min value outdated")
            end
        end
        idx_time = idx_time + 1
    end
    idx_addr = idx_addr + 1;
end

local srvs, err = upstream.get_primary_peers("backend_blog_jamespan_me")
if srvs then
    for _, srv in ipairs(srvs) do
        local real_weight = srv["weight"]
        local server_name = srv["name"]
        local save_weight = weight_dict:get(server_name) or 1
        if save_weight ~= real_weight then
            need_update_weight = true
            ngx.log(ngx.ALERT, "need to update upstream weight because different config found " .. server_name .. "~" .. save_weight .. "~" .. real_weight)
            break
        end
    end
end

if need_update_weight then
    local keys = res_time_dict:get_keys(10)
    local total = 0
    local max_time = 0
    local min_time = 99999
    local server_time_dict = {}

    for _, key in pairs(keys) do
        local time = res_time_dict:get(key)
        server_time_dict[key] = time
        total = total + time
        if time > max_time then
            max_time = time
        end
        if time < min_time then
            min_time = time
        end
    end

    res_time_dict:set("max", max_time)
    res_time_dict:set("min", min_time)

    
    local srvs, err = upstream.get_primary_peers("backend_blog_jamespan_me")
    if srvs then
        for _, srv in ipairs(srvs) do
            local server_name = srv["name"]
            local server_res_time = server_time_dict[server_name]
            if server_res_time ~= nil then
                local weight = math.ceil(max_time / server_res_time)
                local id = srv["id"]
                weight = math.pow(2, weight)
                upstream.set_peer_weight("backend_blog_jamespan_me", false, id, weight)
                weight_dict:set(server_name, weight)
                --upstream.set_peer_current_weight("backend_blog_jamespan_me", false, id, 0)
                upstream.set_peer_effective_weight("backend_blog_jamespan_me", false, id, weight)
            end
        end
    end
end


