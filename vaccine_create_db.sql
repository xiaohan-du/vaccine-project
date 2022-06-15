-- THIS SCRIPT ONLY WORKS FOR YEAR 2022! Assume 2022-01-01 is a Monday. 

SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
/* Determines whether InnoDB performs duplicate key checks.
Import is much faster for large data sets if this check is not performed.
If set to 1 (the default), uniqueness checks for secondary indexes in
InnoDB tables are performed. If set to 0, storage engines are permitted to assume
that duplicate keys are not present in input data. If you know for certain that
your data does not contain uniqueness violations, you can set this to 0 to speed
up large table imports to InnoDB.
Setting this variable to 0 does not require storage engines to ignore duplicate keys.
An engine is still permitted to check for them and issue duplicate-key errors
if it detects them.
https://dev.mysql.com/doc/refman/5.7/en/server-system-variables.html#sysvar_unique_checks */


SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
/* Determines whether the server should check that a referenced table exists when
 defining a foreign key. Due to potential circular references, this check must
 be turned off for the duration of the import, to permit defining foreign keys.
 If set to 1 (the default), foreign key constraints for InnoDB tables are checked.
 https://dev.mysql.com/doc/refman/5.7/en/server-system-variables.html#sysvar_unique_checks*/

SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='ALLOW_INVALID_DATES';
/* Sets SQL_MODE to TRADITIONAL, causing the server to operate in a more restrictive mode,
and ALLOW_INVALID_DATES, causing dates to not be fully validated.
https://dev.mysql.com/doc/refman/5.7/en/sql-mode.html#sqlmode_traditional */

SET SQL_SAFE_UPDATES = 0;

DROP DATABASE IF EXISTS vaccineDB;

CREATE DATABASE IF NOT EXISTS vaccineDB;

USE vaccineDB;

-- create tables
CREATE TABLE `NHS` (
	`UserID` VARCHAR(36) NOT NULL UNIQUE,
	`NhsNumber` BIGINT UNIQUE,
    `FirstName` VARCHAR(45),
    `LastName` VARCHAR(45),
    `DateOfBirth` DATE,
    `Address1` VARCHAR(45),
    `Address2` VARCHAR(45),
    `City` VARCHAR(45),
    `Postcode` VARCHAR(45),
    `Phone` VARCHAR(45),
    CONSTRAINT `PK_NHS` PRIMARY KEY (`UserID`)
);

CREATE TABLE `Vaccines` (
	`VaccineID` VARCHAR(36) NOT NULL UNIQUE,
    `VaccineName` ENUM('Pfizer/BioNTech', 'Oxford/AstraZeneca', 'Moderna'),
    `VaccineType` VARCHAR(15),
    `VaccineManufacturer` VARCHAR(45),
    `VaccineQuantity` INT,
    `VaccineQuantityRecord` INT,
    CONSTRAINT `PK_Vaccines` PRIMARY KEY (`VaccineID`)
);

-- temp table which has 'AppointmentTime' column as dummy data.
CREATE TABLE `Appointments` (
	`AppointmentID` VARCHAR(36) NOT NULL UNIQUE,
    `AppointmentDate` DATE,
    `AppointmentTime` TIME,
    `Users_NhsNumber` BIGINT,
    `Centres_CentreID` VARCHAR(36), 
    `Vaccines_VaccineID` VARCHAR(36),
    CONSTRAINT `PK_Appointments` PRIMARY KEY (`AppointmentID`)
);

-- main table same as Appointments with additional column: 'UpdatedTime' to store the real appointment time.
CREATE TABLE `AppointmentsUpdated` (
	`AppointmentID` VARCHAR(36) NOT NULL UNIQUE,
    `AppointmentDate` DATE,
    `AppointmentTime` TIME,
    `Users_NhsNumber` BIGINT,
    `Centres_CentreID` VARCHAR(36), 
    `Vaccines_VaccineID` VARCHAR(36),
    `UpdatedTime` TIME,
    CONSTRAINT `PK_Appointments` PRIMARY KEY (`AppointmentID`)
);

CREATE TABLE `Appointment_Status` (
	`AppointmentID` VARCHAR(36) NOT NULL UNIQUE,
    `AppointmentFulfilled` ENUM('fulfilled', 'noshow', 'cancelled'),
    `Rejected` ENUM('yes', 'no'),
    `RejectReason` TEXT,
    CONSTRAINT `PK_Appointment_Status` PRIMARY KEY (`AppointmentID`)
);

CREATE TABLE `Capacities` (
	`CapacityID` VARCHAR(36) NOT NULL UNIQUE,
    `WeekDay` VARCHAR(15) NOT NULL,
    `StartTime` TIME,
    `EndTime` TIME,
    `Capacity` INT,
    `CapacityRecord` INT, 
    `Centres_CentreID` VARCHAR(36),
    CONSTRAINT `PK_Capacities` PRIMARY KEY (`CapacityID`)
);

CREATE TABLE `WeeklyCapacities` (
	`WeeklyCapacityID` VARCHAR(36) NOT NULL UNIQUE,
    `WeekNumber` INT,
	`IsFull` ENUM('yes', 'no'),
    `Centres_CentreID` VARCHAR(36) NOT NULL,
    CONSTRAINT `PK_WeeklyCapacity` PRIMARY KEY (`WeeklyCapacityID`)
);

CREATE TABLE `Centres` (
	`CentreID` VARCHAR(36) NOT NULL UNIQUE,
    `CentreName` VARCHAR(45),
    `Address1` VARCHAR(45),
    `Address2` VARCHAR(45), 
    `City` VARCHAR(45),
    `Postcode` VARCHAR(45),
    CONSTRAINT `PK_Centres` PRIMARY KEY (`CentreID`)
);

CREATE TABLE `OpeningTime` (
	`OpeningTimeID` VARCHAR(36) NOT NULL UNIQUE,
	`WeekDay` ENUM('0', '1', '2', '3', '4', '5', '6'),
    `OpenTime` TIME,
    `CloseTime` TIME,
    `FullTime` ENUM('yes', 'no'),
    `OpenOnTheDay` ENUM('yes', 'no'),
    `Centres_CentreID` VARCHAR(36),
    CONSTRAINT `PK_OpeningTime` PRIMARY KEY (`OpeningTimeID`)
);

CREATE TABLE `Centres_has_Vaccines` (
	`ID` VARCHAR(36) NOT NULL UNIQUE,
    `Centres_CentreID` VARCHAR(36),
    `Vaccines_VaccineID` VARCHAR(36),
    `WeekDay` INT,
    CONSTRAINT `PK_Centres_has_Vaccines` PRIMARY KEY (`ID`)
);

CREATE TABLE `NumberToWeekdayString` (
	`NumberToWeekdayStringID` VARCHAR(36) NOT NULL UNIQUE,
    `Number` INT,
    `WeekdayString` ENUM('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday')
);
-- create tables end

-- create assisting functions
DROP FUNCTION IF EXISTS getMarkSeparatedLength;
DELIMITER //
CREATE FUNCTION getMarkSeparatedLength(inp VARCHAR(1000), mark VARCHAR(1))
RETURNS INT
BEGIN
	RETURN(
		LENGTH(inp) - LENGTH(REPLACE(inp, mark, '')) + 1
    );
END//
DELIMITER ;

DROP FUNCTION IF EXISTS getCentreId;
DELIMITER //
CREATE FUNCTION getCentreId(centreName VARCHAR(45))
RETURNS VARCHAR(36)
BEGIN
    RETURN(
		SELECT Centres.CentreID FROM Centres WHERE Centres.CentreName = centreName
	); 
END//
DELIMITER ;

DROP FUNCTION IF EXISTS getVaccineId;
DELIMITER //
CREATE FUNCTION getVaccineId(vaccineName ENUM('Pfizer/BioNTech', 'Oxford/AstraZeneca', 'Moderna'))
RETURNS VARCHAR(36)
BEGIN
    RETURN(
		SELECT Vaccines.VaccineID FROM Vaccines WHERE Vaccines.VaccineName = vaccineName
	); 
END//
DELIMITER ;

-- 0 = Monday, 1 = Tuesday, ......
DROP FUNCTION IF EXISTS getWeekDay;
DELIMITER //
CREATE FUNCTION getWeekDay(day INT, centreName VARCHAR(45))
RETURNS ENUM('0', '1', '2', '3', '4', '5', '6')
BEGIN
	RETURN(
		SELECT OpeningTime.WeekDay FROM OpeningTime WHERE WeekDay = day AND Centres_CentreID = (getCentreId(centreName))
    );
END//
DELIMITER ;
-- create assisting functions end

-- issue 3 Users - basic user info should be recorded
TRUNCATE TABLE NHS;
INSERT INTO NHS VALUES(UUID(), 7260000001, 'Wilmot', 'Barnes', '1991-12-31', '25 Oatlands Chase', 'Surrey', 'Weybridge', 'KT13 9RW', '07741740991 ');
INSERT INTO NHS VALUES(UUID(), 7260000002, 'Olivia', 'Adkins', '2001-01-12', '29 Echline Park', 'West Lothian council', 'South Queensferry', 'EH30 9XQ', '07748274199 ');
INSERT INTO NHS VALUES(UUID(), 7260000003, 'Norris', 'Wade', '1989-02-25', 'Ston Easton', 'Somerset', 'Bath', 'BA3 4DF', '01761241631 ');
INSERT INTO NHS VALUES(UUID(), 7260000004, 'Andy', 'Butler', '1992-04-06', 'Lower Stockbridge Farm', 'Dorset', 'Weybridge', 'KT13 9RW', '07741740991 ');
INSERT INTO NHS VALUES(UUID(), 7260000005, 'Jeremy', 'Evans', '1976-11-09', '20 Saville Row', '', 'Tyne and Wear', 'NE1 8JE', '01912602227 ');
INSERT INTO NHS VALUES(UUID(), 7260000006, 'Helen', 'King', '1993-02-14', '10-12 Dunford Rd', 'West Yorkshire', 'Holmfirth', 'HD9 1HN', '01484687575 ');
INSERT INTO NHS VALUES(UUID(), 7260000007, 'Grant', 'Watson', '1995-04-14', '22 Market Pl', 'South Yorkshire', 'Doncaster', 'DN1 1ND', '01403782311 ');
INSERT INTO NHS VALUES(UUID(), 7260000008, 'Selina', 'Kennedy', '1988-05-28', '26 Birmingham Rd', '	West Midlands', 'Birmingham', 'B43 6NR', '01213586820 ');
-- issue 3 ends

TRUNCATE TABLE NumberToWeekdayString;
INSERT INTO NumberToWeekdayString VALUES (UUID(), 0, 'Monday');
INSERT INTO NumberToWeekdayString VALUES (UUID(), 1, 'Tuesday');
INSERT INTO NumberToWeekdayString VALUES (UUID(), 2, 'Wednesday');
INSERT INTO NumberToWeekdayString VALUES (UUID(), 3, 'Thursday');
INSERT INTO NumberToWeekdayString VALUES (UUID(), 4, 'Friday');
INSERT INTO NumberToWeekdayString VALUES (UUID(), 5, 'Saturday');
INSERT INTO NumberToWeekdayString VALUES (UUID(), 6, 'Sunday');

TRUNCATE TABLE Vaccines;
INSERT INTO Vaccines VALUES (UUID(), 'Pfizer/BioNTech', 'mRNA', 'Pfizer', 2, 2);
INSERT INTO Vaccines VALUES (UUID(), 'Oxford/AstraZeneca', 'viral vector', 'AstraZeneca Plc', 3, 3);
INSERT INTO Vaccines VALUES (UUID(), 'Moderna', 'mRNA', 'Moderna, Inc', 2, 2);

TRUNCATE TABLE Centres;
INSERT INTO Centres VALUES(UUID(), 'Bayside MVC', 'Olympian Dr', NULL, 'Cardiff', 'CF11 0JS');
INSERT INTO Centres VALUES(UUID(), 'Splott MVC', 'Cardiff and Vale Therapy Centre', 'Splott Road', 'Cardiff', 'CF24 2BZ');
INSERT INTO Centres VALUES(UUID(), 'Barry MVC', 'Holm View Leisure Centre', 'Skomer Road', 'Cardiff', 'CF62 9DA');

-- issue 5 Centres - a centre should have default opening time
-- issue 12 Centres - some centres should have their own opening time
TRUNCATE TABLE OpeningTime;
INSERT INTO OpeningTime VALUES(UUID(), 1, '08:00:00', '24:00:00', 0, 1, (SELECT Centres.CentreID FROM Centres WHERE CentreName = 'Bayside MVC'));
INSERT INTO OpeningTime VALUES(UUID(), 2, NULL, NULL, 1, 1, (SELECT Centres.CentreID FROM Centres WHERE CentreName = 'Bayside MVC'));
INSERT INTO OpeningTime VALUES(UUID(), 3, NULL, NULL, 1, 1, (SELECT Centres.CentreID FROM Centres WHERE CentreName = 'Bayside MVC'));
INSERT INTO OpeningTime VALUES(UUID(), 4, NULL, NULL, 1, 1, (SELECT Centres.CentreID FROM Centres WHERE CentreName = 'Bayside MVC'));
INSERT INTO OpeningTime VALUES(UUID(), 5, NULL, NULL, 1, 1, (SELECT Centres.CentreID FROM Centres WHERE CentreName = 'Bayside MVC'));
INSERT INTO OpeningTime VALUES(UUID(), 6, '08:00:00', '24:00:00', 0, 1, (SELECT Centres.CentreID FROM Centres WHERE CentreName = 'Bayside MVC'));
INSERT INTO OpeningTime VALUES(UUID(), 7, '08:00:00', '24:00:00', 0, 1, (SELECT Centres.CentreID FROM Centres WHERE CentreName = 'Bayside MVC'));
INSERT INTO OpeningTime VALUES(UUID(), 1, '08:00:00', '22:00:00', 0, 1, (SELECT Centres.CentreID FROM Centres WHERE CentreName = 'Splott MVC'));
INSERT INTO OpeningTime VALUES(UUID(), 2, '08:00:00', '22:00:00', 0, 1, (SELECT Centres.CentreID FROM Centres WHERE CentreName = 'Splott MVC'));
INSERT INTO OpeningTime VALUES(UUID(), 3, '08:00:00', '22:00:00', 0, 1, (SELECT Centres.CentreID FROM Centres WHERE CentreName = 'Splott MVC'));
INSERT INTO OpeningTime VALUES(UUID(), 4, '08:00:00', '22:00:00', 0, 1, (SELECT Centres.CentreID FROM Centres WHERE CentreName = 'Splott MVC'));
INSERT INTO OpeningTime VALUES(UUID(), 5, '08:00:00', '22:00:00', 0, 1, (SELECT Centres.CentreID FROM Centres WHERE CentreName = 'Splott MVC'));
INSERT INTO OpeningTime VALUES(UUID(), 6, NULL, NULL, 0, 0, (SELECT Centres.CentreID FROM Centres WHERE CentreName = 'Splott MVC'));
INSERT INTO OpeningTime VALUES(UUID(), 7, NULL, NULL, 0, 0, (SELECT Centres.CentreID FROM Centres WHERE CentreName = 'Splott MVC'));
INSERT INTO OpeningTime VALUES(UUID(), 1, NULL, NULL, 0, 0, (SELECT Centres.CentreID FROM Centres WHERE CentreName = 'Barry MVC'));
INSERT INTO OpeningTime VALUES(UUID(), 2, '06:00:00', '18:00:00', 0, 1, (SELECT Centres.CentreID FROM Centres WHERE CentreName = 'Barry MVC'));
INSERT INTO OpeningTime VALUES(UUID(), 3, '06:00:00', '18:00:00', 0, 1, (SELECT Centres.CentreID FROM Centres WHERE CentreName = 'Barry MVC'));
INSERT INTO OpeningTime VALUES(UUID(), 4, '06:00:00', '20:00:00', 0, 1, (SELECT Centres.CentreID FROM Centres WHERE CentreName = 'Barry MVC'));
INSERT INTO OpeningTime VALUES(UUID(), 5, NULL, NULL, 1, 1, (SELECT Centres.CentreID FROM Centres WHERE CentreName = 'Barry MVC'));
INSERT INTO OpeningTime VALUES(UUID(), 6, '06:00:00', '20:00:00', 0, 1, (SELECT Centres.CentreID FROM Centres WHERE CentreName = 'Barry MVC'));
INSERT INTO OpeningTime VALUES(UUID(), 7, NULL, NULL, 0, 0, (SELECT Centres.CentreID FROM Centres WHERE CentreName = 'Barry MVC'));
-- issue 5 and 12 end

-- issue 9 Capacities - a centre should have its capacity for a certain time of the day
DROP PROCEDURE IF EXISTS insertCapacityIntoADay;
DELIMITER //
CREATE PROCEDURE insertCapacityIntoADay(capacities LONGTEXT, weekday INT, centreName VARCHAR(45))
BEGIN
	DECLARE startTime VARCHAR(90);
    DECLARE endTime VARCHAR(90);
    DECLARE capacity VARCHAR(90);
    DECLARE maxIterations INT;
    DECLARE i INT;
    SET maxIterations = (SELECT getMarkSeparatedLength(capacities, ','));
    SET i = 1;
    
	loop_label: LOOP
		IF i > maxIterations THEN
		  LEAVE loop_label;
		END IF;
        SET startTime = (SELECT SUBSTRING_INDEX(SUBSTRING_INDEX(capacities, ",", i), ',', -1));
        SET endTime = (SELECT SUBSTRING_INDEX(SUBSTRING_INDEX(capacities, ",", i + 1), ',', -1));
        SET capacity = (SELECT SUBSTRING_INDEX(SUBSTRING_INDEX(capacities, ",", i + 2), ',', -1));
        INSERT INTO Capacities VALUES(UUID(), (getWeekDay(weekday, centreName)), startTime, endTime, capacity, capacity, getCentreId(centreName));
        SET i = i + 3;         
        ITERATE loop_label;
	END LOOP loop_label;
END//
DELIMITER ;

TRUNCATE TABLE Capacities;
SET @bayCapacityMon = '08:00:00, 08:59:59, 7, 09:00:00, 23:59:59, 2';
SET @bayCapacityTueToFri = '00:00:00, 07:59:59, 2, 08:00:00, 23:59:59, 5';
SET @bayCapacitySatToSun = '08:00:00, 09:59:59, 9, 10:00:00, 23:59:59, 2';
SET @splottCapacityMonToFri = '08:00:00, 11:59:59, 5, 12:00:00, 21:59:59, 2';
CALL insertCapacityIntoADay(@bayCapacityMon, 1, 'Bayside MVC');
CALL insertCapacityIntoADay(@bayCapacityTueToFri, 2, 'Bayside MVC');
CALL insertCapacityIntoADay(@bayCapacityTueToFri, 3, 'Bayside MVC');
CALL insertCapacityIntoADay(@bayCapacityTueToFri, 4, 'Bayside MVC');
CALL insertCapacityIntoADay(@bayCapacityTueToFri, 5, 'Bayside MVC');
CALL insertCapacityIntoADay(@bayCapacitySatToSun, 6, 'Bayside MVC');
CALL insertCapacityIntoADay(@bayCapacitySatToSun, 7, 'Bayside MVC');

TRUNCATE TABLE WeeklyCapacities;

INSERT INTO WeeklyCapacities VALUES (UUID(), 1, 'no', getCentreId('Bayside MVC'));
INSERT INTO WeeklyCapacities VALUES (UUID(), 2, 'no', getCentreId('Bayside MVC'));
INSERT INTO WeeklyCapacities VALUES (UUID(), 3, 'no', getCentreId('Bayside MVC'));
INSERT INTO WeeklyCapacities VALUES (UUID(), 4, 'no', getCentreId('Bayside MVC'));
INSERT INTO WeeklyCapacities VALUES (UUID(), 1, 'no', getCentreId('Splott MVC'));
INSERT INTO WeeklyCapacities VALUES (UUID(), 2, 'no', getCentreId('Splott MVC'));
INSERT INTO WeeklyCapacities VALUES (UUID(), 3, 'no', getCentreId('Splott MVC'));
-- issue 9 ends

TRUNCATE TABLE Centres_has_Vaccines;
INSERT INTO Centres_has_Vaccines VALUES (UUID(), getCentreId('Bayside MVC'), getVaccineID('Pfizer/BioNTech'), 0);
INSERT INTO Centres_has_Vaccines VALUES (UUID(), getCentreId('Bayside MVC'), getVaccineID('Pfizer/BioNTech'), 1);
INSERT INTO Centres_has_Vaccines VALUES (UUID(), getCentreId('Bayside MVC'), getVaccineID('Pfizer/BioNTech'), 2);
INSERT INTO Centres_has_Vaccines VALUES (UUID(), getCentreId('Bayside MVC'), getVaccineID('Pfizer/BioNTech'), 3);
INSERT INTO Centres_has_Vaccines VALUES (UUID(), getCentreId('Bayside MVC'), getVaccineID('Pfizer/BioNTech'), 4);
INSERT INTO Centres_has_Vaccines VALUES (UUID(), getCentreId('Bayside MVC'), getVaccineID('Moderna'), 5);
INSERT INTO Centres_has_Vaccines VALUES (UUID(), getCentreId('Bayside MVC'), getVaccineID('Moderna'), 6);
INSERT INTO Centres_has_Vaccines VALUES (UUID(), getCentreId('Splott MVC'), getVaccineID('Oxford/AstraZeneca'), 0);
INSERT INTO Centres_has_Vaccines VALUES (UUID(), getCentreId('Splott MVC'), getVaccineID('Oxford/AstraZeneca'), 1);
INSERT INTO Centres_has_Vaccines VALUES (UUID(), getCentreId('Splott MVC'), getVaccineID('Oxford/AstraZeneca'), 2);
INSERT INTO Centres_has_Vaccines VALUES (UUID(), getCentreId('Splott MVC'), getVaccineID('Oxford/AstraZeneca'), 3);
INSERT INTO Centres_has_Vaccines VALUES (UUID(), getCentreId('Splott MVC'), getVaccineID('Oxford/AstraZeneca'), 4);
INSERT INTO Centres_has_Vaccines VALUES (UUID(), getCentreId('Splott MVC'), getVaccineID('Moderna'), 5);
INSERT INTO Centres_has_Vaccines VALUES (UUID(), getCentreId('Splott MVC'), getVaccineID('Moderna'), 6);
INSERT INTO Centres_has_Vaccines VALUES (UUID(), getCentreId('Barry MVC'), getVaccineID('Pfizer/BioNTech'), 0);
INSERT INTO Centres_has_Vaccines VALUES (UUID(), getCentreId('Barry MVC'), getVaccineID('Pfizer/BioNTech'), 1);
INSERT INTO Centres_has_Vaccines VALUES (UUID(), getCentreId('Barry MVC'), getVaccineID('Pfizer/BioNTech'), 2);
INSERT INTO Centres_has_Vaccines VALUES (UUID(), getCentreId('Barry MVC'), getVaccineID('Pfizer/BioNTech'), 3);
INSERT INTO Centres_has_Vaccines VALUES (UUID(), getCentreId('Barry MVC'), getVaccineID('Pfizer/BioNTech'), 4);
INSERT INTO Centres_has_Vaccines VALUES (UUID(), getCentreId('Barry MVC'), getVaccineID('Oxford/AstraZeneca'), 5);
INSERT INTO Centres_has_Vaccines VALUES (UUID(), getCentreId('Barry MVC'), getVaccineID('Oxford/AstraZeneca'), 6);

-- issue 17 Appointments - basic info should be logged
TRUNCATE TABLE Appointments;
-- insert appointments sequentially without specifying week, date, time, centre
DROP PROCEDURE IF EXISTS insertAnAppointment;
DELIMITER //
CREATE PROCEDURE insertAnAppointment(nhsNumber BIGINT, vaccineName LONGTEXT, appointmentDate DATE)
BEGIN
    DECLARE maxIteration INT;
    DECLARE i INT;
    DECLARE dailyCpRecord INT;
    DECLARE appointmentDateRecord DATE;
    DECLARE weekNumberRecord INT;
    DECLARE capacityIdRecord VARCHAR(36);
    DECLARE CapacityRecordLastDay INT;
    DECLARE rowCountCapacity INT;
    DECLARE capacityRecordLastDayCurrentWeek INT;
    
    SET maxIteration = (SELECT COUNT(*) FROM Capacities);
    SET i = 0;
	SET weekNumberRecord = (SELECT WeekNumber FROM WeeklyCapacities WHERE IsFull = 'no' LIMIT 1);
    insertloop: WHILE i < maxIteration DO
		SELECT CapacityID, CapacityRecord INTO capacityIdRecord, dailyCpRecord FROM Capacities WHERE Centres_CentreID = getCentreId('Bayside MVC') LIMIT i, 1;
        SELECT COUNT(*) - 1 INTO rowCountCapacity FROM Capacities WHERE Centres_CentreID = getCentreId('Bayside MVC');
        SELECT CapacityRecord INTO CapacityRecordLastDay FROM Capacities WHERE CapacityID = (SELECT CapacityID FROM Capacities LIMIT rowCountCapacity, 1) AND Centres_CentreID = getCentreId('Bayside MVC');
		-- minus 1 in CapacityRecord
		UPDATE Capacities SET CapacityRecord = CapacityRecord - 1 WHERE CapacityID = capacityIdRecord AND CapacityRecord > 0; 
        -- if day capacity > 0 and weekly capacity > 0, insert in the current day, current week
        IF (dailyCpRecord > 0 AND CapacityRecordLastDay > 0) THEN
			INSERT INTO Appointments VALUES (UUID(), appointmentDate, '08:00:00', nhsNumber, getCentreId('Bayside MVC'), getVaccineId(vaccineName));
            SELECT CapacityRecord INTO capacityRecordLastDayCurrentWeek FROM Capacities LIMIT rowCountCapacity, 1; 
            -- if last day capacity = 0 for this week, set the weekly capacity to full
            IF (capacityRecordLastDayCurrentWeek = 0) THEN
				UPDATE WeeklyCapacities SET IsFull = 'yes' WHERE WeekNumber = WeekNumberRecord AND Centres_CentreID = getCentreId('Bayside MVC');
            END IF;
            LEAVE insertloop;
		-- if weekly capacity = 0, reset weekly capacity, start updating next week
		ELSEIF (CapacityRecordLastDay = 0) THEN
			INSERT INTO Appointments VALUES (UUID(), appointmentDate, '08:00:00', nhsNumber, getCentreId('Bayside MVC'), getVaccineId(vaccineName));
			-- reset CapacityRecord
            UPDATE Capacities SET CapacityRecord = Capacity;
			SET WeekNumberRecord = WeekNumberRecord + 1;
            -- minus 1 in CapacityRecord
            UPDATE Capacities SET CapacityRecord = CapacityRecord - 1 WHERE CapacityID = capacityIdRecord AND CapacityRecord > 0; 
            LEAVE insertloop; 
        END IF;
        SET i = i + 1;
    END WHILE;
END//
DELIMITER ;

DROP PROCEDURE IF EXISTS insertBatchAppointmentsForADay;
DELIMITER //
CREATE PROCEDURE insertBatchAppointmentsForADay(nhsStart INT, nhsEnd INT, vaccineName ENUM('Pfizer/BioNTech', 'Oxford/AstraZeneca', 'Moderna'), appointmentDate DATE)
BEGIN
	DECLARE i INT;
    SET i = 1;
    loop_label: LOOP
		IF i - 1 > nhsEnd - nhsStart THEN
			LEAVE loop_label;
        END IF;
        CALL insertAnAppointment(7260000000 + nhsStart + i - 1, vaccineName, appointmentDate); 
        SET i = i + 1;
		ITERATE loop_label;
    END LOOP loop_label;
END //
DELIMITER ;

DROP PROCEDURE IF EXISTS insertBatchAppointmentsForAWeek;
DELIMITER //
CREATE PROCEDURE insertBatchAppointmentsForAWeek(nhsStart BIGINT, startDate DATE, vaccineName ENUM('Pfizer/BioNTech', 'Oxford/AstraZeneca', 'Moderna'))
BEGIN
	DECLARE i INT;
    SET i = 0;
    loop_label: LOOP
		IF i > 6 THEN
			LEAVE loop_label;
        END IF;
        IF i = 0 THEN
			CALL insertBatchAppointmentsForADay(nhsStart - 7260000000, nhsStart - 7260000000 + (SELECT SUM(capacity) FROM Capacities WHERE WeekDay = i) - 1, vaccineName, DATE_ADD(startDate, INTERVAL i DAY));
        ELSE
			CALL insertBatchAppointmentsForADay(nhsStart - 7260000000 + (SELECT SUM(capacity) FROM Capacities WHERE WeekDay BETWEEN 0 AND (i - 1)), 
            nhsStart - 7260000000 + (SELECT SUM(capacity) FROM Capacities WHERE WeekDay BETWEEN 0 AND i) - 1, vaccineName, DATE_ADD(startDate, INTERVAL i DAY));
        END IF;
        SET i = i + 1;
		ITERATE loop_label;
    END LOOP loop_label;
END //
DELIMITER ;
-- issue 17 ends

-- issue 7: Appointments - the appointment system should be able to register a 20-min slot for an appointment
-- TempAppointmentTime table to store 20min appointment slots.
CREATE TABLE `TempAppointmentTime` (
	`ID` VARCHAR(36) NOT NULL UNIQUE,
    `tempTime` TIME,
    `tempDate` DATE,
    CONSTRAINT `PK_TempAppointmentTime` PRIMARY KEY (`ID`)
);

-- set 20min iterative slots for a day, e.g. slot = 08:00:00 - 08:59:59, capacity = 5, then appointment start times will be 08:00:00, 08:20:00, 08:40:00, 08:00:00, 08:20:00
DROP PROCEDURE IF EXISTS setCorrectAppointmentTimeForADay;
DELIMITER //
-- weekday is the weekday in Capacities, 
-- insertDate is the AppointmentDate to be inserted, 
-- startIndex is the index of Capacities.WeekDay n, i.e. WeekDay 0 = 0, WeekDay 1 = 2, WeekDay 2 = 4, etc. 
CREATE PROCEDURE setCorrectAppointmentTimeForADay(weekday INT, insertDate DATE, weekdayStartIndex INT)
BEGIN
	DECLARE iterateTimes INT;
    DECLARE i INT;
    DECLARE totalRows INT;
    DECLARE insertTime TIME;
    DECLARE startTimeRecord TIME;
    DECLARE endTimeRecord TIME;
    DECLARE j INT;
    DECLARE capacitySlotVol INT;
    SET j = weekdayStartIndex;
    loop_label_j: LOOP
		SELECT COUNT(*) INTO capacitySlotVol FROM Capacities WHERE Capacities.WeekDay = weekday;
		IF j >= weekdayStartIndex + capacitySlotVol THEN
			LEAVE loop_label_j;
		END IF;
		SELECT StartTime, EndTime INTO startTimeRecord, endTimeRecord FROM Capacities WHERE Centres_CentreID = getCentreId('Bayside MVC') AND WeekDay = weekday LIMIT j, 1;
		SET iterateTimes = ROUND(SEC_TO_TIME(TIME_TO_SEC(timediff(endTimeRecord, startTimeRecord)) / 20 / 60));
		SELECT Capacity INTO totalRows FROM Capacities WHERE WeekDay = weekday LIMIT j, 1;
		SET i = 0;
		SET insertTime = startTimeRecord;
		loop_label_i: LOOP
			IF i >= totalRows THEN
				LEAVE loop_label_i;
			END IF;
			INSERT INTO TempAppointmentTime VALUES (UUID(), insertTime, insertDate);
			SET insertTime = AddTime(insertTime, '00:20:00');
			SET i = i + 1;
			IF insertTime > endTimeRecord THEN 
				SET insertTime = startTimeRecord;
			END IF;
			ITERATE loop_label_i;
		END LOOP loop_label_i;
    SET j = j + 1;
    ITERATE loop_label_j;
    END LOOP loop_label_j;
END //
DELIMITER ;

DROP PROCEDURE IF EXISTS duplicateTempAppointmentTime;
DELIMITER //
CREATE PROCEDURE duplicateTempAppointmentTime(duplicateTimes INT)
BEGIN
	DECLARE i INT;
    DECLARE rowNumber INT;
    DECLARE tTime TIME;
    DECLARE tDate DATE;
    SELECT SUM(Capacity) INTO rowNumber FROM Capacities;
    SET i = 0;
    loop_label: LOOP
		IF i >= rowNumber THEN
			LEAVE loop_label;
        END IF;
        SELECT tempTime INTO tTime FROM TempAppointmentTime LIMIT i, 1;
        SELECT tempDate INTO tDate FROM TempAppointmentTime LIMIT i, 1;
        INSERT INTO TempAppointmentTime VALUES(UUID(), tTime, DATE_ADD(tDate, INTERVAL 7 * duplicateTimes DAY));
        SET i = i + 1;
		ITERATE loop_label;
    END LOOP loop_label;
END //
DELIMITER ;

-- insert appointments from 2022-01-01 to 2022-01-21 for 3 weeks
CALL insertBatchAppointmentsForAWeek(7260000001, '2022-01-01', 'Pfizer/BioNTech');
CALL insertBatchAppointmentsForAWeek(7260000001 + (SELECT SUM(Capacity) FROM Capacities), '2022-01-08', 'Oxford/AstraZeneca');
CALL insertBatchAppointmentsForAWeek(7260000001 + (SELECT SUM(Capacity) FROM Capacities) * 2, '2022-01-15', 'Moderna');
-- generate appointment time for a week
CALL setCorrectAppointmentTimeForADay(0, '2022-01-01', 0);
CALL setCorrectAppointmentTimeForADay(1, '2022-01-02', 2);
CALL setCorrectAppointmentTimeForADay(2, '2022-01-03', 4);
CALL setCorrectAppointmentTimeForADay(3, '2022-01-04', 6);
CALL setCorrectAppointmentTimeForADay(4, '2022-01-05', 8);
CALL setCorrectAppointmentTimeForADay(5, '2022-01-06', 10);
CALL setCorrectAppointmentTimeForADay(6, '2022-01-07', 12);
-- duplicate above appointment for the next 2 weeks
CALL duplicateTempAppointmentTime(1);
CALL duplicateTempAppointmentTime(2);
-- combine Appointment data with TempAppointmentTime data based on row number
INSERT INTO AppointmentsUpdated (AppointmentID, 
	AppointmentDate, 
	AppointmentTime, 
	Users_NhsNumber, 
	Centres_CentreID, 
	Vaccines_VaccineID, 
	UpdatedTime
) 
SELECT A.AppointmentID, A.AppointmentDate, A.AppointmentTime, A.Users_NhsNumber, A.Centres_CentreID, A.Vaccines_VaccineID, B.tempTime
FROM
(
   SELECT AppointmentID, AppointmentDate, AppointmentTime, Users_NhsNumber, Centres_CentreID, Vaccines_VaccineID, rownum()R
   FROM Appointments
)A INNER join
(
  SELECT tempTime, rownum()R
  FROM TempAppointmentTime
)B ON A.R=B.R; 
-- replace AppointmentsUpdated.AppointmentTime with AppointmentsUpdated.UpdatedTime
UPDATE AppointmentsUpdated SET AppointmentTime = UpdatedTime;
-- drop unused column and tables
ALTER TABLE AppointmentsUpdated DROP UpdatedTime;
DROP TABLE IF EXISTS Appointments;
DROP TABLE IF EXISTS TempAppointmentTime;
-- issue 7 ends

-- issue 13 Appointments - the appointment attendance status should be recorded
DROP PROCEDURE IF EXISTS initializeAppointmentStatus;
DELIMITER //
CREATE PROCEDURE initializeAppointmentStatus()
BEGIN
	DECLARE i INT;
    DECLARE rowNumber INT;
    SELECT COUNT(*) INTO rowNumber FROM AppointmentsUpdated;
    SET i = 0;
    loop_label: LOOP
		IF i >= rowNumber THEN
			LEAVE loop_label;
        END IF;
        INSERT INTO Appointment_Status VALUES((SELECT AppointmentID FROM AppointmentsUpdated LIMIT i, 1), null, null, null);
        SET i = i + 1;
		ITERATE loop_label;
    END LOOP loop_label;
END//
DELIMITER ;
CALL initializeAppointmentStatus();

-- log an appointment: 
DROP PROCEDURE IF EXISTS logAnAppointment;
DELIMITER //
CREATE PROCEDURE logAnAppointment(appointmentDate DATE, appointmentTime TIME, nhsNumber BIGINT, fulfilled ENUM('fulfilled', 'noshow', 'cancelled'), rejected ENUM('yes', 'no'), rejectReason TEXT)
BEGIN
	DECLARE aID VARCHAR(36);
    DECLARE weekdayIndex INT;
    DECLARE weekIndex INT;
    START TRANSACTION;
		SAVEPOINT P1;
		SELECT AppointmentID INTO aID FROM AppointmentsUpdated A WHERE A.AppointmentDate = appointmentDate AND A.AppointmentTime = appointmentTime AND A.Users_NhsNumber = nhsNumber;
		
		IF aID is null THEN
			SIGNAL SQLSTATE 'ERR0R' SET MESSAGE_TEXT = 'Appointment does not exist with this patient at this time, this date.';
            ROLLBACK TO P1;
		ELSEIF fulfilled = 'cancelled' THEN
			-- release the slot in Capacity table
            SELECT MOD(DAY(appointmentDate), 7) - 1 INTO weekdayIndex;
            SELECT FLOOR(DAY(appointmentDate) / 7) + 1 INTO weekIndex;
            -- release the slot in Capacities table
            UPDATE Capacities SET CapacityRecord = CapacityRecord + 1 WHERE WeekDay = weekdayIndex AND appointmentTime >= StartTime AND appointmentTime <= EndTime;
            -- release the slot in WeeklyCapacities table
            UPDATE WeeklyCapacities SET IsFull = 'no' WHERE WeekNumber = weekIndex AND Centres_CentreID = getCentreId('Bayside MVC');
            -- update Appointment status
			UPDATE Appointment_Status SET AppointmentFulfilled = fulfilled, Rejected = rejected, RejectReason = rejectReason WHERE AppointmentID = aID;
		ELSE 
			UPDATE Appointment_Status SET AppointmentFulfilled = fulfilled, Rejected = rejected, RejectReason = rejectReason WHERE AppointmentID = aID;
		END IF;
	COMMIT;
END//
DELIMITER ;
-- try to log an appointment with unmatching information
-- CALL logAnAppointment('2022-01-01', '08:00:00', 7260000002, 'fulfilled', 'no', '');
-- successfully log an attended appointment
CALL logAnAppointment('2022-01-01', '08:00:00', 7260000001, 'fulfilled', 'no', '');
-- update an existing appointment
CALL logAnAppointment('2022-01-01', '08:00:00', 7260000001, 'fulfilled', 'yes', 'Allergy');
-- log a noshow appointment
CALL logAnAppointment('2022-01-01', '08:20:00', 7260000002, 'noshow', 'no', '');
-- log a cancelled first week appointment and release the slot
CALL logAnAppointment('2022-01-01', '09:00:00', 7260000008, 'cancelled', 'no', '');
-- log a cancelled third week appointment and release the slot
CALL logAnAppointment('2022-01-20', '10:00:00', 7260000165, 'cancelled', 'no', '');
-- issue 13 ends


-- issue 15 Report - should report daily data for all centres
-- log more appointments
CALL logAnAppointment('2022-01-01', '08:40:00', 7260000003, 'fulfilled', 'no', '');
CALL logAnAppointment('2022-01-01', '08:00:00', 7260000004, 'fulfilled', 'no', '');
CALL logAnAppointment('2022-01-01', '08:20:00', 7260000005, 'fulfilled', 'yes', 'Allergy');
CALL logAnAppointment('2022-01-01', '08:40:00', 7260000006, 'fulfilled', 'no', '');
CALL logAnAppointment('2022-01-01', '08:00:00', 7260000007, 'fulfilled', 'no', '');
CALL logAnAppointment('2022-01-01', '09:00:00', 7260000008, 'fulfilled', 'no', '');
CALL logAnAppointment('2022-01-01', '09:20:00', 7260000009, 'fulfilled', 'no', '');
CALL logAnAppointment('2022-01-02', '00:00:00', 7260000010, 'fulfilled', 'no', '');
CALL logAnAppointment('2022-01-02', '00:20:00', 7260000011, 'cancelled', 'no', '');
CALL logAnAppointment('2022-01-02', '08:00:00', 7260000012, 'fulfilled', 'no', '');
CALL logAnAppointment('2022-01-02', '08:20:00', 7260000013, 'fulfilled', 'no', '');
CALL logAnAppointment('2022-01-02', '08:40:00', 7260000014, 'noshow', 'no', '');
CALL logAnAppointment('2022-01-02', '09:00:00', 7260000015, 'fulfilled', 'no', '');
CALL logAnAppointment('2022-01-02', '09:20:00', 7260000016, 'fulfilled', 'yes', 'Allergy');
CALL logAnAppointment('2022-01-03', '00:00:00', 7260000017, 'fulfilled', 'no', '');
CALL logAnAppointment('2022-01-03', '00:20:00', 7260000018, 'cancelled', 'no', '');
CALL logAnAppointment('2022-01-03', '08:00:00', 7260000019, 'fulfilled', 'no', '');
CALL logAnAppointment('2022-01-03', '08:20:00', 7260000020, 'fulfilled', 'yes', 'Allergy');
CALL logAnAppointment('2022-01-03', '08:40:00', 7260000021, 'fulfilled', 'no', '');
CALL logAnAppointment('2022-01-03', '09:00:00', 7260000022, 'cancelled', 'no', '');
CALL logAnAppointment('2022-01-03', '09:20:00', 7260000023, 'cancelled', 'no', '');
-- log more appointments for different vaccine type 'Oxford/AstraZeneca'
CALL logAnAppointment('2022-01-08', '08:00:00', 7260000060, 'fulfilled', 'no', '');
CALL logAnAppointment('2022-01-08', '08:20:00', 7260000061, 'fulfilled', 'no', '');
CALL logAnAppointment('2022-01-08', '08:40:00', 7260000062, 'fulfilled', 'no', '');
CALL logAnAppointment('2022-01-08', '08:00:00', 7260000063, 'fulfilled', 'no', '');
CALL logAnAppointment('2022-01-08', '08:20:00', 7260000064, 'fulfilled', 'no', '');
CALL logAnAppointment('2022-01-08', '08:40:00', 7260000065, 'fulfilled', 'no', '');
CALL logAnAppointment('2022-01-08', '08:00:00', 7260000066, 'fulfilled', 'no', '');
CALL logAnAppointment('2022-01-08', '09:00:00', 7260000067, 'fulfilled', 'no', '');
CALL logAnAppointment('2022-01-08', '09:20:00', 7260000068, 'fulfilled', 'no', '');
-- log more appointments for different vaccine type 'Moderna'
CALL logAnAppointment('2022-01-15', '08:00:00', 7260000119, 'fulfilled', 'no', '');
CALL logAnAppointment('2022-01-15', '08:20:00', 7260000120, 'fulfilled', 'no', '');
CALL logAnAppointment('2022-01-15', '08:40:00', 7260000121, 'fulfilled', 'no', '');
CALL logAnAppointment('2022-01-15', '08:00:00', 7260000122, 'fulfilled', 'no', '');
CALL logAnAppointment('2022-01-15', '08:20:00', 7260000123, 'fulfilled', 'no', '');
CALL logAnAppointment('2022-01-15', '08:40:00', 7260000124, 'fulfilled', 'no', '');
CALL logAnAppointment('2022-01-15', '08:00:00', 7260000125, 'fulfilled', 'no', '');
CALL logAnAppointment('2022-01-15', '09:00:00', 7260000126, 'fulfilled', 'no', '');
CALL logAnAppointment('2022-01-15', '09:20:00', 7260000127, 'fulfilled', 'no', '');
-- report number of injections for 3 days
DROP PROCEDURE IF EXISTS reportNumberOfInjectionForADay;
DELIMITER //
CREATE PROCEDURE reportNumberOfInjectionForADay(inputDate DATE)
BEGIN    
	SELECT COUNT(*) FROM Appointment_Status S INNER JOIN AppointmentsUpdated A ON S.AppointmentID = A.AppointmentID WHERE A.AppointmentDate = inputDate AND S.AppointmentFulfilled = 'fulfilled' AND S.Rejected = 'no';
END//
DELIMITER ;
-- CALL reportNumberOfInjectionForADay('2022-01-01');
-- CALL reportNumberOfInjectionForADay('2022-01-02');
-- CALL reportNumberOfInjectionForADay('2022-01-03');
-- report number of appointments made for 3 days
DROP PROCEDURE IF EXISTS reportNumberOfAppointmentsMadeForADay;
DELIMITER //
CREATE PROCEDURE reportNumberOfAppointmentsMadeForADay(inputDate DATE)
BEGIN
	SELECT COUNT(*) FROM Appointment_Status S INNER JOIN AppointmentsUpdated A ON S.AppointmentID = A.AppointmentID WHERE A.AppointmentDate = inputDate AND S.AppointmentFulfilled = 'fulfilled';
END//
DELIMITER ;
-- CALL reportNumberOfAppointmentsMadeForADay('2022-01-01');
-- CALL reportNumberOfAppointmentsMadeForADay('2022-01-02');
-- CALL reportNumberOfAppointmentsMadeForADay('2022-01-03');
-- report number of missed injections for 3 days
DROP PROCEDURE IF EXISTS reportNumberOfMissedInjectionForADay;
DELIMITER //
CREATE PROCEDURE reportNumberOfMissedInjectionForADay(inputDate DATE)
BEGIN    
	SELECT COUNT(*) FROM Appointment_Status S INNER JOIN AppointmentsUpdated A ON S.AppointmentID = A.AppointmentID WHERE A.AppointmentDate = inputDate AND (S.AppointmentFulfilled != 'fulfilled' OR S.Rejected = 'yes');
END//
DELIMITER ;
-- CALL reportNumberOfMissedInjectionForADay('2022-01-01');
-- CALL reportNumberOfMissedInjectionForADay('2022-01-02');
-- CALL reportNumberOfMissedInjectionForADay('2022-01-03');
-- report number of missed appointments for 3 days
DROP PROCEDURE IF EXISTS reportNumberOfMissedAppointmentsForADay;
DELIMITER //
CREATE PROCEDURE reportNumberOfMissedAppointmentsForADay(inputDate DATE)
BEGIN    
	SELECT COUNT(*) FROM Appointment_Status S INNER JOIN AppointmentsUpdated A ON S.AppointmentID = A.AppointmentID WHERE A.AppointmentDate = inputDate AND S.AppointmentFulfilled != 'fulfilled';
END//
DELIMITER ;
CALL reportNumberOfMissedAppointmentsForADay('2022-01-01');
CALL reportNumberOfMissedAppointmentsForADay('2022-01-02');
CALL reportNumberOfMissedAppointmentsForADay('2022-01-03');
-- issue 15 ends

-- issue 16 Report - should report daily data for each centre and each vaccine
-- report number of vaccines given by type
DROP PROCEDURE IF EXISTS reportNumberOfVaccinesByType;
DELIMITER //
CREATE PROCEDURE reportNumberOfVaccinesByType(vName ENUM('Pfizer/BioNTech', 'Oxford/AstraZeneca', 'Moderna'))
BEGIN    
	DECLARE vaccineID VARCHAR(36);
    SELECT V.VaccineID INTO vaccineID FROM Vaccines V WHERE V.VaccineName = vName;
	SELECT COUNT(*) FROM Appointment_Status S INNER JOIN AppointmentsUpdated A ON S.AppointmentID = A.AppointmentID WHERE A.Vaccines_VaccineID = vaccineID AND S.AppointmentFulfilled = 'fulfilled' AND S.Rejected = 'no';
END//
DELIMITER ;
CALL reportNumberOfVaccinesByType('Pfizer/BioNTech');
CALL reportNumberOfVaccinesByType('Oxford/AstraZeneca');
CALL reportNumberOfVaccinesByType('Moderna');
-- issue 16 ends

SELECT * FROM NHS;
SELECT * FROM Vaccines; 
SELECT * FROM Centres;
SELECT * FROM Centres_has_Vaccines;
SELECT * FROM OpeningTime;
SELECT * FROM WeeklyCapacities;
SELECT * FROM Capacities;
SELECT * FROM AppointmentsUpdated;
SELECT * FROM Appointment_Status;
SET SQL_SAFE_UPDATES = 1;
