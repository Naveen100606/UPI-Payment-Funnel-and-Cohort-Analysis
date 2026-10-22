# UPI Payment Funnel, Failure Analysis & User Retention

## Project Overview

This project studies a fictional Indian UPI payment app. The question is simple: why do some initiated payments remain unsuccessful, and what could help users complete a payment and return? The dataset is **synthetic**, generated with NumPy using seed 42. It contains no real customer or provider records. PDM is not assumed to mean Paytm or any other company.

## Business Questions

- How often do initiated payments succeed, and where does the funnel lose attempts?
- Which confirmed failure reasons and segments deserve investigation?
- How often do users retry and complete a payment?
- Who makes successful payments in later weeks?
- How does later participation differ after a successful versus failed first attempt?
- What product change should be tested, and how would success be measured?

## Dataset

| File | Rows | Observation unit |
|---|---:|---|
| users.csv | 8,000 | Registered user, signup date, device, city tier and acquisition channel |
| payment_attempts.csv | 24,268 | Initiated attempt, session, bank, amount in INR, outcome, reason, version and UPI method |
| payment_events.csv | 108,881 | An event that actually occurred in an attempt |

Activity covers January–June 2026, with an exclusive July 1 observation cutoff. All timestamps are local IST. Banks A–D are fictional. The simulation varies bank reliability, authentication outcomes, transaction amounts and time of day. Some users never initiate a payment. Failed attempts may receive one immediate retry. Later session continuation depends on the previous outcome, so usage gaps reflect simulation assumptions. Unresolved pending outcomes occur only in the last 48 hours. The notebook documents the exact probabilities and generation logic.

## Methodology

One sequential notebook loads the CSVs, validates relationships and event order, and calculates an attempt-level funnel. Confirmed failures, pending outcomes and abandonment remain separate. Reliability comparisons use failed / (successful + failed), with sample sizes. Segment tables cover first versus later attempts, device, city tier, bank and amount.

Eight SQLite queries cover daily success, bank reliability, device conversion, failure reasons, first success, weekly activity, retries and bank ranking. Key SQL results are compared with Pandas in simple tables. Cohorts start in the Monday calendar week of first success. Only fully observed future calendar weeks enter retention denominators. First-attempt participation compares eligible users over the next 30 days, excluding the original attempt.

The approach builds on my [Zomato analysis](https://github.com/RajBhumarkar/Zomato-Consumer-Funnel-Cohort-Analysis) and [Cookie Cats experiment project](https://github.com/RajBhumarkar/Statistical-A-B-Test-Analysis-Cookie-Cats-Mobile-Game): readable groupby summaries, pivot tables and short observations. Payment-specific outcome handling, ordered-stage validation, retry identification and observation-window checks are redesigned.

## Key Findings

| Metric | Result |
|---|---:|
| Successful / all initiated attempts | 77.73% |
| Failed / resolved success-or-failure outcomes | 13.68% |
| Pending / all attempts | 0.02% |
| Abandoned / all attempts | 9.93% |
| Week 1 retention, eligible-user weighted | 23.15% |
| Week 4 retention, eligible-user weighted | 15.91% |
| 30-day later participation, successful-first users | 58.78% |
| 30-day later participation, failed-first users | 57.61% |

The largest absolute funnel loss occurs entering `payment_successful`: 1,736 attempts. The largest relative loss occurs entering `payment_successful`: 8.43% of the preceding stage. Funnel loss is not automatically abandonment or bank failure.

The largest confirmed-failure category is **authentication failure**, with 1,253 attempts. Bank D has the highest overall resolved failure rate, 18.26%. Bank volume alone does not explain reliability. These patterns follow fictional probabilities, not real-bank evidence.

## Product Recommendation

Test clearer confirmed-failure guidance and safe recovery options for the largest failure category. Explain the documented outcome and appropriate next step. Check status before another payment; pending users should receive status checking and support. Better guidance may reduce confusion, but cannot fix provider outages.

Randomize affected users 50/50 at their first eligible confirmed failure. Compare the percentage making a successful payment within 24 hours, using all randomized eligible users. Track 30-day participation secondarily. Guard against duplicate debits, pending incidents, support demand and slower payments. Pre-register sample size, a 3-point minimum detectable difference and a fixed readout. The notebook specifies shipping criteria and guardrail margins. This is a proposal, not a completed experiment.

## Visualizations

![Payment funnel](outputs/payment_funnel.png)
![Failure analysis](outputs/failure_analysis.png)
![Weekly retention](outputs/retention_heatmap.png)
![Segment comparison](outputs/segment_comparison.png)

## Tools Used

Python, Pandas, NumPy, SQLite through sqlite3, Matplotlib, Seaborn and Jupyter. No machine learning, backend or dashboard is needed.

## Repository Structure

```text
UPI-Payment-Product-Analytics/
├── data/
│   ├── users.csv
│   ├── payment_attempts.csv
│   └── payment_events.csv
├── outputs/
│   ├── payment_funnel.png
│   ├── failure_analysis.png
│   ├── retention_heatmap.png
│   └── segment_comparison.png
├── payment_product_analytics.ipynb
├── analysis_queries.sql
├── README.md
├── INTERVIEW_GUIDE.md
└── requirements.txt
```

## Limitations

Synthetic transaction behaviour cannot validate real payment-provider reliability. Comparisons are observational, with differing user mixes and repeated attempts per user. Retry identity is a session/time/amount proxy. Pending outcomes use a simplified snapshot. Weekly inactivity does not prove permanent churn. No feature was deployed and no experimental impact was measured.

## How to Run

Use Python 3.11 or later. From the extracted project folder:

```bash
python -m venv .venv
# Windows: .venv\Scripts\activate
# macOS/Linux: source .venv/bin/activate
python -m pip install -r requirements.txt
python -m jupyterlab payment_product_analytics.ipynb
```

Choose the environment's Python kernel, then **Restart Kernel and Run All**. Existing CSVs load by default. Set `REGENERATE = True` to reproduce them; return it to False afterward. Outputs are saved automatically. Inspection tables cover missing values, duplicates, event order, linked IDs and SQL/Pandas agreement. Retention excludes incomplete weeks. See `INTERVIEW_GUIDE.md` for a plain-English walkthrough.
