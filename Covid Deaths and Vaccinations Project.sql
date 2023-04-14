-- Verify that data was imported correctly for both files

SELECT *
FROM CovidDeaths
GROUP BY continent, location;

SELECT *
FROM CovidVaccinations
GROUP BY continent, location;



-- Selecting data relevant to project 

SELECT location, date, total_cases, new_cases, total_deaths, population
FROM CovidDeaths
ORDER BY 1, 2;



-- Examining Total Cases vs. Total Deaths in Finland
-- Shows likelihood of dying if you contract covid in Finland

SELECT location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 AS DeathRate
FROM CovidDeaths
WHERE location = 'Finland'
ORDER BY 1, 2;



-- Examining Total Cases vs. Population in Finland
-- Shows percentage of Finnish population that contracted covid

SELECT location, date, population, total_cases, (total_cases/population)*100 AS InfectionRate
FROM CovidDeaths
WHERE location = 'Finland'
ORDER BY 1, 2;



-- Examining countries with highest Infection Rate compared to Population

SELECT location, population, MAX(total_cases) AS HighestInfectionCount, MAX((total_cases/population))*100 AS InfectionRate
FROM CovidDeaths
WHERE continent <> '' 
GROUP BY 1, 2
ORDER BY InfectionRate DESC; 



-- Examining countries with highest Death Count compared to Population
-- Discovered that location contains both country and continent > continents excluded from location 
-- WHERE continent IS NOT NULL did not work - why?

SELECT RANK () OVER (ORDER BY MAX(total_deaths) DESC) AS Ranking, location, MAX(total_deaths) AS TotalDeaths
FROM CovidDeaths 
WHERE continent <> ''
GROUP BY location
ORDER BY TotalDeaths DESC; 



-- Examining Death Count by continent using location, with rank
-- Different results depending on wether we use location or continent - location more accurate?

SELECT RANK () OVER (ORDER BY MAX(total_deaths) DESC) AS Ranking, location, MAX(total_deaths) AS TotalDeaths
FROM CovidDeaths 
WHERE location IN ('Europe', 'Asia', 'North America', 'South America', 'Africa', 'Oceania')
GROUP BY location
ORDER BY TotalDeaths DESC; 



-- Examining Death Count by continent using continent
-- USE THIS FOR PROJECT
-- Different results depending on wether we use location or continent - location more accurate?

SELECT continent, MAX(total_deaths) AS TotalDeaths
FROM CovidDeaths 
WHERE continent <> ''
GROUP BY continent
ORDER BY TotalDeaths DESC; 



-- Examinig global numbers (total cases, total deaths, death rate) by date
-- Sum of new cases adds up to total cases (we can't use SUM(MAX(total_cases)) because it's an aggregate function within an aggregate function
-- Date is of data type VARCHAR so it needed to be CAST AS DATE

SELECT CAST(date AS DATE) AS Date, SUM(new_cases) AS Cases, SUM(new_deaths) AS Deaths, SUM(new_deaths)/SUM(new_cases)*100 AS DeathRate
FROM CovidDeaths 
WHERE continent <> ''
GROUP BY CAST(date AS DATE)
ORDER BY 1, 2;



-- Examinig the global total numbers (total cases, total deaths, death rate)

SELECT SUM(new_cases) AS Cases, SUM(new_deaths) AS Deaths, SUM(new_deaths)/SUM(new_cases)*100 AS DeathRate
FROM CovidDeaths 
WHERE continent <> ''
ORDER BY 1, 2;



-- Examining Total Population vs. Vaccinations
-- Joining CovidDeaths and CovidVaccination tables
-- Adding rolling count of vaccinated people by country (location) and date
-- Numbers do not appear to be correct, problem with using new_vaccinations?

SELECT cd.continent, cd.location, CAST(cd.date AS DATE), cd.population, CAST(cv.new_vaccinations AS UNSIGNED) AS NewVaccinations, 
	SUM(CAST(cv.new_vaccinations AS UNSIGNED)) OVER (PARTITION BY cd.location ORDER BY cd.location, CAST(cd.date AS DATE)) AS VaccinatedPeopleRollingCount
FROM CovidDeaths cd 
JOIN CovidVaccinations cv 
	ON cd.location = cv.location AND cd.date = cv.date
WHERE cd.continent <> '' -- AND cd.location = 'Finland'
ORDER BY 2, 3;



-- Examining rolling counts of people vaccinated and vaccination rate (vaccinated people vs. population)
-- Using a common table expression (CTE) to be able to calculate VaccinationRate
-- How can Vaccination Rate be over 100%? See Cuba, for example. Problem with using new_vacciantions?

WITH PopvsVac (Continent, Location, Date, Population, NewVaccinations, VaccinatedPeopleRolling)
AS 
(
SELECT 
	cd.continent, 
	cd.location, 
	CAST(cd.date AS DATE), 
	CAST(cd.population AS UNSIGNED), 
	CAST(cv.new_vaccinations AS UNSIGNED), 
	SUM(CAST(cv.new_vaccinations AS UNSIGNED)) OVER (PARTITION BY cd.location ORDER BY cd.location, CAST(cd.date AS DATE)) AS VaccinatedPeopleRolling
FROM CovidDeaths cd 
JOIN CovidVaccinations cv 
	ON cd.location = cv.location AND cd.date = cv.date
WHERE cd.continent <> '' -- AND cd.location = 'Finland' 
)
SELECT *, VaccinatedPeopleRolling/Population*100 AS VaccinationRateRolling
FROM PopvsVac;



-- Examining max numbers of people vaccinated compared to the population of a country
-- In order to be able to GROUP BY location I did the following:
-- Ran command SELECT @@sql_mode; (gives a comma separated list of all enabled modes)
-- Removed ONLY_FULL_GROUP_BY option from list and ran the command below
-- SET sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION'

WITH PopvsVac (Continent, Location, Population, VaccinatedPeopleTotal)
AS 
(
SELECT cd.continent, cd.location, cd.population, MAX(CAST(cv.people_vaccinated AS UNSIGNED))
FROM CovidDeaths cd 
JOIN CovidVaccinations cv 
	ON cd.location = cv.location AND cd.date = cv.date                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           
WHERE cd.continent <> ''
GROUP BY cd.location
)
SELECT *, VaccinatedPeopleTotal/Population*100 AS VaccinationRate
FROM PopvsVac;



-- Creating TEMPORARY TABLES
-- Problem with temp table 1 due to new_vaccinations?

-- SELECT @@sql_mode;
-- gives STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION
-- SET sql_mode = 'NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION'

UPDATE CovidVaccinations 
SET people_vaccinated = '0'
WHERE people_vaccinated = '';

UPDATE CovidVaccinations 
SET new_vaccinations = '0'
WHERE new_vaccinations = '';


DROP TEMPORARY TABLE IF EXISTS PercentPopulationVaccinated1;

CREATE TEMPORARY TABLE PercentPopulationVaccinated1 (
	Continent VARCHAR(100),
	Location VARCHAR(100),
	Date DATE,
	Population INT,
	VaccinationsRolling INT
);

INSERT INTO PercentPopulationVaccinated1
SELECT 
	cd.continent, 
	cd.location, 
	CAST(cd.date AS DATE), 
	CAST(cd.population AS UNSIGNED),
	SUM(CAST(cv.new_vaccinations AS UNSIGNED)) OVER (PARTITION BY cd.location ORDER BY cd.location, CAST(cd.date AS DATE)) -- AS VaccinationsRolling
FROM CovidDeaths cd 
JOIN CovidVaccinations cv 
	ON cd.location = cv.location AND cd.date = cv.date
WHERE cd.continent <> '';
-- GROUP BY cd.location, cd.date
-- ORDER BY cd.location, cd.date;


DROP TEMPORARY TABLE IF EXISTS PercentPopulationVaccinated2;

CREATE TEMPORARY TABLE PercentPopulationVaccinated2 (
	Continent VARCHAR(50),
	Location VARCHAR(50),
	Date DATE,
	Population INT,
	VaccinationsRolling INT,
	VaccinationRate DEC(5,2)
);

INSERT INTO PercentPopulationVaccinated2
SELECT *, VaccinationsRolling/Population*100 -- OVER (PARTITION BY Location ORDER BY Location, Date)
FROM PercentPopulationVaccinated1
GROUP BY Location, Date;


SELECT *
FROM PercentPopulationVaccinated1;
WHERE Location = 'Finland';



-- Creating VIEWS to store data for later visualization

-- Global total numbers (total cases, total deaths, death rate)

CREATE VIEW GlobalDeathRate AS
SELECT SUM(new_cases) AS Cases, SUM(new_deaths) AS Deaths, SUM(new_deaths)/SUM(new_cases)*100 AS DeathRate
FROM CovidDeaths 
WHERE continent <> ''
ORDER BY 1, 2;



-- Rolling count of vaccinations by country and date
-- Numbers do not appear to be correct, problem with using new_vaccinations?

CREATE VIEW PercentPopulationVaccinated1 AS
SELECT 
	cd.continent, 
	cd.location, 
	CAST(cd.date AS DATE), 
	CAST(cd.population AS UNSIGNED),
	SUM(CAST(cv.new_vaccinations AS UNSIGNED)) OVER (PARTITION BY cd.location ORDER BY cd.location, CAST(cd.date AS DATE)) -- AS VaccinationsRolling
FROM CovidDeaths cd 
JOIN CovidVaccinations cv 
	ON cd.location = cv.location AND cd.date = cv.date
WHERE cd.continent <> '';



-- Examining Total Population vs. Vaccinations
-- Rolling count of vaccinations by location and date
-- Numbers do not appear to be correct, problem with using new_vaccinations?

CREATE VIEW PercentPopulationVaccinated2 AS
SELECT cd.continent, cd.location, CAST(cd.date AS DATE), cd.population, CAST(cv.new_vaccinations AS UNSIGNED) AS NewVaccinations, 
	SUM(CAST(cv.new_vaccinations AS UNSIGNED)) OVER (PARTITION BY cd.location ORDER BY cd.location, CAST(cd.date AS DATE)) AS VaccinatedPeopleRollingCount
FROM CovidDeaths cd 
JOIN CovidVaccinations cv 
	ON cd.location = cv.location AND cd.date = cv.date
WHERE cd.continent <> '' -- AND cd.location = 'Finland'
ORDER BY 2, 3;



-- Examining countries with highest Infection Rate compared to Population

CREATE VIEW HighestInfectionRates AS
SELECT location, population, MAX(total_cases) AS HighestInfectionCount, MAX((total_cases/population))*100 AS InfectionRate
FROM CovidDeaths
WHERE continent <> '' 
GROUP BY 1, 2
ORDER BY InfectionRate DESC; 



-- Examining countries with highest Death Count compared to Population

CREATE VIEW HighestDeathCounts AS
SELECT RANK () OVER (ORDER BY MAX(total_deaths) DESC) AS Ranking, location, MAX(total_deaths) AS TotalDeaths
FROM CovidDeaths 
WHERE continent <> ''
GROUP BY location
ORDER BY TotalDeaths DESC; 



-- Examining Death Count by continent using continent

CREATE VIEW DeathCountByContinent AS
SELECT continent, MAX(total_deaths) AS TotalDeaths
FROM CovidDeaths 
WHERE continent <> ''
GROUP BY continent
ORDER BY TotalDeaths DESC; 












