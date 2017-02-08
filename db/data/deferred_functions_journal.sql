-- Table: data.deferred_functions_journal

-- DROP TABLE data.deferred_functions_journal;

CREATE TABLE data.deferred_functions_journal
(
  id serial NOT NULL,
  code text NOT NULL,
  run_time timestamp with time zone NOT NULL,
  function text NOT NULL,
  params jsonb,
  start_time timestamp with time zone NOT NULL DEFAULT now(),
  start_reason text,
  start_object_id integer,
  end_time timestamp with time zone NOT NULL,
  end_reason text,
  end_object_id integer,
  CONSTRAINT deferred_functions_journal_pk PRIMARY KEY (id)
)
WITH (
  OIDS=FALSE
);
