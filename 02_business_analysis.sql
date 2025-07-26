-- ============================================================
-- Business Queries For Insights
-- ============================================================


-- 1) Find number of businesses in each category?

WITH cte AS (
    SELECT business_id, TRIM(A.value) AS category
    FROM table_yelp_business, LATERAL SPLIT_TO_TABLE(categories, ',') A
)
SELECT category, COUNT(*) AS no_of_businesses
FROM cte 
GROUP BY 1
ORDER BY 2 DESC;



-- 2) Find top 10 users who reviewed the most restaurants?

-- Method I
SELECT r.user_id, COUNT(b.business_id) AS count_of_reviewed
FROM table_yelp_reviews AS r
INNER JOIN table_yelp_business b ON r.business_id = b.business_id
WHERE b.categories ILIKE '%Restaurants%'
GROUP BY 1
ORDER BY 2 DESC
LIMIT 10;

-- Method II using CTE and Window function
WITH top_10 AS (
    SELECT r.user_id, COUNT(b.business_id) AS count_of_reviewed
    FROM table_yelp_reviews AS r
    INNER JOIN table_yelp_business b ON r.business_id = b.business_id
    WHERE b.categories ILIKE '%Restaurants%'
    GROUP BY 1
),
ranked AS (
    SELECT *, DENSE_RANK() OVER(ORDER BY count_of_reviewed DESC) AS rnk
    FROM top_10
)
SELECT * FROM ranked WHERE rnk <= 10;



-- 3) Most popular categories by number of reviews?

WITH cte AS (
    SELECT business_id, TRIM(A.value) AS category
    FROM table_yelp_business, LATERAL SPLIT_TO_TABLE(categories, ',') A
)
SELECT category, COUNT(*) AS no_of_reviews
FROM cte
JOIN table_yelp_reviews r ON cte.business_id = r.business_id
GROUP BY 1
ORDER BY 2 DESC;



-- 4) Top 3 most recent reviews for each business?

WITH cte AS (
    SELECT 
        r.business_id,
        TRIM(A.value) AS category,
        r.review_date,
        b.categories,
        b.name,
        ROW_NUMBER() OVER(PARTITION BY b.categories ORDER BY r.review_date DESC) AS recent
    FROM table_yelp_business b
    JOIN table_yelp_reviews r ON b.business_id = r.business_id,
    LATERAL SPLIT_TO_TABLE(categories, ',') A
)
SELECT business_id, name, category, review_date
FROM cte
WHERE recent <= 3
ORDER BY review_date DESC;



-- 5) Month with highest number of reviews?

SELECT MONTH(review_date) AS month, COUNT(*) AS no_of_reviews
FROM table_yelp_reviews
GROUP BY 1
ORDER BY 2 DESC
LIMIT 1;



-- 6) Percentage of 5-star reviews for each business?

SELECT 
    b.business_id, 
    b.name, 
    COUNT(*) AS total_reviews,
    SUM(CASE WHEN r.review_stars = 5 THEN 1 ELSE 0 END) AS star_5_reviews,
    CONCAT(ROUND((SUM(CASE WHEN r.review_stars = 5 THEN 1 ELSE 0 END)::NUMERIC / COUNT(*) * 100), 2), '%') AS star_5_percentage
FROM table_yelp_reviews r
JOIN table_yelp_business b ON r.business_id = b.business_id
GROUP BY b.business_id, b.name
ORDER BY total_reviews DESC;



-- 7) Top 5 most reviewed businesses in each city?

WITH cte AS (
    SELECT b.business_id, b.city, COUNT(*) AS total_reviews
    FROM table_yelp_business b
    JOIN table_yelp_reviews r ON b.business_id = r.business_id
    GROUP BY 1,2
),
ranked AS (
    SELECT business_id, city, total_reviews, ROW_NUMBER() OVER(PARTITION BY city ORDER BY total_reviews DESC) AS rnk
    FROM cte
)
SELECT * FROM ranked WHERE rnk <= 5;



-- 8) Average rating of businesses with at least 100 reviews?

SELECT 
    b.business_id, 
    b.name, 
    COUNT(*) AS total_reviews, 
    AVG(review_stars) AS average_rating
FROM table_yelp_reviews r
JOIN table_yelp_business b ON r.business_id = b.business_id
GROUP BY 1,2
HAVING total_reviews >= 100
ORDER BY 3 DESC;



-- 9) Top 10 users with most reviews and their businesses?

WITH user_review_data AS (
    SELECT
        r.user_id,
        b.business_id,
        b.name AS business_name,
        COUNT(*) OVER (PARTITION BY r.user_id) AS total_reviews
    FROM table_yelp_reviews r
    JOIN table_yelp_business b ON r.business_id = b.business_id
),
ranked_users AS (
    SELECT *,
           DENSE_RANK() OVER (ORDER BY total_reviews DESC) AS rnk
    FROM user_review_data
)
SELECT
    user_id,
    business_id,
    business_name,
    total_reviews,
    rnk
FROM ranked_users
WHERE rnk <= 10
ORDER BY total_reviews DESC, user_id;



-- 10) Top 10 businesses with highest positive sentiment reviews?

SELECT 
    r.business_id, 
    b.name, 
    r.sentiment, 
    COUNT(*) AS total_reviews
FROM table_yelp_reviews r
JOIN table_yelp_business b ON r.business_id = b.business_id
WHERE sentiment = 'Positive'
GROUP BY 1,2,3
ORDER BY 4 DESC;