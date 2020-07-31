-- /*
--  * @Author: zhaobo 
--  * @Date: 2020-07-29 15:26:49 
--  * @Last Modified by:   zhaobo 
--  * @Last Modified time: 2020-07-29 15:26:49 
--  */

local http = require "resty.http"

local ForwardAuthRequestHandler = {
  VERSION = "1.0.0",
  PRIORITY = 2002,
}

function ForwardAuthRequestHandler:header_filter(conf)
  kong.response.set_header("uri pass auth2 ", conf.whitelist)
end

function ForwardAuthRequestHandler:access(conf)
  if kong.request.get_method() == "OPTIONS" then
    return
  end
  -- TODO: 判断白名单路由，这个白名单下的路由不需要做鉴权
  -- token = kong.request.get_header("Token")

  token = kong.request.get_header("Token")
  -- 转发auth server做鉴权校验
  local client = http.new()
    assert(client:connect("10.106.50.80", 8001))
    local res = client:request {
        method = "GET",
        path = "/?token="..token
    }

    if res.status == 200 then
        passed = true
    else
        kong.response.exit(res.status, { message = "auth acess pass"..token })
    end
end

return ForwardAuthRequestHandler