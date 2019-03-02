-- drop function pallas_project.vd_blog_is_confirmed(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_blog_is_confirmed(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_bool_value boolean := json.get_boolean_opt(in_value, false);
begin
  case when v_bool_value then
    return '✔ Подтверждённый блог';
  else
    return null;
  end case;
end;
$$
language plpgsql;
