SELECT *
FROM CovidDeaths

-- Looking at data to show

SELECT location,date,total_cases,new_cases,total_deaths,population
FROM CovidDeaths
ORDER BY 1,2

-- Looking at deaths vs cases in world

SELECT location,date,total_cases,total_deaths,population,(total_deaths/total_cases)*100 as death_percent
FROM CovidDeaths
ORDER BY 1,2

-- Looking at deaths vs cases in India

SELECT location,date,total_cases,total_deaths,population,(total_deaths/total_cases)*100 as death_percent
FROM CovidDeaths
WHERE location = 'India'
ORDER BY 1,2

-- Looking at cases vs population

SELECT location,date,total_cases,population,(total_cases/population)*100 as perct_who_got_covid
FROM CovidDeaths
WHERE location = 'India'
ORDER BY 1,2

-- Looking at countries with highest infection rate w.r.t population

SELECT location,population,MAX(total_cases) as InfectionCount,MAX(total_cases/population)*100 as perct_who_got_covid
FROM CovidDeaths
GROUP BY location,population
ORDER BY 4 desc

-- Looking at countries with highest death count per population

SELECT location,MAX(cast (total_deaths as int)) as TotalDeathsCount
FROM CovidDeaths
WHERE continent is not null
GROUP BY location
ORDER BY 2 desc

-- Looking at countries with highest cases

SELECT location,MAX(total_cases) as TotalCasesCount
FROM CovidDeaths
WHERE continent is not null
GROUP BY location
ORDER BY 2 desc

-- Looking at the continents

SELECT continent,MAX(total_cases) as TotalCasesCount
FROM CovidDeaths
WHERE continent is not null
GROUP BY continent
ORDER BY 2 desc

-- Looking at Global Numbers

SELECT SUM(new_cases) as TotalCases,SUM(cast(new_deaths as int)) as TotalDeaths,SUM(cast(new_deaths as int))/SUM(new_cases)*100 as Death_Percent
FROM CovidDeaths
WHERE continent is not null

-- Joining two tables

SELECT *
FROM CovidDeaths as cd
JOIN CovidVaccinated as cv
 ON cd.location = cv.location
 and cd.date = cv.date

-- Looking at total population vs vaccinated

SELECT cd.continent,cd.location,cd.date,cd.population,cv.new_vaccinations,SUM(CONVERT(int,cv.new_vaccinations)) OVER (PARTITION BY cd.location ORDER BY cd.location,cd.date) as RollingVaccinatedCount
FROM CovidDeaths as cd
JOIN CovidVaccinated as cv
 ON cd.location = cv.location
 and cd.date = cv.date
 WHERE cd.continent is not null
 ORDER BY 2,3

 -- Creating a View

 CREATE VIEW TotalCountWorld AS
 SELECT continent,MAX(total_cases) as TotalCasesCount
FROM CovidDeaths
WHERE continent is not null
GROUP BY continent
