-- drop function pallas_project.vd_debatle_bonuses(integer, jsonb, integer);

create or replace function pallas_project.vd_debatle_bonuses(in_attribute_id integer, in_value jsonb, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_text_value text := '';
  v_bonuses record;
begin
  for v_bonuses in select x.name, x.votes from jsonb_to_recordset(in_value) as x(code text, name text, votes int) order by x.votes desc, x.name
  loop
    if @ v_bonuses.votes%10 = 1 then
      v_text_value := v_text_value || v_bonuses.votes || ' голос за ' || v_bonuses.name || '
';
    else
      v_text_value := v_text_value || v_bonuses.votes || ' голосов за ' || v_bonuses.name || '
';
    end if;
  end loop;
  if v_text_value <> '' then
    v_text_value := '
' || v_text_value;
  end if;
  return v_text_value;
end;
$$
language plpgsql;
