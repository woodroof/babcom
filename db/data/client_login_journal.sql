-- Table: data.client_login_journal

-- DROP TABLE data.client_login_journal;

CREATE TABLE data.client_login_journal
(
  id serial NOT NULL,
  client text NOT NULL,
  login_id integer NOT NULL,
  start_time timestamp with time zone NOT NULL,
  start_reason text,
  start_object_id integer,
  end_time timestamp with time zone NOT NULL,
  end_reason text,
  end_object_id integer,
  CONSTRAINT client_login_journal_pk PRIMARY KEY (id),
  CONSTRAINT client_login_journal_fk_end_object FOREIGN KEY (end_object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT client_login_journal_fk_login FOREIGN KEY (login_id)
      REFERENCES data.logins (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT client_login_journal_fk_start_object FOREIGN KEY (start_object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION
)
WITH (
  OIDS=FALSE
);
