-- Table: data.attributes

-- DROP TABLE data.attributes;

CREATE TABLE data.attributes
(
  id serial NOT NULL,
  code text NOT NULL,
  name text,
  description text,
  type data.attribute_type NOT NULL,
  value_description_function text, -- (user_object_id, attribute_id, value)
  CONSTRAINT attributes_pk PRIMARY KEY (id),
  CONSTRAINT attributes_unique_code UNIQUE (code)
)
WITH (
  OIDS=FALSE
);
COMMENT ON COLUMN data.attributes.value_description_function IS '(user_object_id, attribute_id, value)';

