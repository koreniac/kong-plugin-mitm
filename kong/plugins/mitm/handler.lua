local http_log = require "kong.plugins.mitm.http_log"
local BasePlugin = require "kong.plugins.base_plugin"
-- local body_transformer = require "kong.plugins.response-transformer.body_transformer"
-- local header_transformer = require "kong.plugins.response-transformer.header_transformer"

-- local is_body_transform_set = header_transformer.is_body_transform_set
-- local is_json_body = header_transformer.is_json_body
local concat = table.concat
local kong = kong
local ngx = ngx
local get_raw_body = nil
-- local is_body_transform_set = header_transformer.is_body_transform_set
-- local is_json_body = header_transformer.is_json_body

local MitmHandler = BasePlugin:extend()

function MitmHandler:new()
  MitmHandler.super.new(self, "Mitm")
end

function MitmHandler:access(conf)
  get_raw_body = http_log.getRawBody(conf)
end
function MitmHandler:log(conf)
  local response_code = kong.response.get_status()
  local status = conf.status_code
  local flush_case = conf.flush_case
  local content = nil
  if (flush_case == "FAILED" and response_code >= 400) then
    http_log.log(conf, get_raw_body)
  elseif (flush_case == "SUCCESS" and response_code < 400) then
    http_log.log(conf, get_raw_body)
  elseif flush_case == "ALL" then
    http_log.log(conf, get_raw_body)
  end
end

MitmHandler.PRIORITY = 1900
MitmHandler.VERSION = "0.3.0"

return MitmHandler
