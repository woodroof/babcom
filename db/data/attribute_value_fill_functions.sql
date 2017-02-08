-- Table: data.attribute_value_fill_functions

-- DROP TABLE data.attribute_value_fill_functions;

CREATE TABLE data.attribute_value_fill_functions
(
  id serial NOT NULL,
  attribute_id integer NOT NULL,
  function text NOT NULL, -- coalesce(params, jsonb '{}') || jsonb_build_object('user_object_id', <user_obj_id>, 'object_id', <obj_id>, 'attribute_id', <attr_id>)
  params jsonb,
  description text,
  CONSTRAINT attribute_value_fill_functions_pk PRIMARY KEY (id),
  CONSTRAINT attribute_value_fill_functions_fk_attributes FOREIGN KEY (attribute_id)
      REFERENCES data.attributes (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT attribute_value_fill_functions_unique_ai UNIQUE (attribute_id)
)
WITH (
  OIDS=FALSE
);
COMMENT ON COLUMN data.attribute_value_fill_functions.function IS 'coalesce(params, jsonb ''{}'') || jsonb_build_object(''user_object_id'', <user_obj_id>, ''object_id'', <obj_id>, ''attribute_id'', <attr_id>)';

