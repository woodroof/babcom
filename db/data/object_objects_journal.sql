-- Table: data.object_objects_journal

-- DROP TABLE data.object_objects_journal;

CREATE TABLE data.object_objects_journal
(
  id serial NOT NULL,
  parent_object_id integer NOT NULL,
  object_id integer NOT NULL,
  intermediate_object_ids integer[],
  start_time timestamp with time zone NOT NULL,
  end_time timestamp with time zone NOT NULL,
  CONSTRAINT object_objects_journal_pk PRIMARY KEY (id),
  CONSTRAINT object_objects_journal_fk_object FOREIGN KEY (object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT object_objects_journal_fk_parent_object FOREIGN KEY (parent_object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION
)
WITH (
  OIDS=FALSE
);
