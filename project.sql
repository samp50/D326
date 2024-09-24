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
    customer_id SMALLINT,
    store_id SMALLINT,
    create_date TIMESTAMP,
    rental_id INTEGER,
    rental_date TIMESTAMP,
    return_date TIMESTAMP,
    days_since_last_rental SMALLINT,
    last_update TIMESTAMP
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

-- Insert data into LastRentalTimeDetailed

INSERT INTO last_rental_time_detailed (customer_id, store_id, create_date, rental_id, rental_date, return_date, days_since_last_rental)
SELECT
    c.customer_id,
    c.store_id,
    c.create_date,
    r.rental_id,
    r.rental_date,
    r.return_date,
    calculate_days(rental_date)
    --EXTRACT(DAY FROM CURRENT_DATE - r.rental_date)::INTEGER AS days_since_last_rental
    --CURRENT_DATE AS last_update -- edited this so that last_update field is only updated after calling trigger
FROM
    customer c
JOIN
    rental r ON c.customer_id = r.customer_id
WHERE
    r.rental_date = (
        SELECT MAX(r2.rental_date)
        FROM rental r2
        WHERE r2.customer_id = c.customer_id
    );

-- Create trigger that updates last_rental_time_detailed last_update field with present time
/*
CREATE TRIGGER update_last_update AFTER INSERT ON last_rental_time_detailed
FOR EACH ROW
BEGIN
    UPDATE last_rental_time_detailed
    SET last_update = CURRENT_DATE
    WHERE customer_id = NEW.customer_id;
END
*/
-- Create custom transformation that formats raw timestamp difference into number of days

CREATE OR REPLACE FUNCTION calculate_days(rental_date TIMESTAMP)
RETURNS SMALLINT AS $$
DECLARE
    days_difference SMALLINT;
BEGIN
    -- Calculate the number of days since the rental_date (ignoring time part)
    days_difference := CAST(CURRENT_DATE - rental_date::DATE AS SMALLINT);
    RETURN days_difference;
END;
$$ LANGUAGE plpgsql;