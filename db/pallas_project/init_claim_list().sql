-- drop function pallas_project.init_claim_list();

create or replace function pallas_project.init_claim_list()
returns void
volatile
as
$$
begin
  -- a11d2240-3dce-4d75-bc52-46e98b07ff27 Дело о нападении, Феликс Рыбкин
  perform pallas_project.create_claim(
    jsonb_build_object(
      'title', 'Нападение Сьюзан Сидоровой на Феликса Рыбкина',
      'claim_author', 'aebb6773-8651-4afc-851a-83a79a2bcbec',
      'claim_plaintiff', 'aebb6773-8651-4afc-851a-83a79a2bcbec',
      'claim_defendant', 'a11d2240-3dce-4d75-bc52-46e98b07ff27',
      'claim_status', 'processing',
      'claim_text', 'Сообщаю о том, что 04.03.2340 около 16 часов в коридоре сектора B Сьюзан Сидорова напала на меня, Феликса Рыбкина. Ранее она обвиняла меня в некачественно проведённой очистке шахты от радиации, и сейчас выкрикнув то же обвинение, принялась меня избивать.
      Я заверял её, что сделал все работы как нужно, и просил прекратить меня бить. Но она никак не реагировала на мои слова и продолжала.
      В результате мне были нанесены тяжкие телесные повреждения.',
      'claim_time', pp_utils.format_date((timestamp with time zone '2019-03-08 14:00:00') - '3 days'::interval)), 
    'claims_my');
end;
$$
language plpgsql;
