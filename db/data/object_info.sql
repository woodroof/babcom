-- Type: data.object_info

-- DROP TYPE data.object_info;

CREATE TYPE data.object_info AS
   (object_id integer,
    object_code text,
    attribute_codes text[],
    attribute_names text[],
    attribute_values jsonb[],
    attribute_value_descriptions text[],
    attribute_types data.attribute_type[]);
