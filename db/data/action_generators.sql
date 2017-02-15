-- Table: data.action_generators

-- DROP TABLE data.action_generators;

CREATE TABLE data.action_generators
(
  id serial NOT NULL,
  code text NOT NULL DEFAULT (pgcrypto.gen_random_uuid())::text,
  function text NOT NULL, -- coalesce(params, jsonb '{}') || jsonb_build_object('user_object_id', <user_obj_id>, 'object_id', <obj_id> | null)
  params jsonb,
  description text,
  CONSTRAINT action_generators_pk PRIMARY KEY (id),
  CONSTRAINT action_generators_unique_code UNIQUE (code)
)
WITH (
  OIDS=FALSE
);
COMMENT ON COLUMN data.action_generators.function IS 'coalesce(params, jsonb ''{}'') || jsonb_build_object(''user_object_id'', <user_obj_id>, ''object_id'', <obj_id> | null)';

