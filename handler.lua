local plugin = require("kong.plugins.base_plugin"):extend()
local cjson = require("cjson")

local req_read_body = ngx.req.read_body
local req_get_body_data = ngx.req.get_body_data
local req_set_header = ngx.req.set_header
local pcall = pcall

local function parse_json(body)
  if body then
    local status, res = pcall(cjson.decode, body)
    if status then
      return res
    end
  end
end

local function invalid_request(msg)
  ngx.status = 400
  ngx.say(msg)
  ngx.exit(ngx.OK)
end

local function has_value(tab, val)
  for index, value in ipairs(tab) do
    if value == val then
      return true
    end
  end
  return false
end

function plugin:access(conf)
  req_read_body()

  -- parse json from configuration
  local swagger_json = conf.swagger_json
  local swagger = parse_json(swagger_json)

  -- schema
  local defined_schemes = swagger.schemes
  if defined_schemes ~= nil then
    local request_schema = ngx.var.scheme:lower()
    if not has_value(defined_schemes, request_schema) then
      invalid_request("Given request schema " .. request_schema .. " is not allowed in swagger! ")
    end
  end

  -- paths
  local uri = ngx.var.request_uri
  do
    local idx = string.find(uri, "?", 2, true)
    if idx then
      uri = string.sub(uri, 1, idx - 1)
    end
  end

  local api_path = ngx.ctx.router_matches.uri
  local matched_path = uri
  if string.len(api_path) > 1 then
    matched_path = string.gsub(uri, api_path, "", 1)
  end

  for path, definition in pairs(swagger.paths) do
    if (path == matched_path) then
      -- method
      local request_method = ngx.req.get_method()
      if definition[request_method:lower()] == nil then
        invalid_request("Method " .. request_method .. " is not defined in swagger for endpoint " .. matched_path)
      end
      -- TODO security parse
      return
    end
    -- TODO no exact match - try to find with {id} value - no parsing type
  end

  -- return error
  invalid_request("Requested path " .. matched_path .. " not defined in swagger! ")

end

return plugin
