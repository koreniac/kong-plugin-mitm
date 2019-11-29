local typedefs = require "kong.db.schema.typedefs"

return {
  name = "mitm",
  fields = {
    {run_on = typedefs.run_on_first},
    {protocols = typedefs.protocols_http},
    {
      config = {
        type = "record",
        fields = {
          {upstream_url = {type = "string"}},
          {header_content_type = {type = "string"}},
          {body_json = {type = "string"}}
        }
      }
    }
  }
}
