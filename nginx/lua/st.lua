local time_dict = ngx.shared.upstream_res_time_dict
local weight_dict = ngx.shared.upstream_weight_dict

local server_time_dict = {}

local keys = time_dict:get_keys(10)
local total = 0
local max_time = 0
for _, key in pairs(keys) do
    local time = time_dict:get(key)
    server_time_dict[key] = time
    total = total + time
    if time > max_time then
    	max_time = time
    end
end

ngx.print("upstream_res_time_dict\n")
for k, v in pairs(server_time_dict) do
    ngx.print(k, ", ", v, "\n")
end
ngx.print("\n")

ngx.print("upstream_weight_dict\n")
local keys = weight_dict:get_keys(10)
for _, key in pairs(keys) do
    local w = weight_dict:get(key)
    ngx.print(key, ", ", w, "\n")
end
ngx.print("\n")
