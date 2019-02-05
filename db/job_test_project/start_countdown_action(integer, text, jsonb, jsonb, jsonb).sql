-- drop function job_test_project.start_countdown_action(integer, text, jsonb, jsonb, jsonb);

create or replace function job_test_project.start_countdown_action(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_object_id integer := data.get_active_actor_id(in_client_id);
  v_time timestamp with time zone := now();
begin
  perform data.change_current_object(
    in_client_id,
    in_request_id,
    v_object_id,
    jsonb '[]' || data.attribute_change2jsonb('state', null, jsonb '"state2"') || data.attribute_change2jsonb('description', null, jsonb '"Ждём начала обратного отсчёта..."'));

  perform data.create_job(v_time + interval '4 second', 'job_test_project.change_description', format('{"name": "4", "object_id": %s}', v_object_id)::jsonb);
  perform data.create_job(v_time + interval '3 second', 'job_test_project.change_description', format('{"name": "5", "object_id": %s}', v_object_id)::jsonb);
  perform data.create_job(v_time + interval '5 second', 'job_test_project.change_description', format('{"name": "3", "object_id": %s}', v_object_id)::jsonb);
  perform data.create_job(v_time + interval '6 second', 'job_test_project.change_description', format('{"name": "2", "object_id": %s}', v_object_id)::jsonb);
  perform data.create_job(v_time + interval '7 second', 'job_test_project.change_description', format('{"name": "1", "object_id": %s}', v_object_id)::jsonb);
  perform data.create_job(v_time + interval '8 second', 'job_test_project.change_description', format('{"name": "Ignition!", "object_id": %s}', v_object_id)::jsonb);
end;
$$
language plpgsql;
