/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Ивашкин Георгий Андреевич
 * Дата: 25.04.2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT COUNT(*) AS total_players,
	SUM(payer) AS paying_players,
	ROUND(AVG(payer),4) AS paying_part -- доля платящих игроков 18%
FROM fantasy.users;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT r.race,
	SUM(u.payer) AS paying_players,
	COUNT(u.id) AS total_players,
	ROUND(SUM(u.payer) :: DECIMAL / COUNT(u.id), 4) AS paying_part
FROM fantasy.users AS u
INNER JOIN fantasy.race AS r USING (race_id)
GROUP BY race
ORDER BY paying_part DESC;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT COUNT(*) AS total_purchasing,
	SUM(amount) AS total_amount,
	MIN(amount) AS min_amount,
	MAX(amount) AS max_amount,
	AVG(amount) :: NUMERIC(8,2) AS avg_amount,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount) :: NUMERIC(8,2) AS median_amount,
	STDDEV(amount) :: NUMERIC(8,2) AS stddev_amount
FROM fantasy.events;

-- 2.2: Аномальные нулевые покупки:
SELECT COUNT(*) AS zero_amount,
    ROUND(COUNT(*) :: NUMERIC / (SELECT COUNT(*) FROM fantasy.events), 3) AS zero_amount_percentage
FROM fantasy.events
WHERE amount = 0;

-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
-- Напишите ваш запрос здесь
WITH stats_players AS (
    SELECT u.payer,
        COUNT(DISTINCT u.id) AS players_count,
        COUNT(e.transaction_id) AS total_purchasing,
        SUM(e.amount) AS total_amount
    FROM fantasy.users u
    LEFT JOIN fantasy.events e USING (id)
    WHERE e.amount > 0
    GROUP BY u.payer
)
SELECT
    CASE 
        WHEN payer = 1 THEN 'Платящие игроки'
        ELSE 'Неплатящие игроки'
    END AS player_type,
    players_count,
    ROUND(total_purchasing :: NUMERIC / players_count, 2) AS avg_purchasing_per_player,
    ROUND(total_amount :: NUMERIC / players_count, 2) AS avg_amount_per_player
FROM stats_players
ORDER BY payer DESC;

-- 2.4: Популярные эпические предметы:
WITH 
stat_items AS (
    SELECT i.game_items,
        COUNT(e.transaction_id) AS sales_count,
        ROUND(COUNT(e.transaction_id) :: NUMERIC / (SELECT COUNT(*) FROM fantasy.events e JOIN fantasy.items i ON e.item_code = i.item_code
		WHERE e.amount > 0), 2) AS sales_part, --внес исправление
        COUNT(DISTINCT e.id) AS unique_buyers
    FROM fantasy.events e
    JOIN fantasy.items i USING (item_code)
    WHERE e.amount > 0
    GROUP BY i.game_items
),
total_players AS (
    SELECT COUNT(*) AS count 
    FROM fantasy.users
)
SELECT
    game_items AS epic_item,
    sales_count,
    sales_part,
    ROUND(unique_buyers :: NUMERIC / (SELECT COUNT(DISTINCT id) FROM fantasy.events WHERE amount > 0), 2) AS players_part --внес исправление
FROM stat_items
ORDER BY sales_count DESC;

-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
WITH 
-- 1. Общее количество игроков по расам
race_player_count AS (
    SELECT r.race_id,
        r.race,
        COUNT(u.id) AS total_players
    FROM fantasy.users u
    JOIN fantasy.race r ON u.race_id = r.race_id
    GROUP BY r.race_id, r.race
),
-- 2. Игроки, совершившие покупки, по расам
buying_players AS ( -- исправлен второй CTE
    SELECT 
        u.race_id,
        COUNT(DISTINCT u.id) AS buying_players_count,
        ROUND(AVG(u.payer::numeric), 4) AS paying_share
    FROM fantasy.users u
    JOIN fantasy.events e ON u.id = e.id
    WHERE e.amount > 0
    GROUP BY u.race_id
), 
-- 3. Статистика покупок по расам
purchase_stats AS (
    SELECT u.race_id,
        COUNT(e.transaction_id) AS total_purchases,
        SUM(e.amount) AS total_amount_spent,
        COUNT(DISTINCT e.id) AS unique_buyers
    FROM fantasy.events e
    JOIN fantasy.users u ON e.id = u.id
    WHERE e.amount > 0
    GROUP BY u.race_id
)
-- 4. Итоговый запрос
SELECT 
    rpc.race AS "Раса персонажа",
    rpc.total_players AS "Всего игроков",
    bp.buying_players_count AS "Игроков с покупками",
    ROUND(bp.buying_players_count :: NUMERIC / rpc.total_players, 2) AS "% игроков с покупками",
    bp.paying_share AS "% платящих среди покупателей", --внес исправление
    ROUND(ps.total_purchases :: NUMERIC / ps.unique_buyers, 2) AS "Среднее количество покупок на игрока",
    ROUND(ps.total_amount_spent :: NUMERIC / ps.total_purchases, 2) AS "Средняя стоимость покупки",
    ROUND(ps.total_amount_spent :: NUMERIC / ps.unique_buyers, 2) AS "Средняя суммарная стоимость на игрока"
FROM race_player_count rpc
JOIN buying_players bp ON rpc.race_id = bp.race_id
JOIN purchase_stats ps ON rpc.race_id = ps.race_id
ORDER BY "Средняя суммарная стоимость на игрока" DESC;