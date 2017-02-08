-- Table: data.attribute_values_journal

-- DROP TABLE data.attribute_values_journal;

CREATE TABLE data.attribute_values_journal
(
  id serial NOT NULL,
  object_id integer NOT NULL,
  attribute_id integer NOT NULL,
  value_object_id integer,
  value jsonb,
  start_time timestamp with time zone NOT NULL,
  start_reason text,
  start_object_id integer,
  end_time timestamp with time zone NOT NULL,
  end_reason text,
  end_object_id integer,
  CONSTRAINT attribute_values_journal_pk PRIMARY KEY (id),
  CONSTRAINT attribute_values_journal_fk_attribute FOREIGN KEY (attribute_id)
      REFERENCES data.attributes (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT attribute_values_journal_fk_end_object FOREIGN KEY (end_object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT attribute_values_journal_fk_object FOREIGN KEY (object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT attribute_values_journal_fk_start_object FOREIGN KEY (start_object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT attribute_values_journal_fk_value_object FOREIGN KEY (value_object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION
)
WITH (
  OIDS=FALSE
);
