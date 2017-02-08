-- Table: data.objects

-- DROP TABLE data.objects;

CREATE TABLE data.objects
(
  id serial NOT NULL,
  code text NOT NULL DEFAULT (pgcrypto.gen_random_uuid())::text,
  CONSTRAINT objects_pk PRIMARY KEY (id),
  CONSTRAINT objects_unique_code UNIQUE (code)
)
WITH (
  OIDS=FALSE
);

-- Trigger: objects_trigger_after_insert on data.objects

-- DROP TRIGGER objects_trigger_after_insert ON data.objects;

CREATE TRIGGER objects_trigger_after_insert
  AFTER INSERT
  ON data.objects
  FOR EACH ROW
  EXECUTE PROCEDURE data.objects_after_insert();

