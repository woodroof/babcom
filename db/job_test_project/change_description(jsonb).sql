-- drop function job_test_project.change_description(jsonb);

create or replace function job_test_project.change_description(in_params jsonb)
returns void
volatile
as
$$
begin
  perform data.change_object_and_notify(
    json.get_integer(in_params, 'object_id'),
    jsonb '[]' || data.attribute_change2jsonb('description', null, in_params->'name'));
end;
$$
language plpgsql;
