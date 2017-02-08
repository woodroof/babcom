-- Table: data.client_login

-- DROP TABLE data.client_login;

CREATE TABLE data.client_login
(
  id serial NOT NULL,
  client text NOT NULL,
  login_id integer NOT NULL,
  start_time timestamp with time zone NOT NULL DEFAULT now(),
  start_reason text,
  start_object_id integer,
  CONSTRAINT client_login_pk PRIMARY KEY (id),
  CONSTRAINT client_login_fk_login FOREIGN KEY (login_id)
      REFERENCES data.logins (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT client_login_fk_start_object FOREIGN KEY (start_object_id)
      REFERENCES data.objects (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT client_login_unique_client UNIQUE (client)
)
WITH (
  OIDS=FALSE
);
