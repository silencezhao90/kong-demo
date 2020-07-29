
return {
    name = "formard-auth-request",
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
  