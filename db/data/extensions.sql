-- Table: data.extensions

-- DROP TABLE data.extensions;

CREATE TABLE data.extensions
(
  code text NOT NULL,
  CONSTRAINT extensions_unique_code UNIQUE (code)
)
WITH (
  OIDS=FALSE
);
