-- drop function pallas_project.job_change_packages_status_to_checked(jsonb);

create or replace function pallas_project.job_change_packages_status_to_checked(in_params jsonb)
returns void
volatile
as
$$
declare
  v_t integer;
begin
  for v_t in select json.get_integer(jsonb_array_elements(in_params)) loop
    perform pallas_project.act_customs_package_set_status(null, null, jsonb_build_object('package_code', data.get_object_code(v_t), 'status', 'checked', 'job', true), null, null);
  end loop;
end;
$$
language plpgsql;
