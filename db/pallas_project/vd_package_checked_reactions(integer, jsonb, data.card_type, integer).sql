-- drop function pallas_project.vd_package_checked_reactions(integer, jsonb, data.card_type, integer);

create or replace function pallas_project.vd_package_checked_reactions(in_attribute_id integer, in_value jsonb, in_card_type data.card_type, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_text_value text := '';
  v_record record;
begin
  for v_record in (select * from jsonb_each_text(in_value)) loop
    case 
    when v_record.key = 'life' then
      v_text_value := v_text_value || 'запрещённые вещества или любые формы жизни: ';
    when v_record.key = 'radiation' then
      v_text_value := v_text_value || 'радиация: ';
    when v_record.key = 'metal' then
      v_text_value := v_text_value || 'металл: ';
    else
      null;
    end case;
    case 
    when v_record.value then v_text_value := v_text_value || 'да, ';
    else v_text_value := v_text_value || 'нет, ';
    end case;
  end loop;
  return trim(v_text_value, ', ');
end;
$$
language plpgsql;
