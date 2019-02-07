-- drop function pallas_project.fcard_status_page(integer, integer);

create or replace function pallas_project.fcard_status_page(in_object_id integer, in_actor_id integer)
returns void
volatile
as
$$
declare
  v_code text := data.get_object_code(in_object_id);
  v_prefix text := substring(v_code for position('_status_page' in v_code) - 1);
  v_status integer := json.get_integer(data.get_attribute_value(in_actor_id, 'system_person_' || v_prefix || '_status'));
  v_cycle_number integer := data.get_integer_param('economic_cycle_number');
  v_image_suffix text := (case when v_status = 1 then 'bronze' when v_status = 2 then 'silver' when v_status = 3 then 'gold' else '' end);
  v_image_prefix text := (case
    when v_prefix = 'life_support' then 'life'
    when v_prefix = 'health_care' then 'health'
    when v_prefix = 'recreation' then 'recreation'
    when v_prefix = 'police' then 'police'
    when v_prefix = 'administrative_services' then 'adm'
    else '' end);
  v_images_url text := data.get_string_param('images_url');
  v_description_text text := (case when v_status = 0 then '' else '![](' || v_images_url || v_image_prefix || '_' || v_image_suffix || '.svg)' end);
begin
  perform data.change_object_and_notify(
    in_object_id,
    jsonb '[]' ||
    data.attribute_change2jsonb('subtitle', null, to_jsonb(v_cycle_number || ' цикл')) ||
    data.attribute_change2jsonb('description', null, to_jsonb(v_description_text)),
    in_actor_id);
end;
$$
language plpgsql;
