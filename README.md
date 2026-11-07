# Retail Sales & Customer Intelligence (PostgreSQL)

SQL analysis of Duka Smart Electronics, a Kenyan retailer with 150 customers and 800 orders (January 2025 to September 2026). The project answers 46 business questions, from simple SELECTs to window functions, a view and a PL/pgSQL function, and ends with written insights for management.

## Files
| File | What it is |
|---|---|
| `schema.sql` | CREATE TABLE statements for `customers` and `orders` |
| `queries.sql` | All 46 answers, each under a `-- Q1` ... `-- Q46` comment |
| `insights.md` | Seven business insights with numbers and recommendations |
| `screenshots/` | Output of `05_verify_data.sql` and a few key results |

## Set up
1. Install PostgreSQL and open `psql` (or pgAdmin).
2. Connected to the `postgres` database, run `01_create_database.sql`.
3. Connected to `retail_analytics`, run `02_create_tables.sql` (or `schema.sql`), then `03_insert_customers.sql`, `04_insert_orders.sql` and `05_verify_data.sql`. The check should show 150 customers and 800 orders.
4. Run the answers: `psql -U postgres -d retail_analytics -f queries.sql`

## Business rules
- Revenue = `quantity * unit_price * (1 - discount / 100)`; cost = `quantity * cost_price`; profit = revenue - cost.
- Money questions use `Completed` orders only; order counts include every status.
- "Today" is `MAX(order_date)`, not the computer's date.
- Months use `DATE_TRUNC('month', order_date)`.

## Choices I made where a question was open
- Q18 counts units on completed orders. Q28 defines "popular" as number of orders.
- Q27 averages each purchasing customer's total per segment.
- Q45 thresholds are KSh 300,000 (High) and KSh 100,000 (Medium), explained in the file.
- Stretch: a monthly cohort-retention table is at the end of `queries.sql` (cohort = month of first completed order).
