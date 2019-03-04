-- drop function pallas_project.vd_package_reactions(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_package_reactions(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_text_value text := '';
  v_t text;
begin
  for v_t in select json.get_string(jsonb_array_elements(in_value)) loop
    case 
    when v_t = 'life' then
      v_text_value := v_text_value || 'запрещённые вещества и формы жизни, ';
    when v_t = 'radiation' then
      v_text_value := v_text_value || 'радиация, ';
    when v_t = 'metal' then
      v_text_value := v_text_value || 'металл, ';
    else
      null;
    end case;
  end loop;
  return trim(v_text_value, ', ');
end;
$$
language plpgsql;
