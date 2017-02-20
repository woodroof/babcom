-- Table: data.attribute_values

-- DROP TABLE data.attribute_values;

CREATE TABLE data.attribute_values
(
  id serial NOT NULL,
  object_id integer NOT NULL,
  attribute_id integer NOT NULL,
  value_object_id integer,
  value jsonb,
  start_time timestamp with time zone NOT NULL DEFAULT now(),
  start_reason text,
  start_object_id integer,
  CONSTRAINT attribute_values_pk PRIMARY KEY (id),
  CONSTRAINT attribute_values_fk_attribute FOREIGN KEY (attribute_id)
      REFERENCES data.attributes (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT attribute_values_fk_object FOREIGN KEY (object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT attribute_values_fk_start_object FOREIGN KEY (start_object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT attribute_values_fk_value_object FOREIGN KEY (value_object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION
)
WITH (
  OIDS=FALSE
);

-- Index: data.attribute_values_idx_oi_ai

-- DROP INDEX data.attribute_values_idx_oi_ai;

CREATE UNIQUE INDEX attribute_values_idx_oi_ai
  ON data.attribute_values
  USING btree
  (object_id, attribute_id)
  WHERE value_object_id IS NULL;

-- Index: data.attribute_values_idx_oi_ai_voi

-- DROP INDEX data.attribute_values_idx_oi_ai_voi;

CREATE UNIQUE INDEX attribute_values_idx_oi_ai_voi
  ON data.attribute_values
  USING btree
  (object_id, attribute_id, value_object_id)
  WHERE value_object_id IS NOT NULL;

-- Index: data.attribute_values_nuidx_oi_ai

-- DROP INDEX data.attribute_values_nuidx_oi_ai;

CREATE INDEX attribute_values_nuidx_oi_ai
  ON data.attribute_values
  USING btree
  (object_id, attribute_id);

