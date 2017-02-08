-- Table: data.params

-- DROP TABLE data.params;

CREATE TABLE data.params
(
  id serial NOT NULL,
  code text NOT NULL,
  value jsonb NOT NULL,
  description text,
  CONSTRAINT params_pk PRIMARY KEY (id),
  CONSTRAINT params_unique_code UNIQUE (code)
)
WITH (
  OIDS=FALSE
);
