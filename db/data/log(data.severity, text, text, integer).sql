-- Function: data.log(data.severity, text, text, integer)

-- DROP FUNCTION data.log(data.severity, text, text, integer);

CREATE OR REPLACE FUNCTION data.log(
    in_severity data.severity,
    in_message text,
    in_client text,
    in_login_id integer)
  RETURNS void AS
$BODY$
begin
  insert into data.log(severity, message, client, login_id) values(in_severity, in_message, in_client, in_login_id);
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
