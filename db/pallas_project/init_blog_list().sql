-- drop function pallas_project.init_blog_list();

create or replace function pallas_project.init_blog_list()
returns void
volatile
as
$$
declare
  v_blog_all_id integer := data.get_object_id('blogs_all');
  v_blog_my_id integer := data.get_object_id('blogs_my');
begin

  perform data.create_object(
    'pallada_info',
    jsonb_build_array(
      jsonb_build_object('code', 'title', 'value', 'Паллада Info'),
      jsonb_build_object('code', 'subtitle', 'value', 'Официальный канал Администрации'),
      jsonb_build_object('code', 'blog_is_confirmed', 'value', true),
      jsonb_build_object('code', 'system_blog_author', 'value', to_jsonb(data.get_object_id('36cef6aa-aefc-479d-8cef-55534e8cd159'))),
      jsonb_build_object('code', 'blog_author', 'value', to_jsonb('36cef6aa-aefc-479d-8cef-55534e8cd159'::text), 'value_object_code', 'master')
    ),
    'blog');
  -- Добавляем блог в список всех и в список моих для того, кто создаёт
  perform pp_utils.list_prepend_and_notify(v_blog_all_id, 'pallada_info', null, null);
  perform pp_utils.list_prepend_and_notify(v_blog_my_id, 'pallada_info', data.get_object_id('36cef6aa-aefc-479d-8cef-55534e8cd159'), null);

  perform data.create_object(
    'shengs_voice',
    jsonb_build_array(
      jsonb_build_object('code', 'title', 'value', 'Голос Шенга'),
      jsonb_build_object('code', 'subtitle', 'value', 'Канал сопротивления'),
      jsonb_build_object('code', 'blog_is_confirmed', 'value', true),
      jsonb_build_object('code', 'system_blog_author', 'value', to_jsonb(data.get_object_id('36cef6aa-aefc-479d-8cef-55534e8cd159'))),
      jsonb_build_object('code', 'blog_author', 'value', to_jsonb('36cef6aa-aefc-479d-8cef-55534e8cd159'::text), 'value_object_code', 'master')
    ),
    'blog');
  -- Добавляем блог в список всех и в список моих для того, кто создаёт
  perform pp_utils.list_prepend_and_notify(v_blog_all_id, 'shengs_voice', null, null);
  perform pp_utils.list_prepend_and_notify(v_blog_my_id, 'shengs_voice', data.get_object_id('36cef6aa-aefc-479d-8cef-55534e8cd159'), null);

  perform pallas_project.create_blog_message('shengs_voice', 'Свежая порция правды.',
  'И с вами снова ваш приятель Шенг! Соскучились по правде? У меня есть для вас свежая порция!

Ведь кто, если не я, расскажет, что творится на нашем камне? Я – тот, кто имеет уши и слышит, кто имеет глаза и видит, и тот – у кого хватает смелости говорить! Я – глаза, уши и голос Паллады. Наглость? Естественно, ведь только так в наше время и добывается правда. И только обладая завидной наглостью, правду можно говорить открыто.

Сегодня я расскажу вам о нашей доблестной полиции. О тех самых ребятах, что должны охранять людей Паллады и защищать интересы НАШЕГО общества, служить порядку и восстанавливать справедливость. Но все мы понимаем, чьи интересы они охраняют на самом деле, кому они должны и чему служат. И если у вас есть лишь подозрения, то у меня набралось достаточно реальных фактов!

Факт первый. Месяц назад вандалы разгромили мед.кабинет Джулиуса Янга – тот, что на третьем уровне пятого сектора. Многие знают этого прекрасного парня и отличного доктора. Многим он помог, а кого-то из вас буквально вытащил с того света.
Бардак в кабинете устроили знатный: сломали мебель, разбили стекла, но главное – вскрыли сейф и украли все лекарства. Потери для людей, живущих рядом, трудно себе представить. Многим это стоило здоровья, а значит, и зарплаты. Короче, это такая маленькая гуманитарная катастрофа. Уж не говоря про доктора и его семью.
Спросите: что сделали полицейские? Я скажу. Они нахмурили брови и пообещали, что постараются помочь, чем могут. Очень удобная формулировка, кстати говоря. И всё! На этом их деятельность закончилась. Вы не поверите, но никто даже не опросил свидетелей! У меня есть теория, почему всё так. Потому что на стене ограбленной лавки красовался знак СВП. Я ни на что не намекаю… Хотя нет, намекаю, и еще как.

Да. Полиция защищает тех, кто ей платит. А что может предложить им доктор Янг? Да практически ничего. Всё, что у него есть, он и так отдает: за воду, за воздух, за лекарства для жены, за доставку товара, за страховку и т.д. Все мы знаем, сколько кредитов остается от зарплаты после погашения счетов. А этот парень иногда еще и бесплатно лечит тех, кто не в состоянии рассчитаться. Пожелаем ему удачи, в общем... Надеюсь, найдутся добрые люди, которые оплатят доктору воду и воздух. На правосудие ему явно можно не рассчитывать.

Следующий факт. Два дня назад местная шпана нарисовала граффити на дверях офиса “ТекоМарс”. Накарябали что-то вроде “Пыляне, валите домой”. Да что говорить – мелкое хулиганьё, наслушались в сети девизов СВП-шных радикалов, вот и выпендриваются. Откуда я всё это знаю? Да потому что их уже поймали. На следующий день прямо. И свидетелей нашли, и записи с камер, и обыски провели. Конечно, ведь страшные преступники беззащитных людей обидели! Теперь этим криминальным элементам шьют такие дела, что закачаешься. Тут и экстремистская деятельность, и вандализм, и формирование банды, и материальный ущерб. В общем, не ту стеночку детишки разукрасили, ох, не ту. Заметьте, в отличие от дела Доктора Янга, за эту историю полиция взялась с неожиданным энтузиазмом! Пожелаем ребяткам и их родителям терпения и удачи.

Факты – вещь простая. Относиться друг к другу можно по-разному. Можно дружить с пылянами, работать на землян и в каждом человеке видеть брата. Но что делать, если все твои добрые намерения разбиваются о реальность? К кому взывать о помощи? Где искать справедливость?

Я скажу, что нам поможет. Мы сами! Мы можем помочь друг другу. Астеры привыкли держаться вместе. И каждый белталода знает, как наводить порядок и справедливость на своем камне. Жизнь на Палладе была бы проще без Земли, без Марса, без корпораций и продажных чиновников.
Так что вот вам еще один факт – Паллада прекрасно справится сама. Велвала, вок фон сетешанг! Гравитяне, валите домой!

С вами был Шенг, ребята! Я еще вернусь. Берегите друг друга и помните: правда всегда найдет дорогу к свободе!', pp_utils.format_date(clock_timestamp() - '11 months 5 days 45 minutes 27 seconds'::interval));

  perform pallas_project.create_blog_message('shengs_voice', 'Поговорим о школах.',
  'Всем привет, с вами Шенг!
Голос Паллады, который расскажет вам всю правду.
Без прикрас. Без фальши. Всё, что не должно быть скрыто!

Поговорим-ка с вами про наши школы. Тема важная, ведь детей у нас мало, и тем они ценнее. Малыши вырастут и станут капитанами кораблей, полицейскими и даже, может быть, таможенниками, упаси Пустота. И важно понимать – что вкладывают им в головы и кто это делает. А варианты можно по пальцам пересчитать.

Wang. Вы отдали своё чадо в уютную, маленькую и чистенькую школу ООН (если вам хватило деньжат) и думаете, что там его научат, как быть астероидянином? Расскажут, как выживать на камне и в пустоте? Нет. Не научат.

Ему расскажут, как здорово быть потребителем, смотреть тупые шоу сутками напролёт и жить на пособие. “ООН молодец, ООН накормила голодных! А кто не захотел брать из руки хозяина – тот сам и виноват, что про него говорить”. Вот, что вдолбят ему в наивную голову. Ну и, может быть, про таблицу умножения годам к 15, наконец, поведают. Чтобы знал, сколько налогов отдавать. И ведь это даже не дискриминация астеров – земляне про нас знают только, что мы тупые, умеем копать и живем очень далеко от сытой Земли. А значит, нам можно скармливать всю ту же хрень, что и своим тупым до-гражданам.

Как по мне, наши дети достойны бОльшего.

Хорошо. Вариант tu. Вы заложили вообще всё, что у вас было, и отдали своего ребёнка в филиал марсианского колониального училища. Лелеете надежду, что там из него сделают профи? И снова мимо! Там ему быстренько объяснят, что есть всего два варианта: воевать или сидеть в лаборатории. И снова никаких знаний для жизни на наших камушках. Сплошная пропаганда и накачка мышц. Не сможет отжиматься и стрелять – отправят рисовать проекты куполов или придумывать новую сою. Вот только нет у нас куполов и огородов, а тренировки пылян не рассчитаны на хрупкие кости астеров. Вместо обучения за наши же кровно заработанные получаем бесполезный трёп и сломанные ноги.

Seri. Взять обучение детей в свои руки. Долгое время так и было. Мамы рассказывали про опасности Пустоты, папы – про опасности вечерних прогулок по докам. По вечерам после работы детям включали видюхи с математикой и астрономией. Работало так себе – то мама забудет, то папа устал, то денег на новые уроки нет.

Но у нас, наконец, появилась новая возможность. Ребятки из СВП поняли, что слово иногда сильнее, чем бластер, а будущее – важнее, чем настоящее. И теперь на каждом камне есть свои школы. Ну как школы – скорее маленькие каморки в доках, в которые стащили столы и стулья. И прямо в этих каморках энтузиасты-учителя собирают ребятню и вещают про жизнь на камне, про Первого астера, учат детей постарше всяким инженерным премудростям, помогают выбрать профессию и всё такое…

Все, кто что-то знает про сложную жизнь на Палладе, приходят и делятся знаниями с детьми. Как залатать скафандр в пустоте, как проверить баллон с неисправным датчиком, как работает магнитный замок на ботинке? Делают они это всё за спасибо и копейку на аренду каморки. Потому что хотят для наших детей лучшего будущего. Если же вы боитесь, что без пропаганды и тут не обходится, то оставьте сомнения: это малая цена за шанс на благополучие для новых поколений астеров.

В общем, всё как всегда – на ООН не надейся, Марса сторонись. Кто ещё поможет астерам кроме самих астеров? И мы тут не привыкли браться за руки и петь “Кумабайя” – воздуха не хватает. Но каждый астер чувствует локоть своего товарища. Так всегда было, так всегда будет. Отведите своё чадо на урок по навигации или геологии! Дайте ему знания, которые пригодятся по-настоящему! Вы знаете, кого спросить про школу.

Помните, только вместе мы сила. Пусть гравитяне учат своих сосунков чему хотят, мы сами сделаем из наших детей настоящих астероидян! Сплотившись, создадим новое будущее! Пояс достоин собственного пути!

С вами был Шенг, ребята! Я еще вернусь. Берегите себя и помните: правда всегда найдет дорогу!'
  , pp_utils.format_date(clock_timestamp() - '9 months 2 days 3 minutes 38 seconds'::interval));

  perform pallas_project.create_blog_message('shengs_voice', 'Что случилось с губернатором?',
  'Ойя! Давно я не писал вам правды, ведь жизнь на астероиде темна и полна ужасов. Особенно если ты — тот, кто не боится писать реальные факты. В общем, были маленькие проблемки с местными властями, но уже все хорошо. Надеюсь, вы не слишком за меня переживали.

Ну и пока меня не было, в нашем инфополе на Палладе произошло много всякого разного. Наверное, вам уже успели навешать лапши и рассказать “как всё было на самом деле”. Вы даже, может быть, поверили. Так что хорошо, что я вернулся. Сейчас я поделюсь с вами самой отборной правдой, какая только есть.

Бум! А в курсе ли вы, мои маленькие kopeng, что на нашем астероиде сейчас нет губернатора? Не вообще, а конкретного такого — средних лет планетянина в дорогом костюме? Был-был на станции Майкл Доусон и вдруг исчез — и на работе его нет, и дома не появлялся. Выглядит это очень подозрительно. Но, кажется, на станции это никого не парит. В полиции, как всегда, отделываются общими фразами, а вот в гнезде бюрократии даже дали ответ — по их словам, наш губернатор занят “делами, требующими конфиденциальности”. Знаем мы такие дела, ага. Ну я лично проверил пару мест и поговорил с шлюхами, но ни в борделе, ни в казино его не видели последние три дня. Чем ещё таким секретным может заниматься наш главный администратор, я пока не придумал. Так что сейчас самая главная правда заключается в наличии самого вопроса — “Что случилось с губернатором?”.

Поглядим, ребятки, во что это всё выльется. Дело-то непростое. Главное сейчас — держаться друг друга и присматривать за станцией. Следите за новостями, но не верьте всему, что вам говорят!

С вами был Шенг, ваш голос правды на Палладе.'
  , pp_utils.format_date(clock_timestamp() - '1 months 1 day 200 minutes 14 seconds'::interval));

  perform pallas_project.create_blog_message('pallada_info', 'Сводка новостей',
  'Краткий список новостей последних недель — не считая покалеченных, убитых, арестованных и просто вышедших в шлюз от безысходности.

Месяц назад произошел взрыв на станции “Гефест”, ответственность за который взяли на себя представители СВП со станции. Их посмертное обращение — воззвание к властям ООН с требованием “уважать права астероидян на достойную жизнь”. Главы других ячеек СВП от комментариев отказались.

ООН ужесточило требования к проверке транспортных средств, принадлежащих частным лицам. По всей системе арестованы десятки кораблей и экипажей, обвинения разнятся от Ст. 127 “Перевозка запрещенных товаров и веществ” до Ст. 135 “Содействие террористической деятельности”. Расширены полномочия представителей Совета Безопасности.

Из местных новостей:

Три недели назад произошло обрушение в штольне № 32. Расследование показало, что обрушение — форс-мажор. По станции ползут слухи, что истинной причиной стала обширная каверна в толще стены и потолка, пропущенная при строительстве и плановых инженерных проверках, но обвинения в преступной халатности, предъявленные пострадавшими и их семьями, были отклонены судом. Компания De Beers Space признана невиновной.

Стало известно о внештатной ситуации на танкере “Галилеус”, который в ближайшие дни должен доставить груз льда на станцию Паллада. Согласно полученной информации часть воды была утеряна, размеры водных пайков на ближайшие несколько циклов будут пересмотрены. Также ожидается повышение налога на воздух и воду. Компания Mermaid пока не давала официальных комментариев по поводу произошедшего.

Сутки назад пропал без вести губернатор колонии Майкл Доусон. Последним его указом стало распоряжение о выселении астеров из нескольких районов Паллады по соображениям безопасности — в этих секторах обнаружена неисправность в воздушных фильтрах. О местоположении губернатора до сих пор не известно.

В шахте обнаружен повышенный радиационный фон, в связи с чем шахтёры прекратили работу. По их словам, начальство шахты инициировало очистку шахты, инженерная служба отчиталась о проведённых работах, но радиация никуда не делась. В ответ на требование вернуться на рабочие места шахтёры объявили забастовку.

Сегодня днем ожидается прибытие инспектора ООН Аманды Ганди. По слухам, опровергаемым администрацией, данное событие — долгожданная реакция метрополии на многочисленные петиции, связанные с неэффективностью управления колонией.

    «Здесь всегда БУМ» (с) один лейтенант-командор', pp_utils.format_date(clock_timestamp() - '6 days 300 minutes 24 seconds'::interval));

    perform pallas_project.create_blog_message('shengs_voice', 'Одни вопросы.',
  'Ойя, белта! С вами снова Шенг!

И сегодня я снимаю шепу перед господином Ламбером! То, о чем Шенг твердит вам последние годы, дошло еще и до одного – сила белталода в единстве!

Вот только одно мне не ясно, дорогой Люк: ты предлагаешь поменять систему на систему? Как говорят у нас на камне – отвертку на шампунь? А в чём выгода? Где же гарантии, что бератна не обидит потом сэсата? Что какой-нибудь буро, возомнив, что он теперь тут босманг, не начнет всё тот же террор, под давлением экономических санкций со стороны ООН? Или того интереснее, не начнёт тут строить общество промытых мозгов, как у пылян?

Одни вопросы, белта. Те же, что изо дня в день задают себе наши люди в забоях. Изо дня в день спорят, бывает до драки, и не могут найти ответ. Вот бы был кто большой, добрый и умный, кто рассудил бы нас, помог и всё решил, шепчут в шлюзах друг другу охрипшие и уставшие спорить шахтеры.

Ну что ж, по счастью у тебя есть Шенг. О нет, не подумай, что я собрался за тебя думать и решать, ты брось. Моё дело – новости, и в этих новостях я хочу поведать тебе кое-что интересное.

Слышали ли вы такое имя как Большой Фред, копенг? Да, именно так, именно Большой и именно Фред. Поговаривают, что есть такой мужик, из наших, смекаешь, ке? То тут про него слышно, то там. Вроде как он всех объединить хочет, в помощи не отказывает никому из наших, дело говорит. А вроде и вопросики к нему у людей накопились. Куда ты нас ведешь, Фред? К свободе и братству или в лапы к полицаям?

И вот зачем вам Шенг, белталода. Хочу обратиться к Фреду: дружище, а не заехать ли тебе на к нам на праздник? Тут Палладе 80 лет скоро стукнет. Под шумок бы и поболтали с тобой, в прямом эфире. Ты б и рассказал нам всё как есть, а мы б уже и делали выводы сами, а не по рассказам дядюшки Педро с Эроса. Если не струхнешь, так передай весточку нашим, кенст? А мы уж тут и эфир обеспечим, и безопасность. А главное, правду расскажем всем, правду, которая так нужна.

Ну и напоследок. Вопросики к Фреду задавайте друг другу почаще, да погромче, я услышу и передам ему. Гэ гуд, белта!'
  , pp_utils.format_date(clock_timestamp() - '5 days 168 minutes 13 seconds'::interval));

    perform pallas_project.create_blog_message('pallada_info', '80 лет станции Паллада!',
  'Уже 80 лет астероид Паллада — колония Земли. Восемь десятков лет — большой срок даже для камня в пустоте, а уж для населенного астероида и подавно. За эти годы станция стала для сотен тысяч людей не только домом и местом работы, но и малой родиной. Многое поменялось в этом месте за время под протекторатом ООН. Пустоту и камень заполнила жизнь. Появились администрация, шахта, большой порт, клиника, инженерная служба, таможня — то, без чего трудно представить себе цивилизованное общество. Эти предприятия и организации работают и по сей день, создают рабочие места и служат людям. Трудно сказать, какое будущее ждало на астероиде первых колонистов-энтузиастов, но неспроста отсчёт основания станции ведётся от того дня, когда Паллада стала официальной колонией ООН, ведь именно тогда станция получила билет в светлое будущее. Понадобились неизмеримое количество ресурсов и много лет для того, чтобы сделать астероид приятным и перспективным местом.

В 2340 году компания Де Бирс Спэйс поставляет с Паллады на Землю алмазы и другие ценные минералы, порт принимает до десятка пассажирских кораблей в неделю, а сам астероид является местом для жизни 600 тысяч людей — шахтёров, докторов, докеров, инженеров, работников сферы услуг, журналистов, экономистов... Сюда до сих пор стремятся энтузиасты в попытках найти смысл жизни и предназначение. На Палладе работают уникальные специалисты, получившие образование в лучших учебных заведениях Земли, Марса, Луны и Ганимеда. Благодаря их знаниям и грамотному управлению станция процветает и с каждым днем становится всё лучше.

В день юбилея на Палладе будет праздник. В программе — награждение лучшей бригады шахтёров, речь губернатора и бесплатное угощение в местном баре.

В качестве специального гостя на празднике будет присутствовать официальный представитель ООН, заместитель министра по делам колоний Аманда Ганди со специальной акцией-сюрпризом, объявление про которую выйдет позже.

Историческая справка

2258

Основание первого поселения

2259

Прибытие исследовательской экспедиции ООН по изучению ресурсного потенциала астероида. После обнаружения алмазных трубок Паллада признана перспективным местом для добычи полезных ископаемых.

2260

Признание Паллады колонией ООН

2261

Основание первой шахты корпорации Амико

Отладка линий импорта и экспорта

Строительство разветвленной сети шахт и коридоров станции

Открытие порта и доков для принятия грузо-пассажирского потока

Начало работы государственной клиники, таможни, администрации

Назначение Томаса О’Нил на должность первого губернатора станции', pp_utils.format_date(clock_timestamp() - '4 days 50 minutes 5 seconds'::interval));

    perform pallas_project.create_blog_message('pallada_info', 'Акция-сюрприз!',
  'Пришло время для действительно хороших новостей!

Как вам известно, в скором времени на Палладу прибывает Аманда Ганди, заместитель отдела внутренней ревизии Управления по вопросам космического пространства ООН. Мы тревожились – неужели в ООН придумали для нас какую-то очередную каверзу? Новые условия контрактов? Уменьшение водного пайка? Проверка и смена администрации астероида? Может быть, чиновник ООН хочет развлечься на подконтрольной территории? Но нет! Нам стала известна истинная цель прибытия госпожи Ганди.

Госпожа Ганди прибывает, чтобы провести ЛОТЕРЕЮ ГРАЖДАНСТВА ООН!

Один из неграждан, присутствующих на Палладе, сможет получить полноценное ГРАЖДАНСТВО, соответствующие ему обеспечение и должность, одобренную Главным департаментом занятости граждан ООН.

Правила проведения ЛОТЕРЕИ ГРАЖДАНСТВА:

Старт ЛОТЕРЕИ ГРАЖДАНСТВА назначен на 18:00 8 марта 2340 г. Окончание — на 18:00 9 марта 2340 г. Финальный этап состоится на празднике, посвященном юбилею станции, после торжественной речи Аманды Ганди.

Все неграждане, присутствующие на астероиде Паллада на момент старта лотереи, официально зарегистрированные и имеющие комм, получают ОДИН билет ЛОТЕРЕИ ГРАЖДАНСТВА совершенно бесплатно. Данные об этом будут получены каждым негражданином на его комм.

Каждый негражданин может ДОПОЛНИТЕЛЬНО приобрести ЛЮБОЕ количество билетов лотереи за установленную сумму. Стоимость билета будет объявлена в момент старта ЛОТЕРЕИ ГРАЖДАНСТВА.

Перепродажа и передача билетов ЛОТЕРЕИ ГРАЖДАНСТВА запрещены.

Отказаться от участия в ЛОТЕРЕЕ ГРАЖДАНСТВА нельзя.

ОДИН победитель определяется методом случайного выбора между ВСЕМИ (гарантированными и дополнительно приобретенными) билетами ЛОТЕРЕИ ГРАЖДАНСТВА.

ЛОТЕРЕЯ ГРАЖДАНСТВА проводится Амандой Ганди, заместителем отдела внутренней ревизии Управления по вопросам космического пространства ООН. Контролерами ЛОТЕРЕИ ГРАЖДАНСТВА со стороны астероида Паллада назначаются Александр Корсак, главный экономист, и Кара Трейс, военный наблюдатель.

ПОБЕДИТЕЛЬ получит официальное уведомление на свой комм сразу же после завершения лотереи, также он будет объявлен в местных и земных новостях.

Гражданство может быть отозвано, если выяснится, что награжденный скрывался от правосудия или совершил уголовно наказуемое деяние до победы в лотерее.

Пусть вам повезет!', pp_utils.format_date(clock_timestamp() - '3 days'::interval));

end;
$$
language plpgsql;
