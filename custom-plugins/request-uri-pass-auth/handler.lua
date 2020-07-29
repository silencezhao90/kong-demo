
local RequestUriPassAuthHandler = {
  VERSION = "1.0.0",
  PRIORITY = 2001,
}

function RequestUriPassAuthHandler:header_filter(conf)
  kong.response.set_header("uri pass auth ", conf.whitelist)
end

function RequestUriPassAuthHandler:access(conf)
  -- check request is enable passed with uri auth
  if kong.request.get_method() == "OPTIONS" then
    return
  end

  uri_path = kong.request.get_path()
  local is_whitelist = conf.whitelist
  local passed = false

  if is_whitelist then
    for _, v in ipairs(conf.prefixs) do
      if string.sub(uri_path, 0, string.len(v)) == v then
        passed = true
      end
    end

  else
    passed = true
  end

  if not passed then
    kong.response.exit(401, { message = "not access permission" })
  end
end

return RequestUriPassAuthHandler
