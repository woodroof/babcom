-- Table: data.attribute_value_change_functions

-- DROP TABLE data.attribute_value_change_functions;

CREATE TABLE data.attribute_value_change_functions
(
  id serial NOT NULL,
  attribute_id integer NOT NULL,
  function text NOT NULL, -- coalesce(params, jsonb '{}') || jsonb_build_object('user_object_id', <user_obj_id>, 'object_id', <obj_id>, 'attribute_id', <attr_id>, 'value_object_id', <value_obj_id>, 'old_value', <old_value>, 'new_value', <new_value>)
  params jsonb,
  description text,
  CONSTRAINT attribute_value_change_functions_pk PRIMARY KEY (id),
  CONSTRAINT attribute_value_change_functions_fk_attributes FOREIGN KEY (attribute_id)
      REFERENCES data.attributes (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION
)
WITH (
  OIDS=FALSE
);
COMMENT ON COLUMN data.attribute_value_change_functions.function IS 'coalesce(params, jsonb ''{}'') || jsonb_build_object(''user_object_id'', <user_obj_id>, ''object_id'', <obj_id>, ''attribute_id'', <attr_id>, ''value_object_id'', <value_obj_id>, ''old_value'', <old_value>, ''new_value'', <new_value>)';


-- Index: data.attribute_value_change_functions_idx_attribute_id

-- DROP INDEX data.attribute_value_change_functions_idx_attribute_id;

CREATE INDEX attribute_value_change_functions_idx_attribute_id
  ON data.attribute_value_change_functions
  USING btree
  (attribute_id);

