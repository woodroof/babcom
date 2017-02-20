-- Table: data.object_objects

-- DROP TABLE data.object_objects;

CREATE TABLE data.object_objects
(
  id serial NOT NULL,
  parent_object_id integer NOT NULL,
  object_id integer NOT NULL,
  intermediate_object_ids integer[],
  start_time timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT object_objects_pk PRIMARY KEY (id),
  CONSTRAINT object_objects_fk_object FOREIGN KEY (object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT object_objects_fk_parent_object FOREIGN KEY (parent_object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT object_objects_intermediate_object_ids_check CHECK (intarray.uniq(intarray.sort(intermediate_object_ids)) = intarray.sort(intermediate_object_ids))
)
WITH (
  OIDS=FALSE
);

-- Index: data.object_objects_idx_loi_goi

-- DROP INDEX data.object_objects_idx_loi_goi;

CREATE UNIQUE INDEX object_objects_idx_loi_goi
  ON data.object_objects
  USING btree
  ((LEAST(parent_object_id, object_id)), (GREATEST(parent_object_id, object_id)))
  WHERE intermediate_object_ids IS NULL;

-- Index: data.object_objects_idx_oi

-- DROP INDEX data.object_objects_idx_oi;

CREATE INDEX object_objects_idx_oi
  ON data.object_objects
  USING btree
  (object_id);

-- Index: data.object_objects_idx_poi_oi

-- DROP INDEX data.object_objects_idx_poi_oi;

CREATE UNIQUE INDEX object_objects_idx_poi_oi
  ON data.object_objects
  USING btree
  (parent_object_id, object_id)
  WHERE intermediate_object_ids IS NULL;

-- Index: data.object_objects_idx_poi_oi_ioi

-- DROP INDEX data.object_objects_idx_poi_oi_ioi;

CREATE UNIQUE INDEX object_objects_idx_poi_oi_ioi
  ON data.object_objects
  USING btree
  (parent_object_id, object_id, intarray.uniq(intarray.sort(intermediate_object_ids)))
  WHERE intermediate_object_ids IS NOT NULL;

-- Index: data.object_objects_nuidx_poi_oi

-- DROP INDEX data.object_objects_nuidx_poi_oi;

CREATE INDEX object_objects_nuidx_poi_oi
  ON data.object_objects
  USING btree
  (parent_object_id, object_id);

