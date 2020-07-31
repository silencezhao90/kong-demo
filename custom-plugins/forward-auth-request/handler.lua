-- /*
--  * @Author: zhaobo 
--  * @Date: 2020-07-29 15:26:49 
--  * @Last Modified by:   zhaobo 
--  * @Last Modified time: 2020-07-29 15:26:49 
--  */

local http = require "resty.http"

local ForwardAuthRequestHandler = {
    VERSION = "1.0.0",
    PRIORITY = 2001,
}

function ForwardAuthRequestHandler:header_filter(conf)
    kong.response.set_header("uri pass auth ", conf.whitelist)
end

function ForwardAuthRequestHandler:access(conf)
    if kong.request.get_method() == "OPTIONS" then
        return
    end

    uri_path = kong.request.get_path()
    local is_whitelist = conf.whitelist
    local passed = false
    -- TODO: 判断白名单路由，这个白名单下的路由不需要做鉴权
    token = kong.request.get_query_arg("token")
    headers = kong.request.get_headers()
    kong.response.set_header("forward-auth-request set headers", headers)

    -- 转发auth server做鉴权校验
    local client = assert(http.new())
    assert(client:connect("test-auth", 8001))
    local res = assert(client:request {
        method = "GET",
        path = "/?token="..token
    })

    if res.status == 200 then
        passed = true
    else
        kong.response.exit(res.status, { message = "auth acess pass" })
    end
end

return ForwardAuthRequestHandler

-- local client = assert(http.new())
-- assert(client:connect("test-auth", 8001))

-- local res = assert(client:request {
--     method = "GET",
--     path = "/"
-- })

-- res:read_body()
-- client:close()
-- if res.status == 200 then
--     print("pass")
-- else
--     print("no pass")
-- end
-- assert.equals(200, res.status)

-- local http = require("socket.http")
-- local ltn12 = require("ltn12")

-- local response_body = {}

-- local res, code = http.request{
--     url = "http://127.0.0.1:8000/lookup",
--     method = "GET",
--     sink = ltn12.sink.table(response_body)
-- }
-- print(res)
-- print(code)

-- if code == 200 then
--     print("pass")
-- else
--     print("no pass")
-- end
