-- drop function pallas_project.get_debatle_person_votes_text(text, integer, jsonb);

create or replace function pallas_project.get_debatle_person_votes_text(in_person text, in_votes integer, in_bonuses jsonb)
returns text
volatile
as
$$
declare
  v_votes text;
  v_bonuses integer;
begin
  select coalesce(sum(x.votes), 0) into v_bonuses from jsonb_to_recordset(coalesce(in_bonuses, jsonb '[]')) as x(code text, name text, votes int);

  v_votes := format('Количество голосов за %s: %s + %s (от судьи) = %s',
                    pp_utils.link(in_person), 
                    in_votes, 
                    v_bonuses, 
                    in_votes + v_bonuses);

  return v_votes;
end;
$$
language plpgsql;
