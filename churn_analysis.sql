-- Project: Customer churn (bank)
-- Question: Who is leaving, and how much money is at risk?
-- Tables: churn (raw, never edited), and churn_clean (used for all analysis)
-- Data: bank customer dataset, 10,000 rows
-- Assumptions: exited = 1 means the customer left the bank (not defined in the data)
-- Limit: "active member" is not defined in the data, estimated salary is only an estimate, currency is not stated

-- SECTION 1: SETUP
-- Drops table churn_clean
DROP TABLE IF EXISTS churn_clean;

-- CREATING A CLEAN TABLE FROM CHURN TABLE
-- churn_clean is identical to churn: the checks in Section 2 found nothing to fix. Kept as a separate table so raw data stays untouched.
CREATE TABLE churn_clean AS SELECT * FROM churn;

-- Lists 5 rows from churn_clean table
SELECT * FROM churn_clean LIMIT 5;



-- SECTION 2: DATA QUALITY CHECKS
-- 2.1 - DUPLICATES
-- Q: Is row number and customer id unique?
-- Finding: 10,000 rows, 10,000 row numbers, 10,000 distinct ids, so no duplicates
SELECT count(*) AS total_rows, 
count(DISTINCT row_number) AS distinct_row_numbers,
count(DISTINCT customer_id) AS distinct_customer_id
FROM churn_clean;

-- Q: Are there any repeated customer ids?
-- Finding: 0 rows returned, so none.
SELECT customer_id, count(*) AS customer_count FROM churn_clean 
GROUP BY customer_id HAVING count(*) > 1;


-- 2.2 - NULLS
-- Q: Are there any null values?
-- Finding: 0 nulls in all 14 columns
SELECT count(*)-count(row_number) AS null_row_number, 
count(*)-count(customer_id) AS null_customer_id,
count(*)-count(surname) AS null_surname, 
count(*)-count(credit_score) AS null_credit_score,
count(*)-count(geography) AS null_geography, 
count(*)-count(gender) AS null_gender,
count(*)-count(age) AS null_age, 
count(*)-count(tenure) AS null_tenure,
count(*)-count(balance) AS null_balance, 
count(*)-count(num_of_products) AS null_products,
count(*)-count(has_cr_card) AS null_cr_card, 
count(*)-count(is_active_member) AS null_active_members,
count(*)-count(estimated_salary) AS null_estimated_salary, 
count(*)-count(exited) AS null_exited
FROM churn_clean;


-- 2.3 - VALUE RANGES
-- Q: Do the value ranges make sense?
-- Finding: all ranges believable except min_estimated_salary 11.58 (see below)
SELECT min(credit_score) AS min_credit_score, -- min_credit_score = 350
max(credit_score) AS max_credit_score, -- max_credit_score = 850
min(age) AS min_age, -- min_age = 18
max(age) AS max_age, -- max_age = 92
min(balance) AS min_balance, -- min_balance = 0
max(balance) AS max_balance, -- max_balance = 250,898.09
min(tenure) AS min_tenure,  -- min_tenure = 0
max(tenure) AS max_tenure, -- max_tenure = 10
min(num_of_products) AS min_num_of_products, -- min_num_of_products = 1
max(num_of_products) AS max_num_of_products, -- max_num_of_products = 4
min(estimated_salary) AS min_estimated_salary, -- min_estimated_salary = 11.58
max(estimated_salary) AS max_estimated_salary -- max_estimated_salary = 199,992.48
FROM churn_clean;

-- Q: Are the flag columns only 0 or 1?
-- Finding: no values other than 0 or 1
SELECT sum(CASE WHEN has_cr_card NOT IN (1,0) THEN 1 ELSE 0 END) AS bad_cr_card,
sum(CASE WHEN is_active_member NOT IN (1,0) THEN 1 ELSE 0 END) AS bad_active_member,
sum(CASE WHEN exited NOT IN (1,0) THEN 1 ELSE 0 END) AS bad_exited
FROM churn_clean;

-- Q: What is the count of zero balance customers and low salary customers?
-- Finding: 36% of customers have zero balance (valid, kept). 59 have salary below 1,000 (estimate, kept)
SELECT sum(CASE WHEN balance = 0 THEN 1 ELSE 0 END) AS zero_balance_customers,
round(sum(CASE WHEN balance = 0 THEN 1 ELSE 0 END)*100.0/count(balance),2) AS zero_balance_customers_pct,
sum(CASE WHEN estimated_salary < 1000 THEN 1 ELSE 0 END) AS customers_with_low_estimated_salary
FROM churn_clean;


-- 2.4 - TEXT CLEANING
-- Q: Are there any trailing spaces?
-- Finding: 0 trailing spaces
SELECT sum(CASE WHEN length(geography)<>length(TRIM(geography)) THEN 1 ELSE 0 END) AS trailing_space_geography,
sum(CASE WHEN length(surname)<>length(TRIM(surname)) THEN 1 ELSE 0 END) AS trailing_space_surname,
sum(CASE WHEN length(gender)<>length(TRIM(gender)) THEN 1 ELSE 0 END) AS trailing_space_gender
FROM churn_clean;

-- Q: Are there any hidden characters?
-- Finding: 0 hidden characters
SELECT sum(CASE WHEN geography ~ '[^\x20-\x7E]' THEN 1 ELSE 0 END) AS hidden_char_geography,
sum(CASE WHEN surname ~ '[^\x20-\x7E]' THEN 1 ELSE 0 END) AS hidden_char_surname,
sum(CASE WHEN gender ~ '[^\x20-\x7E]' THEN 1 ELSE 0 END) AS hidden_char_gender
FROM churn_clean;

-- Q: Do hidden duplicates exist in geography or gender?
-- Finding: 3 and 3 countries, 2 and 2 genders, no hidden duplicates
SELECT count(DISTINCT geography) AS unique_geography,
count(DISTINCT lower(TRIM(geography))) AS trimmed_unique_geography,
count(DISTINCT gender) AS unique_gender,
count(DISTINCT lower(TRIM(gender))) AS trimmed_unique_gender
FROM churn_clean;

-- Q: Do surnames contain odd quote characters?
-- Finding: 237 straight apostrophes (real names, kept). 0 curly, 0 backticks, 0 double quotes
SELECT sum(CASE WHEN surname LIKE '%'||chr(39)||'%' THEN 1 ELSE 0 END) AS surname_with_apostrophe,
sum(CASE WHEN surname LIKE '%'||chr(8217)||'%' THEN 1 ELSE 0 END) AS surname_with_curly_apostrophe,
sum(CASE WHEN surname LIKE '%'||chr(96)||'%' THEN 1 ELSE 0 END) AS surname_with_backtick,
sum(CASE WHEN surname LIKE '%'||chr(34)||'%' THEN 1 ELSE 0 END) AS surname_with_double_quote
FROM churn_clean;


-- 2.5 - ROW COUNT (raw vs clean)
-- Q: Are the row counts matching?
-- Finding: 10,000 and 10,000, no rows lost
SELECT (SELECT count(*) FROM churn) AS raw_rows, (SELECT count(*) FROM churn_clean) AS clean_rows;



-- SECTION 3: ANALYSIS
-- 3.1 - BASELINE CHURN 
-- Q: What is the overall churn rate?
-- Finding: churned customers are about 20% of total customers
SELECT count(customer_id) AS total_customers,
sum(CASE WHEN exited=1 THEN 1 ELSE 0 END) AS churned_customers,
round(sum(CASE WHEN exited=1 THEN 1 ELSE 0 END)*100.0/count(customer_id),2) AS churn_pct
FROM churn_clean;


-- 3.2 - GEOGRAPHY
-- Q: Does churn differ by country?
-- Finding: Germany churns about twice as much as the other two countries
SELECT geography,
count(customer_id) AS total_customers, 
sum(exited) AS churned_customers, 
round(sum(exited)*100.0/count(customer_id),2) AS churn_pct
FROM churn_clean
GROUP BY geography
ORDER BY churn_pct DESC;


-- 3.3 - AGE
-- Q: Does churn differ by age band?
-- Finding: 46-60 churns at about 51%, which is 3x the rate of 31-45
SELECT CASE WHEN age >= 80 THEN '80 & above' 
WHEN age > 60 THEN '61 to 79'
WHEN age > 45 THEN '46 to 60'
WHEN age > 30 THEN '31 to 45'
ELSE '18 to 30' END AS age_band,
count(customer_id) AS total_customers, 
sum(exited) AS churned_customers, 
round(sum(exited)*100.0/count(customer_id),2) AS churn_pct
FROM churn_clean
GROUP BY age_band
ORDER BY min(age);


-- 3.4 - NUMBER OF PRODUCTS
-- Q: Does churn differ by number of products?
-- Finding: 2 products churn least (about 8%) and 3 or 4 products churn above 80%, but only 326 customers
SELECT num_of_products,
count(customer_id) AS total_customers, 
sum(exited) AS churned_customers, 
round(sum(exited)*100.0/count(customer_id),2) AS churn_pct
FROM churn_clean
GROUP BY num_of_products
ORDER BY num_of_products;


-- 3.5 - ACTIVE MEMBERS
-- Q: Does churn differ between non-active and active members?
-- Finding: non-active members churn at 26.85% while active members churn at 14.27%
SELECT CASE WHEN is_active_member=1 THEN 'Active' ELSE 'Non-active' END AS member_status,
count(customer_id) AS total_customers, 
sum(exited) AS churned_customers, 
round(sum(exited)*100.0/count(customer_id),2) AS churn_pct
FROM churn_clean
GROUP BY member_status
ORDER BY member_status;


-- 3.6 - GENDER
-- Q: Does churn differ by gender?
-- Finding: female customers churn at 25.07% and male customers at 16.46%
SELECT gender,
count(customer_id) AS total_customers, 
sum(exited) AS churned_customers, 
round(sum(exited)*100.0/count(customer_id),2) AS churn_pct
FROM churn_clean
GROUP BY gender
ORDER BY gender;


-- 3.7 - BALANCE
-- Q: Does churn differ between the customers with a balance and customers with zero balance?
-- Finding: customers with balance churn at 24.08% and with zero balance churn at 13.82% (see 4.1).
SELECT CASE WHEN balance = 0 THEN 'Zero' ELSE 'Has Balance' END AS balance_status, 
count(customer_id) AS total_customers,
sum(exited) AS churned_customers, 
round(sum(exited)*100.0/count(customer_id),2) AS churn_pct
FROM churn_clean
GROUP BY balance_status
ORDER BY balance_status;


-- 3.8 - WEAK DRIVERS
-- Q: Does churn differ by tenure?
-- Finding: no trend: churn stays between 17% and 23% in every tenure year
SELECT tenure,
count(customer_id) AS total_customers,
sum(exited) AS churned_customers, 
round(sum(exited)*100.0/count(customer_id),2) AS churn_pct
FROM churn_clean
GROUP BY tenure
ORDER BY tenure;

-- Q: Does churn differ by credit card? 
-- Finding: card holders churn at 20.18% and non-holders at 20.81%
SELECT CASE WHEN has_cr_card=1 THEN 'Yes' ELSE 'No' END AS card_holder,
count(customer_id) AS total_customers,
sum(exited) AS churned_customers, 
round(sum(exited)*100.0/count(customer_id),2) AS churn_pct
FROM churn_clean
GROUP BY card_holder
ORDER BY card_holder;

-- Q: What is the average salary of churned and stayed customers?
-- Finding: average salary is almost the same for both, so it doesn't explain churn (and it's only an estimate)
SELECT CASE WHEN exited=1 THEN 'Churned' ELSE 'Stayed' END AS customer_status,
round(avg(estimated_salary),2) AS average_estimated_salary
FROM churn_clean
GROUP BY customer_status;



-- SECTION 4: DEEP DIVE
-- 4.1 - BALANCE BY COUNTRY
-- Q: Does the balance gap hold inside each country?
-- Finding: balance gap is smaller inside France and Spain. Germany (no zero balance customers) inflated the overall gap
SELECT geography,
CASE WHEN balance = 0 THEN 'Zero' ELSE 'Has Balance' END AS balance_status, 
count(customer_id) AS total_customers,
sum(exited) AS churned_customers, 
round(sum(exited)*100.0/count(customer_id),2) AS churn_pct
FROM churn_clean
GROUP BY geography,balance_status
ORDER BY geography,balance_status;


-- 4.2 - AGE BY COUNTRY
-- Q: Does the age pattern hold inside each country?
-- Finding: 46-60 churns most in every country, so age is a real driver
SELECT CASE WHEN age >= 80 THEN '80 & above' 
WHEN age > 60 THEN '61 to 79'
WHEN age > 45 THEN '46 to 60'
WHEN age > 30 THEN '31 to 45'
ELSE '18 to 30' END AS age_band,
geography,
count(customer_id) AS total_customers, 
sum(exited) AS churned_customers, 
round(sum(exited)*100.0/count(customer_id),2) AS churn_pct
FROM churn_clean
GROUP BY age_band,geography
ORDER BY min(age),churn_pct DESC;


-- 4.3 - HOTSPOT
-- Q: Inside the age 46 to 60 band, how does churn change with the number of products? 
-- Finding: 1 product churns at 60.90%, 2 products at 23.57%, and 3 or 4 products at 99.08%, only 109 customers in 3 or 4 products 
-- Biggest Hotspot: 1 product, 606 leavers = 29.75% of all churn (606 of 2,037)
SELECT CASE WHEN num_of_products=1 THEN '1'
WHEN num_of_products=2 THEN '2' ELSE '3 or 4' END AS product_group,
count(customer_id) AS total_customers,
sum(exited) AS churned_customers, 
round(sum(exited)*100.0/count(customer_id),2) AS churn_pct
FROM churn_clean
WHERE age BETWEEN 46 AND 60
GROUP BY product_group
ORDER BY min(num_of_products);


-- 4.4 - MONEY AT RISK
-- Q: How much balance did the churned customers hold, compared with all customers? 
-- Finding: churned customers held 185.6M of 764.9M 
-- Takeaway: churners are 20.37% of customers but hold 24.26% of balance
SELECT sum(balance) AS total_balance,
sum(CASE WHEN exited=1 THEN balance END) AS churned_balance,
round(sum(CASE WHEN exited=1 THEN balance END)*100.0/sum(balance),2) AS churned_balance_pct
FROM churn_clean;


-- 4.5 - PILOT GROUP
-- Q: What is the average balance of customers aged 46 to 60 with 1 product?
-- Finding: 995 total customers, 606 churned customers, 94,500.87 average balance
SELECT count(customer_id) AS total_customers,
sum(exited) AS churned_customers, 
round(avg(balance),2) AS avg_balance
FROM churn_clean
WHERE (age BETWEEN 46 AND 60) AND (num_of_products=1);
