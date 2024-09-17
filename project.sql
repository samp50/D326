-- A. Business question: How many days has it been since each customers' last rental?

-- B. Transformation Function: 

--CREATE OR REPLACE FUNCTION last_update_mod()

-- Create LastRentalTimeSummary table

DROP TABLE IF EXISTS last_rental_time_summary;
CREATE TABLE last_rental_time_summary (
    customer_id SMALLINT,
    rental_id INTEGER,
    days_since_last_rental SMALLINT
);

-- Create LastRentalTimeDetailed table

DROP TABLE IF EXISTS last_rental_time_detailed;
CREATE TABLE last_rental_time_detailed (
    customer_id SMALLINT;
    store_id SMALLINT;
    create_date TIMESTAMP;
    rental_id INTEGER;
    rental_date TIMESTAMP;
    return_date TIMESTAMP;
    days_since_last_rental SMALLINT;
    last_update TIMESTAMP;
);

-- Insert data into LastRentalTimeSummary table

INSERT INTO last_rental_time_summary (customer_id, rental_id, days_since_last_rental)
SELECT 
    customer.customer_id, 
    latest_rentals.rental_id, 
    EXTRACT(DAY FROM CURRENT_DATE - latest_rentals.rental_date)::INTEGER AS days_since_last_rental
FROM customer
JOIN (
    SELECT 
        rental.customer_id, 
        rental.rental_id, 
        rental.rental_date
    FROM rental
    JOIN (
        SELECT customer_id, MAX(rental_date) AS latest_rental_date
        FROM rental
        GROUP BY customer_id
    ) AS latest_rental_dates
    ON rental.customer_id = latest_rental_dates.customer_id
    AND rental.rental_date = latest_rental_dates.latest_rental_date
) AS latest_rentals
ON customer.customer_id = latest_rentals.customer_id;

