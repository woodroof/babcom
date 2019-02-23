-- drop function pallas_project.get_debatle_target_audience(text[]);

create or replace function pallas_project.get_debatle_target_audience(in_target_audience text[])
returns text
volatile
as
$$
declare
  v_text text := '';
  v_str text;
begin
  for v_str in (select *
                   from unnest(in_target_audience)) loop
    v_text:= v_text || ', ' || json.get_string_opt(data.get_raw_attribute_value_for_share(data.get_object_id(v_str), 'title'), '');
  end loop;

  v_text := trim(v_text, ', ');

  return v_text;
end;
$$
language plpgsql;
