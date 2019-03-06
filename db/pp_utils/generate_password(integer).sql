-- drop function pp_utils.generate_password(integer);

create or replace function pp_utils.generate_password(in_length integer default 4)
returns text
volatile
as
$$
declare
  v_chars text[] := '{0,1,2,3,4,5,6,7,8,9,a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z}';
  v_chars_len integer := array_length(v_chars, 1);
  v_password text = '';
begin
  assert in_length > 0;

  for i in 1..in_length loop
    v_password := v_password || v_chars[random.random_integer(1, v_chars_len)];
  end loop;

  return v_password;
end;
$$
language plpgsql;
