-- Table: data.logins

-- DROP TABLE data.logins;

CREATE TABLE data.logins
(
  id serial NOT NULL,
  description text,
  is_admin boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  CONSTRAINT logins_pk PRIMARY KEY (id)
)
WITH (
  OIDS=FALSE
);
