/* Решаем ad hoc задачи
 */
-- Пример фильтрации данных от аномальных значений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
-- Выведем объявления без выбросов:
SELECT *
FROM real_estate.flats
WHERE id IN (SELECT * FROM filtered_id);


-- Задача 1: Время активности объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. Какие сегменты рынка недвижимости Санкт-Петербурга и городов Ленинградской области 
--    имеют наиболее короткие или длинные сроки активности объявлений?
-- 2. Какие характеристики недвижимости, включая площадь недвижимости, среднюю стоимость квадратного метра, 
--    количество комнат и балконов и другие параметры, влияют на время активности объявлений? 
--    Как эти зависимости варьируют между регионами?
-- 3. Есть ли различия между недвижимостью Санкт-Петербурга и Ленинградской области по полученным результатам?

-- Фильтрация аномалий
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
        AND type_id = 'F8EM'
)
-- Основной запрос
SELECT 
    CASE 
        WHEN c.city = 'Санкт-Петербург' THEN 'СПБ' 
        ELSE 'ЛО' 
    END AS region,
    CASE 
        WHEN a.days_exposition BETWEEN 1 AND 30 THEN '1_month'
        WHEN a.days_exposition BETWEEN 31 AND 90 THEN '3_months'
        WHEN a.days_exposition BETWEEN 91 AND 180 THEN '6_months'
        WHEN a.days_exposition >= 181 THEN '> 6_months' 
    END AS activity_segment,
    ROUND(AVG(a.last_price/f.total_area)::numeric, 2) AS avg_price_sqm,
    ROUND(AVG(f.total_area)::numeric, 2) AS avg_area,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.rooms) AS median_rooms,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.balcony) AS median_balconies,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.floor) AS median_floor,
    COUNT(*) AS listings_count
FROM real_estate.flats f
JOIN real_estate.city c ON c.city_id = f.city_id 
JOIN real_estate.advertisement a ON a.id = f.id
WHERE f.id IN (SELECT id FROM filtered_id) 
    AND a.days_exposition IS NOT NULL
GROUP BY region, activity_segment
ORDER BY region DESC, activity_segment ASC;


-- Задача 2: Сезонность объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости? 
--    А в какие — по снятию? Это показывает динамику активности покупателей.
-- 2. Совпадают ли периоды активной публикации объявлений и периоды, 
--    когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений)?
-- 3. Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? 
--    Что можно сказать о зависимости этих параметров от месяца?

--По публикации объявлений
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
        AND type_id = 'F8EM'
)
SELECT 
    EXTRACT(MONTH FROM first_day_exposition) AS publication_month,
	COUNT(f.id) AS listings_count,
    ROUND(AVG(last_price/total_area)::NUMERIC, 2) AS avg_price_per_sqm,
    ROUND(AVG(total_area)::NUMERIC, 2) AS avg_area
FROM real_estate.flats f 
JOIN real_estate.advertisement a ON a.id = f.id
WHERE f.id IN (SELECT * FROM filtered_id) 
    AND type_id = 'F8EM'
GROUP BY publication_month
ORDER BY listings_count DESC;

--По снятым с публикации объявлениям
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
        AND type_id = 'F8EM'
)
SELECT 
    EXTRACT(MONTH FROM (first_day_exposition::date + days_exposition::INT)) AS removal_month,
	COUNT(f.id) AS listing_count,
    ROUND(AVG(last_price/total_area)::NUMERIC, 2) AS avg_price_per_sqm,
    ROUND(AVG(total_area)::NUMERIC, 2) AS avg_area
FROM real_estate.flats f 
JOIN real_estate.advertisement a ON a.id = f.id
WHERE f.id IN (SELECT * FROM filtered_id) 
    AND days_exposition IS NOT NULL 
    AND type_id = 'F8EM'
GROUP BY removal_month
ORDER BY listing_count DESC;

-- Задача 3: Анализ рынка недвижимости Ленобласти
-- Результат запроса должен ответить на такие вопросы:
-- 1. В каких населённые пунктах Ленинградской области наиболее активно публикуют объявления о продаже недвижимости?
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
locality_stats AS (
    SELECT 
        c.city AS locality,
        COUNT(*) AS total_ads,
        COUNT(CASE WHEN a.days_exposition IS NOT NULL THEN 1 END) AS sold_ads,
        ROUND(AVG(a.last_price/f.total_area)::numeric, 2) AS avg_price_sqm,
        ROUND(AVG(f.total_area)::numeric, 2) AS avg_area,
        ROUND(AVG(a.days_exposition)::numeric, 1) AS avg_days_on_market
    FROM real_estate.flats f
    JOIN real_estate.advertisement a ON f.id = a.id
    JOIN real_estate.city c ON f.city_id = c.city_id
    WHERE f.id IN (SELECT id FROM filtered_id)
        AND c.city != 'Санкт-Петербург'
    GROUP BY c.city
    HAVING COUNT(*) >= 50
)
SELECT 
    locality,
    total_ads,
    ROUND(sold_ads * 100.0 / total_ads, 2) AS sold_percentage,
    avg_price_sqm,
    avg_area,
    avg_days_on_market
FROM locality_stats
ORDER BY total_ads DESC
LIMIT 15;


-- 2. В каких населённых пунктах Ленинградской области — самая высокая доля снятых с публикации объявлений? 
--    Это может указывать на высокую долю продажи недвижимости.
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
)
SELECT
    c.city AS city_name,
    COUNT(f.id) FILTER(WHERE a.days_exposition IS NOT NULL) AS removed_listings_count,
    ROUND(COUNT(f.id) FILTER(WHERE a.days_exposition IS NOT NULL) / COUNT(f.id)::NUMERIC, 4) AS removal_rate
FROM real_estate.flats f
JOIN real_estate.city c ON c.city_id = f.city_id 
JOIN real_estate.advertisement a ON a.id = f.id
WHERE f.id IN (SELECT id FROM filtered_id) 
    AND c.city != 'Санкт-Петербург'
GROUP BY c.city
ORDER BY removed_listings_count DESC;

-- 3. Какова средняя стоимость одного квадратного метра и средняя площадь продаваемых квартир в различных населённых пунктах? 
--    Есть ли вариация значений по этим метрикам?
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
)
SELECT
    c.city AS city_name,
    COUNT(f.id) AS listings_count,
    ROUND(AVG(a.last_price/f.total_area)::numeric, 2) AS avg_price_per_sqm,
    ROUND(AVG(f.total_area)::numeric, 2) AS avg_area
FROM real_estate.flats f
JOIN real_estate.city c ON c.city_id = f.city_id 
JOIN real_estate.advertisement a ON a.id = f.id
WHERE f.id IN (SELECT id FROM filtered_id) 
    AND c.city != 'Санкт-Петербург'
    AND a.days_exposition IS NOT NULL
GROUP BY c.city
ORDER BY avg_area DESC;

-- 4. Среди выделенных населённых пунктов какие пункты выделяются по продолжительности публикации объявлений? 
--    То есть где недвижимость продаётся быстрее, а где — медленнее.

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
)
SELECT
    c.city AS city_name,
    COUNT(f.id) AS listing_count,
    ROUND((AVG(a.days_exposition)/30) :: NUMERIC, 2) AS avg_listing_duration_months
FROM real_estate.flats f
JOIN real_estate.city c ON c.city_id = f.city_id 
JOIN real_estate.advertisement a ON a.id = f.id
WHERE f.id IN (SELECT id FROM filtered_id) 
    AND c.city != 'Санкт-Петербург' 
    AND a.days_exposition IS NOT NULL
GROUP BY c.city
ORDER BY listing_count DESC;
