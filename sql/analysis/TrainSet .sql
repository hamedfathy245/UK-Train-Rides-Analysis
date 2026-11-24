
CREATE TABLE IF NOT EXISTS railway_clean (
    "Transaction ID" TEXT PRIMARY KEY,
    "Date of Purchase" DATE,
    "Time of Purchase" TIME,
    "Purchase Type" TEXT,
    "Payment Method" TEXT,
    "Railcard" TEXT,
    "Ticket Class" TEXT,
    "Ticket Type" TEXT,
    "Price" INTEGER,
    "Departure Station" TEXT,
    "Arrival Destination" TEXT,
    "Date of Journey" DATE,
    "Departure Time" TIME,
    "Arrival Time" TIME,
    "Actual Arrival Time" TIME,
    "Journey Status" TEXT,
    "Reason for Delay" TEXT,
    "Refund Request" TEXT
);

-- Question 1: How many tickets (rides) were sold in total, and what is the total revenue?
SELECT COUNT(*) AS total_tickets, SUM("Price") AS total_revenue
FROM railway_clean;

-- Question 2: What is the average, median, minimum and maximum ticket price?
SELECT AVG("Price") AS average_price,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY "Price") AS median_price,
       MIN("Price") AS minimum_price,
       MAX("Price") AS maximum_price
FROM railway_clean;

-- Question 3: How do daily rides and daily revenue trend over the whole period?
SELECT "Date of Journey" AS journey_date, COUNT(*) AS rides, SUM("Price") AS revenue
FROM railway_clean
GROUP BY "Date of Journey"
ORDER BY journey_date;

-- Question 4: How do weekly and monthly rides and revenue compare (Jan, Feb, Mar, Apr 2024)?
SELECT 'Week' AS period_type, date_trunc('week', "Date of Journey")::date AS period_start,
       COUNT(*) AS rides, SUM("Price") AS revenue
FROM railway_clean GROUP BY 1,2
UNION ALL
SELECT 'Month', date_trunc('month', "Date of Journey")::date,
       COUNT(*), SUM("Price")
FROM railway_clean GROUP BY 1,2
ORDER BY period_type, period_start;

-- Question 5: Which day of the week has the most rides and the highest revenue?
SELECT trim(to_char("Date of Journey", 'Day')) AS day_of_week,
       COUNT(*) AS rides, SUM("Price") AS revenue
FROM railway_clean
GROUP BY EXTRACT(ISODOW FROM "Date of Journey"), trim(to_char("Date of Journey", 'Day'))
ORDER BY EXTRACT(ISODOW FROM "Date of Journey");

-- Question 6: Are weekends different from weekdays in volume, price and ticket mix?
SELECT CASE WHEN EXTRACT(ISODOW FROM "Date of Journey") IN (6,7) THEN 'Weekend' ELSE 'Weekday' END AS day_group,
       COUNT(*) AS tickets, AVG("Price") AS average_price,
       COUNT(*) FILTER (WHERE "Ticket Type"='Advance') AS advance_tickets,
       COUNT(*) FILTER (WHERE "Ticket Type"='Off-Peak') AS off_peak_tickets,
       COUNT(*) FILTER (WHERE "Ticket Type"='Anytime') AS anytime_tickets
FROM railway_clean GROUP BY 1 ORDER BY 1;

-- Question 7: Which dates had the highest and lowest sales, and what might explain them?
WITH daily AS (
  SELECT "Date of Journey" AS journey_date, COUNT(*) AS rides, SUM("Price") AS revenue
  FROM railway_clean GROUP BY 1
), ranked AS (
  SELECT *, rank() OVER (ORDER BY rides DESC) AS ride_high,
            rank() OVER (ORDER BY rides ASC) AS ride_low,
            rank() OVER (ORDER BY revenue DESC) AS revenue_high,
            rank() OVER (ORDER BY revenue ASC) AS revenue_low
  FROM daily
)
SELECT * FROM ranked WHERE ride_high=1 OR ride_low=1 OR revenue_high=1 OR revenue_low=1
ORDER BY journey_date;

-- Question 8: Which hours of the day are busiest for departures (peak vs off-peak)?
SELECT EXTRACT(HOUR FROM "Departure Time")::int AS departure_hour,
       COUNT(*) AS rides,
       CASE WHEN EXTRACT(HOUR FROM "Departure Time") BETWEEN 7 AND 9
                  OR EXTRACT(HOUR FROM "Departure Time") BETWEEN 16 AND 18
            THEN 'Peak' ELSE 'Off-Peak' END AS period
FROM railway_clean GROUP BY 1,3 ORDER BY 1;

-- Question 9: What is the revenue contribution of each ticket type (Advance, Off-Peak, Anytime)?
SELECT "Ticket Type", COUNT(*) AS tickets, SUM("Price") AS revenue,
       ROUND(100.0*SUM("Price")/SUM(SUM("Price")) OVER (),2) AS revenue_share_pct
FROM railway_clean GROUP BY 1 ORDER BY revenue DESC;

-- Question 10: What is the revenue contribution of Standard vs First Class compared with their share of tickets?
SELECT "Ticket Class", COUNT(*) AS tickets, SUM("Price") AS revenue,
       ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER (),2) AS ticket_share_pct,
       ROUND(100.0*SUM("Price")/SUM(SUM("Price")) OVER (),2) AS revenue_share_pct
FROM railway_clean GROUP BY 1 ORDER BY revenue DESC;

-- Question 11: Is the price distribution skewed, and what share of revenue comes from the top 10% most expensive tickets?
WITH ranked AS (
 SELECT "Price", ntile(10) OVER (ORDER BY "Price" DESC) AS price_decile FROM railway_clean
)
SELECT (SELECT AVG("Price") FROM railway_clean) AS average_price,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY "Price") AS median_price,
       SUM("Price") FILTER (WHERE price_decile=1) AS top_decile_revenue,
       ROUND(100.0*SUM("Price") FILTER (WHERE price_decile=1)/(SELECT SUM("Price") FROM railway_clean),2) AS top_decile_revenue_share_pct
FROM ranked;

-- Question 12: What is the month-over-month growth rate in rides and revenue?
WITH monthly AS (
 SELECT date_trunc('month', "Date of Journey")::date AS month,
        COUNT(*) AS rides, SUM("Price") AS revenue
 FROM railway_clean GROUP BY 1
)
SELECT month, rides, revenue,
       ROUND(100.0*(rides-LAG(rides) OVER (ORDER BY month))/NULLIF(LAG(rides) OVER (ORDER BY month),0),2) AS rides_mom_pct,
       ROUND(100.0*(revenue-LAG(revenue) OVER (ORDER BY month))/NULLIF(LAG(revenue) OVER (ORDER BY month),0),2) AS revenue_mom_pct
FROM monthly ORDER BY month;

-- Question 13: What are the top 10 routes by number of tickets?
SELECT "Departure Station" || ' → ' || "Arrival Destination" AS route,
       COUNT(*) AS tickets FROM railway_clean
GROUP BY 1 ORDER BY tickets DESC LIMIT 10;

-- Question 14: What are the top 10 routes by revenue? Destination, Price
SELECT "Departure Station" || ' → ' || "Arrival Destination" AS route,
       COUNT(*) AS tickets, SUM("Price") AS revenue
FROM railway_clean GROUP BY 1 ORDER BY revenue DESC LIMIT 10;

-- Question 15: Which departure stations are the busiest, and which are the least used?
SELECT "Departure Station", COUNT(*) AS departures
FROM railway_clean GROUP BY 1 ORDER BY departures DESC;

-- Question 16: Which arrival destinations are the most popular?
SELECT "Arrival Destination", COUNT(*) AS arrivals
FROM railway_clean GROUP BY 1 ORDER BY arrivals DESC;

-- Question 17: Which routes have the highest and lowest average ticket price?
SELECT "Departure Station" || ' → ' || "Arrival Destination" AS route,
       COUNT(*) AS tickets, AVG("Price") AS average_price
FROM railway_clean GROUP BY 1 HAVING COUNT(*) >= 10 ORDER BY average_price DESC;

-- Question 18: Which routes have high volume but low revenue per ticket (and the reverse)?
SELECT "Departure Station" || ' → ' || "Arrival Destination" AS route,
       COUNT(*) AS tickets, SUM("Price") AS revenue, AVG("Price") AS revenue_per_ticket
FROM railway_clean GROUP BY 1 ORDER BY tickets DESC, revenue_per_ticket ASC;

-- Question 19: Which routes are rarely used and could be reviewed or reduced?
SELECT "Departure Station" || ' → ' || "Arrival Destination" AS route,
       COUNT(*) AS tickets FROM railway_clean GROUP BY 1
ORDER BY tickets ASC LIMIT 20;

-- Question 20: Which stations act mainly as origins and which mainly as destinations (net flow)?
WITH flows AS (
 SELECT station, SUM(origins) AS origin_tickets, SUM(destinations) AS destination_tickets
 FROM (
  SELECT "Departure Station" AS station, COUNT(*) AS origins, 0::bigint AS destinations FROM railway_clean GROUP BY 1
  UNION ALL
  SELECT "Arrival Destination", 0::bigint, COUNT(*) FROM railway_clean GROUP BY 1
 ) s GROUP BY station
)
SELECT *, origin_tickets-destination_tickets AS net_outflow
FROM flows ORDER BY net_outflow DESC;

-- Question 21: Do some routes depend heavily on one ticket type or class?
SELECT "Departure Station" || ' → ' || "Arrival Destination" AS route,
       "Ticket Type", "Ticket Class", COUNT(*) AS tickets,
       ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER (PARTITION BY "Departure Station", "Arrival Destination"),2) AS route_mix_pct
FROM railway_clean GROUP BY 1,2,3,"Departure Station","Arrival Destination"
ORDER BY route, tickets DESC;

-- Question 22: How does route demand vary by day of week and by month?
SELECT "Departure Station" || ' → ' || "Arrival Destination" AS route,
       EXTRACT(ISODOW FROM "Date of Journey") AS weekday_num,
       date_trunc('month', "Date of Journey")::date AS journey_month,
       COUNT(*) AS tickets
FROM railway_clean GROUP BY 1,2,3 ORDER BY route, journey_month, weekday_num;

-- Question 23: What share of total revenue comes from the top 5 routes (concentration risk)?
WITH routes AS (
 SELECT "Departure Station", "Arrival Destination", SUM("Price") AS revenue
 FROM railway_clean GROUP BY 1,2
), ranked AS (SELECT *, row_number() OVER (ORDER BY revenue DESC) AS rn FROM routes)
SELECT SUM(revenue) FILTER (WHERE rn<=5) AS top_5_revenue,
       ROUND(100.0*SUM(revenue) FILTER (WHERE rn<=5)/(SELECT SUM("Price") FROM railway_clean),2) AS top_5_revenue_share_pct
FROM ranked;

-- Question 24: Are there routes served at many different departure times, and how is demand spread across them?
SELECT "Departure Station" || ' → ' || "Arrival Destination" AS route,
       COUNT(DISTINCT "Departure Time") AS distinct_departure_times,
       COUNT(*) AS tickets, COUNT(*)::numeric/NULLIF(COUNT(DISTINCT "Departure Time"),0) AS average_tickets_per_time
FROM railway_clean GROUP BY 1 ORDER BY distinct_departure_times DESC;

-- Question 25: What is the split between Advance, Off-Peak and Anytime tickets?
SELECT "Ticket Type", COUNT(*) AS tickets,
       ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER (),2) AS ticket_share_pct
FROM railway_clean GROUP BY 1 ORDER BY tickets DESC;

-- Question 26: What is the average price of each ticket type, and for each class within each type?
SELECT "Ticket Type", "Ticket Class", COUNT(*) AS tickets, AVG("Price") AS average_price
FROM railway_clean GROUP BY 1,2 ORDER BY 1,2;

-- Question 27: How does the ticket type mix change by day of week, month and hour of departure?
SELECT EXTRACT(ISODOW FROM "Date of Journey") AS weekday_num,
       date_trunc('month',"Date of Journey")::date AS journey_month,
       EXTRACT(HOUR FROM "Departure Time")::int AS departure_hour,
       "Ticket Type", COUNT(*) AS tickets
FROM railway_clean GROUP BY 1,2,3,4 ORDER BY 2,1,3,4;

-- Question 28: Which routes sell the most First Class tickets?
SELECT "Departure Station" || ' → ' || "Arrival Destination" AS route,
       COUNT(*) AS first_class_tickets
FROM railway_clean WHERE "Ticket Class"='First Class'
GROUP BY 1 ORDER BY 2 DESC LIMIT 10;

-- Question 29: Is the First Class premium consistent across routes and ticket types?
SELECT "Departure Station" || ' → ' || "Arrival Destination" AS route,
       "Ticket Type",
       AVG("Price") FILTER (WHERE "Ticket Class"='First Class') AS first_class_avg_price,
       AVG("Price") FILTER (WHERE "Ticket Class"='Standard') AS standard_avg_price,
       AVG("Price") FILTER (WHERE "Ticket Class"='First Class')-AVG("Price") FILTER (WHERE "Ticket Class"='Standard') AS premium_amount
FROM railway_clean GROUP BY 1,2 ORDER BY 1,2;

-- Question 30: Do Anytime tickets cluster at peak hours, and Advance tickets at off-peak hours?
SELECT "Ticket Type",
       CASE WHEN EXTRACT(HOUR FROM "Departure Time") BETWEEN 7 AND 9 OR EXTRACT(HOUR FROM "Departure Time") BETWEEN 16 AND 18
            THEN 'Peak' ELSE 'Off-Peak' END AS departure_period,
       COUNT(*) AS tickets,
       ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER (PARTITION BY "Ticket Type"),2) AS type_share_pct
FROM railway_clean GROUP BY 1,2 ORDER BY 1,2;

-- Question 31: Which ticket type and class combination yields the highest revenue per ticket?
SELECT "Ticket Type", "Ticket Class", COUNT(*) AS tickets,
       SUM("Price") AS revenue, AVG("Price") AS revenue_per_ticket
FROM railway_clean GROUP BY 1,2 ORDER BY revenue_per_ticket DESC;

-- Question 32: Is Standard vs First Class demand changing over time?
SELECT date_trunc('month',"Date of Journey")::date AS journey_month,
       "Ticket Class", COUNT(*) AS tickets
FROM railway_clean GROUP BY 1,2 ORDER BY 1,2;

-- Question 33: What is the split between Online and Station purchases, and is it changing over time?
SELECT date_trunc('month',"Date of Purchase")::date AS purchase_month,
       "Purchase Type", COUNT(*) AS purchases
FROM railway_clean GROUP BY 1,2 ORDER BY 1,2;

-- Question 34: Which payment methods are most used, and do they differ by purchase channel?
SELECT "Purchase Type", "Payment Method", COUNT(*) AS transactions
FROM railway_clean GROUP BY 1,2 ORDER BY 1,3 DESC;

-- Question 35: Do average prices differ between online and station purchases?
SELECT "Purchase Type", COUNT(*) AS tickets, AVG("Price") AS average_price
FROM railway_clean GROUP BY 1 ORDER BY 1;

-- Question 36: What is the booking lead time (journey date minus purchase date), and how is it distributed?
WITH x AS (SELECT "Date of Journey"-"Date of Purchase" AS lead_time_days FROM railway_clean)
SELECT lead_time_days, COUNT(*) AS tickets
FROM x GROUP BY 1 ORDER BY 1;

-- Question 37: Does lead time differ by ticket type? (Advance tickets should be bought earlier.)
SELECT "Ticket Type", COUNT(*) AS tickets,
       AVG("Date of Journey"-"Date of Purchase") AS average_lead_days,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY "Date of Journey"-"Date of Purchase") AS median_lead_days
FROM railway_clean GROUP BY 1 ORDER BY average_lead_days DESC;

-- Question 38: Does buying earlier lead to a lower price?
SELECT "Date of Journey"-"Date of Purchase" AS lead_time_days,
       COUNT(*) AS tickets, AVG("Price") AS average_price
FROM railway_clean GROUP BY 1 ORDER BY 1;

-- Question 39: What hours of the day do customers buy tickets, online and at stations?
SELECT EXTRACT(HOUR FROM "Time of Purchase")::int AS purchase_hour,
       "Purchase Type", COUNT(*) AS purchases
FROM railway_clean GROUP BY 1,2 ORDER BY 1,2;

-- Question 40: Which days of the week have the most purchases, and how does that differ from journey days?
SELECT activity_type, weekday_num, COUNT(*) AS records
FROM (
 SELECT 'Purchase' AS activity_type, EXTRACT(ISODOW FROM "Date of Purchase") AS weekday_num FROM railway_clean
 UNION ALL
 SELECT 'Journey', EXTRACT(ISODOW FROM "Date of Journey") FROM railway_clean
) x GROUP BY 1,2 ORDER BY 1,2;

-- Question 41: Do First Class buyers book earlier or later than Standard buyers?
SELECT "Ticket Class", COUNT(*) AS tickets,
       AVG("Date of Journey"-"Date of Purchase") AS average_lead_days,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY "Date of Journey"-"Date of Purchase") AS median_lead_days
FROM railway_clean GROUP BY 1 ORDER BY 1;

-- Question 42: Are there same-day purchases, and which routes or ticket types do they involve?
SELECT "Departure Station" || ' → ' || "Arrival Destination" AS route,
       "Ticket Type", COUNT(*) AS same_day_tickets
FROM railway_clean WHERE "Date of Journey"="Date of Purchase"
GROUP BY 1,2 ORDER BY 3 DESC;

-- Question 43: Do contactless payments dominate at stations compared with online?
SELECT "Purchase Type", "Payment Method", COUNT(*) AS transactions,
       ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER (PARTITION BY "Purchase Type"),2) AS channel_share_pct
FROM railway_clean GROUP BY 1,2 ORDER BY 1,3 DESC;

-- Question 44: Which ticket types and routes are preferred by online buyers vs station buyers?
SELECT "Purchase Type", "Ticket Type",
       "Departure Station" || ' → ' || "Arrival Destination" AS route,
       COUNT(*) AS tickets
FROM railway_clean GROUP BY 1,2,3 ORDER BY 1,4 DESC;

-- Question 45: What share of tickets use a railcard (Adult, Disabled, Senior) and what share use none?
SELECT COALESCE("Railcard",'No Railcard') AS railcard_group,
       COUNT(*) AS tickets,
       ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER (),2) AS ticket_share_pct
FROM railway_clean GROUP BY 1 ORDER BY tickets DESC;

-- Question 46: What is the average price paid by each railcard group vs no railcard?
SELECT COALESCE("Railcard",'No Railcard') AS railcard_group,
       COUNT(*) AS tickets, AVG("Price") AS average_price
FROM railway_clean GROUP BY 1 ORDER BY average_price DESC;

-- Question 47: Which railcard groups prefer which ticket types and classes?
SELECT COALESCE("Railcard",'No Railcard') AS railcard_group,
       "Ticket Type", "Ticket Class", COUNT(*) AS tickets
FROM railway_clean GROUP BY 1,2,3 ORDER BY 1,4 DESC;

-- Question 48: Do railcard holders travel on different days or hours?
SELECT COALESCE("Railcard",'No Railcard') AS railcard_group,
       EXTRACT(ISODOW FROM "Date of Journey") AS weekday_num,
       EXTRACT(HOUR FROM "Departure Time")::int AS departure_hour,
       COUNT(*) AS tickets
FROM railway_clean GROUP BY 1,2,3 ORDER BY 1,2,3;

-- Question 49: Which routes have the highest railcard usage?
SELECT "Departure Station" || ' → ' || "Arrival Destination" AS route,
       COUNT(*) FILTER (WHERE "Railcard" IS NOT NULL) AS railcard_tickets,
       COUNT(*) AS total_tickets,
       ROUND(100.0*COUNT(*) FILTER (WHERE "Railcard" IS NOT NULL)/COUNT(*),2) AS railcard_usage_pct
FROM railway_clean GROUP BY 1 ORDER BY railcard_usage_pct DESC;

-- Question 50: Do railcard holders buy earlier or later than others?
SELECT COALESCE("Railcard",'No Railcard') AS railcard_group,
       AVG("Date of Journey"-"Date of Purchase") AS average_lead_days,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY "Date of Journey"-"Date of Purchase") AS median_lead_days
FROM railway_clean GROUP BY 1 ORDER BY average_lead_days DESC;

-- Question 51: How much revenue is associated with each railcard group, and how does it compare with its ticket share?
SELECT COALESCE("Railcard",'No Railcard') AS railcard_group,
       COUNT(*) AS tickets, SUM("Price") AS revenue,
       ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER (),2) AS ticket_share_pct,
       ROUND(100.0*SUM("Price")/SUM(SUM("Price")) OVER (),2) AS revenue_share_pct
FROM railway_clean GROUP BY 1 ORDER BY revenue DESC;

-- Question 52: Do railcard holders purchase online or at the station more often?
SELECT COALESCE("Railcard",'No Railcard') AS railcard_group,
       "Purchase Type", COUNT(*) AS tickets
FROM railway_clean GROUP BY 1,2 ORDER BY 1,3 DESC;

-- Question 53: Are railcard holders more likely to request refunds?
SELECT COALESCE("Railcard",'No Railcard') AS railcard_group,
       COUNT(*) AS tickets,
       COUNT(*) FILTER (WHERE "Refund Request"='Yes') AS refund_requests,
       ROUND(100.0*COUNT(*) FILTER (WHERE "Refund Request"='Yes')/COUNT(*),2) AS refund_rate_pct
FROM railway_clean GROUP BY 1 ORDER BY refund_rate_pct DESC;

-- Question 54: What are the overall rates of On Time, Delayed and Cancelled journeys?
SELECT "Journey Status", COUNT(*) AS tickets,
       ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER (),2) AS ticket_share_pct
FROM railway_clean GROUP BY 1 ORDER BY tickets DESC;

-- Question 55: Which routes have the worst punctuality (highest delay or cancellation rate)?
SELECT "Departure Station" || ' → ' || "Arrival Destination" AS route,
       COUNT(*) AS tickets,
       ROUND(100.0*COUNT(*) FILTER (WHERE "Journey Status"='Delayed')/COUNT(*),2) AS delayed_ticket_pct,
       ROUND(100.0*COUNT(*) FILTER (WHERE "Journey Status"='Cancelled')/COUNT(*),2) AS cancelled_ticket_pct
FROM railway_clean
GROUP BY 1
HAVING COUNT(*) >= 20
ORDER BY (
    100.0 * COUNT(*) FILTER (WHERE "Journey Status" IN ('Delayed','Cancelled'))
    / COUNT(*)
) DESC;

-- Question 56: Which departure stations and arrival destinations are most affected by disruption?
SELECT station, station_role, COUNT(*) AS affected_tickets
FROM (
 SELECT "Departure Station" AS station, 'Departure' AS station_role FROM railway_clean WHERE "Journey Status" IN ('Delayed','Cancelled')
 UNION ALL
 SELECT "Arrival Destination", 'Arrival' FROM railway_clean WHERE "Journey Status" IN ('Delayed','Cancelled')
) s GROUP BY 1,2 ORDER BY affected_tickets DESC;

-- Question 57: How does punctuality vary by hour of departure?
SELECT EXTRACT(HOUR FROM "Departure Time")::int AS departure_hour,
       COUNT(*) AS tickets,
       COUNT(*) FILTER (WHERE "Journey Status"='Delayed') AS delayed_tickets,
       COUNT(*) FILTER (WHERE "Journey Status"='Cancelled') AS cancelled_tickets,
       ROUND(100.0*COUNT(*) FILTER (WHERE "Journey Status" IN ('Delayed','Cancelled'))/COUNT(*),2) AS disruption_rate_pct
FROM railway_clean GROUP BY 1 ORDER BY 1;

-- Question 58: How does punctuality vary by day of week and by month?
SELECT EXTRACT(ISODOW FROM "Date of Journey") AS weekday_num,
       date_trunc('month',"Date of Journey")::date AS journey_month,
       COUNT(*) AS tickets,
       ROUND(100.0*COUNT(*) FILTER (WHERE "Journey Status" IN ('Delayed','Cancelled'))/COUNT(*),2) AS disruption_rate_pct
FROM railway_clean GROUP BY 1,2 ORDER BY 2,1;

-- Question 59: What are the most common reasons for delay or cancellation, after merging duplicate labels?
SELECT CASE WHEN "Reason for Delay" IN ('Weather','Weather Conditions') THEN 'Weather'
            WHEN "Reason for Delay" IN ('Staffing','Staff Shortage') THEN 'Staffing'
            ELSE "Reason for Delay" END AS normalized_reason,
       COUNT(*) AS tickets
FROM railway_clean WHERE "Journey Status" IN ('Delayed','Cancelled')
GROUP BY 1 ORDER BY tickets DESC;

-- Question 60: Which delay reasons dominate on which routes?
SELECT "Departure Station" || ' → ' || "Arrival Destination" AS route,
       CASE WHEN "Reason for Delay" IN ('Weather','Weather Conditions') THEN 'Weather'
            WHEN "Reason for Delay" IN ('Staffing','Staff Shortage') THEN 'Staffing'
            ELSE "Reason for Delay" END AS normalized_reason,
       COUNT(*) AS affected_tickets
FROM railway_clean WHERE "Journey Status" IN ('Delayed','Cancelled')
GROUP BY 1,2 ORDER BY 1,3 DESC;

-- Question 61: What is the average delay in minutes (actual minus scheduled arrival) for delayed trains?
SELECT AVG(EXTRACT(EPOCH FROM ("Actual Arrival Time"-"Arrival Time"))/60.0) AS average_delay_minutes
FROM railway_clean WHERE "Journey Status"='Delayed' AND "Actual Arrival Time" IS NOT NULL;

-- Question 62: How does delay length vary by reason (e.g. Signal Failure vs Weather)?
SELECT CASE WHEN "Reason for Delay" IN ('Weather','Weather Conditions') THEN 'Weather'
            WHEN "Reason for Delay" IN ('Staffing','Staff Shortage') THEN 'Staffing'
            ELSE "Reason for Delay" END AS normalized_reason,
       COUNT(*) AS delayed_tickets,
       AVG(EXTRACT(EPOCH FROM ("Actual Arrival Time"-"Arrival Time"))/60.0) AS average_delay_minutes
FROM railway_clean WHERE "Journey Status"='Delayed' AND "Actual Arrival Time" IS NOT NULL
GROUP BY 1 ORDER BY average_delay_minutes DESC;

-- Question 63: What is the distribution of delays: how many are under 15 minutes, 15 to 30, 30 to 60, over 60?
WITH delays AS (
 SELECT EXTRACT(EPOCH FROM ("Actual Arrival Time"-"Arrival Time"))/60.0 AS delay_minutes
 FROM railway_clean WHERE "Journey Status"='Delayed' AND "Actual Arrival Time" IS NOT NULL
)
SELECT CASE WHEN delay_minutes<15 THEN 'Under 15 minutes'
            WHEN delay_minutes<30 THEN '15 to under 30 minutes'
            WHEN delay_minutes<60 THEN '30 to under 60 minutes'
            ELSE '60 minutes or more' END AS delay_band,
       COUNT(*) AS tickets
FROM delays GROUP BY 1 ORDER BY MIN(delay_minutes);

-- Question 64: Are cancellations or delays more common in certain months (for example weather in winter)?
SELECT date_trunc('month',"Date of Journey")::date AS journey_month,
       "Journey Status",
       COUNT(*) AS tickets
FROM railway_clean GROUP BY 1,2 ORDER BY 1,2;

-- Question 65: Do some stations or routes suffer repeatedly from the same cause?
SELECT "Departure Station" || ' → ' || "Arrival Destination" AS route,
       CASE WHEN "Reason for Delay" IN ('Weather','Weather Conditions') THEN 'Weather'
            WHEN "Reason for Delay" IN ('Staffing','Staff Shortage') THEN 'Staffing'
            ELSE "Reason for Delay" END AS normalized_reason,
       COUNT(*) AS affected_tickets
FROM railway_clean WHERE "Journey Status" IN ('Delayed','Cancelled')
GROUP BY 1,2 ORDER BY affected_tickets DESC;

-- Question 66: What is the scheduled journey duration per route, and does it vary suspiciously (timetable accuracy)?
SELECT "Departure Station" || ' → ' || "Arrival Destination" AS route,
       AVG(EXTRACT(EPOCH FROM ("Arrival Time"-"Departure Time"))/60.0) AS average_scheduled_minutes,
       MIN(EXTRACT(EPOCH FROM ("Arrival Time"-"Departure Time"))/60.0) AS min_scheduled_minutes,
       MAX(EXTRACT(EPOCH FROM ("Arrival Time"-"Departure Time"))/60.0) AS max_scheduled_minutes,
       COUNT(*) AS journeys
FROM railway_clean GROUP BY 1 ORDER BY 1;

-- Question 67: Are delays getting better or worse over the four months?
SELECT date_trunc('month',"Date of Journey")::date AS journey_month,
       COUNT(*) AS tickets,
       ROUND(100.0*COUNT(*) FILTER (WHERE "Journey Status" IN ('Delayed','Cancelled'))/COUNT(*),2) AS disruption_rate_pct,
       ROUND(100.0*COUNT(*) FILTER (WHERE "Journey Status"='Delayed')/COUNT(*),2) AS delayed_rate_pct
FROM railway_clean GROUP BY 1 ORDER BY 1;

-- Question 68: Do early arrivals (actual earlier than scheduled) exist, and how common are they?
SELECT COUNT(*) FILTER (WHERE "Actual Arrival Time"<"Arrival Time") AS early_arrivals,
       COUNT(*) FILTER (WHERE "Actual Arrival Time" IS NOT NULL) AS records_with_actual_arrival,
       ROUND(100.0*COUNT(*) FILTER (WHERE "Actual Arrival Time"<"Arrival Time")/NULLIF(COUNT(*) FILTER (WHERE "Actual Arrival Time" IS NOT NULL),0),2) AS early_arrival_pct
FROM railway_clean;

-- Question 69: What is the average actual journey time compared with scheduled by route?
SELECT "Departure Station" || ' → ' || "Arrival Destination" AS route,
       AVG(EXTRACT(EPOCH FROM ("Arrival Time"-"Departure Time"))/60.0) AS scheduled_minutes,
       AVG(EXTRACT(EPOCH FROM ("Actual Arrival Time"-"Departure Time"))/60.0) FILTER (WHERE "Actual Arrival Time" IS NOT NULL) AS actual_minutes
FROM railway_clean GROUP BY 1 ORDER BY 1;

-- Question 70: What is the overall refund request rate?
SELECT COUNT(*) FILTER (WHERE "Refund Request"='Yes') AS refund_requests,
       COUNT(*) AS total_tickets,
       ROUND(100.0*COUNT(*) FILTER (WHERE "Refund Request"='Yes')/COUNT(*),2) AS refund_rate_pct
FROM railway_clean;

-- Question 71: How does the refund request rate differ between delayed and cancelled journeys?
SELECT "Journey Status", COUNT(*) AS tickets,
       COUNT(*) FILTER (WHERE "Refund Request"='Yes') AS refund_requests,
       ROUND(100.0*COUNT(*) FILTER (WHERE "Refund Request"='Yes')/COUNT(*),2) AS refund_rate_pct
FROM railway_clean WHERE "Journey Status" IN ('Delayed','Cancelled') GROUP BY 1;

-- Question 72: Does longer delay increase the likelihood of a refund request?
SELECT CASE WHEN "Actual Arrival Time" IS NULL OR "Journey Status"<>'Delayed' THEN 'Not delayed / no actual time'
            WHEN EXTRACT(EPOCH FROM ("Actual Arrival Time"-"Arrival Time"))/60.0<15 THEN 'Under 15 minutes'
            WHEN EXTRACT(EPOCH FROM ("Actual Arrival Time"-"Arrival Time"))/60.0<30 THEN '15 to under 30 minutes'
            WHEN EXTRACT(EPOCH FROM ("Actual Arrival Time"-"Arrival Time"))/60.0<60 THEN '30 to under 60 minutes'
            ELSE '60 minutes or more' END AS delay_band,
       COUNT(*) AS tickets,
       ROUND(100.0*COUNT(*) FILTER (WHERE "Refund Request"='Yes')/COUNT(*),2) AS refund_rate_pct
FROM railway_clean GROUP BY 1 ORDER BY 1;

-- Question 73: Which delay reasons lead to the most refund requests?
SELECT "Reason for Delay", COUNT(*) FILTER (WHERE "Refund Request"='Yes') AS refund_requests,
       COUNT(*) AS tickets,
       ROUND(100.0*COUNT(*) FILTER (WHERE "Refund Request"='Yes')/COUNT(*),2) AS refund_rate_pct
FROM railway_clean WHERE "Journey Status" IN ('Delayed','Cancelled') GROUP BY 1 ORDER BY refund_requests DESC;

-- Question 74: Which routes and stations generate the most refund requests?
SELECT "Departure Station" || ' → ' || "Arrival Destination" AS route,
       COUNT(*) FILTER (WHERE "Refund Request"='Yes') AS refund_requests,
       COUNT(*) AS tickets
FROM railway_clean GROUP BY 1 ORDER BY refund_requests DESC;

-- Question 75: Do refund rates differ by ticket type, class or railcard?
SELECT "Ticket Type", "Ticket Class", COALESCE("Railcard",'No Railcard') AS railcard_group,
       COUNT(*) AS tickets,
       ROUND(100.0*COUNT(*) FILTER (WHERE "Refund Request"='Yes')/COUNT(*),2) AS refund_rate_pct
FROM railway_clean GROUP BY 1,2,3 ORDER BY refund_rate_pct DESC;

-- Question 76: What is the potential revenue at risk from refund requests (sum of Price where Refund Request = Yes)?
SELECT SUM("Price") FILTER (WHERE "Refund Request"='Yes') AS potential_revenue_at_risk,
       COUNT(*) FILTER (WHERE "Refund Request"='Yes') AS refund_request_tickets
FROM railway_clean;

-- Question 77: What revenue is tied to cancelled journeys, and how much of it was claimed?
SELECT SUM("Price") FILTER (WHERE "Journey Status"='Cancelled') AS cancelled_journey_revenue,
       SUM("Price") FILTER (WHERE "Journey Status"='Cancelled' AND "Refund Request"='Yes') AS cancelled_revenue_with_refund_request,
       ROUND(100.0*SUM("Price") FILTER (WHERE "Journey Status"='Cancelled' AND "Refund Request"='Yes')/
             NULLIF(SUM("Price") FILTER (WHERE "Journey Status"='Cancelled'),0),2) AS claimed_revenue_pct
FROM railway_clean;

-- Question 78: Do passengers who bought online request refunds more than those who bought at the station?
SELECT "Purchase Type", COUNT(*) AS tickets,
       COUNT(*) FILTER (WHERE "Refund Request"='Yes') AS refund_requests,
       ROUND(100.0*COUNT(*) FILTER (WHERE "Refund Request"='Yes')/COUNT(*),2) AS refund_rate_pct
FROM railway_clean GROUP BY 1;

-- Question 79: What share of eligible (delayed or cancelled) passengers did NOT request a refund, and what is the value of that unclaimed amount?
SELECT COUNT(*) FILTER (WHERE "Refund Request"='No') AS eligible_no_refund_tickets,
       COUNT(*) AS eligible_tickets,
       ROUND(100.0*COUNT(*) FILTER (WHERE "Refund Request"='No')/COUNT(*),2) AS no_refund_share_pct,
       SUM("Price") FILTER (WHERE "Refund Request"='No') AS associated_ticket_value
FROM railway_clean WHERE "Journey Status" IN ('Delayed','Cancelled');

-- Question 80: Do First Class passengers claim refunds more often than Standard passengers?
SELECT "Ticket Class", COUNT(*) AS tickets,
       COUNT(*) FILTER (WHERE "Refund Request"='Yes') AS refund_requests,
       ROUND(100.0*COUNT(*) FILTER (WHERE "Refund Request"='Yes')/COUNT(*),2) AS refund_rate_pct
FROM railway_clean GROUP BY 1 ORDER BY refund_rate_pct DESC;

-- Question 81: Is there a refund hotspot, a route + reason combination with a very high refund rate?
SELECT "Departure Station" || ' → ' || "Arrival Destination" AS route,
       "Reason for Delay", COUNT(*) AS tickets,
       COUNT(*) FILTER (WHERE "Refund Request"='Yes') AS refund_requests,
       ROUND(100.0*COUNT(*) FILTER (WHERE "Refund Request"='Yes')/COUNT(*),2) AS refund_rate_pct
FROM railway_clean WHERE "Journey Status" IN ('Delayed','Cancelled')
GROUP BY 1,2 HAVING COUNT(*)>=10 ORDER BY refund_rate_pct DESC;

-- Question 82: Do First Class passengers experience different punctuality from Standard passengers?
SELECT "Ticket Class", "Journey Status", COUNT(*) AS tickets,
       ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER (PARTITION BY "Ticket Class"),2) AS class_status_share_pct
FROM railway_clean GROUP BY 1,2 ORDER BY 1,2;

-- Question 83: Which combination of route, ticket type and time of day generates the most revenue?
SELECT "Departure Station" || ' → ' || "Arrival Destination" AS route,
       "Ticket Type",
       CASE WHEN EXTRACT(HOUR FROM "Departure Time") BETWEEN 7 AND 9 OR EXTRACT(HOUR FROM "Departure Time") BETWEEN 16 AND 18
            THEN 'Peak' ELSE 'Off-Peak' END AS departure_period,
       COUNT(*) AS tickets, SUM("Price") AS revenue
FROM railway_clean GROUP BY 1,2,3 ORDER BY revenue DESC LIMIT 20;

-- Question 84: Is there a correlation between price and delay or cancellation?
SELECT corr("Price"::double precision,
             CASE WHEN "Journey Status"='On Time' THEN 0.0 ELSE 1.0 END) AS price_disruption_correlation,
       AVG("Price") FILTER (WHERE "Journey Status"='On Time') AS on_time_average_price,
       AVG("Price") FILTER (WHERE "Journey Status"='Delayed') AS delayed_average_price,
       AVG("Price") FILTER (WHERE "Journey Status"='Cancelled') AS cancelled_average_price
FROM railway_clean;

-- Question 85: Which routes are both high revenue and high disruption (priority for operational improvement)?
SELECT "Departure Station" || ' → ' || "Arrival Destination" AS route,
       COUNT(*) AS tickets, SUM("Price") AS revenue,
       ROUND(100.0*COUNT(*) FILTER (WHERE "Journey Status" IN ('Delayed','Cancelled'))/COUNT(*),2) AS disruption_rate_pct
FROM railway_clean GROUP BY 1 HAVING COUNT(*)>=20
ORDER BY revenue DESC, disruption_rate_pct DESC;

-- Question 86: Which customer segment (railcard x class x purchase channel) is most valuable?
SELECT COALESCE("Railcard",'No Railcard') AS railcard_group,
       "Ticket Class", "Purchase Type", COUNT(*) AS tickets,
       SUM("Price") AS revenue, AVG("Price") AS revenue_per_ticket
FROM railway_clean GROUP BY 1,2,3 ORDER BY revenue DESC;

-- Question 87: Which routes have the largest refund exposure relative to revenue?
SELECT "Departure Station" || ' → ' || "Arrival Destination" AS route,
       SUM("Price") AS total_revenue,
       SUM("Price") FILTER (WHERE "Refund Request"='Yes') AS refund_request_value,
       ROUND(100.0*SUM("Price") FILTER (WHERE "Refund Request"='Yes')/NULLIF(SUM("Price"),0),2) AS refund_exposure_pct
FROM railway_clean GROUP BY 1 ORDER BY refund_exposure_pct DESC;

-- Question 88: Are peak-hour trains more delayed than off-peak ones?
SELECT CASE WHEN EXTRACT(HOUR FROM "Departure Time") BETWEEN 7 AND 9 OR EXTRACT(HOUR FROM "Departure Time") BETWEEN 16 AND 18
            THEN 'Peak' ELSE 'Off-Peak' END AS departure_period,
       COUNT(*) AS tickets,
       ROUND(100.0*COUNT(*) FILTER (WHERE "Journey Status"='Delayed')/COUNT(*),2) AS delayed_rate_pct,
       ROUND(100.0*COUNT(*) FILTER (WHERE "Journey Status"='Cancelled')/COUNT(*),2) AS cancelled_rate_pct
FROM railway_clean GROUP BY 1;

-- Question 89: Does demand drop after major disruption days?
WITH daily AS (
 SELECT "Date of Journey" AS journey_date, COUNT(*) AS rides,
        COUNT(*) FILTER (WHERE "Journey Status" IN ('Delayed','Cancelled')) AS disrupted_tickets
 FROM railway_clean GROUP BY 1
), flagged AS (
 SELECT *, disrupted_tickets::numeric/NULLIF(rides,0) AS disruption_share,
        LAG(rides) OVER (ORDER BY journey_date) AS previous_day_rides
 FROM daily
)
SELECT journey_date, rides, disrupted_tickets, ROUND(100*disruption_share,2) AS disruption_share_pct,
       previous_day_rides,
       ROUND(100.0*(rides-previous_day_rides)/NULLIF(previous_day_rides,0),2) AS rides_change_vs_previous_day_pct
FROM flagged ORDER BY disruption_share DESC;

-- Question 90: What recommendations on pricing, timetable or capacity follow from the data?
SELECT "Ticket Type", "Ticket Class", COUNT(*) AS tickets,
       AVG("Price") AS average_price, SUM("Price") AS revenue,
       ROUND(100.0*COUNT(*) FILTER (WHERE "Journey Status" IN ('Delayed','Cancelled'))/COUNT(*),2) AS disruption_rate_pct,
       ROUND(100.0*COUNT(*) FILTER (WHERE "Refund Request"='Yes')/COUNT(*),2) AS refund_rate_pct
FROM railway_clean GROUP BY 1,2 ORDER BY revenue DESC;

-- Question 91: Which stations should be prioritised for staffing or infrastructure investment?
SELECT station, SUM(affected_tickets) AS disrupted_tickets,
       string_agg(DISTINCT reason, ', ' ORDER BY reason) AS observed_reasons
FROM (
 SELECT "Departure Station" AS station,
        CASE WHEN "Reason for Delay" IN ('Weather','Weather Conditions') THEN 'Weather'
             WHEN "Reason for Delay" IN ('Staffing','Staff Shortage') THEN 'Staffing'
             ELSE "Reason for Delay" END AS reason,
        COUNT(*) AS affected_tickets
 FROM railway_clean WHERE "Journey Status" IN ('Delayed','Cancelled') GROUP BY 1,2
 UNION ALL
 SELECT "Arrival Destination",
        CASE WHEN "Reason for Delay" IN ('Weather','Weather Conditions') THEN 'Weather'
             WHEN "Reason for Delay" IN ('Staffing','Staff Shortage') THEN 'Staffing'
             ELSE "Reason for Delay" END,
        COUNT(*)
 FROM railway_clean WHERE "Journey Status" IN ('Delayed','Cancelled') GROUP BY 1,2
) x GROUP BY station ORDER BY disrupted_tickets DESC;
