-- drop function pallas_project.init_mine();

create or replace function pallas_project.init_mine()
returns void
volatile
as
$$
begin
  insert into data.attributes(code, type, card_type, can_be_overridden) values
  ('mine_available_equipment', 'hidden', 'full', true),
  ('mine_available_companies', 'hidden', 'full', true),
  ('mine_client_ids', 'hidden', 'full', false),
  ('mine_map', 'hidden', null, false),
  ('mine_equipment', 'hidden', null, false);

  -- train (CM) все
  -- buksir (AC) чамберс онил
  -- digger (DB) шахтёры, 6
  -- dron (AD портер чао_су сильверстоун, TM хиго остин)
  -- loader (AC) грузчики, 3 (DB) шахтёры, 6
  -- stealer (CT) чамберс (OP) онил - всегда заправлен
  -- ship (TM) тейлор (TA) синглтон (AD) трейс
  -- driller (AD) Портер
  -- всё - мастер

  perform data.add_object_to_object('5074485d-73cd-4e19-8d4b-4ffedcf1fb5f', 'miners');
  perform data.add_object_to_object('82d0dbb5-0c9b-412c-810f-79827370c37f', 'miners');
  perform data.add_object_to_object('a11d2240-3dce-4d75-bc52-46e98b07ff27', 'miners');
  perform data.add_object_to_object('3beea660-35a3-431e-b9ae-e2e88e6ac064', 'miners');
  perform data.add_object_to_object('09951000-d915-495d-867d-4d0e7ebfcf9c', 'miners');
  perform data.add_object_to_object('be0489a5-05ec-430f-a74c-279a198a22e5', 'miners');

  perform data.add_object_to_object('1fbcf296-e9ad-43b0-9064-1da3ff6d326d', 'loaders');
  perform data.add_object_to_object('3a83fb3c-b954-4a04-aa6c-7a46d7bf9b8e', 'loaders');
  perform data.add_object_to_object('a9e4bc61-4e10-4c9e-a7de-d8f61536f657', 'loaders');

  perform data.create_object(
    'mine',
    jsonb '[
      {"code": "type", "value": "mine"},
      {"code": "title", "value": "Карта"},
      {"code": "description", "value": "Управление оборудованием доступно только со специально оборудованных мест"},
      {"code": "mine_client_ids", "value": []},
      {"code": "is_visible", "value": true},
      {"code": "is_master", "value": false},
      {"code": "is_master", "value": true, "value_object_code": "master"},
      {"code": "actions_function", "value": "pallas_project.actgenerator_mine"},
      {"code": "mine_available_equipment", "value": ["train"]},
      {"code": "mine_available_companies", "value": ["CM"]},
      {"code": "mine_available_equipment", "value": ["train", "buksir", "stealer"], "value_object_code": "47d63ed5-3764-4892-b56d-597dd1bbc016"},
      {"code": "mine_available_companies", "value": ["CM", "AC", "CT"], "value_object_code": "47d63ed5-3764-4892-b56d-597dd1bbc016"},
      {"code": "mine_available_equipment", "value": ["train", "buksir", "stealer"], "value_object_code": "5a764843-9edc-4cfb-8367-80c1d3c54ed9"},
      {"code": "mine_available_companies", "value": ["CM", "AC", "OP"], "value_object_code": "5a764843-9edc-4cfb-8367-80c1d3c54ed9"},
      {"code": "mine_available_equipment", "value": ["train", "digger", "loader"], "value_object_code": "miners"},
      {"code": "mine_available_companies", "value": ["CM", "DB"], "value_object_code": "miners"},
      {"code": "mine_available_equipment", "value": ["train", "dron", "driller"], "value_object_code": "95a3dc9e-8512-44ab-9173-29f0f4fd6e05"},
      {"code": "mine_available_companies", "value": ["CM", "AD"], "value_object_code": "95a3dc9e-8512-44ab-9173-29f0f4fd6e05"},
      {"code": "mine_available_equipment", "value": ["train", "dron"], "value_object_code": "2ce20542-04f1-418f-99eb-3c9d2665f733"},
      {"code": "mine_available_companies", "value": ["CM", "AD"], "value_object_code": "2ce20542-04f1-418f-99eb-3c9d2665f733"},
      {"code": "mine_available_equipment", "value": ["train", "dron"], "value_object_code": "18ce44b8-5df9-4c84-8af4-b58b3f5e7b21"},
      {"code": "mine_available_companies", "value": ["CM", "AD"], "value_object_code": "18ce44b8-5df9-4c84-8af4-b58b3f5e7b21"},
      {"code": "mine_available_equipment", "value": ["train", "dron"], "value_object_code": "c336c33b-5b87-4844-8459-eaff6124cd15"},
      {"code": "mine_available_companies", "value": ["CM", "TM"], "value_object_code": "c336c33b-5b87-4844-8459-eaff6124cd15"},
      {"code": "mine_available_equipment", "value": ["train", "dron"], "value_object_code": "9b8c205e-9483-44f9-be9b-2af47a765f9c"},
      {"code": "mine_available_companies", "value": ["CM", "TM"], "value_object_code": "9b8c205e-9483-44f9-be9b-2af47a765f9c"},
      {"code": "mine_available_equipment", "value": ["train", "loader"], "value_object_code": "loaders"},
      {"code": "mine_available_companies", "value": ["CM", "AC"], "value_object_code": "loaders"},
      {"code": "mine_available_equipment", "value": ["train", "ship"], "value_object_code": "2d912a30-6c35-4cef-9d74-94665ac0b476"},
      {"code": "mine_available_companies", "value": ["CM", "TM"], "value_object_code": "2d912a30-6c35-4cef-9d74-94665ac0b476"},
      {"code": "mine_available_equipment", "value": ["train", "ship"], "value_object_code": "468c4f12-1a52-4681-8a78-d80dfeaec90e"},
      {"code": "mine_available_companies", "value": ["CM", "TA"], "value_object_code": "468c4f12-1a52-4681-8a78-d80dfeaec90e"},
      {"code": "mine_available_equipment", "value": ["train", "ship"], "value_object_code": "494dd323-d808-48e6-8971-cd8f18656ec0"},
      {"code": "mine_available_companies", "value": ["CM", "AD"], "value_object_code": "494dd323-d808-48e6-8971-cd8f18656ec0"},
      {
        "code": "mine_available_equipment",
        "value": ["train", "driller", "box", "brill", "buksir", "digger", "dron", "iron", "loader", "stealer", "stone", "ship", "barge", "brillmine", "stonemine", "ironmine"],
        "value_object_code": "master"
      },
      {"code": "mine_available_companies", "value": ["CM", "TM", "DB", "SH", "TO", "AC", "AD", "OP", "CT", "TA"], "value_object_code": "master"},
      {"code": "content", "value": ["mine_map", "mine_equipment"]},
      {
        "code": "template",
        "value": {
          "title": "title",
          "groups": [{"code": "group", "attributes": ["description"]}]
        }
      }
    ]');

  perform data.create_object(
    'mine_map',
    jsonb '{
      "type": "mine_map",
      "is_visible": true,
      "template": {"groups": []},
      "mine_map": "st l|st t r|cl t|cl t b|cl t b|cl t|cl t b|cl t r|cl t|cl t b|cl t r|cl t|cl t|cl t r b|cl t|cl t b|cl t|cl t b|cl t r b|cl t|cl t b|cl t r|cl t|cl t b|cl t r|cl t|cl t b|cl t r|cl t|cl t b|cl t b|cl t|cl t b|cl t b|cl t b|cl t b|cl t r|cl t b|cl t b|cl t b|cl t r|cl t|cl t b|cl t b|cl t|cl t r|cl t|cl t r|cl t|cl t r|cl l r b|cl b|cl b|cl r b|cl|cl r b|cl|cl r b|cl r|cl|cl r b|cl r|cl r|cl|cl r b|cl|cl r|cl|cl b|cl b|cl r b|cl r|cl r|cl r|cl r|cl r|cl r|cl r|cl r|cl|cl r|cl b|cl b|cl r|cl b|cl r|cl r|cl|cl b|cl r|cl b|cl r b|cl|cl b|cl r b|cl r|cl r|cl|cl r b|cl r b|cl l|cl b|cl b|cl r|cl r|cl r|cl b|cl r|cl r b|cl b|cl r|cl r|cl r|cl|cl r b|cl r|cl r|cl r|cl r|cl|cl r|cl b|cl r|cl r|cl r|cl r|cl r|cl b|cl r b|cl r|cl r|cl|cl r|cl b|cl r|cl b|cl b|cl r b|cl r|cl b|cl b|cl r|cl r|cl b|cl b|cl b|cl r b|cl r b|cl|cl r|cl l r|cl r|cl|cl b|cl r b|cl b|cl b|cl|cl b|cl b|cl r b|cl r|cl b|cl r b|cl|cl r b|cl r b|cl|cl r b|cl r|cl b|cl r|cl b|cl r b|cl|cl r b|cl|cl r|cl|cl r|cl r|cl r b|cl b|cl r|cl b|cl b|cl b|cl r|cl b|cl b|cl|cl r b|cl b|cl|cl r|cl|cl b|cl b|cl r b|cl r|cl l r|cl b|cl r b|cl|cl r|cl|cl r|cl r|cl|cl b|cl r|cl b|cl b|cl r|cl b|cl b|cl b|cl r b|cl|cl r b|cl r|cl b|cl b|cl r|cl b|cl b|cl r b|cl r|cl r b|cl r|cl b|cl b|cl r|cl|cl b|cl|cl r b|cl b|cl b|cl r|cl b|cl b|cl r|cl r b|cl b|cl b|cl r b|cl|cl b|cl r|cl l|cl r|cl|cl r b|cl b|cl r b|cl r|cl r b|cl r|cl r|cl b|cl b|cl b|cl r b|cl|cl r|cl|cl b|cl r b|cl|cl b|cl b|cl b|cl r b|cl b|cl|cl r b|cl b|cl r|cl r|cl|cl r|cl b|cl r b|cl r|cl r|cl|cl b|cl b|cl r|cl|cl r|cl b|cl b|cl b|cl b|cl b|cl r b|cl|cl r b|cl l r|cl b|cl r b|cl|cl b|cl r b|cl r|cl|cl r b|cl|cl r|cl|cl r|cl|cl r b|cl r|cl b|cl r|cl|cl r b|cl|cl b|cl b|cl|cl b|cl r b|cl|cl b|cl r b|cl r|cl r|cl r|cl b|cl b|cl b|cl r|cl b|cl b|cl r|cl r b|cl r|cl r|cl r|cl|cl b|cl b|cl b|cl r|cl r|cl r|cl l r|cl b|cl b|cl r|cl|cl r|cl r|cl b|cl b|cl r b|cl r|cl r|cl b|cl r b|cl r|cl b|cl r|cl r|cl r|cl b|cl b|cl b|cl r b|cl|cl r|cl|cl r b|cl|cl b|cl r b|cl r|cl b|cl b|cl b|cl r|cl b|cl r|cl r|cl b|cl b|cl r b|cl r|cl r|cl b|cl r|cl|cl r b|cl r|cl r|cl r|cl l b|cl b|cl r|cl r|cl r|cl r|cl b|cl b|cl r|cl|cl r b|cl r|cl|cl|cl b|cl r b|cl r|cl r|cl r|cl|cl b|cl b|cl r|cl r|cl b|cl b|cl b|cl r b|cl|cl b|cl r b|cl b|cl|cl r|cl b|cl r|cl b|cl r b|cl|cl b|cl b|cl r b|cl r|cl|cl r b|cl b|cl r|cl b|cl r b|cl r|cl l|cl r|cl b|cl r|cl r|cl b|cl r|cl|cl r|cl b|cl r|cl r|cl r b|cl r|cl|cl b|cl r b|cl r|cl b|cl r b|cl|cl b|cl r b|cl|cl r b|cl|cl r|cl|cl r b|cl|cl b|cl r|cl r|cl r|cl|cl r b|cl|cl b|cl r b|cl|cl r|cl|cl r|cl r|cl|cl b|cl r|cl|cl b|cl r|cl l r|cl b|cl b|cl r b|cl r|cl b|cl b|cl r b|cl r|cl|cl r b|cl b|cl|cl r b|cl r|cl|cl b|cl r b|cl|cl r|cl b|cl r|cl|cl r b|cl|cl r b|cl r|cl r|cl|cl r b|cl r|cl r|cl r b|cl b|cl b|cl r|cl r|cl b|cl b|cl r|cl r b|cl r|cl b|cl r b|cl r|cl b|cl b|cl r b|cl r|cl r|cl l b|cl|cl b|cl r b|cl|cl b|cl r|cl b|cl r b|cl|cl b|cl r b|cl r|cl|cl r b|cl b|cl b|cl b|cl r b|cl r|cl|cl r b|cl r b|cl|cl r b|cl|cl r b|cl b|cl b|cl b|cl r|cl b|cl b|cl r|cl|cl r b|cl b|cl r|cl|cl r b|cl|cl r b|cl|cl r|cl|cl b|cl b|cl r|cl|cl r b|cl l r|cl r|cl|cl r|cl b|cl r b|cl b|cl|cl b|cl r b|cl|cl b|cl r b|cl b|cl|cl b|cl b|cl|cl r b|cl r|cl b|cl b|cl r|cl r|cl|cl r b|cl|cl b|cl r|cl b|cl|cl b|cl r b|cl r|cl b|cl b|cl r|cl r|cl|cl b|cl r b|cl|cl r b|cl b|cl b|cl r b|cl|cl r b|cl r|cl r|cl l b|cl r b|cl r|cl b|cl b|cl b|cl r|cl|cl r b|cl|cl r b|cl r|cl|cl b|cl r b|cl r|cl|cl r b|cl|cl r b|cl|cl r|cl r|cl r|cl b|cl r|cl r|cl r|cl b|cl r|cl r|cl|cl b|cl r b|cl|cl r b|cl b|cl r b|cl r|cl|cl r|cl b|cl r|cl|cl r b|cl|cl r b|cl b|cl r|cl r|cl l|cl r|cl r|cl|cl r|cl r|cl r|cl r|cl|cl r b|cl b|cl r|cl r|cl b|cl r|cl|cl r b|cl|cl r b|cl r|cl r|cl r|cl r|cl r|cl|cl r b|cl r|cl|cl r|cl r|cl r b|cl r|cl r|cl|cl r|cl|cl r|cl|cl r b|cl r b|cl r|cl|cl r b|cl b|cl r|cl b|cl b|cl r|cl b|cl r|cl l r|cl b|cl r b|cl r|cl b|cl r b|cl r|cl r b|cl b|cl b|cl r|cl r|cl b|cl r|cl|cl r b|cl r|cl r b|cl b|cl b|cl r b|cl r|cl b|cl r b|cl r|cl|cl r b|cl r|cl r b|cl r|cl|cl r|cl b|cl r b|cl|cl r b|cl r|cl b|cl b|cl r|cl r|cl b|cl b|cl r|cl b|cl|cl r b|cl r|cl|cl r b|cl l b|cl r|cl|cl b|cl b|cl r|cl r|cl|cl b|cl b|cl b|cl b|cl r|cl r|cl b|cl r|cl|cl b|cl b|cl b|cl b|cl r|cl|cl r|cl r|cl|cl r|cl b|cl r|cl b|cl r b|cl r|cl|cl r|cl r b|cl|cl b|cl b|cl r|cl r|cl b|cl|cl r|cl b|cl r|cl b|cl r|cl r|cl b|cl r|cl l|cl r b|cl b|cl b|cl r b|cl r|cl b|cl r b|cl r|cl|cl b|cl r|cl r b|cl b|cl r|cl r|cl|cl r|cl b|cl b|cl|cl r b|cl r|cl b|cl r b|cl r b|cl b|cl r|cl r|cl|cl b|cl r b|cl r|cl b|cl r|cl b|cl r|cl|cl r b|cl b|cl r|cl r b|cl b|cl b|cl b|cl b|cl r b|cl r|cl|cl r b|cl l b|cl b|cl b|cl b|cl b|cl r|cl|cl|cl r|cl r|cl b|cl b|cl b|cl r|cl r|cl r|cl r b|cl r|cl|cl r|cl r|cl r|cl r|cl|cl b|cl b|cl b|cl r b|cl|cl r b|cl|cl b|cl r b|cl r|cl r|cl|cl r b|cl r|cl|cl r|cl|cl b|cl b|cl b|cl b|cl b|cl b|cl r b|cl b|cl r|cl l r|cl|cl b|cl b|cl b|cl r b|cl r|cl r|cl r b|cl b|cl b|cl r|cl b|cl b|cl r b|cl b|cl r|cl b|cl r b|cl r|cl b|cl r|cl r|cl b|cl b|cl r|cl b|cl b|cl b|cl r b|cl r|cl|cl b|cl r b|cl r|cl r|cl b|cl r b|cl r|cl b|cl r b|cl|cl r|cl b|cl|cl r b|cl|cl b|cl r|cl r|cl l|cl r b|cl b|cl b|cl r|cl|cl r b|cl b|cl|cl r b|cl|cl r b|cl|cl b|cl r|cl r|cl r|cl|cl b|cl r b|cl b|cl r b|cl b|cl b|cl r|cl b|cl r|cl|cl b|cl r|cl b|cl r|cl|cl r|cl r|cl|cl b|cl b|cl b|cl b|cl r|cl r|cl b|cl r|cl b|cl b|cl b|cl r|cl r|cl r|cl l r|cl b|cl|cl r|cl b|cl r|cl r|cl|cl r b|cl|cl r|cl|cl r b|cl|cl r b|cl|cl b|cl r b|cl|cl b|cl b|cl|cl|cl r b|cl r|cl|cl r b|cl r|cl r|cl b|cl b|cl r b|cl r|cl b|cl r b|cl r|cl r|cl|cl r|cl b|cl r b|cl r|cl r|cl b|cl r|cl|cl r|cl r b|cl b|cl r|cl l b|cl b|cl r b|cl b|cl r|cl b|cl r|cl b|cl r|cl r|cl r|cl r|cl r|cl b|cl r|cl r b|cl|cl b|cl r b|cl|cl b|cl r b|cl r|cl|cl r b|cl r|cl|cl r b|cl|cl r|cl|cl r b|cl b|cl r|cl b|cl b|cl r b|cl r|cl r|cl|cl b|cl r b|cl|cl r|cl b|cl r b|cl r|cl|cl r|cl r|cl l|cl b|cl|cl r b|cl b|cl r|cl b|cl r b|cl r|cl r|cl r b|cl r|cl|cl r|cl b|cl b|cl r b|cl|cl r b|cl b|cl b|cl r|cl r b|cl r|cl|cl b|cl r b|cl b|cl r|cl r|cl b|cl|cl r b|cl r|cl|cl b|cl b|cl r b|cl b|cl r b|cl r|cl|cl r b|cl|cl r b|cl|cl r b|cl r|cl r|cl r|cl l|cl r|cl r b|cl|cl b|cl r b|cl|cl b|cl r|cl b|cl r|cl r|cl r|cl b|cl b|cl b|cl b|cl b|cl r|cl|cl r|cl b|cl b|cl r b|cl r|cl b|cl b|cl|cl r b|cl r|cl|cl r b|cl|cl r b|cl r|cl b|cl b|cl b|cl|cl r b|cl|cl r b|cl r|cl b|cl r|cl r|cl|cl r b|cl r|cl r|cl l r|cl b|cl r|cl r|cl|cl b|cl r|cl b|cl b|cl r|cl b|cl r b|cl r b|cl|cl b|cl r|cl|cl r|cl b|cl r b|cl|cl b|cl b|cl r|cl b|cl r|cl|cl r b|cl r|cl r|cl b|cl r|cl b|cl b|cl r b|cl|cl b|cl r|cl r|cl|cl b|cl b|cl r b|cl|cl r|cl r|cl b|cl r|cl r|cl r|cl l r|cl r|cl r|cl r|cl b|cl r b|cl|cl b|cl r|cl r|cl|cl b|cl b|cl r b|cl r|cl r|cl r|cl b|cl b|cl r|cl r|cl|cl b|cl r b|cl b|cl b|cl r b|cl b|cl b|cl b|cl b|cl b|cl b|cl r|cl b|cl r|cl b|cl r|cl b|cl b|cl r b|cl|cl r|cl r|cl r|cl b|cl b|cl r b|cl r|cl r|cl l b|cl r|cl b|cl r b|cl|cl r|cl b|cl r b|cl r|cl b|cl r b|cl|cl b|cl r|cl|cl r b|cl r|cl|cl r b|cl b|cl r b|cl r|cl|cl|cl b|cl b|cl b|cl b|cl r|cl|cl b|cl b|cl b|cl b|cl r|cl b|cl r|cl b|cl b|cl b|cl r|cl r|cl r|cl r|cl b|cl r|cl b|cl r|cl r|cl r|cl l r|cl b|cl r|cl b|cl r|cl b|cl b|cl r|cl r|cl|cl r|cl b|cl r b|cl r|cl b|cl b|cl r b|cl r|cl|cl b|cl b|cl r b|cl r b|cl r|cl|cl b|cl r|cl|cl r b|cl b|cl b|cl r|cl|cl r|cl b|cl r|cl r|cl|cl|cl r b|cl b|cl r b|cl b|cl r b|cl r|cl b|cl b|cl r|cl r|cl r|cl l|cl r|cl b|cl r|cl b|cl r|cl r|cl r|cl r|cl r|cl b|cl b|cl b|cl|cl b|cl r b|cl|cl b|cl r b|cl|cl b|cl|cl b|cl r b|cl r|cl|cl r b|cl b|cl r|cl b|cl b|cl r|cl r|cl r|cl|cl r b|cl r|cl r b|cl r|cl|cl b|cl|cl r b|cl|cl|cl b|cl r b|cl r|cl r|cl r|cl l r|cl b|cl r|cl r|cl|cl r b|cl r|cl b|cl r b|cl|cl b|cl b|cl r|cl r b|cl|cl r|cl b|cl b|cl r|cl b|cl r b|cl b|cl b|cl r|cl r|cl b|cl|cl r b|cl b|cl b|cl r|cl r|cl r|cl r|cl b|cl b|cl r b|cl|cl r b|cl b|cl r|cl b|cl b|cl r b|cl b|cl b|cl b|cl r b|cl r|cl r|cl l r|cl r|cl r|cl b|cl r b|cl|cl|cl r|cl b|cl b|cl r|cl|cl r b|cl|cl r b|cl b|cl|cl r|cl b|cl r|cl|cl b|cl b|cl r b|cl b|cl r|cl b|cl|cl r b|cl|cl r b|cl r b|cl r|cl b|cl b|cl r|cl b|cl r|cl|cl b|cl r b|cl|cl|cl r|cl b|cl r|cl|cl b|cl r b|cl r|cl l b|cl r|cl b|cl b|cl b|cl r b|cl r|cl b|cl r|cl|cl r b|cl b|cl b|cl r b|cl r|cl|cl r b|cl r|cl|cl r b|cl r|cl|cl|cl r|cl r|cl b|cl r|cl b|cl b|cl r b|cl|cl r|cl r|cl|cl r b|cl r|cl|cl r|cl b|cl r|cl r|cl r|cl r|cl b|cl b|cl r|cl r|cl|cl r|cl r|cl l b|cl b|cl r b|cl|cl b|cl b|cl r b|cl|cl r b|cl b|cl r|cl b|cl|cl r|cl r|cl r|cl b|cl r|cl b|cl r|cl r|cl r|cl r|cl|cl r b|cl|cl r b|cl|cl b|cl b|cl r b|cl b|cl r b|cl r|cl|cl r b|cl r|cl|cl r b|cl r|cl|cl r b|cl r|cl b|cl b|cl r b|cl b|cl r|cl r|cl r b|cl l|cl r|cl|cl r b|cl b|cl|cl r|cl b|cl b|cl r|cl r|cl|cl r|cl b|cl r b|cl b|cl r|cl|cl r b|cl b|cl r b|cl r b|cl r|cl r|cl|cl r b|cl r|cl|cl r|cl b|cl b|cl r|cl|cl b|cl r b|cl b|cl r|cl r|cl|cl r b|cl r b|cl|cl r b|cl|cl b|cl b|cl r|cl r b|cl b|cl r|cl l r|cl b|cl r b|cl|cl b|cl r b|cl b|cl b|cl r|cl r|cl r|cl r|cl r b|cl|cl b|cl r|cl r|cl r|cl|cl b|cl b|cl|cl r|cl r b|cl r|cl r|cl|cl r b|cl r|cl|cl b|cl r b|cl b|cl r|cl|cl r|cl r|cl r b|cl b|cl b|cl r|cl b|cl r|cl r|cl|cl r|cl b|cl b|cl r|cl r|cl l r|cl r|cl|cl r|cl|cl b|cl r|cl b|cl r b|cl r|cl|cl r b|cl|cl r b|cl r|cl b|cl r b|cl r|cl r|cl|cl b|cl r b|cl r b|cl|cl r b|cl r|cl r|cl|cl r b|cl r|cl|cl b|cl r|cl b|cl r b|cl r|cl|cl|cl b|cl r b|cl b|cl r|cl r|cl r|cl r|cl b|cl b|cl b|cl r b|cl r|cl l r|cl b|cl r b|cl b|cl r|cl r|cl r|cl|cl r|cl r|cl r|cl|cl r b|cl r|cl|cl r|cl|cl r b|cl r|cl r|cl|cl b|cl r|cl r|cl|cl b|cl r b|cl r|cl b|cl b|cl b|cl r b|cl r|cl|cl b|cl r b|cl r b|cl r|cl|cl b|cl b|cl b|cl r b|cl r|cl b|cl b|cl r|cl b|cl|cl r|cl l r|cl|cl b|cl r|cl b|cl r b|cl b|cl r b|cl r|cl r|cl r b|cl r|cl b|cl b|cl r b|cl|cl r b|cl r|cl r|cl b|cl r b|cl r|cl b|cl r b|cl r|cl r|cl|cl r b|cl|cl r|cl|cl b|cl r b|cl r|cl|cl b|cl r|cl b|cl r b|cl|cl r|cl|cl r|cl b|cl r|cl|cl r b|cl|cl r b|cl r|cl l r|cl b|cl r|cl b|cl b|cl r|cl|cl b|cl r b|cl b|cl r|cl|cl b|cl b|cl r|cl r|cl b|cl r|cl b|cl r|cl|cl|cl b|cl r b|cl b|cl r|cl b|cl b|cl r b|cl r|cl r|cl|cl b|cl r b|cl r|cl b|cl b|cl b|cl r|cl r|cl r|cl r|cl b|cl b|cl r b|cl b|cl r|cl r|cl|cl r b|cl l|cl b|cl r b|cl r|cl|cl r b|cl b|cl r|cl|cl r|cl r|cl b|cl r|cl|cl r b|cl b|cl b|cl r b|cl|cl r b|cl r|cl b|cl r|cl|cl r|cl r|cl b|cl b|cl r|cl r|cl r|cl b|cl b|cl r|cl|cl r|cl|cl r|cl b|cl r b|cl b|cl r b|cl b|cl|cl|cl r b|cl b|cl r b|cl r|cl r|cl l r|cl b|cl|cl r b|cl b|cl b|cl r|cl b|cl r|cl b|cl r b|cl|cl r b|cl r|cl|cl r|cl|cl b|cl r b|cl b|cl b|cl r b|cl b|cl r b|cl|cl r b|cl|cl b|cl r b|cl r|cl b|cl b|cl|cl r b|cl r b|cl r|cl r|cl b|cl r|cl|cl b|cl|cl r|cl r b|cl r|cl|cl|cl r b|cl b|cl r|cl l b|cl r|cl b|cl|cl b|cl r b|cl b|cl r|cl b|cl b|cl r|cl r b|cl|cl r b|cl r|cl b|cl r b|cl|cl b|cl b|cl b|cl b|cl b|cl r|cl b|cl b|cl r b|cl|cl r|cl r|cl|cl r|cl r|cl|cl r|cl r|cl b|cl r|cl r|cl b|cl r|cl r|cl b|cl b|cl r|cl r|cl b|cl b|cl r|cl r|cl l r|cl b|cl b|cl r|cl|cl b|cl r|cl|cl r|cl b|cl b|cl b|cl r|cl|cl r b|cl b|cl b|cl r|cl|cl|cl r b|cl|cl b|cl r b|cl|cl b|cl b|cl r b|cl r|cl b|cl r|cl r|cl b|cl r b|cl r|cl r|cl|cl r b|cl b|cl r|cl r b|cl b|cl r|cl r|cl r|cl r|cl|cl r b|cl b|cl r b|cl l|cl r|cl|cl r b|cl r|cl r|cl r|cl r|cl b|cl r|cl b|cl b|cl r b|cl r|cl|cl b|cl r|cl r|cl r|cl r|cl|cl r b|cl|cl r b|cl|cl b|cl r|cl r|cl b|cl r|cl r|cl b|cl r|cl|cl r b|cl b|cl r|cl|cl r|cl r|cl|cl b|cl r b|cl r|cl r|cl r|cl b|cl|cl|cl r|cl l r|cl b|cl b|cl r b|cl r|cl|cl r b|cl b|cl r b|cl b|cl r|cl|cl b|cl r b|cl r|cl r|cl b|cl r b|cl r|cl r|cl r|cl|cl b|cl r|cl r|cl|cl r b|cl|cl r|cl r|cl b|cl r b|cl r|cl r|cl|cl r|cl r|cl r|cl r b|cl r|cl r|cl b|cl r|cl|cl r b|cl b|cl r|cl r|cl r|cl r b|cl l r|cl r|cl|cl b|cl r b|cl b|cl b|cl b|cl b|cl b|cl r b|cl b|cl r|cl|cl r|cl|cl r|cl|cl r b|cl b|cl r b|cl r|cl|cl r b|cl r|cl b|cl r|cl r|cl b|cl r b|cl|cl r|cl r|cl b|cl r b|cl r|cl b|cl r|cl|cl r b|cl|cl r|cl b|cl r|cl|cl b|cl r b|cl r b|cl b|cl r|cl l r|cl r|cl b|cl b|cl b|cl b|cl b|cl b|cl b|cl b|cl r|cl|cl r b|cl r b|cl r|cl r|cl r b|cl r|cl|cl b|cl b|cl r b|cl b|cl b|cl r b|cl|cl r b|cl b|cl r|cl|cl r b|cl b|cl r b|cl b|cl r|cl r|cl|cl r b|cl r|cl|cl r b|cl b|cl r|cl r|cl b|cl r|cl|cl b|cl b|cl r|cl l r|cl b|cl|cl r|cl b|cl b|cl|cl r|cl r|cl|cl r b|cl b|cl b|cl b|cl r b|cl|cl b|cl r b|cl b|cl r b|cl|cl b|cl b|cl b|cl r|cl r|cl|cl r b|cl r|cl r|cl r|cl|cl b|cl|cl r b|cl r|cl b|cl r b|cl r|cl r|cl|cl b|cl r b|cl b|cl r b|cl r|cl r|cl|cl b|cl r b|cl l b|cl b|cl r b|cl b|cl b|cl b|cl r b|cl b|cl r b|cl b|cl b|cl b|cl b|cl b|cl b|cl b|cl b|cl b|cl b|cl b|cl r b|cl b|cl b|cl b|cl b|cl r b|cl b|cl b|cl b|cl r b|cl b|cl b|cl r b|cl b|cl b|cl b|cl b|cl b|cl r b|cl r b|cl b|cl b|cl b|cl b|cl b|cl b|cl r b|cl b|cl b|cl r"
    }');
  perform data.create_object(
    'mine_equipment',
    jsonb '{
      "type": "mine_map",
      "is_visible": true,
      "template": {"groups": []},
      "mine_equipment": [
        {"id": "1", "x":11, "y":11, "type":"driller", "actor_id": false, "fueled": true, "broken":true, "firm":"TM", "content":[]},
        {"id": "2", "x":11, "y":12, "type":"box", "actor_id": false, "fueled": true, "broken":false, "firm":"TM", "content":[]},
        {"id": "3", "x":11, "y":13, "type":"brill", "actor_id": false, "fueled": true, "broken":false, "firm":"DB", "content":[]},
        {"id": "4", "x":11, "y":14, "type":"buksir", "actor_id": false, "fueled": true, "broken":false, "firm":"DB", "content":[]},
        {"id": "5", "x":11, "y":15, "type":"digger", "actor_id": false, "fueled": true, "broken":false, "firm":"SH", "content":[]},
        {"id": "6", "x":11, "y":16, "type":"dron", "actor_id": false, "fueled": true, "broken":false, "firm":"AD", "content":[]},
        {"id": "7", "x":11, "y":17, "type":"iron", "actor_id": false, "fueled": true, "broken":false, "firm":"TO", "content":[]},
        {"id": "8", "x":11, "y":19, "type":"loader", "actor_id": false, "fueled": true, "broken":false, "firm":"TO", "content":[]},
        {"id": "9", "x":11, "y":20, "type":"stealer", "actor_id": false, "fueled": true, "broken":false, "firm":"AC", "content":[]},
        {"id": "10", "x":11, "y":21, "type":"stone", "actor_id": false, "fueled": true, "broken":false, "firm":"AC", "content":[]},
        {"id": "11", "x":11, "y":22, "type":"ship", "actor_id": false, "fueled": true, "broken":false," firm":"AC", "content":[]},
        {"id": "12", "x":11, "y":23, "type":"barge", "actor_id": false, "fueled": true, "broken":false, "firm":"AC", "content":[]},
        {"id": "13", "x":11, "y":24, "type":"train", "actor_id": false, "fueled": true, "broken":false, "firm":"AC", "content":[]},
        {"id": "14", "x":11, "y":12, "type":"brillmine", "actor_id": false, "fueled": true, "broken":false, "firm":"TM", "content":[]},
        {"id": "15", "x":11, "y":13, "type":"stonemine", "actor_id": false, "fueled": true, "broken":false, "firm":"DB", "content":[]},
        {"id": "16", "x":11, "y":14, "type":"ironmine", "actor_id": false, "fueled": true, "broken":false, "firm":"DB", "content":[]}
      ]
    }');
end;
$$
language plpgsql;
