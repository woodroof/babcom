-- drop function pallas_project.init_players();

create or replace function pallas_project.init_players()
returns void
volatile
as
$$
begin
  perform pallas_project.create_person(
    'b7845724-0c9a-498e-8b2f-a01455c22399',
    'b784',
    jsonb '{
      "title":"Фрида Фогель",
      "description":"Временно исполняющий обязанности губернатора. Землянин. Член совета станции.",
      "person_state":"un",
      "person_district":"sector_A",
      "person_un_rating":570,
      "person_occupation":"И.о. губернатора, секретарь администрации",
      "person_opa_rating":1,
      "system_person_economy_type":"un",
      "system_person_police_status":3,
      "system_person_recreation_status":3,
      "system_person_health_care_status":3,
      "system_person_life_support_status":3,
      "system_person_administrative_services_status":3
    }',
    array['all_person', 'player', 'un']);
  perform pallas_project.create_person(
    '0d07f15b-2952-409b-b22e-4042cf70acc6',
    '0d07',
    jsonb '{
      "title":"Саша Корсак",
      "description":"Специалист, ответственный за экономическую деятельность колонии. Землянин. Член совета станции.",
      "person_state":"un",
      "person_district":"sector_A",
      "person_un_rating":460,
      "person_occupation":"Главный экономист",
      "person_opa_rating":1,
      "system_person_economy_type":"un",
      "system_person_police_status":2,
      "system_person_recreation_status":2,
      "system_person_health_care_status":2,
      "system_person_life_support_status":3,
      "system_person_administrative_services_status":3
    }',
    array['all_person', 'player', 'un']);
  perform pallas_project.create_person(
    '9b956c40-7978-4b0a-993e-8373fe581761',
    '9b95',
    jsonb '{
      "title":"Сергей Корсак",
      "description":"Верховный судья колонии. Землянин. Член совета станции.",
      "person_state":"un",
      "person_district":"sector_A",
      "person_un_rating":420,
      "person_occupation":"Судья",
      "person_opa_rating":1,
      "system_person_economy_type":"un",
      "system_person_police_status":2,
      "system_person_recreation_status":2,
      "system_person_health_care_status":2,
      "system_person_life_support_status":3,
      "system_person_administrative_services_status":3
    }',
    array['all_person', 'player', 'un']);
  perform pallas_project.create_person(
    '7545edc8-d3f8-4ff3-a984-6c96e261f5c5',
    '7545',
    jsonb '{
      "title":"Михаил Ситников",
      "description":"Единственный астер, работающий в администрации.",
      "system_money":165,
      "person_district":"sector_B",
      "person_occupation":"Специалист по связям с общественностью",
      "person_opa_rating":1,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":1500,
      "system_person_police_status":1,
      "system_person_recreation_status":2,
      "system_person_health_care_status":2,
      "system_person_life_support_status":1,
      "system_person_administrative_services_status":1
    }',
    array['all_person', 'player', 'aster']);
  perform pallas_project.create_person(
    '494dd323-d808-48e6-8971-cd8f18656ec0',
    '494d',
    jsonb '{
      "title":"Кара Трэйс",
      "description":"Выпускница звёздной академии ООН им. Н. Армстронга. Деятельная личность. Идеалистка и гуманистка. Младший лейтенант. Землянин. Представитель Министерства обороны ООН на Палладе. Член совета станции.",
      "person_state":"un",
      "person_district":"sector_B",
      "person_un_rating":230,
      "person_occupation":"Военный атташе",
      "person_opa_rating":1,
      "system_person_economy_type":"un",
      "system_person_police_status":2,
      "system_person_recreation_status":2,
      "system_person_health_care_status":2,
      "system_person_life_support_status":2,
      "system_person_administrative_services_status":2
    }',
    array['all_person', 'player', 'un']);
  perform pallas_project.create_person(
    '95a3dc9e-8512-44ab-9173-29f0f4fd6e05',
    '95a3',
    jsonb '{
      "title":"Рон Портер",
      "description":"Учёный. Эколог. Землянин. Член совета станции.",
      "person_state":"un",
      "person_district":"sector_B",
      "person_un_rating":410,
      "person_occupation":"Главный инженер",
      "person_opa_rating":1,
      "system_person_economy_type":"un",
      "system_person_police_status":2,
      "system_person_recreation_status":2,
      "system_person_health_care_status":2,
      "system_person_life_support_status":3,
      "system_person_administrative_services_status":3
    }',
    array['all_person', 'player', 'un']);
  perform pallas_project.create_person(
    'aebb6773-8651-4afc-851a-83a79a2bcbec',
    'aebb',
    jsonb '{
      "title":"Феликс Рыбкин",
      "description":"Известный учёный-астроном. Землянин.",
      "person_state":"un",
      "person_district":"sector_B",
      "person_un_rating":660,
      "person_occupation":"Инженер",
      "person_opa_rating":1,
      "system_person_economy_type":"un",
      "system_person_police_status":3,
      "system_person_recreation_status":3,
      "system_person_health_care_status":3,
      "system_person_life_support_status":3,
      "system_person_administrative_services_status":3
    }',
    array['all_person', 'player', 'un']);
  perform pallas_project.create_person(
    '5f7c2dc0-0cb4-4fc5-870c-c0776272a02e',
    '5f7c',
    jsonb '{
      "title":"Люк Ламбер",
      "description":"Опытный инженер. Член СВП. Астер.",
      "system_money":75,
      "person_district":"sector_D",
      "person_occupation":"Ремонтник",
      "person_opa_rating":4,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":750,
      "system_person_police_status":1,
      "system_person_recreation_status":1,
      "system_person_health_care_status":1,
      "system_person_life_support_status":2,
      "system_person_administrative_services_status":1
    }',
    array['all_person', 'player', 'aster', 'opa']);
  perform pallas_project.create_person(
    '4cb29808-bc92-4cf8-a755-a3f0785ac4b8',
    '4cb2',
    jsonb '{
      "title":"Кристиан Остерхаген",
      "description":"Работник администрации. Астер.",
      "system_money":75,
      "person_district":"sector_D",
      "person_occupation":"Инженер-электронщик",
      "person_opa_rating":1,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":750,
      "system_person_police_status":1,
      "system_person_recreation_status":1,
      "system_person_health_care_status":1,
      "system_person_life_support_status":2,
      "system_person_administrative_services_status":1
    }',
    array['all_person', 'player', 'aster']);
  perform pallas_project.create_person(
    '784e4126-8dd7-41a3-a916-0fdc53a31ce2',
    '784e',
    jsonb '{
      "title":"Мишон Грэй",
      "description":"Начальник филиала компании Де Бирс на астероиде Паллада. Землянин.",
      "person_state":"un",
      "person_district":"sector_A",
      "person_un_rating":430,
      "person_occupation":"Начальник филиала Де Бирс",
      "person_opa_rating":1,
      "system_person_economy_type":"un",
      "system_person_police_status":2,
      "system_person_recreation_status":2,
      "system_person_health_care_status":2,
      "system_person_life_support_status":3,
      "system_person_administrative_services_status":3
    }',
    array['all_person', 'player', 'un']);
  perform pallas_project.create_person(
    '0a0dc809-7bf1-41ee-bfe7-700fd26c1c0a',
    '0a0d',
    jsonb '{
      "title":"Абрахам Грей",
      "description":"Заместитель начальника филиала Де Бирс на астероиде Паллада.",
      "system_money":240,
      "person_district":"sector_A",
      "person_occupation":"Зам. начальника филиала Де Бирс",
      "person_opa_rating":1,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":2000,
      "system_person_police_status":2,
      "system_person_recreation_status":2,
      "system_person_health_care_status":2,
      "system_person_life_support_status":2,
      "system_person_administrative_services_status":1,
      "system_person_miner_skill":1
    }',
    array['all_person', 'player', 'aster', 'cartel']);
  perform pallas_project.create_person(
    '5074485d-73cd-4e19-8d4b-4ffedcf1fb5f',
    '5074',
    jsonb '{
      "title":"Лаура Джаррет",
      "description":"Глава профсоюза шахтёров. Член СВП. Астер.",
      "system_money":75,
      "person_district":"sector_F",
      "person_occupation":"Бригадир шахтёров",
      "person_opa_rating":3,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":200,
      "system_person_police_status":1,
      "system_person_recreation_status":1,
      "system_person_health_care_status":1,
      "system_person_life_support_status":2,
      "system_person_administrative_services_status":1,
      "system_person_miner_skill":1
    }',
    array['all_person', 'player', 'aster', 'opa']);
  perform pallas_project.create_person(
    '82d0dbb5-0c9b-412c-810f-79827370c37f',
    '82d0',
    jsonb '{
      "title":"Невил Гонзалес",
      "description":"Астер.",
      "system_money":43,
      "person_district":"sector_F",
      "person_occupation":"Шахтёр",
      "person_opa_rating":1,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":73,
      "system_person_police_status":0,
      "system_person_recreation_status":1,
      "system_person_health_care_status":1,
      "system_person_life_support_status":2,
      "system_person_administrative_services_status":0
    }',
    array['all_person', 'player', 'aster']);
  perform pallas_project.create_person(
    'a11d2240-3dce-4d75-bc52-46e98b07ff27',
    'a11d',
    jsonb '{
      "title":"Сьюзан Сидорова",
      "description":"Астер.",
      "system_money":43,
      "person_district":"sector_D",
      "person_occupation":"Шахтёр",
      "person_opa_rating":3,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":224,
      "system_person_police_status":0,
      "system_person_recreation_status":1,
      "system_person_health_care_status":1,
      "system_person_life_support_status":2,
      "system_person_administrative_services_status":0
    }',
    array['all_person', 'player', 'aster']);
  perform pallas_project.create_person(
    '3beea660-35a3-431e-b9ae-e2e88e6ac064',
    '3bee',
    jsonb '{
      "title":"Джеф Бриджес",
      "description":"Астер.",
      "system_money":75,
      "person_district":"sector_F",
      "person_occupation":"Бригадир шахтёров",
      "person_opa_rating":2,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":91,
      "system_person_police_status":1,
      "system_person_recreation_status":1,
      "system_person_health_care_status":1,
      "system_person_life_support_status":2,
      "system_person_administrative_services_status":1
    }',
    array['all_person', 'player', 'aster', 'opa']);
  perform pallas_project.create_person(
    '09951000-d915-495d-867d-4d0e7ebfcf9c',
    '0995',
    jsonb '{
      "title":"Аарон Краузе",
      "description":"Опытный шахтёр. Астер.",
      "system_money":61,
      "person_district":"sector_F",
      "person_occupation":"Шахтёр",
      "person_opa_rating":1,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":650,
      "system_person_police_status":1,
      "system_person_recreation_status":1,
      "system_person_health_care_status":1,
      "system_person_life_support_status":2,
      "system_person_administrative_services_status":0,
      "system_person_miner_skill":1
    }',
    array['all_person', 'player', 'aster']);
  perform pallas_project.create_person(
    'be0489a5-05ec-430f-a74c-279a198a22e5',
    'be04',
    jsonb '{
      "title":"Хэнк Даттон",
      "system_money":32,
      "person_district":"sector_G",
      "person_occupation":"Шахтёр",
      "person_opa_rating":1,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":0,
      "system_person_police_status":0,
      "system_person_recreation_status":1,
      "system_person_health_care_status":1,
      "system_person_life_support_status":1,
      "system_person_administrative_services_status":0
    }',
    array['all_person', 'player', 'aster']);
  perform pallas_project.create_person(
    '2ce20542-04f1-418f-99eb-3c9d2665f733',
    '2ce2',
    jsonb '{
      "title":"Герберт Чао Су",
      "description":"Астер.",
      "system_money":75,
      "person_district":"sector_D",
      "person_occupation":"Геологоразведчик",
      "person_opa_rating":2,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":750,
      "system_person_police_status":1,
      "system_person_recreation_status":1,
      "system_person_health_care_status":1,
      "system_person_life_support_status":2,
      "system_person_administrative_services_status":1,
      "system_person_miner_skill":1
    }',
    array['all_person', 'player', 'aster']);
  perform pallas_project.create_person(
    '18ce44b8-5df9-4c84-8af4-b58b3f5e7b21',
    '18ce',
    jsonb '{
      "title":"Алисия Сильверстоун",
      "description":"Получила образование на Луне. Астер.",
      "system_money":75,
      "person_district":"sector_D",
      "person_occupation":"Геологоразведчик",
      "person_opa_rating":1,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":2000,
      "system_person_police_status":1,
      "system_person_recreation_status":1,
      "system_person_health_care_status":1,
      "system_person_life_support_status":2,
      "system_person_administrative_services_status":1
    }',
    array['all_person', 'player', 'aster', 'cartel']);
  perform pallas_project.create_person(
    '48569d1d-5f01-410f-a67b-c5fe99d8dbc1',
    '4856',
    jsonb '{
      "title":"Кайла Ангас",
      "description":"Лейтенант полиции. Астер.",
      "system_money":240,
      "person_district":"sector_B",
      "person_occupation":"Начальник филиала Star Helix",
      "person_opa_rating":1,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":2000,
      "system_person_police_status":0,
      "system_person_recreation_status":2,
      "system_person_health_care_status":2,
      "system_person_life_support_status":3,
      "system_person_administrative_services_status":2
    }',
    array['all_person', 'player', 'aster']);
  perform pallas_project.create_person(
    '2903429c-8f58-4f78-96f7-315246b17796',
    '2903',
    jsonb '{
      "title":"Борислав Маслов",
      "description":"Землянин русского происхождения, морпех ООН в отставке.",
      "person_state":"un",
      "person_district":"sector_C",
      "person_un_rating":350,
      "person_occupation":"Зам. начальника филиала Star Helix",
      "person_opa_rating":1,
      "system_person_economy_type":"un",
      "system_person_police_status":2,
      "system_person_recreation_status":2,
      "system_person_health_care_status":3,
      "system_person_life_support_status":3,
      "system_person_administrative_services_status":3
    }',
    array['all_person', 'player', 'un']);
  perform pallas_project.create_person(
    '3d303557-6459-4b94-b834-3c70d2ba295d',
    '3d30',
    jsonb '{
      "title":"Джордан Закс",
      "description":"Астер.",
      "system_money":135,
      "person_district":"sector_C",
      "person_occupation":"Полицейский",
      "person_opa_rating":1,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":2100,
      "system_person_police_status":0,
      "system_person_recreation_status":1,
      "system_person_health_care_status":2,
      "system_person_life_support_status":3,
      "system_person_administrative_services_status":1
    }',
    array['all_person', 'player', 'aster']);
  perform pallas_project.create_person(
    '24f8fd67-962e-4466-ac85-02ca88cd66eb',
    '24f8',
    jsonb '{
      "title":"Бобби Смит",
      "description":"Астер.",
      "system_money":135,
      "person_district":"sector_C",
      "person_occupation":"Полицейский",
      "person_opa_rating":1,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":1430,
      "system_person_police_status":0,
      "system_person_recreation_status":1,
      "system_person_health_care_status":2,
      "system_person_life_support_status":3,
      "system_person_administrative_services_status":1
    }',
    array['all_person', 'player', 'un']);
  perform pallas_project.create_person(
    'be28d490-6c68-4ee4-a244-6700d01d16cc',
    'be28',
    jsonb '{
      "title":"Лила Финчер",
      "description":"Астер.",
      "system_money":135,
      "person_district":"sector_C",
      "person_occupation":"Детектив",
      "person_opa_rating":1,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":1300,
      "system_person_police_status":0,
      "system_person_recreation_status":1,
      "system_person_health_care_status":2,
      "system_person_life_support_status":3,
      "system_person_administrative_services_status":1
    }',
    array['all_person', 'player', 'aster']);
  perform pallas_project.create_person(
    '81491084-b02a-471f-9293-b20497e0054a',
    '8149',
    jsonb '{
      "title":"Наоми Гейтс",
      "description":"Астер.",
      "system_money":43,
      "person_district":"sector_D",
      "person_occupation":"Бригадир ремонтной бригады",
      "person_opa_rating":1,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":500,
      "system_person_police_status":0,
      "system_person_recreation_status":1,
      "system_person_health_care_status":1,
      "system_person_life_support_status":2,
      "system_person_administrative_services_status":0
    }',
    array['all_person', 'player', 'aster']);
  perform pallas_project.create_person(
    'b9309ed3-d19f-4d2d-855a-a9a3ffdf8e9c',
    'b930',
    jsonb '{
      "title":"Харальд Скарсгард",
      "description":"Астер.",
      "system_money":43,
      "person_district":"sector_F",
      "person_occupation":"Ремонтник",
      "person_opa_rating":1,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":11,
      "system_person_police_status":1,
      "system_person_recreation_status":1,
      "system_person_health_care_status":1,
      "system_person_life_support_status":1,
      "system_person_administrative_services_status":0
    }',
    array['all_person', 'player', 'aster']);
  perform pallas_project.create_person(
    'c9e08512-e729-430a-b2fd-df8e7c94a5e7',
    'c9e0',
    jsonb '{
      "title":"Чарльз Вилкинсон",
      "description":"Астер.",
      "system_money":50,
      "person_district":"sector_G",
      "person_occupation":"Ремонтник-механик",
      "person_opa_rating":1,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":19,
      "system_person_police_status":2,
      "system_person_recreation_status":3,
      "system_person_health_care_status":2,
      "system_person_life_support_status":3,
      "system_person_administrative_services_status":0
    }',
    array['all_person', 'player', 'aster', 'cartel']);
  perform pallas_project.create_person(
    '1fbcf296-e9ad-43b0-9064-1da3ff6d326d',
    '1fbc',
    jsonb '{
      "title":"Амели Сноу",
      "description":"Астер.",
      "system_money":50,
      "person_district":"sector_G",
      "person_occupation":"Бригадир грузчиков",
      "person_opa_rating":1,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":1000,
      "system_person_police_status":1,
      "system_person_recreation_status":1,
      "system_person_health_care_status":2,
      "system_person_life_support_status":2,
      "system_person_administrative_services_status":0
    }',
    array['all_person', 'player', 'aster', 'cartel']);
  perform pallas_project.create_person(
    '3a83fb3c-b954-4a04-aa6c-7a46d7bf9b8e',
    '3a83',
    jsonb '{
      "title":"Джессика Куин",
      "description":"Астер.",
      "system_money":43,
      "person_district":"sector_F",
      "person_occupation":"Грузчик",
      "person_opa_rating":1,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":300,
      "system_person_police_status":1,
      "system_person_recreation_status":1,
      "system_person_health_care_status":1,
      "system_person_life_support_status":1,
      "system_person_administrative_services_status":0
    }',
    array['all_person', 'player', 'aster']);
  perform pallas_project.create_person(
    'a9e4bc61-4e10-4c9e-a7de-d8f61536f657',
    'a9e4',
    jsonb '{
      "title":"Сэмми Куин",
      "description":"Астер.",
      "system_money":43,
      "person_district":"sector_F",
      "person_occupation":"Грузчик",
      "person_opa_rating":1,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":20,
      "system_person_police_status":1,
      "system_person_recreation_status":1,
      "system_person_health_care_status":1,
      "system_person_life_support_status":1,
      "system_person_administrative_services_status":0
    }',
    array['all_person', 'player', 'aster']);
  perform pallas_project.create_person(
    '70e5db08-df47-4395-9f4a-15eef99b2b89',
    '70e5',
    jsonb '{
      "title":"Марк Попов",
      "description":"Заведующий складом в порту. Астер.",
      "system_money":180,
      "person_district":"sector_G",
      "person_occupation":"Зав. складом",
      "person_opa_rating":1,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":5000,
      "system_person_police_status":3,
      "system_person_recreation_status":2,
      "system_person_health_care_status":2,
      "system_person_life_support_status":2,
      "system_person_administrative_services_status":2
    }',
    array['all_person', 'player', 'aster', 'cartel']);
  perform pallas_project.create_person(
    '939b6537-afc1-41f4-963a-21ccfd1c7d28',
    '939b',
    jsonb '{
      "title":"Роберт Ли",
      "description":"Астер.",
      "system_money":240,
      "person_district":"sector_B",
      "person_occupation":"Начальник порта",
      "person_opa_rating":3,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":0,
      "system_person_police_status":2,
      "system_person_recreation_status":1,
      "system_person_health_care_status":2,
      "system_person_life_support_status":2,
      "system_person_administrative_services_status":2
    }',
    array['all_person', 'player', 'aster', 'opa']);
  perform pallas_project.create_person(
    '5a764843-9edc-4cfb-8367-80c1d3c54ed9',
    '5a76',
    jsonb '{
      "title":"Луиза О''Нил",
      "description":"Пилот буксира.",
      "system_money":43,
      "person_district":"sector_D",
      "person_occupation":"Пилот",
      "person_opa_rating":1,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":41,
      "system_person_police_status":1,
      "system_person_recreation_status":1,
      "system_person_health_care_status":0,
      "system_person_life_support_status":2,
      "system_person_administrative_services_status":0
    }',
    array['all_person', 'player', 'aster', 'opa']);
  perform pallas_project.create_person(
    '47d63ed5-3764-4892-b56d-597dd1bbc016',
    '47d6',
    jsonb '{
      "title":"Дональд Чамберс",
      "description":"Пилот буксира",
      "system_money":32,
      "person_district":"sector_G",
      "person_occupation":"Пилот",
      "person_opa_rating":1,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":91,
      "system_person_police_status":0,
      "system_person_recreation_status":1,
      "system_person_health_care_status":1,
      "system_person_life_support_status":1,
      "system_person_administrative_services_status":0
    }',
    array['all_person', 'player', 'aster', 'cartel']);
  perform pallas_project.create_person(
    '54e94c45-ce2a-459a-8613-9b75e23d9b68',
    '54e9',
    jsonb '{
      "title":"Лина Ковач",
      "description":"Врач-генетик родом с Ганимеда. Астер.",
      "person_state":"un",
      "person_district":"sector_B",
      "person_un_rating":380,
      "person_occupation":"Глава гос. клиники",
      "person_opa_rating":1,
      "system_person_economy_type":"un",
      "system_person_police_status":2,
      "system_person_recreation_status":2,
      "system_person_health_care_status":3,
      "system_person_life_support_status":3,
      "system_person_administrative_services_status":3
    }',
    array['all_person', 'player', 'un']);
  perform pallas_project.create_person(
    '7051afe2-3430-44a7-92e3-ad299aae62e1',
    '7051',
    jsonb '{
      "title":"Мария Липпи",
      "description":"Медсестра по образованию. Астер.",
      "system_money":43,
      "person_district":"sector_D",
      "person_occupation":"Сотрудник клининговой компании",
      "person_opa_rating":1,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":500,
      "system_person_police_status":1,
      "system_person_recreation_status":1,
      "system_person_health_care_status":0,
      "system_person_life_support_status":1,
      "system_person_administrative_services_status":0
    }',
    array['all_person', 'player', 'aster']);
  perform pallas_project.create_person(
    '21670857-6be0-4f77-8756-79636950bc36',
    '2167',
    jsonb '{
      "title":"Анна Джаррет",
      "description":"Методист. Астер.",
      "system_money":43,
      "person_district":"sector_D",
      "person_occupation":"Медсестра в клинике",
      "person_opa_rating":1,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":500,
      "system_person_police_status":1,
      "system_person_recreation_status":1,
      "system_person_health_care_status":1,
      "system_person_life_support_status":1,
      "system_person_administrative_services_status":0
    }',
    array['all_person', 'player', 'aster']);
  perform pallas_project.create_person(
    '523e8589-f948-4c42-a32b-fe39648488f2',
    '523e',
    jsonb '{
      "title":"Лиза Скай",
      "description":"Астер.",
      "system_money":32,
      "person_district":"sector_G",
      "person_occupation":"Медсестра",
      "person_opa_rating":1,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":500,
      "system_person_police_status":0,
      "system_person_recreation_status":1,
      "system_person_health_care_status":1,
      "system_person_life_support_status":1,
      "system_person_administrative_services_status":0
    }',
    array['all_person', 'player', 'aster']);
  perform pallas_project.create_person(
    'e0c49e51-779f-4f21-bb94-bbbad33bc6e2',
    'e0c4',
    jsonb '{
      "title":"Элисон Янг",
      "description":"Землянин.",
      "person_state":"un",
      "person_district":"sector_D",
      "person_un_rating":50,
      "person_occupation":"Директор компании Чистый Астероид",
      "person_opa_rating":2,
      "system_person_economy_type":"un",
      "system_person_police_status":1,
      "system_person_recreation_status":0,
      "system_person_health_care_status":1,
      "system_person_life_support_status":1,
      "system_person_administrative_services_status":1
    }',
    array['all_person', 'player', 'un']);
  perform pallas_project.create_person(
    '8f7b1cc6-28cd-4fb1-8c81-e0ab1c0df5c9',
    '8f7b',
    jsonb '{
      "title":"Рашид Файзи",
      "description":"Марсианин.",
      "person_state":"mcr",
      "system_money":0,
      "person_district":"sector_B",
      "person_occupation":"Глава филиала Теко Марс",
      "person_opa_rating":1,
      "system_person_economy_type":"mcr",
      "system_person_police_status":2,
      "system_person_recreation_status":1,
      "system_person_health_care_status":2,
      "system_person_life_support_status":2,
      "system_person_administrative_services_status":2
    }',
    array['all_person', 'player', 'mcr']);
  perform pallas_project.create_person(
    '2ecb2a46-50f7-4e93-b340-2c9875287252',
    '2ecb',
    jsonb '{
      "title":"Грейс Огустин",
      "description":"Марсианин.",
      "person_state":"mcr",
      "system_money":0,
      "person_district":"sector_C",
      "person_occupation":"Учёный-микробиолог",
      "person_opa_rating":1,
      "system_person_economy_type":"mcr",
      "system_person_police_status":2,
      "system_person_recreation_status":1,
      "system_person_health_care_status":3,
      "system_person_life_support_status":1,
      "system_person_administrative_services_status":0
    }',
    array['all_person', 'player', 'mcr']);
  perform pallas_project.create_person(
    '9b8c205e-9483-44f9-be9b-2af47a765f9c',
    '9b8c',
    jsonb '{
      "title":"Сара Ф. Остин",
      "description":"Марсианин.",
      "person_state":"mcr",
      "system_money":0,
      "person_district":"sector_B",
      "person_occupation":"Учёный-физик",
      "person_opa_rating":1,
      "system_person_economy_type":"mcr",
      "system_person_police_status":2,
      "system_person_recreation_status":1,
      "system_person_health_care_status":3,
      "system_person_life_support_status":1,
      "system_person_administrative_services_status":0
    }',
    array['all_person', 'player', 'mcr']);
  perform pallas_project.create_person(
    'c336c33b-5b87-4844-8459-eaff6124cd15',
    'c336',
    jsonb '{
      "title":"Чан Хи Го",
      "description":"Марсианин.",
      "person_state":"mcr",
      "system_money":0,
      "person_district":"sector_C",
      "person_occupation":"Лаборант",
      "person_opa_rating":1,
      "system_person_economy_type":"mcr",
      "system_person_police_status":2,
      "system_person_recreation_status":1,
      "system_person_health_care_status":2,
      "system_person_life_support_status":1,
      "system_person_administrative_services_status":0
    }',
    array['all_person', 'player', 'mcr']);
  perform pallas_project.create_person(
    'ea68988b-b540-4685-aefb-cbd999f4c9ba',
    'ea68',
    jsonb '{
      "title":"Том Алиев",
      "description":"Марсианин",
      "person_state":"mcr",
      "system_money":0,
      "person_district":"sector_B",
      "person_occupation":"Лаборант",
      "person_opa_rating":1,
      "system_person_economy_type":"mcr",
      "system_person_police_status":2,
      "system_person_recreation_status":1,
      "system_person_health_care_status":2,
      "system_person_life_support_status":1,
      "system_person_administrative_services_status":0
    }',
    array['all_person', 'player', 'mcr']);
  perform pallas_project.create_person(
    '2956e4b7-7b02-4ffd-a725-ea3390b9a1cc',
    '2956',
    jsonb '{
      "title":"Валентин Штерн",
      "system_money":0,
      "person_district":"sector_E",
      "person_occupation":"Капитан",
      "person_opa_rating":2,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":0,
      "system_person_police_status":2,
      "system_person_recreation_status":2,
      "system_person_health_care_status":2,
      "system_person_life_support_status":2,
      "system_person_administrative_services_status":1
    }',
    array['all_person', 'player', 'aster']);
  perform pallas_project.create_person(
    '468c4f12-1a52-4681-8a78-d80dfeaec90e',
    '468c',
    jsonb '{
      "title":"Джэйн Синглтон",
      "system_money":240,
      "person_district":"sector_E",
      "person_occupation":"Пилот",
      "person_opa_rating":1,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":1200,
      "system_person_police_status":2,
      "system_person_recreation_status":2,
      "system_person_health_care_status":2,
      "system_person_life_support_status":2,
      "system_person_administrative_services_status":0
    }',
    array['all_person', 'player', 'aster']);
  perform pallas_project.create_person(
    'ac1b23d0-ba5f-4042-85d5-880a66254803',
    'ac1b',
    jsonb '{
      "title":"Уильям Келли",
      "description":"Активист Церкви Космической Выси. Мормон. Астер.",
      "system_money":0,
      "person_district":"sector_E",
      "person_occupation":"Проповедник",
      "person_opa_rating":4,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":0,
      "system_person_police_status":2,
      "system_person_recreation_status":2,
      "system_person_health_care_status":2,
      "system_person_life_support_status":2,
      "system_person_administrative_services_status":2
    }',
    array['all_person', 'player', 'aster', 'opa']);
  perform pallas_project.create_person(
    '2d912a30-6c35-4cef-9d74-94665ac0b476',
    '2d91',
    jsonb '{
      "title":"Грег Тэйлор",
      "description":"Бывший военный пилот, майор в отставке. Марсианин.",
      "person_state":"mcr",
      "system_money":1000,
      "person_district":"sector_E",
      "person_occupation":"Капитан",
      "person_opa_rating":1,
      "system_person_economy_type":"mcr",
      "system_person_police_status":1,
      "system_person_recreation_status":1,
      "system_person_health_care_status":2,
      "system_person_life_support_status":2,
      "system_person_administrative_services_status":0
    }',
    array['all_person', 'player', 'mcr']);
  perform pallas_project.create_person(
    '6dc0a14a-a63f-44aa-a677-e5376490f28d',
    '6dc0',
    jsonb '{
      "title":"Люси Мартин",
      "description":"Марсианин.",
      "person_state":"mcr",
      "system_money":1800,
      "person_district":"sector_E",
      "person_occupation":"Капеллан",
      "person_opa_rating":1,
      "system_person_economy_type":"mcr",
      "system_person_police_status":2,
      "system_person_recreation_status":2,
      "system_person_health_care_status":2,
      "system_person_life_support_status":3,
      "system_person_administrative_services_status":1
    }',
    array['all_person', 'player', 'mcr']);
  perform pallas_project.create_person(
    '8d3e1b38-ab96-4d87-8c51-1be2ce1a0111',
    '8d3e',
    jsonb '{
      "title":"Нозоми Табато",
      "description":"Марсианин.",
      "person_state":"mcr",
      "system_money":0,
      "person_district":"sector_E",
      "person_occupation":"Судовой врач",
      "person_opa_rating":1,
      "system_person_economy_type":"mcr",
      "system_person_police_status":2,
      "system_person_recreation_status":2,
      "system_person_health_care_status":2,
      "system_person_life_support_status":2,
      "system_person_administrative_services_status":2
    }',
    array['all_person', 'player', 'mcr']);
  perform pallas_project.create_person(
    '97539130-5977-41cb-a96d-d160522430f8',
    '9753',
    jsonb '{
      "title":"Джэй Рейнольдс",
      "description":"Хозяин \"Каверны\". Трижды разведён. Астер.",
      "person_district":"sector_F",
      "person_occupation":"Бармен",
      "person_opa_rating":2,
      "system_person_economy_type":"fixed",
      "system_person_police_status":2,
      "system_person_recreation_status":3,
      "system_person_health_care_status":2,
      "system_person_life_support_status":2,
      "system_person_administrative_services_status":2
    }',
    array['all_person', 'player', 'aster']);
  perform pallas_project.create_person(
    '9f114f78-8b87-4363-bf55-a19522282e4e',
    '9f11',
    jsonb '{
      "title":"Соня Попова",
      "description":"Родилась на Марсе.",
      "system_money":32,
      "person_district":"sector_G",
      "person_occupation":"Официантка",
      "person_opa_rating":1,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":0,
      "system_person_police_status":1,
      "system_person_recreation_status":1,
      "system_person_health_care_status":0,
      "system_person_life_support_status":1,
      "system_person_administrative_services_status":0
    }',
    array['all_person', 'player', 'aster']);
  perform pallas_project.create_person(
    '7a51a4fc-ed1f-47c9-a67a-d56cd56b67de',
    '7a51',
    jsonb '{
      "title":"Марта Скарсгард",
      "description":"Сестра Харальда. Астер.",
      "system_money":60,
      "person_district":"sector_F",
      "person_occupation":"Работница бара",
      "person_opa_rating":1,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":190,
      "system_person_police_status":1,
      "system_person_recreation_status":2,
      "system_person_health_care_status":1,
      "system_person_life_support_status":1,
      "system_person_administrative_services_status":0
    }',
    array['all_person', 'player', 'aster']);
  perform pallas_project.create_person(
    'ea450b61-9489-4f98-ab0e-375e01a7df03',
    'ea45',
    jsonb '{
      "title":"Кип Шиммер",
      "description":"Астер.",
      "system_money":43,
      "person_district":"sector_F",
      "person_occupation":"Диджей",
      "person_opa_rating":1,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":71,
      "system_person_police_status":2,
      "system_person_recreation_status":1,
      "system_person_health_care_status":2,
      "system_person_life_support_status":3,
      "system_person_administrative_services_status":0
    }',
    array['all_person', 'player', 'aster']);
  perform pallas_project.create_person(
    'd23550d0-d599-4cf2-9a15-1594fd2df2b2',
    'd235',
    jsonb '{
      "title":"Шона Кагари",
      "description":"Астер",
      "system_money":0,
      "person_district":"sector_F",
      "person_occupation":"Владелица тату-салона",
      "person_opa_rating":1,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":0,
      "system_person_police_status":1,
      "system_person_recreation_status":1,
      "system_person_health_care_status":1,
      "system_person_life_support_status":1,
      "system_person_administrative_services_status":0
    }',
    array['all_person', 'player', 'aster']);
  perform pallas_project.create_person(
    '74bc1a0f-72d9-4271-b358-0ef464f3cbf9',
    '74bc',
    jsonb '{
      "title":"Милан Ясневски",
      "description":"Ясновидящий. Астер.",
      "system_money":0,
      "person_district":"sector_G",
      "person_occupation":"Говорящий с иными мирами",
      "person_opa_rating":1,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":430,
      "system_person_police_status":1,
      "system_person_recreation_status":1,
      "system_person_health_care_status":1,
      "system_person_life_support_status":1,
      "system_person_administrative_services_status":0
    }',
    array['all_person', 'player', 'aster']);
  perform pallas_project.create_person(
    '36cef6aa-aefc-479d-8cef-55534e8cd159',
    '36ce',
    jsonb '{
      "title":"Джаспер Шоу",
      "description":"Репортёр. Землянин.",
      "person_state":"un",
      "person_district":"sector_G",
      "person_un_rating":440,
      "person_occupation":"Журналист",
      "person_opa_rating":3,
      "system_person_economy_type":"un",
      "system_person_police_status":2,
      "system_person_recreation_status":2,
      "system_person_health_care_status":3,
      "system_person_life_support_status":3,
      "system_person_administrative_services_status":3
    }',
    array['all_person', 'player', 'un']);
  perform pallas_project.create_person(
    'cb792572-631b-4b09-8248-ae3e1e2dc7dc',
    'cb79',
    jsonb '{
      "title":"Шань Ю",
      "description":"Работает по контракту с медиа-компанией ООН Reuters. Астер.",
      "person_district":"sector_F",
      "person_occupation":"Оператор съёмочной команды",
      "person_opa_rating":1,
      "system_person_economy_type":"fixed",
      "system_person_police_status":2,
      "system_person_recreation_status":2,
      "system_person_health_care_status":2,
      "system_person_life_support_status":2,
      "system_person_administrative_services_status":2
    }',
    array['all_person', 'player', 'aster']);
  perform pallas_project.create_person(
    '457ea315-fc47-4579-a12b-fd7b91375ba8',
    '457e',
    jsonb '{
      "title":"Джулия Рэйс",
      "description":"Принадлежит к богатой семье с Земли.",
      "person_state":"un",
      "person_district":"sector_B",
      "person_un_rating":520,
      "person_occupation":"Писательница",
      "person_opa_rating":1,
      "system_person_economy_type":"un",
      "system_person_police_status":3,
      "system_person_recreation_status":3,
      "system_person_health_care_status":3,
      "system_person_life_support_status":3,
      "system_person_administrative_services_status":3
    }',
    array['all_person', 'player', 'un']);
  perform pallas_project.create_person(
    '19b66636-cd8e-4733-8a3d-2f16346bb81e',
    '19b6',
    jsonb '{
      "title":"Аманда Ганди",
      "description":"Заместитель отдела внутренней ревизии Управления по вопросам космического пространства ООН. Землянка.",
      "person_state":"un",
      "person_district":"sector_B",
      "person_un_rating":620,
      "person_occupation":"Особый уполномоченный ООН",
      "person_opa_rating":1,
      "system_person_economy_type":"un",
      "system_person_police_status":3,
      "system_person_recreation_status":3,
      "system_person_health_care_status":3,
      "system_person_life_support_status":3,
      "system_person_administrative_services_status":3
    }',
    array['all_person', 'player', 'un']);
  perform pallas_project.create_person(
    '37fb2074-498c-4d28-8395-9fdf993f2b06',
    '37fb',
    jsonb '{
      "title":"Джесси О''Коннелл",
      "description":"Астер.",
      "system_money":60,
      "person_district":"sector_G",
      "person_occupation":"Работник таможни",
      "person_opa_rating":1,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":700,
      "system_person_police_status":1,
      "system_person_recreation_status":1,
      "system_person_health_care_status":1,
      "system_person_life_support_status":3,
      "system_person_administrative_services_status":0
    }',
    array['all_person', 'player', 'aster']);
  perform pallas_project.create_person(
    '555e076c-ff8d-4dbb-a6c6-9d935314ff59',
    '555e',
    jsonb '{
      "title":"Лола Ди",
      "description":"Работает по контракту с медиа-компанией ООН Reuters.",
      "person_district":"sector_F",
      "person_occupation":"Корреспондент",
      "person_opa_rating":1,
      "system_person_economy_type":"fixed",
      "system_person_police_status":2,
      "system_person_recreation_status":2,
      "system_person_health_care_status":2,
      "system_person_life_support_status":2,
      "system_person_administrative_services_status":2
    }',
    array['all_person', 'player']);
  perform pallas_project.create_person(
    'd6ed7fcb-2e68-40b3-b0ab-5f6f4edc2f19',
    'd6ed',
    jsonb '{
      "title":"Элен Марвинг",
      "description":"Астер",
      "system_money":75,
      "person_district":"sector_F",
      "person_occupation":"Работник таможни",
      "person_opa_rating":1,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":700,
      "system_person_police_status":1,
      "system_person_recreation_status":1,
      "system_person_health_care_status":1,
      "system_person_life_support_status":3,
      "system_person_administrative_services_status":0
    }',
    array['all_person', 'player', 'aster']);
  perform pallas_project.create_person(
    'dc2505e8-9f8e-4a41-b42f-f1f348db8c99',
    'dc25',
    jsonb '{
      "title":"Ашшурбанапал Ганди",
      "description":"Землянин.",
      "person_state":"un",
      "person_district":"sector_B",
      "person_un_rating":550,
      "person_occupation":"Глава инвестиционного фонда ООН",
      "person_opa_rating":0,
      "system_person_economy_type":"un",
      "system_person_police_status":3,
      "system_person_recreation_status":3,
      "system_person_health_care_status":3,
      "system_person_life_support_status":3,
      "system_person_administrative_services_status":3
    }',
    array['all_person', 'player', 'un']);
  perform pallas_project.create_person(
    '82a7d37d-1067-4f21-a980-9c0665ce579c',
    '82a7',
    jsonb '{
      "title":"Мишель Буфано",
      "system_money":255,
      "person_district":"sector_D",
      "person_opa_rating":1,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":0,
      "system_person_police_status":2,
      "system_person_recreation_status":2,
      "system_person_health_care_status":2,
      "system_person_life_support_status":2,
      "system_person_administrative_services_status":1
    }',
    array['all_person', 'player', 'rider']);
  perform pallas_project.create_person(
    '0815d2a6-c82c-476c-a3dd-ed70a3f59e91',
    '0815',
    jsonb '{
      "title":"Саймон Фронцек",
      "system_money":255,
      "person_district":"sector_D",
      "person_opa_rating":1,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":0,
      "system_person_police_status":2,
      "system_person_recreation_status":2,
      "system_person_health_care_status":2,
      "system_person_life_support_status":2,
      "system_person_administrative_services_status":1
    }',
    array['all_person', 'player', 'rider']);
  perform pallas_project.create_person(
    'f4a2767d-73f2-4057-9430-f887d4cd05e5',
    'f4a2',
    jsonb '{
      "title":"Джейсон Айронхарт",
      "system_money":0,
      "person_district":"sector_G",
      "person_occupation":"Разнорабочий",
      "person_opa_rating":0,
      "system_person_economy_type":"asters",
      "system_person_deposit_money":0,
      "system_person_police_status":0,
      "system_person_recreation_status":1,
      "system_person_health_care_status":0,
      "system_person_life_support_status":1,
      "system_person_administrative_services_status":0
    }',
    array['all_person', 'player', 'aster', 'rider']);

  -- todo проставить астеры/картель/свп медик/таможня
  -- todo доп. персонажи
  -- 0d07f15b-2952-409b-b22e-4042cf70acc6 Одна мёртвая душа, с которой заключён контракт\r\nЭлтон Спирс
  -- c9e08512-e729-430a-b2fd-df8e7c94a5e7 Чарльз Эшфорд, астер, фикс серый, UN$2000
  -- 939b6537-afc1-41f4-963a-21ccfd1c7d28 Руперт Мёрдок, гражданин, рейтинг 450, фикс. статусы: золото, серебро, серебро, серебро, золото + Тамара Мёрдок - внешний контакт + Дана Скалли
  -- 5a764843-9edc-4cfb-8367-80c1d3c54ed9 Карла Хьюз, нет денег, фикс нет + Лицензия пилота
  -- 523e8589-f948-4c42-a32b-fe39648488f2 Клэр Санхилл, фикс серый, письмо от Эшли Гарсия
  -- ac1b23d0-ba5f-4042-85d5-880a66254803 Фред Амбер, фикс серый, компания Свободное Небо\r\n+ Письмо доктору Янг\r\n+ Заказ оружия с Марса\r\n+ Письмо Сьюзан Сидоровой\r\n+ Перевод денег Свободного Неба Чистому Астероиду
  -- 6dc0a14a-a63f-44aa-a677-e5376490f28d Алекс Камаль, 10000, фикс золотой, марсианин\r\n+ документ со списком особых полномочий + связь с советником
  -- 36cef6aa-aefc-479d-8cef-55534e8cd159 Астер Шенг, блог
  -- f4a2767d-73f2-4057-9430-f887d4cd05e5 Безухов

  -- С паролем: Брэндон Мёрфи - доп. персонаж\r\n- Астер, фикс. серый, цепочка стимуляторов картеля, любовное письмо к Алисии Сильверстоун, письмо - заказ у Валентины Штерн пробирки с вирусом, заметка в календаре о встрече с человеком с Джорданом Заксом, 500
end;
$$
language plpgsql;
