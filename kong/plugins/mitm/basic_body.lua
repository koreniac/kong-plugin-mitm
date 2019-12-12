local tablex = require "pl.tablex"
local ngx_ssl = require "ngx.ssl"

local gkong = kong

local table_insert = table.insert
local get_uri_args = kong.request.get_query
local set_uri_args = kong.service.request.set_query
local clear_header = kong.service.request.clear_header
local get_header = kong.request.get_header
local set_header = kong.service.request.set_header
local get_headers = kong.request.get_headers
local set_headers = kong.service.request.set_headers
local set_method = kong.service.request.set_method
local get_raw_body = kong.request.get_raw_body
local set_raw_body = kong.service.request.set_raw_body
local encode_args = ngx.encode_args
local ngx_decode_args = ngx.decode_args
local type = type
local str_find = string.find
local pcall = pcall
local pairs = pairs
local error = error
local rawset = rawset
local pl_copy_table = pl_tablex.deepcopy

local _M = {}

local EMPTY = tablex.readonly({})

function _M.serialize(ngx, kong)
    local ctx = ngx.ctx
    local var = ngx.var
    local req = ngx.req

    if not kong then
        kong = gkong
    end

    local authenticated_entity
    if ctx.authenticated_credential ~= nil then
        authenticated_entity = {
            id = ctx.authenticated_credential.id,
            consumer_id = ctx.authenticated_credential.consumer_id
        }
    end

    local request_tls
    local request_tls_ver = ngx_ssl.get_tls1_version_str()
    if request_tls_ver then
        request_tls = {
            version = request_tls_ver,
            cipher = var.ssl_cipher,
            client_verify = var.ssl_client_verify
        }
    end

    local request_uri = var.request_uri or ""

    return {
        request = {
            uri = request_uri,
            url = var.scheme .. "://" .. var.host .. ":" .. var.server_port .. request_uri,
            querystring = kong.request.get_query(), -- parameters, as a table
            method = kong.request.get_method(), -- http method
            headers = kong.request.get_headers(),
            body = kong.request.get_raw_body(),
            size = var.request_length,
            tls = request_tls
        },
        upstream_uri = var.upstream_uri,
        response = {
            status = ngx.status,
            headers = ngx.resp.get_headers(),
            size = var.bytes_sent
        },
        tries = (ctx.balancer_data or EMPTY).tries,
        latencies = {
            kong = (ctx.KONG_ACCESS_TIME or 0) + (ctx.KONG_RECEIVE_TIME or 0) + (ctx.KONG_REWRITE_TIME or 0) +
                (ctx.KONG_BALANCER_TIME or 0),
            proxy = ctx.KONG_WAITING_TIME or -1,
            request = var.request_time * 1000
        },
        authenticated_entity = authenticated_entity,
        route = ctx.route,
        service = ctx.service,
        consumer = ctx.authenticated_consumer,
        client_ip = var.remote_addr,
        started_at = req.start_time() * 1000
    }
end
local function transform_body(conf)
    local content_type_value = get_header(CONTENT_TYPE)
    local content_type = get_content_type(content_type_value)

    -- Call req_read_body to read the request body first
    local body = get_raw_body()
    local is_body_transformed = false
    local content_length = (body and #body) or 0

    if content_type == ENCODED then
        is_body_transformed, body = transform_url_encoded_body(conf, body, content_length)
    elseif content_type == MULTI then
        is_body_transformed, body = transform_multipart_body(conf, body, content_length, content_type_value)
    elseif content_type == JSON then
        is_body_transformed, body = transform_json_body(conf, body, content_length)
    end

    if is_body_transformed then
        set_raw_body(body)
        set_header(CONTENT_LENGTH, #body)
    end
end
return _M
