-- Type: data.attribute_value_info

-- DROP TYPE data.attribute_value_info;

CREATE TYPE data.attribute_value_info AS
   (last_modified timestamp with time zone,
    value jsonb);
