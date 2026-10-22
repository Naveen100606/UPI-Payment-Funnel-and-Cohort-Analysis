-- 1. Daily attempt success, pending and abandonment shares
SELECT date(attempt_timestamp) AS day, COUNT(*) AS attempts,
       100.0 * SUM(CASE WHEN payment_status = 'success' THEN 1 ELSE 0 END) / COUNT(*) AS success_pct,
       100.0 * SUM(CASE WHEN payment_status = 'pending' THEN 1 ELSE 0 END) / COUNT(*) AS pending_pct,
       100.0 * SUM(CASE WHEN payment_status = 'abandoned' THEN 1 ELSE 0 END) / COUNT(*) AS abandoned_pct
FROM payment_attempts GROUP BY day ORDER BY day;

-- 2. Bank reliability: resolved outcomes are the denominator
SELECT bank_name, COUNT(*) AS attempts,
       SUM(CASE WHEN payment_status IN ('success','failed') THEN 1 ELSE 0 END) AS resolved,
       100.0 * SUM(CASE WHEN payment_status = 'failed' THEN 1 ELSE 0 END) /
       NULLIF(SUM(CASE WHEN payment_status IN ('success','failed') THEN 1 ELSE 0 END), 0) AS failure_pct
FROM payment_attempts GROUP BY bank_name ORDER BY failure_pct DESC;

-- 3. Device conversion with signup attributes joined to attempts
SELECT u.device_type, COUNT(*) AS attempts, COUNT(DISTINCT p.user_id) AS users,
       100.0 * SUM(CASE WHEN p.payment_status = 'success' THEN 1 ELSE 0 END) / COUNT(*) AS success_pct
FROM payment_attempts p JOIN users u ON p.user_id = u.user_id
GROUP BY u.device_type ORDER BY u.device_type;

-- 4. Confirmed failure reasons only
SELECT failure_reason, COUNT(*) AS failures,
       100.0 * COUNT(*) / (SELECT COUNT(*) FROM payment_attempts WHERE payment_status = 'failed') AS share_of_failures_pct
FROM payment_attempts WHERE payment_status = 'failed'
GROUP BY failure_reason ORDER BY failures DESC;

-- 5. First successful payment: failed-only users have no row
SELECT user_id, MIN(attempt_timestamp) AS first_success
FROM payment_attempts WHERE payment_status = 'success' GROUP BY user_id ORDER BY user_id;

-- 6. Weekly successful activity and users with at least two successes in that calendar week
WITH user_week AS (
    SELECT user_id, date(attempt_timestamp, '-6 days', 'weekday 1') AS week_start, COUNT(*) AS successes
    FROM payment_attempts WHERE payment_status = 'success' GROUP BY user_id, week_start
)
SELECT week_start, COUNT(*) AS successful_users,
       SUM(CASE WHEN successes >= 2 THEN 1 ELSE 0 END) AS users_with_multiple_successes
FROM user_week GROUP BY week_start ORDER BY week_start;

-- 7. Retry proxy independently derived with LAG, not the Pandas is_retry field
WITH previous_attempt AS (
    SELECT *, LAG(payment_status) OVER w AS previous_status,
           LAG(attempt_timestamp) OVER w AS previous_time,
           LAG(session_id) OVER w AS previous_session,
           LAG(bank_name) OVER w AS previous_bank,
           LAG(payment_amount) OVER w AS previous_amount,
           LAG(payment_method) OVER w AS previous_method
    FROM payment_attempts
    WINDOW w AS (PARTITION BY user_id ORDER BY attempt_timestamp, attempt_id)
)
SELECT attempt_id, user_id, payment_status FROM previous_attempt
WHERE previous_status = 'failed' AND session_id = previous_session
  AND bank_name = previous_bank AND payment_amount = previous_amount AND payment_method = previous_method
  AND julianday(attempt_timestamp) > julianday(previous_time)
  AND (julianday(attempt_timestamp) - julianday(previous_time)) * 1440 <= 30
ORDER BY attempt_id;

-- 8. Rank sufficiently observed banks by resolved failure rate
WITH bank_rates AS (
    SELECT bank_name, COUNT(*) AS resolved,
           100.0 * SUM(CASE WHEN payment_status = 'failed' THEN 1 ELSE 0 END) / COUNT(*) AS failure_pct
    FROM payment_attempts WHERE payment_status IN ('success','failed')
    GROUP BY bank_name HAVING COUNT(*) >= 100
)
SELECT *, DENSE_RANK() OVER (ORDER BY failure_pct DESC) AS failure_rank
FROM bank_rates ORDER BY failure_rank, bank_name;
