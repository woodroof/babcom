-- Function: data.create_checksum(integer, text, text, jsonb)

-- DROP FUNCTION data.create_checksum(integer, text, text, jsonb);

CREATE OR REPLACE FUNCTION data.create_checksum(
    in_user_object_id integer,
    in_generator_code text,
    in_action_code text,
    in_params jsonb)
  RETURNS text AS
$BODY$
begin
  assert in_user_object_id is not null;
  assert in_generator_code is not null;
  assert in_action_code is not null;

  return encode(pgcrypto.digest(in_user_object_id::text || in_generator_code || in_action_code || coalesce(in_params::text, '{}'), 'sha256'), 'base64');
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
