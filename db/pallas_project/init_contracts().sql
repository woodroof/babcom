-- drop function pallas_project.init_contracts();

create or replace function pallas_project.init_contracts()
returns void
volatile
as
$$
begin
  perform pallas_project.create_contract('7545edc8-d3f8-4ff3-a984-6c96e261f5c5', 'org_administration', 'active', 300, 'Михаил Ситников обязуется выполнять обязанности, перечисленные в должностной инструкции специалиста по связям с общественностью администрации колонии ООН');
  perform pallas_project.create_contract('5f7c2dc0-0cb4-4fc5-870c-c0776272a02e', 'org_administration', 'active', 150, 'Люк Ламбер обязуется выполнять обязанности, перечисленные в должностной инструкции инженера-ремонтника 3 разряда');
  perform pallas_project.create_contract('4cb29808-bc92-4cf8-a755-a3f0785ac4b8', 'org_administration', 'active', 150, 'Кристиан Остерхаген обязуется выполнять обязанности, перечисленные в должностной инструкции инженера-электронщика 3 разряда');
  perform pallas_project.create_contract('2ce20542-04f1-418f-99eb-3c9d2665f733', 'org_administration', 'suspended', 150, 'Герберт Чао Су обязуется выполнять обязанности, перечисленные в должностной инструкции геологоразведчика');
  perform pallas_project.create_contract('18ce44b8-5df9-4c84-8af4-b58b3f5e7b21', 'org_administration', 'suspended', 150, 'Алисия Сильверстоун обязуется выполнять обязанности, перечисленные в должностной инструкции геологоразведчика');
  perform pallas_project.create_contract('09c74928-0cf8-4c15-b9a9-aef481b438e6', 'org_administration', 'active', 150, 'Элтон Спирс обязуется выполнять обязанности, перечисленные в должностной инструкции сантехника 3 разряда');
  perform pallas_project.create_contract('0a0dc809-7bf1-41ee-bfe7-700fd26c1c0a', 'org_de_beers', 'active', 400, 'Абрахам Грей обязуется выполнять обязанности, перечисленные в должностной инструкции заместителя директора филиала организации Де Бирс');
  perform pallas_project.create_contract('5074485d-73cd-4e19-8d4b-4ffedcf1fb5f', 'org_de_beers', 'suspended', 150, 'Лаура Джаррет обязуется выполнять обязанности, перечисленные в должностной инструкции бригадира шахтёров');
  perform pallas_project.create_contract('3beea660-35a3-431e-b9ae-e2e88e6ac064', 'org_de_beers', 'suspended', 150, 'Джеф Бриджес обязуется выполнять обязанности, перечисленные в должностной инструкции бригадира шахтёров');
  perform pallas_project.create_contract('09951000-d915-495d-867d-4d0e7ebfcf9c', 'org_de_beers', 'suspended', 135, 'Аарон Краузе обязуется выполнять обязанности, перечисленные в должностной инструкции шахтёра высшей категории');
  perform pallas_project.create_contract('82d0dbb5-0c9b-412c-810f-79827370c37f', 'org_de_beers', 'suspended', 115, 'Невил Гонзалес обязуется выполнять обязанности, перечисленные в должностной инструкции шахтёра');
  perform pallas_project.create_contract('a11d2240-3dce-4d75-bc52-46e98b07ff27', 'org_de_beers', 'suspended', 115, 'Сьюзан Сидорова обязуется выполнять обязанности, перечисленные в должностной инструкции шахтёра');
  perform pallas_project.create_contract('be0489a5-05ec-430f-a74c-279a198a22e5', 'org_de_beers', 'suspended', 115, 'Хэнк Даттон обязуется выполнять обязанности, перечисленные в должностной инструкции шахтёра');
  perform pallas_project.create_contract('48569d1d-5f01-410f-a67b-c5fe99d8dbc1', 'org_star_helix', 'active', 400, 'Кайла Ангас  обязуется выполнять обязанности, перечисленные в должностной инструкции директора филиала Star Helix');
  perform pallas_project.create_contract('3d303557-6459-4b94-b834-3c70d2ba295d', 'org_star_helix', 'active', 260, 'Джордан Закс обязуется выполнять обязанности, перечисленные в должностной инструкции полицейского');
  perform pallas_project.create_contract('24f8fd67-962e-4466-ac85-02ca88cd66eb', 'org_star_helix', 'active', 260, 'Бобби Смит обязуется выполнять обязанности, перечисленные в должностной инструкции полицейского');
  perform pallas_project.create_contract('be28d490-6c68-4ee4-a244-6700d01d16cc', 'org_star_helix', 'active', 260, 'Лила Финчер обязуется выполнять обязанности, перечисленные в должностной инструкции детектива');
  perform pallas_project.create_contract('939b6537-afc1-41f4-963a-21ccfd1c7d28', 'org_akira_sc', 'active', 400, 'Роберт Ли обязуется выполнять обязанности, перечисленные в должностной инструкции начальника порта');
  perform pallas_project.create_contract('70e5db08-df47-4395-9f4a-15eef99b2b89', 'org_akira_sc', 'active', 300, 'Невил Гонзалес обязуется выполнять обязанности, перечисленные в должностной инструкции заведующего складом');
  perform pallas_project.create_contract('37fb2074-498c-4d28-8395-9fdf993f2b06', 'org_akira_sc', 'active', 150, 'Джесси О''Коннелл обязуется выполнять обязанности, перечисленные в должностной инструкции таможенного специалита');
  perform pallas_project.create_contract('d6ed7fcb-2e68-40b3-b0ab-5f6f4edc2f19', 'org_akira_sc', 'active', 150, 'Элен Марвинг обязуется выполнять обязанности, перечисленные в должностной инструкции таможенного специалита');
  perform pallas_project.create_contract('81491084-b02a-471f-9293-b20497e0054a', 'org_akira_sc', 'active', 115, 'Наоми Гейтс обязуется выполнять обязанности, перечисленные в должностной инструкции бригадира ремонтной бригады');
  perform pallas_project.create_contract('b9309ed3-d19f-4d2d-855a-a9a3ffdf8e9c', 'org_akira_sc', 'active', 115, 'Харальд Скарсгард обязуется выполнять обязанности, перечисленные в должностной инструкции инженера по ремонту технических систем');
  perform pallas_project.create_contract('c9e08512-e729-430a-b2fd-df8e7c94a5e7', 'org_akira_sc', 'active', 115, 'Чарльз Вилкинсон обязуется выполнять обязанности, перечисленные в должностной инструкции инженера по ремонту технических систем');
  perform pallas_project.create_contract('1fbcf296-e9ad-43b0-9064-1da3ff6d326d', 'org_akira_sc', 'active', 115, 'Амели Сноу обязуется выполнять обязанности, перечисленные в должностной инструкции бригадира грузчиков');
  perform pallas_project.create_contract('3a83fb3c-b954-4a04-aa6c-7a46d7bf9b8e', 'org_akira_sc', 'active', 115, 'Джессика Куин обязуется выполнять обязанности, перечисленные в должностной инструкции грузчика');
  perform pallas_project.create_contract('a9e4bc61-4e10-4c9e-a7de-d8f61536f657', 'org_akira_sc', 'active', 115, 'Сэмми Куин обязуется выполнять обязанности, перечисленные в должностной инструкции грузчика');
  perform pallas_project.create_contract('5a764843-9edc-4cfb-8367-80c1d3c54ed9', 'org_akira_sc', 'active', 115, 'Луиза О''Нил обязуется выполнять обязанности, перечисленные в должностной инструкции пилота');
  perform pallas_project.create_contract('47d63ed5-3764-4892-b56d-597dd1bbc016', 'org_akira_sc', 'active', 115, 'Дональд Чамберс обязуется выполнять обязанности, перечисленные в должностной инструкции пилота');
  perform pallas_project.create_contract('7051afe2-3430-44a7-92e3-ad299aae62e1', 'org_clean_asteroid', 'active', 115, 'Мария Липпи обязуется выполнять обязанности, перечисленные в должностной инструкции клинингового специалиста');
  perform pallas_project.create_contract('21670857-6be0-4f77-8756-79636950bc36', 'org_clinic', 'active', 115, 'Анна Джаррет обязуется выполнять обязанности, перечисленные в должностной инструкции медсестры');
  perform pallas_project.create_contract('523e8589-f948-4c42-a32b-fe39648488f2', 'org_clinic', 'active', 115, 'Лиза Скай обязуется выполнять обязанности, перечисленные в должностной инструкции медсестры');
  perform pallas_project.create_contract('468c4f12-1a52-4681-8a78-d80dfeaec90e', 'org_tariel', 'active', 300, 'Джэйн Синглтон обязуется выполнять обязанности, перечисленные в должностной инструкции пилота');
  perform pallas_project.create_contract('9f114f78-8b87-4363-bf55-a19522282e4e', 'org_cavern', 'active', 115, 'Соня Попова обязуется выполнять обязанности, перечисленные в должностной инструкции официанта');
  perform pallas_project.create_contract('7a51a4fc-ed1f-47c9-a67a-d56cd56b67de', 'org_cavern', 'active', 115, 'Марта Скарсгард обязуется выполнять обязанности, перечисленные в должностной инструкции официанта');
  perform pallas_project.create_contract('ea450b61-9489-4f98-ab0e-375e01a7df03', 'org_cavern', 'active', 115, 'Кип Шиммер обязуется выполнять обязанности, перечисленные в должностной инструкции диджея');
  perform pallas_project.create_contract('82a7d37d-1067-4f21-a980-9c0665ce579c', 'org_riders_digest', 'active', 350, 'Мишель Буфано обязуется выполнять обязанности, перечисленные в должностной инструкции представителя организации при переговорах в колониях ООН');
  perform pallas_project.create_contract('0815d2a6-c82c-476c-a3dd-ed70a3f59e91', 'org_riders_digest', 'active', 350, 'Саймон Фронцек обязуется выполнять обязанности, перечисленные в должностной инструкции представителя организации при переговорах в колониях ООН');
end;
$$
language plpgsql;
