-- Table: data.deferred_functions

-- DROP TABLE data.deferred_functions;

CREATE TABLE data.deferred_functions
(
  id serial NOT NULL,
  code text NOT NULL,
  run_time timestamp with time zone NOT NULL,
  function text NOT NULL,
  params jsonb,
  start_time timestamp with time zone NOT NULL DEFAULT now(),
  start_reason text,
  start_object_id integer,
  CONSTRAINT deferred_functions_pk PRIMARY KEY (id)
)
WITH (
  OIDS=FALSE
);

-- Index: data.deferred_functions_idx_code

-- DROP INDEX data.deferred_functions_idx_code;

CREATE INDEX deferred_functions_idx_code
  ON data.deferred_functions
  USING btree
  (code COLLATE pg_catalog."default");

-- Index: data.deferred_functions_idx_rt

-- DROP INDEX data.deferred_functions_idx_rt;

CREATE INDEX deferred_functions_idx_rt
  ON data.deferred_functions
  USING btree
  (run_time);

