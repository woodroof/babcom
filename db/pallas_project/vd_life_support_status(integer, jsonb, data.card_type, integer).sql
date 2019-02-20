-- drop function pallas_project.vd_life_support_status(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_life_support_status(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
stable
as
$$
declare
  v_status integer := json.get_integer(in_value);
begin
  assert v_status in (0, 1, 2, 3);

  if in_card_type = 'mini' then
    if v_status = 0 then
      return 'Нет';
    elsif v_status = 1 then
      return 'Бронзовый';
    elsif v_status = 2 then
      return 'Серебряный';
    else
      return 'Золотой';
    end if;
  else
    if in_value = jsonb '0' then
      return '';
    end if;

    return '![](' || data.get_string_param('images_url') || 'life_' || (case when v_status = 1 then 'bronze' when v_status = 2 then 'silver' else 'gold' end) || '.svg)';
  end if;
end;
$$
language plpgsql;
