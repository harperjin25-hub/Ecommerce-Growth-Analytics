--- PART I Traffic Source Analysis ---

-- <1. Analyzing Traffic Source> --
-- where your customers are coming from
-- which channels are driving the highest quality traffic (Conversion Rate)/CVR
-- UTM parameters to identify paid website sessions

-- (1) Find the Top Traffic Sources
-- gsearch nonbrand
SELECT 
	utm_source,
    utm_campaign,
    http_referer,
    COUNT(DISTINCT website_session_id) AS sessions
FROM website_sessions
WHERE created_at < '2012-04-12'
GROUP BY 1,2,3
ORDER BY sessions DESC;

-- (2) Traffic Source Conversion Rate
-- CVR ~ 2.88% Lower than the 4% threshold 
-- OverSpending ~ Save Some $$$
SELECT 
	COUNT(DISTINCT ws.website_session_id) AS sessions,
    COUNT(DISTINCT o.order_id) AS orders,
    COUNT(DISTINCT o.order_id)/COUNT(DISTINCT ws.website_session_id) AS session_to_order_conv_rate
FROM website_sessions ws
LEFT JOIN orders o on ws.website_session_id = o.website_session_id
WHERE ws.created_at < '2012-04-14'
AND ws.utm_source ='gsearch' AND ws.utm_campaign = 'nonbrand';

-- <2. Bid Optimization & Trend Analysys> --
-- understanding the value of various segments of paid traffic
-- optimize your marketing budget

-- (1) Traffic Source Trending
-- bid down gsearch nonbrand on 04/15 
-- gsearch nonbrand is fairly sensitive to bid changes
SELECT
	-- YEAR(created_at) AS yr,
    -- WEEK(created_at) AS wk,
    MIN(DATE(created_at)) AS week_started_at,
    COUNT(DISTINCT website_session_id) AS sessions
FROM website_sessions
WHERE created_at < '2012-05-10'
AND utm_source ='gsearch' AND utm_campaign = 'nonbrand'
GROUP BY YEAR(created_at), WEEK(created_at);

-- (2) Bid Optimization for Paid Traffic
-- desktop ~ 3.73 WHILE mobile ~ < 1% (CVR)
-- increase bid on desktop
SELECT 
	device_type,
    COUNT(DISTINCT website_sessions.website_session_id) AS sessions,
    COUNT(DISTINCT order_id) AS orders,
    COUNT(DISTINCT order_id)/COUNT(DISTINCT website_sessions.website_session_id) AS conv_rt
FROM website_sessions
LEFT JOIN orders on website_sessions.website_session_id = orders.website_session_id
WHERE website_sessions.created_at < '2012-05-11'
AND utm_source ='gsearch' AND utm_campaign = 'nonbrand'
GROUP BY 1;

-- (3) Trending w/Granular Segments
-- PIVOT TABLE(Total --> A+B) <--> CASE WHEN
-- bid desktop on 05/20
-- AFTER bid desktop strong, mobile flat or a little down
SELECT 
	-- YEAR(created_at) AS yr,
    -- WEEK(created_at) AS wk,
    MIN(DATE(created_at)) AS week_start_date,
    COUNT(DISTINCT CASE WHEN device_type = 'desktop' THEN website_session_id ELSE NULL END) AS desktop_sessions,
    COUNT(DISTINCT CASE WHEN device_type = 'mobile' THEN website_session_id ELSE NULL END) AS mobile_sessions
FROM website_sessions
WHERE website_sessions.created_at < '2012-06-09'
	AND website_sessions.created_at > '2012-04-15'
	AND utm_source ='gsearch' AND utm_campaign = 'nonbrand'
GROUP BY YEAR(created_at), WEEK(created_at);

--- PART II Website Performance ---
-- <2. Analyzing Website Performance> --
-- Which Pages are seen the most by users

-- (1) Finding Top Website Pages
-- /home, /products, /mr-fuzzy get the bulk of our traffic
-- LOOK AT ENTRY PAGES
SELECT 
	pageview_url,
    COUNT(DISTINCT website_pageview_id) AS pvs
FROM website_pageviews
WHERE created_at < '2012-06-09'
GROUP BY 1
ORDER BY pvs DESC;

-- (2) Finding the Top Entry Pages (TEMPORARY TABLES)
-- STEP 1: find the FIRST PV for each session
-- STEP 2: find the url the customer saw on the FIRST PV
-- landing_page: /home make any improvement??
CREATE TEMPORARY TABLE first_pv_per_session
SELECT
	website_session_id,
    MIN(website_pageview_id) AS first_pv
FROM website_pageviews
WHERE created_at < '2012-06-12'
GROUP BY 1;

SELECT 
	website_pageviews.pageview_url AS Landing_page,
    COUNT(DISTINCT first_pv_per_session.website_session_id) AS sessions_hitting_page
FROM first_pv_per_session
LEFT JOIN website_pageviews
ON first_pv_per_session.first_pv = website_pageviews.website_pageview_id
GROUP BY website_pageviews.pageview_url;

-- (3) Calculating Bounce Rates (ONLY LANDING PAGE NOT MOVING)
-- bounce_rate: ~ 60% --> A/B Test 50/50
-- STEP 1: Finding the first website_pageview_id for revelent session
CREATE TEMPORARY TABLE first_pageviews
SELECT
	website_session_id,
    MIN(website_pageview_id) AS min_pageview_id
FROM website_pageviews
WHERE created_at < '2012-06-14'
GROUP BY 1;

-- STEP 2: Identify the landing page of each session
CREATE TEMPORARY TABLE sessions_w_home_landing_page
SELECT 
	first_pageviews.website_session_id,
    website_pageviews.pageview_url AS landing_page
FROM first_pageviews
LEFT JOIN website_pageviews
ON first_pageviews.min_pageview_id = website_pageviews.website_pageview_id;
-- SELECT * FROM sessions_w_home_landing_page;

-- STEP 3: counting each pageviews for each session, to identify "bounces"
CREATE TEMPORARY TABLE bounced_sessions
SELECT 
	sessions_w_home_landing_page.website_session_id,
    sessions_w_home_landing_page.landing_page,
    COUNT(website_pageviews.website_pageview_id) AS count_of_pages_viewed
FROM sessions_w_home_landing_page
LEFT JOIN website_pageviews
ON sessions_w_home_landing_page.website_session_id = website_pageviews.website_session_id
GROUP BY 
	sessions_w_home_landing_page.website_session_id,
    sessions_w_home_landing_page.landing_page
HAVING COUNT(website_pageviews.website_pageview_id) = 1;
-- SELECT * FROM bounced_sessions;

-- STEP 4: summarizing total sessions and "bounced sessions"
SELECT 
	sessions_w_home_landing_page.website_session_id,
    bounced_sessions.website_session_id AS bounced_website_session_id
FROM sessions_w_home_landing_page
LEFT JOIN bounced_sessions
ON sessions_w_home_landing_page.website_session_id = bounced_sessions.website_session_id
ORDER BY sessions_w_home_landing_page.website_session_id;

SELECT 
	COUNT(DISTINCT sessions_w_home_landing_page.website_session_id) AS total_sessions,
    COUNT(DISTINCT bounced_sessions.website_session_id) AS bounced_sessions,
    COUNT(DISTINCT bounced_sessions.website_session_id)/COUNT(DISTINCT sessions_w_home_landing_page.website_session_id) AS bounce_rate
FROM sessions_w_home_landing_page
LEFT JOIN bounced_sessions
ON sessions_w_home_landing_page.website_session_id = bounced_sessions.website_session_id;

-- (4) Analyzing Landing Page Tests(A/B Test)
-- '/lander-1' ~ 53% vs '/home' ~ 58%
-- NEW LANDER BETTER!!!

-- STEP 0: find out when the new page/lander launched
-- 2012-06-19 ID: 23504
SELECT 
	MIN(created_at) AS first_created_at,
    MIN(website_pageview_id) AS first_pageview_id
FROM website_pageviews
WHERE pageview_url = '/lander-1' AND created_at IS NOT NULL;

-- STEP 1: Finding the first website_pageview_id for revelent session
CREATE TEMPORARY TABLE first_test_pageview_id
SELECT 
	website_pageviews.website_session_id,
    MIN(website_pageviews.website_pageview_id) AS min_pageview_id
FROM website_pageviews
INNER JOIN website_sessions
ON website_sessions.website_session_id = website_pageviews.website_session_id
AND website_sessions.created_at < '2012-07-28'
AND website_pageviews.website_pageview_id > 23504
AND utm_source = "gsearch"
AND utm_campaign = "nonbrand"
GROUP BY website_pageviews.website_session_id;

-- next, we'll bring in the landing page to each session, like last time, but restricting to home or lander-1
CREATE TEMPORARY TABLE nonbrand_test_sessions_w_landing_page
SELECT 
	first_test_pageview_id.website_session_id,
    website_pageviews.pageview_url AS landing_page
FROM first_test_pageview_id
LEFT JOIN website_pageviews
ON first_test_pageview_id.min_pageview_id = website_pageviews.website_pageview_id
WHERE website_pageviews.pageview_url IN ('/home', '/lander-1');

-- then a table to have count of pageviews per session
-- then limit to just bounced_sessions
CREATE TEMPORARY TABLE nonbrand_test_bounced_sessions
SELECT 
	nonbrand_test_sessions_w_landing_page.website_session_id,
    nonbrand_test_sessions_w_landing_page.landing_page,
    COUNT(website_pageviews.website_pageview_id) AS count_of_pages_viewed
FROM nonbrand_test_sessions_w_landing_page
LEFT JOIN website_pageviews
ON nonbrand_test_sessions_w_landing_page.website_session_id = website_pageviews.website_session_id
GROUP BY
	nonbrand_test_sessions_w_landing_page.website_session_id,
    nonbrand_test_sessions_w_landing_page.landing_page
HAVING COUNT(website_pageviews.website_pageview_id) = 1;

SELECT 
	nonbrand_test_sessions_w_landing_page.landing_page,
    nonbrand_test_sessions_w_landing_page.website_session_id,
    nonbrand_test_bounced_sessions.website_session_id AS bounced_website_session_id
FROM nonbrand_test_sessions_w_landing_page
LEFT JOIN nonbrand_test_bounced_sessions
ON nonbrand_test_sessions_w_landing_page.website_session_id = nonbrand_test_bounced_sessions.website_session_id
ORDER BY nonbrand_test_sessions_w_landing_page.website_session_id;

-- final
SELECT 
	nonbrand_test_sessions_w_landing_page.landing_page,
    COUNT(DISTINCT nonbrand_test_sessions_w_landing_page.website_session_id) AS sessions,
    COUNT(DISTINCT nonbrand_test_bounced_sessions.website_session_id) AS bounced_sessions,
    COUNT(DISTINCT nonbrand_test_bounced_sessions.website_session_id)/COUNT(DISTINCT nonbrand_test_sessions_w_landing_page.website_session_id) AS bounce_rate
FROM nonbrand_test_sessions_w_landing_page
LEFT JOIN nonbrand_test_bounced_sessions
ON nonbrand_test_sessions_w_landing_page.website_session_id = nonbrand_test_bounced_sessions.website_session_id
GROUP BY nonbrand_test_sessions_w_landing_page.landing_page;

-- (5) Landing Page Trend Analysis
-- switch over to custom lander 'bounce rate' 60% ~ 50%
-- STEP 1: find the first website_pageview_id for relevent sessions
CREATE TEMPORARY TABLE sessions_w_min_pv_id_and_view_count
SELECT 
	website_sessions.website_session_id,
    MIN(website_pageviews.website_pageview_id) AS first_pageview_id,
    COUNT(website_pageviews.website_pageview_id) AS count_pageviews
FROM website_sessions
LEFT JOIN website_pageviews
ON website_sessions.website_session_id = website_pageviews.website_session_id
WHERE website_sessions.created_at > '2012-06-01'
	AND website_sessions.created_at < '2012-08-31'
AND utm_source = "gsearch"
AND utm_campaign = "nonbrand"
GROUP BY website_sessions.website_session_id;

-- STEP 2: identifying the landing page of each sessions
CREATE TEMPORARY TABLE sessions_w_counts_lander_and_created_at
SELECT 
	sessions_w_min_pv_id_and_view_count.website_session_id,
    sessions_w_min_pv_id_and_view_count.first_pageview_id,
    sessions_w_min_pv_id_and_view_count.count_pageviews,
    website_pageviews.pageview_url AS landing_page,
    website_pageviews.created_at AS session_created_at
FROM sessions_w_min_pv_id_and_view_count
LEFT JOIN website_pageviews
ON sessions_w_min_pv_id_and_view_count.first_pageview_id = website_pageviews.website_pageview_id;

-- 3: count pageviews for each session, to identify "bounces"
SELECT 
	-- YEARWEEK(session_created_at) AS year_week,
    MIN(DATE(session_created_at)) AS week_start_date,
    -- COUNT(DISTINCT website_session_id) AS total_sessions,
    -- COUNT(DISTINCT CASE WHEN count_pageviews = 1 THEN website_session_id ELSE NULL END) AS bounced_sessions,
    COUNT(DISTINCT CASE WHEN count_pageviews = 1 THEN website_session_id ELSE NULL END)/ COUNT(DISTINCT website_session_id) AS bounce_rate,
    COUNT(DISTINCT CASE WHEN landing_page = '/home' THEN website_session_id ELSE NULL END) AS home_sessions,
    COUNT(DISTINCT CASE WHEN landing_page = '/lander-1' THEN website_session_id ELSE NULL END) AS lander_sessions
FROM sessions_w_counts_lander_and_created_at
GROUP BY YEARWEEK(session_created_at);

-- (6) Building Conversion Funnels
-- 'lander': ~ 47% AND 'mr-fuzzy': ~ 44% AND 'biling': ~ 44%
-- They have the LOWEST CLICK RATES

SELECT 
	website_sessions.website_session_id,
    website_pageviews.pageview_url,
    -- website_pageviews.created_at AS pageview_created_at,
    CASE WHEN website_pageviews.pageview_url = '/products' THEN 1 ELSE 0 END AS products_page,
    CASE WHEN website_pageviews.pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END AS mrfuzzy_page,
    CASE WHEN website_pageviews.pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page,
    CASE WHEN website_pageviews.pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping_page,
    CASE WHEN website_pageviews.pageview_url = '/billing' THEN 1 ELSE 0 END AS billing_page,
    CASE WHEN website_pageviews.pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS thankyou_page
FROM website_sessions
LEFT JOIN website_pageviews
ON website_sessions.website_session_id = website_pageviews.website_session_id
WHERE website_sessions.created_at > '2012-08-05' AND website_sessions.created_at < '2012-09-05'
	AND website_sessions.utm_source = 'gsearch'
    AND website_sessions.utm_campaign = 'nonbrand'
ORDER BY
	website_sessions.website_session_id,
    website_pageviews.created_at;

CREATE TEMPORARY TABLE session_level_made_it_flags
SELECT
	website_session_id,
    MAX(products_page) AS products_made_it,
    MAX(mrfuzzy_page) AS mrfuzzy_made_it,
    MAX(cart_page) AS cart_made_it,
    MAX(shipping_page) AS shipping_made_it,
    MAX(billing_page) AS billing_made_it,
    MAX(thankyou_page) AS thankyou_made_it
FROM (
SELECT 
	website_sessions.website_session_id,
    website_pageviews.pageview_url,
    CASE WHEN website_pageviews.pageview_url = '/products' THEN 1 ELSE 0 END AS products_page,
    CASE WHEN website_pageviews.pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END AS mrfuzzy_page,
    CASE WHEN website_pageviews.pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page,
    CASE WHEN website_pageviews.pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping_page,
    CASE WHEN website_pageviews.pageview_url = '/billing' THEN 1 ELSE 0 END AS billing_page,
    CASE WHEN website_pageviews.pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS thankyou_page
FROM website_sessions
LEFT JOIN website_pageviews
ON website_sessions.website_session_id = website_pageviews.website_session_id
WHERE website_sessions.created_at > '2012-08-05' AND website_sessions.created_at < '2012-09-05'
	AND website_sessions.utm_source = 'gsearch'
    AND website_sessions.utm_campaign = 'nonbrand'
ORDER BY
	website_sessions.website_session_id,
    website_pageviews.created_at) AS pageview_level
GROUP BY website_session_id;

SELECT 
	COUNT(DISTINCT website_session_id) AS sessions,
    COUNT(DISTINCT CASE WHEN products_made_it = 1 THEN website_session_id ELSE NULL END) AS to_products,
    COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id ELSE NULL END) AS to_mrfuzzy,
    COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END) AS to_cart,
    COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id ELSE NULL END) AS to_shipping,
    COUNT(DISTINCT CASE WHEN billing_made_it = 1 THEN website_session_id ELSE NULL END) AS to_billing,
    COUNT(DISTINCT CASE WHEN thankyou_made_it = 1 THEN website_session_id ELSE NULL END) AS to_thankyou
FROM session_level_made_it_flags;

SELECT 
	COUNT(DISTINCT website_session_id) AS sessions,
    COUNT(DISTINCT CASE WHEN products_made_it = 1 THEN website_session_id ELSE NULL END) /COUNT(DISTINCT website_session_id) AS lander_clickthrough_rate,
    COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id ELSE NULL END) /COUNT(DISTINCT CASE WHEN products_made_it = 1 THEN website_session_id ELSE NULL END) AS products_clickthrough_rate,
    COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END) /COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id ELSE NULL END) AS mr_fuzzy_clickthrough_rate,
    COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id ELSE NULL END)/COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END) AS cart_clickthrough_rate,
    COUNT(DISTINCT CASE WHEN billing_made_it = 1 THEN website_session_id ELSE NULL END)/COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id ELSE NULL END) AS shipping_clickthrough_rate,
    COUNT(DISTINCT CASE WHEN thankyou_made_it = 1 THEN website_session_id ELSE NULL END)/COUNT(DISTINCT CASE WHEN billing_made_it = 1 THEN website_session_id ELSE NULL END) AS billing_clickthrough_rate
FROM session_level_made_it_flags;

-- (7) Analyzing Conversion Funnel Tests (A/B Test)
-- Focus on biling page to drive more sales!
-- 'biling': ~ 46% vs 'biling-2': ~ 63%
SELECT 
	MIN(website_pageview_id) AS first_pv_id
FROM website_pageviews
WHERE pageview_url = '/billing-2';
-- first_pv_id = 53550

SELECT 
	website_pageviews.website_session_id,
    website_pageviews.pageview_url AS billing_version_seen,
    orders.order_id
FROM website_pageviews
LEFT JOIN orders
ON website_pageviews.website_session_id = orders.website_session_id
WHERE website_pageviews.website_pageview_id >= 53550
AND website_pageviews.created_at < '2012-11-10'
AND website_pageviews.pageview_url IN ('/billing', '/billing-2');

SELECT 
	billing_version_seen,
    COUNT(DISTINCT website_session_id) AS sessions,
    COUNT(DISTINCT order_id) AS orders,
    COUNT(DISTINCT order_id)/COUNT(DISTINCT website_session_id) AS billing_to_order_rt
FROM (
SELECT 
	website_pageviews.website_session_id,
    website_pageviews.pageview_url AS billing_version_seen,
    orders.order_id
FROM website_pageviews
LEFT JOIN orders
ON website_pageviews.website_session_id = orders.website_session_id
WHERE website_pageviews.website_pageview_id >= 53550
AND website_pageviews.created_at < '2012-11-10'
AND website_pageviews.pageview_url IN ('/billing', '/billing-2')
) AS billing_sessions_w_orders
GROUP BY billing_version_seen;

--- PART III Channel Portfolio Management ---
-- <3. Analyzing Channel Portfolio> --
-- bidding efficiently and using data to maximize the effectiveness of your marketing budget

-- (1) Analyzing Channel Portfolios
-- gsearch = 3*bsearch
SELECT 
	MIN(DATE(created_at)) AS week_start_date,
    COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' THEN website_session_id ELSE NULL END) AS gsearch_sessions,
    COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' THEN website_session_id ELSE NULL END) AS bsearch_sessions
FROM website_sessions
WHERE website_sessions.created_at > '2012-08-22' AND website_sessions.created_at < '2012-11-29'
AND utm_campaign = 'nonbrand'
GROUP BY YEARWEEK(created_at);

-- (2) Comparing Channel Characteristics
-- bsearch_moblie: ~ 8.62%
-- gsearch_moblie: ~ 24.52%
SELECT 
	utm_source,
    COUNT(DISTINCT website_sessions.website_session_id) AS sessions,
    COUNT(DISTINCT CASE WHEN device_type = "mobile" THEN website_session_id ELSE NULL END) AS mobile_sessions,
    COUNT(DISTINCT CASE WHEN device_type = "mobile" THEN website_session_id ELSE NULL END)/
		COUNT(DISTINCT website_sessions.website_session_id) AS pct_mobile 
FROM website_sessions
WHERE created_at > '2012-08-22' 
AND created_at < '2012-11-30' 
AND utm_campaign = "nonbrand"
GROUP BY utm_source;

-- (3) Cross-Channel Bid Optimization
-- mobile & desktop: gsearch > bsearch
-- BID DOWN bsearch
SELECT 
	website_sessions.device_type,
    website_sessions.utm_source,
    COUNT(DISTINCT website_sessions.website_session_id) AS sessions,
    COUNT(DISTINCT orders.order_id) AS orders,
    COUNT(DISTINCT orders.order_id)/COUNT(DISTINCT website_sessions.website_session_id) AS conv_rate 
FROM website_sessions
LEFT JOIN orders
ON orders.website_session_id = website_sessions.website_session_id
WHERE website_sessions.created_at > '2012-08-22' AND website_sessions.created_at < '2012-09-19' 
AND utm_campaign = "nonbrand"
GROUP BY 1, 2;

-- (4) Analyzing Channel Portfolio Trends
-- Bid Down bsearch nonbrand since December 2nd
-- bsearch traffic dropped off a bit
-- Black Friday & Cyber Monday
SELECT 
	MIN(DATE(created_at)) AS week_start_date,
    COUNT(DISTINCT CASE WHEN utm_source = "gsearch" AND device_type = "desktop" THEN website_session_id ELSE NULL END) AS g_dtop_sessions,
    COUNT(DISTINCT CASE WHEN utm_source = "bsearch" AND device_type = "desktop" THEN website_session_id ELSE NULL END) AS b_dtop_sessions,
    COUNT(DISTINCT CASE WHEN utm_source = "bsearch" AND device_type = "desktop" THEN website_session_id ELSE NULL END)/
		COUNT(DISTINCT CASE WHEN utm_source = "gsearch" AND device_type = "desktop" THEN website_session_id ELSE NULL END) AS b_pct_of_g_dtop,
	COUNT(DISTINCT CASE WHEN utm_source = "gsearch" AND device_type = "mobile" THEN website_session_id ELSE NULL END) AS g_mob_sessions,
    COUNT(DISTINCT CASE WHEN utm_source = "bsearch" AND device_type = "mobile" THEN website_session_id ELSE NULL END) AS b_mob_sessions,
    COUNT(DISTINCT CASE WHEN utm_source = "bsearch" AND device_type = "mobile" THEN website_session_id ELSE NULL END)/
		COUNT(DISTINCT CASE WHEN utm_source = "gsearch" AND device_type = "mobile" THEN website_session_id ELSE NULL END) AS b_pct_of_g_mob
FROM website_sessions
WHERE website_sessions.created_at > '2012-11-04' AND website_sessions.created_at < '2012-12-22' 
AND utm_campaign = "nonbrand"
GROUP BY YEARWEEK(created_at);

-- (5) Analyzing Direct Traffic
-- the volumes of brand, direct and organic are growing
SELECT 
	YEAR(created_at) AS yr,
    MONTH(created_at) AS mo,
    COUNT(DISTINCT CASE WHEN channel_group = "paid_nonbrand" THEN website_session_id ELSE NULL END) AS nonbrand,
    COUNT(DISTINCT CASE WHEN channel_group = "paid_brand" THEN website_session_id ELSE NULL END) AS brand,
    COUNT(DISTINCT CASE WHEN channel_group = "paid_brand" THEN website_session_id ELSE NULL END)/
		COUNT(DISTINCT CASE WHEN channel_group = "paid_nonbrand" THEN website_session_id ELSE NULL END) AS brand_pct_of_nonbrand,
	COUNT(DISTINCT CASE WHEN channel_group = "direct_type_in" THEN website_session_id ELSE NULL END) AS direct,
    COUNT(DISTINCT CASE WHEN channel_group = "direct_type_in" THEN website_session_id ELSE NULL END)/
		COUNT(DISTINCT CASE WHEN channel_group = "paid_nonbrand" THEN website_session_id ELSE NULL END) AS direct_pct_of_nonbrand,
	COUNT(DISTINCT CASE WHEN channel_group = "organic_search" THEN website_session_id ELSE NULL END) AS organic,
    COUNT(DISTINCT CASE WHEN channel_group = "organic_search" THEN website_session_id ELSE NULL END)/
		COUNT(DISTINCT CASE WHEN channel_group = "paid_nonbrand" THEN website_session_id ELSE NULL END) AS organic_pct_of_nonbrand
FROM(
	SELECT 
	website_session_id,
    created_at,
	CASE
		WHEN utm_source IS NULL AND http_referer IN ('https://www.gsearch.com', 'https://www.bsearch.com') THEN 'organic_search'
        WHEN utm_campaign = 'nonbrand' THEN 'paid_nonbrand'
        WHEN utm_campaign = 'brand' THEN 'paid_brand'
        WHEN utm_source IS NULL AND http_referer IS NULL THEN 'direct_type_in'
	END AS channel_group
FROM website_sessions
WHERE created_at < '2012-12-23'
) AS sessions_w_channel_group
GROUP BY 1, 2;

--- PART IV Business Patterns and Seasonality ---
-- <4. Analyzing Business Patterns and Seasonality> --
-- generating insights to help you maximize efficiency and anticipate future trends

-- (1) Analyzing Seasonality
-- steadily grow all year
-- significant growth around (Black Friday & Cyber Monday)
SELECT 
	YEAR(website_sessions.created_at) AS yr,
    WEEK(website_sessions.created_at) AS wk,
    MIN(DATE(website_sessions.created_at)) AS week_start,
    COUNT(DISTINCT website_sessions.website_session_id) AS sessions,
    COUNT(DISTINCT orders.order_id) AS orders
FROM website_sessions
LEFT JOIN orders on website_sessions.website_session_id = orders.website_session_id
WHERE website_sessions.created_at < '2013-01-01'
GROUP BY 1, 2;

-- (2) Analyzing Business Patterns
-- 8am - 5pm Monday-Friday busy! 
SELECT 
	hr,
    ROUND(AVG(CASE WHEN wkday = 0 THEN website_sessions ELSE NULL END), 1) AS mon,
    ROUND(AVG(CASE WHEN wkday = 1 THEN website_sessions ELSE NULL END), 1) AS tue,
    ROUND(AVG(CASE WHEN wkday = 2 THEN website_sessions ELSE NULL END), 1) AS wed,
    ROUND(AVG(CASE WHEN wkday = 3 THEN website_sessions ELSE NULL END), 1) AS thu,
    ROUND(AVG(CASE WHEN wkday = 4 THEN website_sessions ELSE NULL END), 1) AS fri,
    ROUND(AVG(CASE WHEN wkday = 5 THEN website_sessions ELSE NULL END), 1) AS sat,
    ROUND(AVG(CASE WHEN wkday = 6 THEN website_sessions ELSE NULL END), 1) AS sun
FROM(
	SELECT
	DATE(created_at) AS created_date,
    WEEKDAY(created_at) AS wkday,
    HOUR(created_at) AS hr,
    COUNT(DISTINCT website_session_id) AS website_sessions
FROM website_sessions
WHERE created_at BETWEEN '2012-09-15' AND '2012-11-15'
GROUP BY 1, 2, 3
) AS daily_hourly_sessions
GROUP BY 1
ORDER BY 1;

--- PART V Product Analysis ---
-- <5. Analyzing Product Sales & Product Launches> --
-- understanding how each product contributes to your business,
-- how product launches impact the overall portfolio

-- (1) Product-Level Sales Analysis
-- baseline data for new product
SELECT 
	YEAR(created_at) AS yr,
    MONTH(created_at) AS mo,
    COUNT(DISTINCT order_id) AS number_of_sales,
    SUM(price_usd) AS total_revenue,
    SUM(price_usd - cogs_usd) AS total_margin
FROM orders
WHERE created_at < '2013-01-04'
GROUP BY
	YEAR(created_at),
    MONTH(created_at);

-- (2) Analyzing Product Launches
-- conversion rate increases but not sure new product??
SELECT 
	YEAR(website_sessions.created_at) AS yr,
    MONTH(website_sessions.created_at) AS mo,
    COUNT(DISTINCT website_sessions.website_session_id) AS sessions,
    COUNT(DISTINCT orders.order_id) AS orders,
    COUNT(DISTINCT orders.order_id)/COUNT(DISTINCT website_sessions.website_session_id) AS conv_rate,
    SUM(orders.price_usd)/COUNT(DISTINCT website_sessions.website_session_id) AS revenue_per_session,
    COUNT(DISTINCT CASE WHEN primary_product_id = 1 THEN order_id ELSE NULL END) AS product_one_orders,
    COUNT(DISTINCT CASE WHEN primary_product_id = 2 THEN order_id ELSE NULL END) AS product_two_orders
FROM website_sessions
LEFT JOIN orders ON website_sessions.website_session_id = orders.website_session_id
WHERE website_sessions.created_at < '2013-04-05' AND website_sessions.created_at > '2012-04-01'
GROUP BY 1, 2;

-- (3) Product-Level Website Pathing
-- % pv of mrfuzzy GOES DOWN since the launch of lovebear
-- overall clickthrough rate has gone up, additional product interest

-- STEP 1: find the relevant products pageviews with the website_session_id
CREATE TEMPORARY TABLE products_pageviews
SELECT
	website_session_id,
    website_pageview_id,
    created_at,
    CASE WHEN created_at < '2013-01-06' THEN 'A. Pre_Product_2'
         WHEN created_at >= '2013-01-06' THEN 'B. Pre_Product_2'
	ELSE 'uh on...check logic'
    END AS time_period
FROM website_pageviews
WHERE created_at < '2013-04-06' AND created_at > '2012-10-06'
AND pageview_url = '/products';

-- STEP 2: find the next pageviews id that occurs AFTER the product pageview
CREATE TEMPORARY TABLE sessions_w_next_pageview_id
SELECT 
	products_pageviews.time_period,
    products_pageviews.website_session_id,
    MIN(website_pageviews.website_pageview_id) AS min_next_pageview_id
FROM products_pageviews 
LEFT JOIN website_pageviews
	ON website_pageviews.website_session_id = products_pageviews.website_session_id
	AND website_pageviews.website_pageview_id > products_pageviews.website_pageview_id
GROUP BY 1, 2;

-- STEP 3: find the pageview_url associated with any applicable next pageview id
CREATE TEMPORARY TABLE sessions_w_next_pageview_url
SELECT 
	sessions_w_next_pageview_id.time_period,
    sessions_w_next_pageview_id.website_session_id,
    website_pageviews.pageview_url AS next_pageview_url
FROM sessions_w_next_pageview_id
LEFT JOIN website_pageviews
ON sessions_w_next_pageview_id.min_next_pageview_id = website_pageviews.website_pageview_id;

-- STEP 4: summarize the data and analyze the pre vs post periods
SELECT 
	time_period,
    COUNT(DISTINCT website_session_id) AS sessions,
    COUNT(DISTINCT CASE WHEN next_pageview_url IS NOT NULL THEN website_session_id ELSE NULL END) AS w_next_pg,
    COUNT(DISTINCT CASE WHEN next_pageview_url IS NOT NULL THEN website_session_id ELSE NULL END)/COUNT(DISTINCT website_session_id) AS pct_w_next_pg,
    COUNT(DISTINCT CASE WHEN next_pageview_url = '/the-original-mr-fuzzy' THEN website_session_id ELSE NULL END) AS to_mrfuzzy,
    COUNT(DISTINCT CASE WHEN next_pageview_url = '/the-original-mr-fuzzy' THEN website_session_id ELSE NULL END)/COUNT(DISTINCT website_session_id) AS pct_to_mrfuzzy,
    COUNT(DISTINCT CASE WHEN next_pageview_url = '/the-forever-love-bear' THEN website_session_id ELSE NULL END) AS to_lovebear,
    COUNT(DISTINCT CASE WHEN next_pageview_url = '/the-forever-love-bear' THEN website_session_id ELSE NULL END)/COUNT(DISTINCT website_session_id) AS pct_to_lovebear
FROM sessions_w_next_pageview_url
GROUP BY time_period;

-- (4) Building Product-Level Converion Funnels
-- adding a second product increased overall CTR!
-- lovebear has a better click rate to the '/cart' page and the rest of the funnel!

-- STEP 1: select all pageviews for relevant sessions
CREATE TEMPORARY TABLE sessions_seeing_product_pages
SELECT 
	website_session_id,
    website_pageview_id,
    pageview_url AS product_page_seen
FROM website_pageviews
WHERE created_at < '2013-04-10' AND created_at > '2013-01-06'
AND website_pageviews.pageview_url IN ('/the-original-mr-fuzzy', '/the-forever-love-bear');

-- STEP 2: figure out which pageview url to look for (After saw the product)
SELECT DISTINCT
	website_pageviews.pageview_url
FROM sessions_seeing_product_pages
LEFT JOIN website_pageviews
ON website_pageviews.website_session_id = sessions_seeing_product_pages.website_session_id
AND website_pageviews.website_pageview_id > sessions_seeing_product_pages.website_pageview_id;

-- STEP 3: pull all pageviews and identify the funnel steps
SELECT 
	sessions_seeing_product_pages.website_session_id,
    sessions_seeing_product_pages.product_page_seen,
    CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page,
    CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping_page,
    CASE WHEN pageview_url = '/billing-2' THEN 1 ELSE 0 END AS billing_page,
    CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS thankyou_page
FROM sessions_seeing_product_pages
LEFT JOIN website_pageviews
	ON website_pageviews.website_session_id = sessions_seeing_product_pages.website_session_id
	AND website_pageviews.website_pageview_id > sessions_seeing_product_pages.website_pageview_id
ORDER BY
	sessions_seeing_product_pages.website_session_id,
    website_pageviews.created_at
;

-- STEP 4: create the session-level conversion funnel view
CREATE TEMPORARY TABLE session_product_level_made_it_flags
SELECT 
	website_session_id,
    CASE WHEN product_page_seen = '/the-original-mr-fuzzy' THEN 'mrfuzzy'
		 WHEN product_page_seen = '/the-forever-love-bear' THEN 'lovebear'
         ELSE 'uh on...check logic'
	END AS product_seen,
    MAX(cart_page) AS cart_made_it,
    MAX(shipping_page) AS shipping_made_it,
    MAX(billing_page) AS billing_made_it,
    MAX(thankyou_page) AS thankyou_made_it
FROM(
SELECT 
	sessions_seeing_product_pages.website_session_id,
    sessions_seeing_product_pages.product_page_seen,
    CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page,
    CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping_page,
    CASE WHEN pageview_url = '/billing-2' THEN 1 ELSE 0 END AS billing_page,
    CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS thankyou_page
FROM sessions_seeing_product_pages
LEFT JOIN website_pageviews
	ON website_pageviews.website_session_id = sessions_seeing_product_pages.website_session_id
	AND website_pageviews.website_pageview_id > sessions_seeing_product_pages.website_pageview_id
ORDER BY
	sessions_seeing_product_pages.website_session_id,
    website_pageviews.created_at
) AS pageview_level
GROUP BY 
	website_session_id,
    CASE WHEN product_page_seen = '/the-original-mr-fuzzy' THEN 'mrfuzzy'
		 WHEN product_page_seen = '/the-forever-love-bear' THEN 'lovebear'
         ELSE 'uh on...check logic'
	END
;
-- STEP 5: aggregrate the data to access funnel performance
SELECT 
	product_seen,
    COUNT(DISTINCT website_session_id) AS sessions,
    COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END) AS to_cart,
    COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id ELSE NULL END) AS to_shipping,
    COUNT(DISTINCT CASE WHEN billing_made_it = 1 THEN website_session_id ELSE NULL END) AS to_billing,
    COUNT(DISTINCT CASE WHEN thankyou_made_it = 1 THEN website_session_id ELSE NULL END) AS to_thankyou
FROM session_product_level_made_it_flags
GROUP BY product_seen;

SELECT 
	product_seen,
    COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END)/COUNT(DISTINCT website_session_id) AS product_page_click_rt,
    COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id ELSE NULL END)/COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END) AS cart_click_rt,
    COUNT(DISTINCT CASE WHEN billing_made_it = 1 THEN website_session_id ELSE NULL END)/COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id ELSE NULL END) AS shipping_click_rt,
    COUNT(DISTINCT CASE WHEN thankyou_made_it = 1 THEN website_session_id ELSE NULL END)/COUNT(DISTINCT CASE WHEN billing_made_it = 1 THEN website_session_id ELSE NULL END) AS billing_click_rt
FROM session_product_level_made_it_flags
GROUP BY product_seen;

-- (5) Cross-Sell Analysis
-- understanding which products users are most likely to purchase together
-- Everthing Went UP!!

-- STEP 1: Identify the relevant /cart page views and their sessions
CREATE TEMPORARY TABLE sessions_seeing_cart
SELECT
    CASE WHEN created_at < '2013-09-25' THEN 'A. Pre_Cross_Sell'
         WHEN created_at >= '2013-09-25' THEN 'B. Post_Cross_Sell'
	ELSE 'uh on...check logic'
    END AS time_period,
    website_session_id AS cart_session_id,
    website_pageview_id AS cart_pageview_id
FROM website_pageviews
WHERE created_at BETWEEN '2013-08-25' AND '2013-10-25'
AND pageview_url = '/cart';

-- STEP 2: See which of those /cart sessions clicked through to the shipping page
CREATE TEMPORARY TABLE cart_sessions_seeing_another_cart
SELECT 
	sessions_seeing_cart.time_period,
    sessions_seeing_cart.cart_session_id,
    MIN(website_pageviews.website_pageview_id) AS pv_id_after_cart
FROM sessions_seeing_cart
LEFT JOIN website_pageviews
ON sessions_seeing_cart.cart_session_id = website_pageviews.website_session_id
AND website_pageviews.website_pageview_id > sessions_seeing_cart.cart_pageview_id
GROUP BY
	sessions_seeing_cart.time_period,
    sessions_seeing_cart.cart_session_id
HAVING MIN(website_pageviews.website_pageview_id) IS NOT NULL;

-- STEP 3: Find the orders associated with the /cart sessions. Analyze products purchased, AOV
CREATE TEMPORARY TABLE pre_post_sessions_orders
SELECT 
	time_period,
    cart_session_id,
    order_id,
    items_purchased,
    price_usd
FROM sessions_seeing_cart
INNER JOIN orders
ON sessions_seeing_cart.cart_session_id = orders.website_session_id;

-- STEP 4: Aggregate and analyze a summary of our findings
SELECT 
	time_period,
    COUNT(DISTINCT cart_session_id) AS cart_sessions,
    SUM(clicked_to_another_page) AS clickthroughs,
    SUM(clicked_to_another_page)/COUNT(DISTINCT cart_session_id) AS cart_ctr,
    SUM(placed_order) AS orders_placed,
    SUM(items_purchased) AS products_purchased,
    SUM(items_purchased)/SUM(placed_order) AS products_per_order,
    SUM(price_usd)/SUM(placed_order) AS aov,
    SUM(price_usd)/COUNT(DISTINCT cart_session_id) rev_per_cart_session
FROM(
SELECT
	sessions_seeing_cart.time_period,
    sessions_seeing_cart.cart_session_id,
    CASE WHEN cart_sessions_seeing_another_cart.cart_session_id IS NULL THEN 0 ELSE 1 END AS clicked_to_another_page,
    CASE WHEN pre_post_sessions_orders.cart_session_id IS NULL THEN 0 ELSE 1 END AS placed_order,
    pre_post_sessions_orders.items_purchased,
    pre_post_sessions_orders.price_usd
FROM sessions_seeing_cart
LEFT JOIN cart_sessions_seeing_another_cart
ON sessions_seeing_cart.cart_session_id = cart_sessions_seeing_another_cart.cart_session_id
LEFT JOIN pre_post_sessions_orders
ON sessions_seeing_cart.cart_session_id = pre_post_sessions_orders.cart_session_id
ORDER BY cart_session_id
) AS full_data
GROUP BY time_period;

-- (6) Product Portfolio Expansion
-- launched third product, all the metrics improved

SELECT 
	CASE WHEN website_sessions.created_at < '2013-12-22' THEN 'A. Pre_Birthday_Bear'
		 WHEN website_sessions.created_at >= '2013-12-22' THEN 'B. Post_Birthday_Bear'
         ELSE 'uh on...check logic'
	END AS time_period,
	-- COUNT(DISTINCT website_sessions.website_session_id) AS sessions,
    -- COUNT(DISTINCT orders.order_id) AS orders,
    COUNT(DISTINCT orders.order_id)/COUNT(DISTINCT website_sessions.website_session_id) AS conv_rate,
    -- SUM(orders.price_usd) AS total_revenue,
    -- SUM(orders.items_purchased) AS total_products_sold,
    SUM(orders.price_usd)/COUNT(DISTINCT orders.order_id) AS average_order_value,
    SUM(orders.items_purchased)/COUNT(DISTINCT orders.order_id) AS products_per_order,
    SUM(orders.price_usd)/COUNT(DISTINCT website_sessions.website_session_id) AS revenue_per_session
FROM website_sessions
LEFT JOIN orders
ON website_sessions.website_session_id = orders.website_session_id
WHERE website_sessions.created_at BETWEEN '2013-11-22' AND '2014-01-22'
GROUP BY 1;

-- (7) Product Refund Rate
-- refund rates for mrfuzzy went down after the initial improvement Sep
-- new supplier is doing better
SELECT 
	YEAR(order_items.created_at) AS yr,
    MONTH(order_items.created_at) AS mo,
    COUNT(DISTINCT CASE WHEN product_id = 1 THEN order_items.order_item_id ELSE NULL END) AS p1_orders,
    COUNT(DISTINCT CASE WHEN product_id = 1 THEN order_item_refunds.order_item_id ELSE NULL END)
		/COUNT(DISTINCT CASE WHEN product_id = 1 THEN order_items.order_item_id ELSE NULL END) AS p1_refund_rt,
	COUNT(DISTINCT CASE WHEN product_id = 2 THEN order_items.order_item_id ELSE NULL END) AS p2_orders,
    COUNT(DISTINCT CASE WHEN product_id = 2 THEN order_item_refunds.order_item_id ELSE NULL END)
		/COUNT(DISTINCT CASE WHEN product_id = 2 THEN order_items.order_item_id ELSE NULL END) AS p2_refund_rt,
	COUNT(DISTINCT CASE WHEN product_id = 3 THEN order_items.order_item_id ELSE NULL END) AS p3_orders,
    COUNT(DISTINCT CASE WHEN product_id = 3 THEN order_item_refunds.order_item_id ELSE NULL END)
		/COUNT(DISTINCT CASE WHEN product_id = 3 THEN order_items.order_item_id ELSE NULL END) AS p3_refund_rt,
	COUNT(DISTINCT CASE WHEN product_id = 4 THEN order_items.order_item_id ELSE NULL END) AS p4_orders,
    COUNT(DISTINCT CASE WHEN product_id = 4 THEN order_item_refunds.order_item_id ELSE NULL END)
		/COUNT(DISTINCT CASE WHEN product_id = 4 THEN order_items.order_item_id ELSE NULL END) AS p4_refund_rt
FROM order_items
LEFT JOIN order_item_refunds
ON order_items.order_item_id = order_item_refunds.order_item_id
WHERE order_items.created_at < '2014-10-15'
GROUP BY 1, 2;

--- PART VI User Analysis ---
-- <6. Analyzing Repeat Visit & Purchase Behavior> --
-- understanding user behavior and identify some of your most valuable customers

-- (1) Identify Repeat Visitors
-- a fair number of our customers do come back to our site after first session

CREATE TEMPORARY TABLE sessions_w_repeats
SELECT 
	new_sessions.user_id,
    new_sessions.website_session_id AS new_session_id,
    website_sessions.website_session_id AS repeat_session_id
FROM(
SELECT
	user_id,
    website_session_id
FROM website_sessions
WHERE created_at < '2014-11-01' AND created_at >= '2014-01-01'
AND is_repeat_session = 0
) AS new_sessions
LEFT JOIN website_sessions
ON website_sessions.user_id = new_sessions.user_id
AND website_sessions.is_repeat_session = 1
AND website_sessions.created_at < '2014-11-01'
AND website_sessions.created_at >= '2014-01-01';

SELECT 
	repeat_sessions,
    COUNT(DISTINCT user_id) AS users
FROM(
SELECT 
	user_id,
    COUNT(DISTINCT new_session_id) AS new_sessions,
    COUNT(DISTINCT repeat_session_id) AS repeat_sessions
FROM sessions_w_repeats
GROUP BY 1
) AS user_level
GROUP BY 1;

-- (2) Analyzing Time to Repeat 
-- AVG: ~ 33d, MIN: 1d, MAX: 69d 
CREATE TEMPORARY TABLE sessions_w_repeats_for_time_diff
SELECT 
	new_sessions.user_id,
    new_sessions.website_session_id AS new_session_id,
    new_sessions.created_at AS new_session_created_at,
    website_sessions.website_session_id AS repeat_session_id,
    website_sessions.created_at AS repeat_session_created_at
FROM(
SELECT
	user_id,
    website_session_id,
    created_at
FROM website_sessions
WHERE created_at < '2014-11-03' AND created_at >= '2014-01-01'
AND is_repeat_session = 0
) AS new_sessions
LEFT JOIN website_sessions
ON website_sessions.user_id = new_sessions.user_id
AND website_sessions.is_repeat_session = 1
AND website_sessions.created_at < '2014-11-03'
AND website_sessions.created_at >= '2014-01-01';

CREATE TEMPORARY TABLE users_first_to_second
SELECT 
	user_id,
    DATEDIFF(second_session_created_at, new_session_created_at) AS days_first_to_second_session
FROM(
SELECT
	user_id,
    new_session_id,
    new_session_created_at,
    MIN(repeat_session_id) AS second_session_id,
    MIN(repeat_session_created_at) AS second_session_created_at
FROM sessions_w_repeats_for_time_diff
WHERE repeat_session_id IS NOT NULL
GROUP BY 1, 2, 3
) AS first_second;

SELECT 
	AVG(days_first_to_second_session) AS avg_days_first_to_second,
    MIN(days_first_to_second_session) AS min_days_first_to_second,
    MAX(days_first_to_second_session) AS max_days_first_to_second
FROM users_first_to_second;

-- (3) Analyzing Repeat Channel Behavior
-- organic search, direct type-in, paid brand
SELECT 
	utm_source,
    utm_campaign,
    http_referer,
    COUNT(CASE WHEN is_repeat_session = 0 THEN website_session_id ELSE NULL END) AS new_sessions,
    COUNT(CASE WHEN is_repeat_session = 1 THEN website_session_id ELSE NULL END) AS repeat_sessions
FROM website_sessions
WHERE created_at < '2014-11-05' AND created_at >= '2014-01-01'
GROUP BY 1, 2, 3
ORDER BY 5 DESC;

SELECT 
	CASE WHEN utm_source IS NULL AND http_referer IN ('https://www.gsearch.com', 'https://www.bsearch.com') THEN 'organic_search'
         WHEN utm_campaign = 'nonbrand' THEN 'paid_nonbrand'
         WHEN utm_campaign = 'brand' THEN 'paid_brand'
         WHEN utm_source IS NULL AND http_referer IS NULL THEN 'direct_type_in'
         WHEN utm_source = 'socialbook' THEN 'paid_social'
	END AS channel_group,
    COUNT(CASE WHEN is_repeat_session = 0 THEN website_session_id ELSE NULL END) AS new_sessions,
    COUNT(CASE WHEN is_repeat_session = 1 THEN website_session_id ELSE NULL END) AS repeat_sessions
FROM website_sessions
WHERE created_at < '2014-11-05' AND created_at >= '2014-01-01'
GROUP BY 1
ORDER BY 3 DESC;

-- (4) Analyzing New & Repeat Conversion Rate
-- REPEAT session is more likely to convert!
SELECT 
	is_repeat_session,
    COUNT(DISTINCT website_sessions.website_session_id) AS sessions,
    COUNT(DISTINCT orders.order_id)/COUNT(DISTINCT website_sessions.website_session_id) AS conv_rate,
    SUM(price_usd)/COUNT(DISTINCT website_sessions.website_session_id) AS rev_per_session
FROM website_sessions
LEFT JOIN orders
ON website_sessions.website_session_id = orders.website_session_id
WHERE website_sessions.created_at < '2014-11-08'
	AND website_sessions.created_at >= '2014-01-01'
GROUP BY 1;

--- PART VII Final Outcome ---
/* 1. Volume Growth by quarter*/
SELECT 
	YEAR(website_sessions.created_at) AS yr,
    QUARTER(website_sessions.created_at) AS qtr,
    COUNT(DISTINCT website_sessions.website_session_id) AS sessions,
    COUNT(DISTINCT orders.order_id) AS orders
FROM website_sessions
LEFT JOIN orders
ON website_sessions.website_session_id = orders.website_session_id
GROUP BY 1, 2
ORDER BY 1, 2;

/* 2. Efficiency Improvements for conversion rate, revenue per order, and revenue per session*/
SELECT 
	YEAR(website_sessions.created_at) AS yr,
    QUARTER(website_sessions.created_at) AS qtr,
    COUNT(DISTINCT orders.order_id)/COUNT(DISTINCT website_sessions.website_session_id) AS session_to_order_conv_rate,
    SUM(price_usd)/COUNT(DISTINCT orders.order_id) AS revenue_per_order,
    SUM(price_usd)/COUNT(DISTINCT website_sessions.website_session_id) AS revenue_per_session
FROM website_sessions
LEFT JOIN orders
ON website_sessions.website_session_id = orders.website_session_id
GROUP BY 1, 2
ORDER BY 1, 2;

/* 3. Growth in specific Channels*/
SELECT 
	YEAR(website_sessions.created_at) AS yr,
    QUARTER(website_sessions.created_at) AS qtr,
    COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' AND utm_campaign = 'nonbrand' THEN orders.order_id ELSE NULL END) AS gsearch_nonbrand_orders,
    COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' AND utm_campaign = 'nonbrand' THEN orders.order_id ELSE NULL END) AS bsearch_nonbrand_orders,
    COUNT(DISTINCT CASE WHEN utm_campaign = 'brand' THEN orders.order_id ELSE NULL END) AS brand_search_orders,
    COUNT(DISTINCT CASE WHEN utm_source IS NULL  AND http_referer IS NOT NULL THEN orders.order_id ELSE NULL END) AS organic_search_orders,
    COUNT(DISTINCT CASE WHEN utm_source IS NULL  AND http_referer IS NULL THEN orders.order_id ELSE NULL END) AS direct_type_in_orders
FROM website_sessions
LEFT JOIN orders
ON website_sessions.website_session_id = orders.website_session_id
GROUP BY 1, 2
ORDER BY 1, 2;




