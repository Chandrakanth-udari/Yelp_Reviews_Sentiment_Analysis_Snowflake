/**********************************************************************
  YELP SNOWFLAKE PIPELINE AND ANALYSIS
  Author  : chandrakanth yadav
  Purpose : Load Yelp JSON data from Amazon S3 into Snowflake,
            flatten data, perform sentiment analysis.
**********************************************************************/

-- ============================================================
-- STEP 1: CREATE TABLES FOR RAW JSON DATA
-- ============================================================

-- Yelp Reviews Raw Table
CREATE OR REPLACE TABLE yelp_reviews (
    review_text VARIANT
);

-- Yelp Business Raw Table
CREATE OR REPLACE TABLE yelp_business (
    business_text VARIANT
);

-- ============================================================
-- STEP 2: COPY JSON DATA FROM AMAZON S3 INTO RAW TABLES
-- ============================================================

COPY INTO yelp_reviews
FROM 's3://yelp-json-project'
CREDENTIALS = (
    AWS_KEY_ID = 'XXXXXXXXXXXXXXXXX'
    AWS_SECRET_KEY = 'XXXXXXXXXXXXXXXXXXXXXXXXX'
)
FILE_FORMAT = (TYPE = 'JSON');

COPY INTO yelp_business
FROM 's3://yelp-json-project/yelp_academic_dataset_business.json'
CREDENTIALS = (
    AWS_KEY_ID = 'XXXXXXXXXXXXXXXXX'
    AWS_SECRET_KEY = 'XXXXXXXXXXXXXXXXXXXXXXX'
)
FILE_FORMAT = (TYPE = 'JSON');

-- ============================================================
-- STEP 3: USER DEFINED FUNCTION (UDF) FOR SENTIMENT ANALYSIS
-- ============================================================

CREATE OR REPLACE FUNCTION analyze_sentiment(text STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('textblob') 
HANDLER = 'sentiment_analyzer'
AS $$
from textblob import TextBlob
def sentiment_analyzer(text):
    analysis = TextBlob(text)
    if analysis.sentiment.polarity > 0:
        return 'Positive'
    elif analysis.sentiment.polarity == 0:
        return 'Neutral'
    else:
        return 'Negative'
$$;

-- ============================================================
-- STEP 4: FLATTEN JSON INTO TABULAR STRUCTURES
-- ============================================================

-- Table: Yelp Reviews (Flattened)
CREATE OR REPLACE TABLE table_yelp_reviews AS 
SELECT 
    review_text:business_id::STRING AS business_id,
    review_text:date::DATE AS review_date,
    review_text:user_id::STRING AS user_id,
    review_text:stars::NUMBER AS review_stars,
    review_text:text::STRING AS review_text,
    analyze_sentiment(review_text:text::STRING) AS sentiment
FROM yelp_reviews;

-- Table: Yelp Business (Flattened)
CREATE OR REPLACE TABLE table_yelp_business AS 
SELECT 
    business_text:business_id::STRING AS business_id,
    business_text:name::STRING AS name,
    business_text:city::STRING AS city,
    business_text:state::STRING AS state,
    business_text:review_count::NUMBER AS review_count,
    business_text:stars::NUMBER AS stars,
    business_text:categories::STRING AS categories
FROM yelp_business;

-- Preview Data
SELECT * FROM table_yelp_reviews LIMIT 100;
SELECT * FROM table_yelp_business LIMIT 100;