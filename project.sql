-- A. Business question: How many days has it been since each customers' last rental?

-- B. Transformation Function: 

--CREATE OR REPLACE FUNCTION last_update_mod()

-- Create LastRentalTimeSummary table

DROP TABLE IF EXISTS last_rental_time_summary;
CREATE TABLE last_rental_time_summary (
    customer_id SMALLINT,
    rental_id INTEGER,
    days_since_last_rental SMALLINT,
    PRIMARY KEY (customer_id, rental_id)
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
    PRIMARY KEY (customer_id, rental_id)
);

-- Calculate number of days since rental's timestamp

CREATE OR REPLACE FUNCTION calculate_days(rental_date TIMESTAMP)
RETURNS SMALLINT AS $$
DECLARE
    days_difference SMALLINT;
BEGIN
    days_difference := CAST(CURRENT_DATE - rental_date::DATE AS SMALLINT);
    RETURN days_difference;
END;
$$ LANGUAGE plpgsql;

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

-- Trigger function 

CREATE OR REPLACE FUNCTION copy_changes_to_summary()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO last_rental_time_summary (customer_id, rental_id, days_since_last_rental)
    VALUES (NEW.customer_id, NEW.rental_id, NEW.days_since_last_rental)
    ON CONFLICT (customer_id, rental_id) -- If the row already exists, update it
    DO UPDATE SET
        days_since_last_rental = EXCLUDED.days_since_last_rental;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Clear both tables' data and insert original data from dvdrental database
CREATE OR REPLACE PROCEDURE refresh_data() AS $$
BEGIN 
    DROP TABLE last_rental_time_summary;
    DROP TABLE last_rental_time_detailed;
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
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER copy_changes_summary
AFTER INSERT OR UPDATE ON last_rental_time_detailed
FOR EACH ROW
EXECUTE FUNCTION copy_changes_to_summary();

DROP TRIGGER IF EXISTS copy_changes_summary ON last_rental_time_detailed;
DROP FUNCTION IF EXISTS copy_changes_to_summary();
DROP FUNCTION IF EXISTS calculate_days;
DROP TABLE IF EXISTS last_rental_time_summary;
DROP TABLE IF EXISTS last_rental_time_detailed;
DROP PROCEDURE IF EXISTS refresh_data;