
return {
  name = "request-uri-pass-auth",
  fields = {
    {
      config = {
        type = "record",
        fields = {
          { whitelist = { type = "boolean", default = true }, },
          { prefixs = { type = "set", elements = { type = "string" }, default = {} }, },
        },
      },
    },
  }
}
