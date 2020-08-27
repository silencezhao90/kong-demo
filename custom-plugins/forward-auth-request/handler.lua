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

  token = kong.request.get_header("Token")
  uri_path = kong.request.get_path()
  -- 转发auth server做鉴权校验
  local body = {
    token = token,
    path = uri_path
  }

  local client = http.new()
  assert(client:connect("test-auth.default.svc.cluster.local", 8080))
  local res, err = client:request {
      method = "POST",
      path = "/api/v1/auth",
      body = body,
  }
  if not res then
    kong.response.exit(res.status, { message = "failed to request: "..err})
  else
    if res.status == 200 then
      -- TODO: 设置请求头用户信息
      local set_header = kong.service.request.set_header
      set_header("Authorization", res:read_body())
      client:close()
      passed = true
    else
      kong.response.exit(res.status, { message = "auth not pass"})
    end
  end
end

return ForwardAuthRequestHandler