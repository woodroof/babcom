-- Table: data.login_objects

-- DROP TABLE data.login_objects;

CREATE TABLE data.login_objects
(
  id serial NOT NULL,
  login_id integer NOT NULL,
  object_id integer NOT NULL,
  start_time timestamp with time zone NOT NULL DEFAULT now(),
  start_reason text,
  start_object_id integer,
  CONSTRAINT login_objects_pk PRIMARY KEY (id),
  CONSTRAINT login_objects_fk_login FOREIGN KEY (login_id)
      REFERENCES data.logins (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT login_objects_fk_object FOREIGN KEY (object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT login_objects_fk_start_object FOREIGN KEY (start_object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT login_objects_unique_li_oi UNIQUE (login_id, object_id)
)
WITH (
  OIDS=FALSE
);
