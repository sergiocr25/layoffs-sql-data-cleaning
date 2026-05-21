select * from layoffs;

create table layoffs_testing like layoffs;

insert layoffs_testing select * from layoffs;

-- Empezamos creando nuestra tabla de testing

select * from layoffs_testing;

-- DUPLICATES

SELECT 
    company,
    location,
    industry,
    total_laid_off,
    date,
    stage, 
    country,
    funds_raised_millions,
    COUNT(*) as n_veces
FROM layoffs_testing
GROUP BY 
    company,
    location,
    industry,
    total_laid_off,
    date,
    stage, 
    country,
    funds_raised_millions
HAVING COUNT(*) > 1;

 -- Vemos cuantos duplicados hay

CREATE TABLE layoffs_clean AS
WITH cte_duplicados AS (
    SELECT *,
        ROW_NUMBER() OVER(
            PARTITION BY 
                company,
                location,
                industry,
                total_laid_off,
                date,
                stage,
                country,
                funds_raised_millions
        ) as fila
    FROM layoffs
)

SELECT *
FROM cte_duplicados
WHERE fila = 1;

select * from layoffs_clean 
where fila = 1;

/*Creamos una nueva tabla con la columna "fila"
la cual clasifica los duplicados, pero solo seleccionamos aquellos que son = 1
es decir, dejamos fuera los != 1 para ya no tener los duplicados */

/*Eliminamos la tabla testing que creamos al principio para encontrar duplicados
y renombramos la nueva tabla. */

RENAME TABLE layoffs_clean TO layoffs_staging;

-- STANDARIZING

-- Buscamos patrones

-- Tienen espacios en blancos, los corregimos.

select distinct industry, trim(industry) 
from layoffs_staging;

update layoffs_staging 
set industry = trim(industry);

-- Hay datos que son los mismos repetidos

select distinct industry
from layoffs_staging
order by 1;

select * from layoffs_staging
where industry like 'Crypto%'
order by industry;

update layoffs_staging
set industry = 'Crypto'
where industry like 'Crypto%';

select industry from layoffs_staging
where industry != 'Crypto'
order by industry;

select distinct industry
from layoffs_staging
where (
industry like 'Crypto%'
or industry like '%Crypto'
)
AND industry != 'Crypto';

-- Tienen espacios en blancos, los corregimos.

select distinct company, trim(company)
from layoffs_staging;

update layoffs_staging 
set company = trim(company);

select distinct company
from layoffs_staging
order by 1;

select distinct company
from layoffs_staging 
where company like 'Elem%';

select distinct company
from layoffs_staging 
where company like 'Bit%';

-- Parece que no hay repetidos, que no está de más revisarlo de nuevo.

select distinct * from 
layoffs_staging;

select distinct location 
from layoffs_staging
order by location; 

select distinct location, trim(location)
from layoffs_staging order by location;

update layoffs_staging
set location = trim(location); 

-- No había ninguna fila afectada, eso es bueno.

select * from layoffs_staging;

select distinct country, trim(country)
from layoffs_staging
order by country asc;

update layoffs_staging
set country = trim(country);

-- 0 rows affected

select distinct country, trim(country)
from layoffs_staging
order by country desc;

-- Problemas con (United States. United States)

update layoffs_staging
set country = 'United States'
where country = 'United States.';

-- Seguimos buscando

select * from layoffs_staging;

-- Vamos a trabajar el tipo de date (ahora mismo es text)

select date, str_to_date(date, '%m/%d/%Y') 
as converted_date
from layoffs_staging
order by date asc;

update layoffs_staging
set date = str_to_date(date, '%m/%d/%Y');

select date from layoffs_staging
order by date asc;

/*Casi listo, pero tenemos que hacer alter table,
no vale solo con updatear y ya. */

alter table layoffs_staging
modify column date date;

-- Ahora SÍ está parseado!!!

select * from layoffs_staging;

/*Quiero comprobar si percentage_laid_off tiene algún
valor > 1. */

select count(percentage_laid_off) from layoffs_staging
where percentage_laid_off >= 1; -- 116 = 1, no hay mayores de 1. 116 empresas a la quiebra

select count(percentage_laid_off) from layoffs_staging; -- 1572

select * from layoffs_staging;

select distinct stage 
from layoffs_staging
order by stage asc;

-- stage está todo bien

-- SIGUIENTE PASO ES NULL & BLANKS VALUES

select *  from layoffs_staging; 

select * from layoffs_staging
where total_laid_off is null;

select count(*) from layoffs_staging
where total_laid_off is null; -- 739 nulls

select total_laid_off, percentage_laid_off from layoffs_staging
order by total_laid_off asc, percentage_laid_off asc;

select * from layoffs_staging
where total_laid_off is null
and percentage_laid_off is null;

select count(*) from layoffs_staging
where total_laid_off is null
and percentage_laid_off is null; -- 361 nulls en ambas columnas

/*vamos a eliminar aquellos que sean nulls en cualquiera de las 2 columnas
porque si no sabemos el total no sabes la magnitud real
y si no sabes el percentage, no sabes la relativa... no tiene mucho sentido
mantenerlo. */

-- antes vamos a ver cuantas filas perderíamos

select count(*) from layoffs_staging
where total_laid_off is null 
or percentage_laid_off is null;

/*1162 filas vamos a perder, pero es que claro si el dataset va de despidos
y no tenemos ambas columnas, no podemos hacer mucho... */

-- antes vamos a seguir viendo otros apartados por si podemos salvar alguno

select * from layoffs_staging
order by company asc;

/*
He encontrado que Airbnb tiene como industria travel y
un valor blank... eso hay que corregirlo
*/

select * from layoffs_staging
where company = 'Airbnb';

select t1.industry, t2.industry
from layoffs_staging t1
join layoffs_staging t2
	on t1.company = t2.company
where (t1.industry is null or t1.industry = '')
and t2.industry is not null;

/*
seleccioname aquellos que la compañía sean iguales pero
la industria de uno sea null or blank y la otra no, vamos a 
updatearlo, pero así directamente no funciona, ya lo he probado
tenemos que cambiar los blanks por nulls primero y luego ya updatear
*/

update layoffs_staging
set industry = null
where industry = '';

update layoffs_staging t1
join layoffs_staging t2
	on t1.company = t2.company
set t1.industry = t2.industry
where (t1.industry is null)
and t2.industry is not null;

select * from layoffs_staging
where industry is null or
industry = '';

select * from layoffs_staging
where company like 'Ball%';

/*
No podemos hacer nada por arreglar el último que nos queda
*/

select * from layoffs_staging;

/*
No creo que podamos hacer mucho más, vamos a limpiar columnas y cosas que
sean irrelevantes.
*/

select count(*) from layoffs_staging
where total_laid_off is null 
or percentage_laid_off is null;

select count(*) from layoffs_staging
where total_laid_off is null 
and percentage_laid_off is null;

/*
Tengo dudas en cual eliminar, por ahora solo los que tienen ambos...
aunque no estoy 100% seguro si también deberían ser alguna de las 2 nulls
motivo de delete...
*/

delete from layoffs_staging
where total_laid_off is null 
and percentage_laid_off is null;

select * from layoffs_staging;

/*
Eliminamos la columna fila que hicimos para 
identificar duplicados
*/

alter table layoffs_staging
drop column fila;

select * from layoffs_staging;

/*
Sería de gran ayudar tener la columna total de los empleados para así
poder calcular el total_laid_off con el percentage y viceversa
para poder calcular percentage_laid_off con el total_laid_off y el total.

Esto termina por aquí la limpieza de este dataset.
*/

/*
Pasamos con la visualización, un poco de análisis exploratorio etc.
*/

-- vamos a mirar por ejemplo, cual ha sido el peor mes (en cuanto a despidos)

select year(date), month(date), sum(total_laid_off) as total_despedidos
from layoffs_staging where total_laid_off is not null
group by year(date), month(date)
order by total_despedidos desc;

-- cuál fue el peor año?

select year(date), sum(total_laid_off) as total_despedidos
from layoffs_staging where total_laid_off is not null
group by year(date);

/*
Al hacer esa query encontramos que tenemos 1 dato sin fecha
*/

select * from layoffs_staging
where date is null;

select * from layoffs_staging
where company like 'Black%';

-- ¿Qué empresas despidieron más gente?

select company, sum(total_laid_off) as total
from layoffs_staging
where total_laid_off is not null
group by company order by total desc;

-- Qué empresas despidieron a más gente en proporción?

select company, percentage_laid_off 
from layoffs_staging
where percentage_laid_off <= 1
and percentage_laid_off > 0.5
order by percentage_laid_off desc;

-- Qué países sufrieron más despidos?

select country, sum(total_laid_off) as total_por_paises
from layoffs_staging
where total_laid_off is not null
group by country order by total_por_paises desc;

-- Y por ciudades y países?

select country, location, sum(total_laid_off) as total_despidos
from layoffs_staging
where total_laid_off is not null
group by country, location order by total_despidos desc;

-- Qué industrias fueron las más afectadas?

select industry, sum(total_laid_off) as total_despidos_industry
from layoffs_staging
where total_laid_off is not null
group by industry order by total_despidos_industry desc;

-- Y las más resistentes?

select industry, sum(total_laid_off) as total_despidos_industry
from layoffs_staging
where total_laid_off is not null
group by industry order by total_despidos_industry asc;

-- El estar en bolsa y tal afecta a los despidos?

select * from layoffs_staging;

select stage, sum(total_laid_off) as total_per_stage
from layoffs_staging
where total_laid_off is not null
group by stage order by total_per_stage desc; -- tenemos nulls

select * from layoffs_staging
where stage is null;

-- Cómo se iban acumulando los despidos en alguna empresa (por ejemplo amazon)?

select industry, date, sum(total_laid_off) as despidos_dia,
sum(sum(total_laid_off)) over(order by date) as rolling_total
from layoffs_staging
where total_laid_off is not null
and date is not null
and industry like 'Consum%'
group by industry, date order by date;

-- Cuál fue el top 5 peores días de industry = Consumer?

select industry, date, sum(total_laid_off) total_despidos
from layoffs_staging 
where industry like 'Consu%'
and total_laid_off is not null
and date is not null
group by industry, date order by total_despidos desc
limit 5;

/*
Por qué usamos sum y no max, si queremos saber el maximo de despidos
en un día? porque max es si fuera una empresa en concreto por ejemplo
sería tratarlo a nivel individual y sum es si el total lo componen varios,
en este caso industry está formado por varias empresas que despidieron a 
gente ese mismo día, por eso es sum y no max.
*/

/* 
Qué empresas fueron ese top 5 (ahora si es max, pq miramos
a nivel individual)
*/

select company, date, max(total_laid_off) total_despidos
from layoffs_staging 
where total_laid_off is not null
and date is not null
group by company, date order by total_despidos desc
limit 5;

-- tener más financiación implica más despidos?

select company, funds_raised_millions, sum(total_laid_off) total_despidos
from layoffs_staging
where funds_raised_millions is not null
and total_laid_off is not null
group by company, funds_raised_millions order by funds_raised_millions desc;

-- Qué países tienen más despidos por año?

select country, year(date), sum(total_laid_off) as total
from layoffs_staging
where date is not null
and total_laid_off is not null
and country is not null
group by country, year(date) order by total desc;







