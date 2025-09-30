CREATE TABLE IF NOT EXISTS flight_metrics (
    id INT PRIMARY KEY DEFAULT 1,
    row_count BIGINT,
    last_transponder_seen_at DATETIME,
    count_of_unique_transponders BIGINT,
    most_popular_destination VARCHAR(50),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);