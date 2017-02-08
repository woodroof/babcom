-- Table: data.log

-- DROP TABLE data.log;

CREATE TABLE data.log
(
  id serial NOT NULL,
  severity data.severity NOT NULL,
  event_time timestamp with time zone NOT NULL DEFAULT now(),
  message text NOT NULL,
  client text,
  login_id integer,
  CONSTRAINT log_pk PRIMARY KEY (id),
  CONSTRAINT log_fk_login FOREIGN KEY (login_id)
      REFERENCES data.logins (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION
)
WITH (
  OIDS=FALSE
);
