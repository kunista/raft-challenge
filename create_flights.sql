CREATE TABLE IF NOT EXISTS flights (
    callsign        VARCHAR(20),
    number          VARCHAR(20),
    icao24          VARCHAR(20),
    registration    VARCHAR(20),
    typecode        VARCHAR(20),
    origin          VARCHAR(4),
    destination     VARCHAR(4),
    firstseen       TIMESTAMP NOT NULL,
    lastseen        TIMESTAMP NOT NULL,
    day             DATE NOT NULL,
    latitude_1      DOUBLE,
    longitude_1     DOUBLE,
    altitude_1      DOUBLE,
    latitude_2      DOUBLE,
    longitude_2     DOUBLE,
    altitude_2      DOUBLE
);