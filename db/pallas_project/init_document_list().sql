-- drop function pallas_project.init_document_list();

create or replace function pallas_project.init_document_list()
returns void
volatile
as
$$
begin
  perform pallas_project.create_document('Выписка со счёта', 'TODO Сергей Корсак, Переводы Марте Скарсгард', array['9b956c40-7978-4b0a-993e-8373fe581761', '7a51a4fc-ed1f-47c9-a67a-d56cd56b67de']);
  perform pallas_project.create_document('Отчёт о состоянии штолен 30-35', 'TODO: поддельный, подписи?', array['95a3dc9e-8512-44ab-9173-29f0f4fd6e05', '3beea660-35a3-431e-b9ae-e2e88e6ac064']);
  perform pallas_project.create_document('Расписка', 'TODO: Рыбкина на имя Вилкинсона, подписи?', array['aebb6773-8651-4afc-851a-83a79a2bcbec']);
  perform pallas_project.create_document('Справка о вирусе Рио Миаморе', 'TODO', array['5f7c2dc0-0cb4-4fc5-870c-c0776272a02e', 'b9309ed3-d19f-4d2d-855a-a9a3ffdf8e9c', '54e94c45-ce2a-459a-8613-9b75e23d9b68', '7051afe2-3430-44a7-92e3-ad299aae62e1', '7a51a4fc-ed1f-47c9-a67a-d56cd56b67de']);
  perform pallas_project.create_document('Выписка со счёта', 'TODO, Перевод Де Бирс -> Сакура', array['784e4126-8dd7-41a3-a916-0fdc53a31ce2', '8f7b1cc6-28cd-4fb1-8c81-e0ab1c0df5c9']);
  perform pallas_project.create_document('Выписка со счёта', 'TODO, Перевод Де Бирс -> Вишнёвый сад', array['784e4126-8dd7-41a3-a916-0fdc53a31ce2', '8f7b1cc6-28cd-4fb1-8c81-e0ab1c0df5c9']);
  perform pallas_project.create_document('Уведомление о смерти TODO', 'TODO отца Лауры Джаррет', array['5074485d-73cd-4e19-8d4b-4ffedcf1fb5f']);
  perform pallas_project.create_document('Контракт TODO', 'TODO контракт Невила Гонзалеса с ледовозом на время взрыва Гефеста', array['82d0dbb5-0c9b-412c-810f-79827370c37f']);
  perform pallas_project.create_document('Список арестов', 'TODO Сьюзан Сидоровой', array['a11d2240-3dce-4d75-bc52-46e98b07ff27']);
  perform pallas_project.create_document('Письмо TODO', 'TODO Сьюзан Сидоровой от большого Фреда', array['a11d2240-3dce-4d75-bc52-46e98b07ff27', 'ac1b23d0-ba5f-4042-85d5-880a66254803']);
  perform pallas_project.create_document('TODO', 'TODO глаза женщины', array['3beea660-35a3-431e-b9ae-e2e88e6ac064']);
  perform pallas_project.create_document('Решение суда по коллективному иску о школьне 32', 'TODO', array['3beea660-35a3-431e-b9ae-e2e88e6ac064']);
  perform pallas_project.create_document('Результаты анализов', 'TODO Хэнк Даттон', array['be0489a5-05ec-430f-a74c-279a198a22e5']);
  perform pallas_project.create_document('Уведомление о смерти TODO', 'TODO отца Алисии Сильверстоун', array['18ce44b8-5df9-4c84-8af4-b58b3f5e7b21']);
  perform pallas_project.create_document('Письмо TODO', 'TODO любовное Алисии Сильверстоун от Брэндона Мёрфи', array['18ce44b8-5df9-4c84-8af4-b58b3f5e7b21', '71efd585-080c-431d-a258-b4e222ff7623']);
  perform pallas_project.create_document('Свидетельство об обучении', 'TODO Алисии Сильверстоун, геологоразведка на Луне', array['18ce44b8-5df9-4c84-8af4-b58b3f5e7b21']);
  perform pallas_project.create_document('Список дел', 'TODO полицейские (несколько документов?)', array['48569d1d-5f01-410f-a67b-c5fe99d8dbc1', '2903429c-8f58-4f78-96f7-315246b17796', '3d303557-6459-4b94-b834-3c70d2ba295d', 'be28d490-6c68-4ee4-a244-6700d01d16cc']);
  perform pallas_project.create_document('Рекомендация TODO', 'TODO Кайла Ангас на Лилу Финчер о повышении', array['48569d1d-5f01-410f-a67b-c5fe99d8dbc1']);
  perform pallas_project.create_document('Выписка со счёта', 'TODO Джордан Закс, множество переводов со счёта Харальда', array['3d303557-6459-4b94-b834-3c70d2ba295d']);
  perform pallas_project.create_document('Свидетельство о рождении', 'TODO Джордан Закс', array['3d303557-6459-4b94-b834-3c70d2ba295d']);
  perform pallas_project.create_document('Уведомление о смерти TODO', 'TODO отца Бобби Смита', array['24f8fd67-962e-4466-ac85-02ca88cd66eb']);
  perform pallas_project.create_document('Выписка со счёта', 'TODO Бобби Смит, множество переводов со счёта Милана Ясневски', array['24f8fd67-962e-4466-ac85-02ca88cd66eb', '74bc1a0f-72d9-4271-b358-0ef464f3cbf9']);
  perform pallas_project.create_document('Отчёт о состоянии штолен 30-35', 'TODO: оригинал, подписи?', array['b9309ed3-d19f-4d2d-855a-a9a3ffdf8e9c', '9b8c205e-9483-44f9-be9b-2af47a765f9c']);
  perform pallas_project.create_document('Выписка со счёта', 'TODO: Харальд Скаард, Множество переводов на счёт Закса', array['b9309ed3-d19f-4d2d-855a-a9a3ffdf8e9c']);
  perform pallas_project.create_document('Выписка со счёта', 'TODO: Чарльз Вилкинсон, Множество переводов от Милана Ясневски', array['c9e08512-e729-430a-b2fd-df8e7c94a5e7']);
  perform pallas_project.create_document('TODO', 'TODO флэшка (Янг)', array['1fbcf296-e9ad-43b0-9064-1da3ff6d326d', 'e0c49e51-779f-4f21-bb94-bbbad33bc6e2']);
  perform pallas_project.create_document('Выписка со счёта', 'TODO: Перевод Амели Сноу от Тома Алиева', array['1fbcf296-e9ad-43b0-9064-1da3ff6d326d', 'ea68988b-b540-4685-aefb-cbd999f4c9ba']);
  perform pallas_project.create_document('TODO', 'TODO: Попов, Компромат на Ситникова', array['70e5db08-df47-4395-9f4a-15eef99b2b89']);
  perform pallas_project.create_document('TODO', 'TODO: Попов, Компромат на Вилкинсона', array['70e5db08-df47-4395-9f4a-15eef99b2b89']);
  perform pallas_project.create_document('TODO', 'TODO: Попов, Компромат на Луизу О''Нил', array['70e5db08-df47-4395-9f4a-15eef99b2b89']);
  perform pallas_project.create_document('TODO', 'TODO: Попов, Ориентировка по картелю на мальчика Криса Марвинга (а другим из картеля?)', array['70e5db08-df47-4395-9f4a-15eef99b2b89']);
  perform pallas_project.create_document('Расписка', 'TODO: Попов, от Дональда Чамберса на $10000 (подписи!)', array['70e5db08-df47-4395-9f4a-15eef99b2b89', '47d63ed5-3764-4892-b56d-597dd1bbc016']);
  perform pallas_project.create_document('Выписка со счёта', 'TODO: Попов, Список переводов Шиммеру за слежку за дочерью', array['70e5db08-df47-4395-9f4a-15eef99b2b89', 'ea450b61-9489-4f98-ab0e-375e01a7df03']);
  perform pallas_project.create_document('Выписка со счёта', 'TODO: Попов, Список переводов Амели Сноу', array['70e5db08-df47-4395-9f4a-15eef99b2b89']);
  perform pallas_project.create_document('Выписка со счёта', 'TODO: Попов, Список переводов Абрахаму Грей', array['70e5db08-df47-4395-9f4a-15eef99b2b89']);
  perform pallas_project.create_document('Выписка со счёта', 'TODO: Попов, Список переводов Чарльзу Вилкинсону', array['70e5db08-df47-4395-9f4a-15eef99b2b89']);
  perform pallas_project.create_document('Список арестов', 'TODO Луизы О''Нил', array['5a764843-9edc-4cfb-8367-80c1d3c54ed9']);
  perform pallas_project.create_document('Форма согласия на добровольное участие в испытаниях медицинских препаратов', 'TODO', array['54e94c45-ce2a-459a-8613-9b75e23d9b68', '8f7b1cc6-28cd-4fb1-8c81-e0ab1c0df5c9', '6dc0a14a-a63f-44aa-a677-e5376490f28d']);
  perform pallas_project.create_document('Согласие Льва Уильяма на добровольное участие в испытаниях TODO', 'TODO (подписи?)', array['54e94c45-ce2a-459a-8613-9b75e23d9b68', '8f7b1cc6-28cd-4fb1-8c81-e0ab1c0df5c9', '6dc0a14a-a63f-44aa-a677-e5376490f28d']);
  perform pallas_project.create_document('Сертификат о завершении курса медсестёр', 'TODO Мария Липпи, липовый', array['7051afe2-3430-44a7-92e3-ad299aae62e1']);
  perform pallas_project.create_document('Сертификат о завершении курса медсестёр', 'TODO Анна Джаррет на Ганимеде', array['21670857-6be0-4f77-8756-79636950bc36']);
  perform pallas_project.create_document('Сертификат о завершении курса медсестёр', 'TODO Лиза Скай, липовый', array['523e8589-f948-4c42-a32b-fe39648488f2']);
  perform pallas_project.create_document('TODO', 'TODO Письмо от департамента занятости', array['e0c49e51-779f-4f21-bb94-bbbad33bc6e2']);
  perform pallas_project.create_document('Выписка со счёта', 'TODO, Перевод Свободное небо -> Чистый астероид, $2000', array['e0c49e51-779f-4f21-bb94-bbbad33bc6e2', 'ac1b23d0-ba5f-4042-85d5-880a66254803']);
  perform pallas_project.create_document('Разрешение на выселение', 'TODO астеров', array['8f7b1cc6-28cd-4fb1-8c81-e0ab1c0df5c9']);
  perform pallas_project.create_document('TODO', 'TODO заказ лекарств', array['8f7b1cc6-28cd-4fb1-8c81-e0ab1c0df5c9']);
  perform pallas_project.create_document('TODO', 'TODO Письмо от Теко Марс, рекомендуют поддержать проект доктора Остин', array['8f7b1cc6-28cd-4fb1-8c81-e0ab1c0df5c9']);
  perform pallas_project.create_document('Договор аренды', 'TODO', array['8f7b1cc6-28cd-4fb1-8c81-e0ab1c0df5c9', '19b66636-cd8e-4733-8a3d-2f16346bb81e']);
  perform pallas_project.create_document('TODO', 'TODO Сара Ф Остин, Расшифровка разговора с братом с Гефеста', array['9b8c205e-9483-44f9-be9b-2af47a765f9c']);
  perform pallas_project.create_document('TODO', 'TODO Письмо Валентину Штерну от Брэндона Мёрфи', array['2956e4b7-7b02-4ffd-a725-ea3390b9a1cc', '71efd585-080c-431d-a258-b4e222ff7623']);
  perform pallas_project.create_document('TODO', 'TODO Диск марсианской лаборатории с Гефеста (зашифрован), часть 1', array['2956e4b7-7b02-4ffd-a725-ea3390b9a1cc']);
  perform pallas_project.create_document('Выписка со счёта', 'TODO, Перевод Штерну от Уильяма Келли за проезд', array['2956e4b7-7b02-4ffd-a725-ea3390b9a1cc', 'ac1b23d0-ba5f-4042-85d5-880a66254803']);
  perform pallas_project.create_document('TODO', 'TODO, список контрабанды, перевезённой за последнее время', array['2956e4b7-7b02-4ffd-a725-ea3390b9a1cc']);
  perform pallas_project.create_document('TODO', 'TODO, Джэйн Синглтон письмо от Вилкинсона', array['468c4f12-1a52-4681-8a78-d80dfeaec90e']);
  perform pallas_project.create_document('Приказ об отчислении', 'TODO, Джэйн Синглтон из академии', array['468c4f12-1a52-4681-8a78-d80dfeaec90e']);
  perform pallas_project.create_document('Разрешение на проведение публичной проповеди', 'TODO Уильяму Келли', array['ac1b23d0-ba5f-4042-85d5-880a66254803']);
  perform pallas_project.create_document('TODO', 'TODO письмо доктору Янг от Фреда Амбера', array['ac1b23d0-ba5f-4042-85d5-880a66254803']);
  perform pallas_project.create_document('TODO', 'TODO Заказ оружия с Марса Фредом Амбером', array['ac1b23d0-ba5f-4042-85d5-880a66254803']);
  perform pallas_project.create_document('Накладная', 'TODO 1 Грег Тэйлор', array['2d912a30-6c35-4cef-9d74-94665ac0b476']);
  perform pallas_project.create_document('Накладная', 'TODO 2 Грег Тэйлор', array['2d912a30-6c35-4cef-9d74-94665ac0b476']);
  perform pallas_project.create_document('Отчёт по проекту Анлант, Паллада', 'TODO', array['6dc0a14a-a63f-44aa-a677-e5376490f28d']);
  perform pallas_project.create_document('Отчёт по проекту Анлант, Гефест', 'TODO', array['6dc0a14a-a63f-44aa-a677-e5376490f28d']);
  perform pallas_project.create_document('TODO', 'TODO документ со списком особых полномочий на имя Алекс Камаль', array['6dc0a14a-a63f-44aa-a677-e5376490f28d']);
  perform pallas_project.create_document('Инструкция TODO', 'TODO к прибору про гравитацию', array['8d3e1b38-ab96-4d87-8c51-1be2ce1a0111']);
  perform pallas_project.create_document('Список арестов', 'TODO Марта Скарсгард', array['7a51a4fc-ed1f-47c9-a67a-d56cd56b67de']);
  perform pallas_project.create_document('TODO', 'TODO Письмо от Сергея Корсака', array['7a51a4fc-ed1f-47c9-a67a-d56cd56b67de']);
  perform pallas_project.create_document('TODO', 'TODO Отчёты о деятельности Сони', array['ea450b61-9489-4f98-ab0e-375e01a7df03']);
  perform pallas_project.create_document('Книга Первого Астера', 'TODO', array['74bc1a0f-72d9-4271-b358-0ef464f3cbf9']);
  perform pallas_project.create_document('Выписка со счёта', 'TODO Милан Ясневски Переводы Айронхарту за помощь в работе', array['74bc1a0f-72d9-4271-b358-0ef464f3cbf9', 'f4a2767d-73f2-4057-9430-f887d4cd05e5']);
  perform pallas_project.create_document('Компромат на TODO', 'TODO Шоу на папу Ганди', array['36cef6aa-aefc-479d-8cef-55534e8cd159']);
  perform pallas_project.create_document('TODO', 'TODO Справка по Гефесту', array['457ea315-fc47-4579-a12b-fd7b91375ba8']);
  perform pallas_project.create_document('Пациент Лев Уильямс, клинические испытания препарата № J412F', 'TODO', array['457ea315-fc47-4579-a12b-fd7b91375ba8']);
  perform pallas_project.create_document('TODO', 'TODO Диск с информацией с Гефеста, часть 2. Зашифрован.', array['457ea315-fc47-4579-a12b-fd7b91375ba8']);
  perform pallas_project.create_document('Фоторобот', 'TODO Люси Мартин', array['457ea315-fc47-4579-a12b-fd7b91375ba8']);
  perform pallas_project.create_document('TODO', 'TODO Аманда Ганди, письмо от Борислава Маслова', array['19b66636-cd8e-4733-8a3d-2f16346bb81e']);
  perform pallas_project.create_document('О забастовке на станции Паллада', 'TODO Аманда Ганди доклад', array['19b66636-cd8e-4733-8a3d-2f16346bb81e']);
  perform pallas_project.create_document('TODO', 'TODO Документ, подтверждающий полномочия', array['19b66636-cd8e-4733-8a3d-2f16346bb81e']);
  perform pallas_project.create_document('TODO', 'TODO Список погибших из морга Балтимора', array['d6ed7fcb-2e68-40b3-b0ab-5f6f4edc2f19']);
  perform pallas_project.create_document('Проект Радист', 'TODO', array['dc2505e8-9f8e-4a41-b42f-f1f348db8c99']);
  perform pallas_project.create_document('TODO', 'TODO документы по ридерам', array['82a7d37d-1067-4f21-a980-9c0665ce579c', '0815d2a6-c82c-476c-a3dd-ed70a3f59e91']);
  perform pallas_project.create_document('TODO', 'TODO что-нибудь про ридеров для Айронхарта', array['f4a2767d-73f2-4057-9430-f887d4cd05e5']);
  perform pallas_project.create_document('TODO', 'TODO заметка в календаре о встрече Мёрфи с Джорданом Заксом', array['71efd585-080c-431d-a258-b4e222ff7623']);
  perform pallas_project.create_document('Лицензия пилота', 'TODO на имя Карлы Хьюз', array['5a764843-9edc-4cfb-8367-80c1d3c54ed9']);
  perform pallas_project.create_document('TODO', 'TODO письмо от Эшли Гарсия Клэр Санхилл', array['523e8589-f948-4c42-a32b-fe39648488f2']);

  -- Большие телеги
  perform pallas_project.create_document('Манифест вергуманизма', E'**Преамбула**\n\nСовременный Солнечный гуманизм преобразует мир. Его идеи и ценности непрестанно поддерживают нашу уверенность в способности справиться с проблемами, с которыми мы сталкиваемся, и освоить ещё неведомые нам реальности.\n\nНа протяжении всей истории планетарное сообщество людей имело возможность примирять любые имеющиеся у нас различия сообща и мирным путем. Мы используем термин «сообщество» ввиду возникновения глобального сознания и широкого признания факта нашей взаимозависимости. Во всей Солнечной системе технологии сделали наши коммуникации практически мгновенными, и что бы ни случилось с кем-либо и где-либо в нашей системе, это сразу же затрагивает каждого из нас, живущего в ней.\n\nСейчас большинство решений, затрагивающих интересы людей, принимается на местном, планетарном или астероидном уровне. Некоторые проблемы могут превосходить эти масштабы, именно такие, как региональные войны, грубые нарушения прав человека, жесткое расслоение общества в материальном плане, новые идеи в области науки, этики и философии. Особое значение имеет сегодня тот факт, что мы – обитатели общей Солнечной системы, и что отрицательные результаты многих видов деятельности в одном месте могут перекинуться на другие, например, истощение астероидов, загрязнение атмосферы и водных путей, невозможность демографического процветания в районах с низкой гравитацией. Глобальная милитаристская напряженность вызывает особую озабоченность у каждого человека в системе. То же можно сказать о вспышках эпидемий, перебоях поставок чистой воды и воздуха. Здесь явно обнаруживается необходимость координации деятельности всех заселенных уголков Солнечной системы.\n\nМы видим, что всё новые и новые проблемы начинают занимать внимание всего Солнечного сообщества. И они могут потребовать от нас совместных действий, таких, скажем, как сохранение хрупких экосистем, ограничение отдельных видов деятельности, в том числе и научной, предотвращение или борьба с экономическим спадом, развитие новых технологий и изучение их влияния на перспективы существования человечества; совместного реагирования на проблемы нищеты и голода, чрезмерные социальные различия в доходах, а, главное, в возможностях. Перед нами стоит и вопрос о снижении неграмотности, необходимости инвестиций в развитие человеческого капитала не только и не столько на Земле, но и во всех заселенных участках нашего мира. Особенно остро стоит вопрос об освобождении людей от предрешённости их дальнейшей жизни. Обреченности неграждан, бессмысленности дограждан, рабском существовании астероидян и бесконечной борьбы за выживание марсиан.\n\nЭтот скорбный список весьма долог, и потому так важна непрекращающаяся кампания за повышение общей образованности и улучшение среды человеческого существования.\n\n* * *\n\nМы заявляем, что науку и технику следует использовать во благо ВСЕГО человечества. Мы должны быть готовы пересмотреть человеческие ценности и изменить собственное поведение в свете этих выводов. В быстро меняющемся мире необходимы новые идеи и подходы, чтобы обеспечить прогресс человечества. Мы сталкиваемся с необходимостью пересмотреть архаичные традиции и отношения, чтобы благополучие и счастье стали доступны всем, кто стремится к достойной жизни для себя и других. Мы ввели термин **«вергуманизм»** (verum humanismum – настоящий гуманизм), означающий новый смелый подход к решению общих проблем не отдельных групп людей, а всего человечества во всей Солнечной системе. В соответствии с этим подходом, утверждение светских принципов и ценностей вергуманизма предлагается нами как конструктивный вклад в Солнечное сообщество.\n\n**Истинный Гуманизм**\n\nКаковы же характеристики вергуманизма, провозглашаемые в настоящей Декларации?\n\n**_Первое,_ вергуманисты стремятся к большей открытости.** Мы сотрудничаем с религиозными и нерелигиозными сообществами в деле решения общих проблем, но не являемся и членами той или иной религиозной деноминации, а если и принадлежим, то чисто номинально. Мы обращаемся исключительно к науке и разуму для решения проблем человечества, опираемся на опытную проверку наших знаний и ценностей. Вергуманисты не воинствующие безбожники или анархисты, хотя и настроены критически к заявлениям об истинности религиозной, идеологической и политической точек зрения, особенно если они выражены в догматической и фундаменталистской форме или покушается на свободу других людей. Мы понимаем, что ни эмоции, ни интуиция, ни власть, ни обычай, ни субъективность сами по себе не могут заменить поиска истины с помощью разума.\n\n**_Второе,_ вергуманисты подвергают сомнению состоятельность традиционного теизма.** Мы можем быть агностиками, скептиками, атеистами или даже инакомыслящими в рамках той или иной религиозной традиции. Мы считаем, что традиционные концепции Бога противоречивы и необоснованны. Мы не верим, что Библия, Коран, Книга мормонов или Бхагавадгиты священны и являются особого рода духовными источниками. Мы скептичны в отношении древних верований, обнаруживающих свою необоснованность в свете современной научной и философской критики, особенно, в свете научной экспертизы так называемых священных текстов и их источников. Мы подвергаем сомнению истинность тех моральных абсолютов, о которых говорят эти тексты, и рассматриваем их в качестве продуктов архаичных цивилизаций. Тем не менее, мы признаем, что некоторые из религиозных моральных принципов могут заслуживать внимания и высокой оценки, особенно если мы понимаем их как наше культурное наследие. Мы рассматриваем традиционный акцент религий на «спасении» как повод для ослабления усилий по совершенствованию нашей жизни здесь и сейчас.\n\n**_Третье,_ знание этого мира основано на наблюдении, экспериментировании и рациональном анализе.** Вергуманизм считает, что наука - это наилучший метод выработки такого знания, а также метод решения проблем и развития полезных технологий. Мы также признаем ценность новых направлений мысли, искусства и внутреннего опыта при условии их открытости для анализа критического разума. Многие знания не преумножают скорбь, но всегда приносят лишь прогресс вертикальный и горизонтальный. Только наука, искусство и мышление помогали человечеству справиться с глобальными проблемами, особенно во время революционных изменений цивилизации. И с расселением человечества по всей Солнечной системе пришли очередные такие революционные изменения.\n\n**_Четвертое,_ люди являются интегральной частью природы, результатом ненаправленных эволюционных изменений.** Вергуманисты признают самодостаточность природы. Мы признаем, что наша жизнь - это все, что мы имеем, и проводим различие между объективно существующими вещами и тем, что мы можем желать или воображать в связи с ними. Мы приветствуем вызовы будущего, нас притягивает непознанное, и мы не страшимся его. И, в свою очередь, жизнь любого человека является бесценной, а ее улучшение – основной и единственной целью всего человечества.\n\n**_Пятое,_ этические ценности основаны на человеческих потребностях и интересах и проверяются на опыте.** Вергуманистические ценности опираются на человеческое благосостояние, обусловленное условиями существования, интересами и заботами и простирающееся до пределов глобальной экосистемы и даже за ее пределы. Особое значение эти ценности приобретают в эпоху экспансивного роста нашей экосистемы. Наше отношение к каждому человеку строится на признании его неотъемлемой ценности и достоинства и его способности совершать осознанный выбор в контексте свободы, сопряженной с ответственностью, вне зависимости от того, насколько отдаленно в Солнечной системе этот человек не располагается.\n\n**_Шестое,_ полнота жизни проистекает из индивидуального участия в служении общечеловеческим идеалам.** Мы стремимся к максимально возможному развитию нашего потенциала, мы пытаемся наполнить нашу жизнь глубоким чувством смысла и цели, относясь с изумлением и благоговением к радости и красоте человеческого существования, его вызовам и трагедиям и даже к неизбежности и окончательности смерти. Вергуманисты опираются на богатое наследие человеческой культуры и жизненную позицию Вергуманизма для того, чтобы обрести утешение в трудностях и удовлетворенность в успехах. Ибо только постоянное совершенствование жизни всего человечества может дать неиссякаемый смысл жизни для любого человека, так как процесс совершенствования не дискретен, а перманентен.\n\n**_Седьмое,_ люди социальны по своей природе и находят смысл в отношениях друг с другом.** Вергуманисты стремятся достичь общества взаимной помощи и заботы, общества, свободного от жестокости и ее последствий, где различия разрешаются посредством сотрудничества, не прибегая к насилию. Наша жизнь обогащается как индивидуальностью, так и взаимной зависимостью друг от друга. Эта взаимосвязь побуждает нас обогащать жизнь других людей и питает наши надежды на достижение мира, справедливости и возможностей для всех. Только равноправие возможностей и справедливое отношение к каждому человеку может являться залогом процветания всех страт человечества и даже тех, которые находятся в настоящий отрезок времени в наиболее лучших условиях.\n\n**_Восьмое,_ работа на благо общества максимизирует индивидуальное счастье.** Прогрессивные культуры способствуют освобождению человечества от жестоких условий на грани выживания, уменьшению страданий, улучшению общества и развитию глобального человеческого сообщества. Мы ищем пути, чтобы уменьшить неравенство условий и способностей. Мы поддерживаем справедливое распределение природных ресурсов и плодов человеческих усилий, так чтобы как можно больше людей могли воспользоваться преимуществами благополучной жизни. Наряду с этим стоит справедливо оценивать и условия, в которых вынуждены жить определенные слои населения, преследуя цель расселения человеческой расы по всей Солнечной системе. Объективные условия на Марсе и астероидах тяжелы для существования, поэтому стоит это учитывать для определения справедливости применения ресурсов всего человечества.\n\n**_Девятое,_ вергуманисты применяют объективные методы для оценки этических принципов и ценностей.** Наилучшим образом моральные нормы можно оценивать по последствиям их применения. В ходе развития цивилизации человечество обрело этическую мудрость, хотя устаревшие моральные рецепты требуют пересмотра; вместе с тем не исключено возникновение новых моральных принципов.\n\n**_Десятое,_ вергуманисты привержены ключевым этическим принципам и ценностям, которые для людей имеют жизненное значение.** Они не выведены из богословских абсолютов, но возникли и развивались в свете современных исследований и опыта.\n\n- Ключевой ценностью является *счастливая* и *плодотворная* жизнь каждого человека.\n\n- Творческое развитие личных *интересов* должно быть согласовано с *дарованиями* и *ценностями*.\n\n- *Разумная жизнь в гармонии с чувством* – самый надёжный источник получаемого от жизни удовлетворения. Это означает, что человек должен быть в когнитивном контакте с внешним миром и со своими собственными потребностями и желаниями.\n\n- Личность должна стремиться достигать наивысших – из числа возможных – стандартов *качества* и *совершенства*.\n\n- Человек не может жить в изоляции от людей и должен разделять ценности с другими членами общества.\n\n- Именно поэтому *сострадание* является основной составляющей полной жизни.\n\n- Общество должно стремиться культивировать *нравственный рост* детей и взрослых.\n\n- Личность не может считаться полноценной, если она не сочувствует нуждам других людей и не имеет подлинной *альтруистической заботы* об их благе.\n\n**_Одиннадцатое,_ вергуманисты поддерживают право на неприкосновенность частной жизни как центральный постулат современного общества.** Индивиду должно быть дано право принимать самостоятельные решения и реализовывать свои ценности в той мере, в какой это не ущемляет права других.\n\n**_Двенадцатое,_ вергуманисты признают, что человечество обязано преодолевать узкие рамки эгоцентрического индивидуализма и шовинистического национализма. Солнечное сообщество нуждается в разработке новых транспланетарных институтов.** Новой реальностью является тот факт, что никто в Солнечной системе не может жить в изоляции, и все части Солнечного сообщества взаимосвязаны.\n\n- Существует необходимость нового транспланетарного агентства для мониторинга нарушений общепринятых норм и контроля за теми группами, которые допускают эти нарушения.\n\n- Новые транспланетарные институты должны поддерживать мир и обеспечивать безопасность всего человечества, выступать против насилия, способствовать решению глобальных конфликтов; ввиду этой задачи, человечеству потребуются адекватные многонациональные вооруженные полицейские силы.\n\n- Транспланетарным институтам следует принять свод законов, который будет применяться по всей Солнечной системе; учредить законодательные органы, которое будут принимать и модернизировать эти законы; всемирный суд, который будет интерпретировать их; выборный исполнительный орган, который будет применять эти законы.\n\nВергуманисты заинтересованы в благополучии для всех, мы ценим разнообразие и уважаем различные точки зрения, основанные на гуманности. Мы работаем на достижение идеала прав человека и гражданских свобод в открытом, светском обществе и принимаем как гражданский долг участие в прогрессе человечества и как долг участие в защите целостности экосистем всех мест проживания людей, их разнообразия и красоты способами, поддерживающими ее безопасность и устойчивость.\n\nБудучи частью общего потока жизни, мы придерживаемся этих устремлений с осознанным убеждением, что человечество обладает способностью продвигаться вперед в направлении своих наивысших идеалов. Ответственность за наши жизни и за тот мир, в котором мы живем, лежит на нас и только на нас. Прогресс не отвратим!', array['aebb6773-8651-4afc-851a-83a79a2bcbec']);
  perform pallas_project.create_document('Манифест', E'Ойя, белталода.\nЯ смотрю по сторонам, и вижу, что мы стоим у края. У границы, за которой привычная жизнь закончится. По всему Поясу бератнас и сесатас готовы бросаться с камнями на колониальных десантников, а парни с «Гефеста» натурально показали – что означает «забрать в ад компанию».\nБелталода вокруг меня часто выступают «против» – против нищенских контрактов, против урезания квот на воду, воздух и энергию, против засилья велвала в руководстве на любом камне Пояса. Но я почти не слышу, чтобы мои бератнас и сесатас подавали голос «за» что-то. Мне возразят, что астеры требуют правового равенства, хотят получать честную плату за свой труд , желают, чтобы их перестали считать за людей второго сорта... Это все – чистая правда, и такая же чистая брехня!\nМы воюем со следствиями, не видя причины. Туманги навязывают нам свои порядки не потому, что у них – миллионные армии, сотни кораблей и тысячи боеголовок. Кораблями и боеголовками не прокормить тридцать миллиардов оовощей. Земляне ставят нас раком, потому что за ними – Система! Саса ке?! Девять сотен лет они оттачивали умение захапать все, до чего смогут дотянуться! Поколениями они воевали за право грабить друг друга, и любого манга, предкам которого не повезло поселиться возле золотой жилы, нефтяного озера или кимберлитовой трубки. Система, которые выстроили их (и наши!) отцы и матери, сминает, растаптывает и уничтожает любое сопротивление. Метнуть в бунтующий камень торпеду – нехитрое дело, а вот купить с потрохами каждого, кто на этом камне имеет хоть какую-то власть – вот так работает Система! А еще лучше – объявить все камни своими, и передать «свою» власть над «своим» камнем «своим» людям. Просто потому, что можешь. Ничего не напоминает, белталода?\nЧего вы хотите добиться от Системы, бератнас? Протесты, забастовки, взрывы – все это только инструменты, не хуже и не лучше других. Только чего вы хотите с помощью этих инструментов достичь? Выторговать себе контракт пожирнее? Упросить копов бить вас пореже? Вымолить право называть себя «гражданами ООН второго сорта»? Быть частью Системы, но на особом положении? Перестать быть «Белталода»?\nИли вы хотите чего-то посерьезнее? Например, самим выбирать власть на камне? Или сообща устанавливать приемлемые нижние границы потребления? Вместе определять, на каких условиях планетяне смогут рыть наши камни? Самостоятельно контролировать, куда тратятся заработанные на камне деньги? Последнее, кстати, главное. Саса ке, копенг?\nМне скажут: эй, но ведь борьба – это не дело одного дня! Мы тут работаем, бастуем, жжем синт-покрышки, и бомбим свои тэги даже на потолках! Наши стачки бьют тумангов по самому больному – по карману! Хотят и дальше получать профит – пускай услышат нас! А не то мы!..\nА что мы? Что мы сделаем, если менеджер из «Де Бирс» завтра плюнет, и разорвет шахтерские контракты, наняв на Энцеладе других, согласных на что угодно – лишь бы поближе к Солнцу? Что мы сделаем, если через неделю администратор плюнет, наймет еще пару ЧОПов вдобавок к «Спирали», и даст им карт-бланш? Что мы сделаем, если Земля возьмется за нас всерьез? Будем уповать на общественное мнение, которое не позволит стереть нас в порошок?\nУспешно бороться против Системы может только другая Система. И вот тут у нас большие проблемы. Что такое «СВП», кроме красивых лозунгов и наколок? У нас по каждому вопросу – дюжина мнений, и каждое невгребенно важное, на каждом камне – с десяток «вождей», и каждый тянет одеяло на себя. У Пояса есть общие, глобальные проблемы, без решения которых белталода просто не будет… но мы продолжаем собачиться между собой. И пока у нас нет Системы, которая не зависит от кого-то одного, которая одинаково работает по всему Поясу, и объединяет людей ради дела (а не ненависти!) – до этих пор мы просто обогреваем Пустоту.\nНе объединившись, мы вымрем, белталода. Ойяденг.', array['5f7c2dc0-0cb4-4fc5-870c-c0776272a02e']);
end;
$$
language plpgsql;
