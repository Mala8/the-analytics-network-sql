-- ## Semana 1 - Parte A
-- 1. Mostrar todos los productos dentro de la categoria electro junto con todos los detalles.
select *
from stg.product_master
where categoria = 'Electro';
-- 2. Cuales son los producto producidos en China?
select 
	product_code,
	name,
	origin
from stg.product_master
where origin = 'China';
-- 3. Mostrar todos los productos de Electro ordenados por nombre.
select
	name,
	category
from stg.product_master
where category = 'Electro'
order by name;
-- 4. Cuales son las TV que se encuentran activas para la venta?
select *
from stg.product_master
where subcategory = 'TV'
and is_active = 'true'; 
-- 5. Mostrar todas las tiendas de Argentina ordenadas por fecha de apertura de las mas antigua a la mas nueva.
select *
from stg.store_master
where country = 'Argentina'
order by start_date asc;
-- 6. Cuales fueron las ultimas 5 ordenes de ventas?
select *
from stg.order_line_sale
order by date desc
limit 5;
-- 7. Mostrar los primeros 10 registros de el conteo de trafico por Super store ordenados por fecha.
select *
from stg.super_store_count
order by date
limit 10;
-- 8. Cuales son los producto de electro que no son Soporte de TV ni control remoto.
select *
from stg.product_master
where category = 'Electro'
and subsubcategory != 'Soporte'
and subsubcategory != 'Control remoto';
-- 9. Mostrar todas las lineas de venta donde el monto sea mayor a $100.000 solo para transacciones en pesos.
select *
from stg.order_line_sale
where sale > 100000
and currency = 'ARS';
-- 10. Mostrar todas las lineas de ventas de Octubre 2022.
select * 
From stg.order_line_sale
where date between '2022-10-01' and '2022-10-31';
-- 11. Mostrar todos los productos que tengan EAN.
select *
from stg.product_master
where ean is not null;
-- 12. Mostrar todas las lineas de venta que que hayan sido vendidas entre 1 de Octubre de 2022 y 10 de Noviembre de 2022.
select * 
from stg.order_line_sale
where date between '2022-10-01' and '2022-11-10';

-- ## Semana 1 - Parte B
-- 1. Cuales son los paises donde la empresa tiene tiendas?
select distinct country as Paises
from stg.store_master;
-- 2. Cuantos productos por subcategoria tiene disponible para la venta?
select 
	subcategory, 
	count (distinct product_code)
from stg.product_master
where is_active = 'true'
group by subcategory;
--Otra forma--
select 
	subcategory, 
	count(*) as cantidad_de_productos
from stg.product_master
group by subcategory;
-- 3. Cuales son las ordenes de venta de Argentina de mayor a $100.000?
select 
	os.order_number,
	round(os.sale,2)
from stg.order_line_sale os
left join stg.store_master sm
on os.store = sm.store_id
where country = 'Argentina'
and sale > 100000;
-- 4. Obtener los decuentos otorgados durante Noviembre de 2022 en cada una de las monedas?
select
	currency,
	round(sum(promotion),2) Discount
from stg.order_line_sale
where date between '2022-11-01' and '2022-11-30'
group by
	currency;
-- 5. Obtener los impuestos pagados en Europa durante el 2022.
select 
	currency,
	round(sum(tax),2) tax
from stg.order_line_sale
where currency = 'EUR'
and date between '2022-01-01' and '2022-12-31'
group by currency;
-- 6. En cuantas ordenes se utilizaron creditos?
select
	count(distinct order_number) count_credit
from stg.order_line_sale
where credit is not null;
-- 7. Cual es el % de descuentos otorgados (sobre las ventas) por tienda?
select
	store,
	round((sum(promotion)/sum(sale)),4) *100 as Disscount
from stg.order_line_sale ols
group by
	store
order by
	store;
-- 8. Cual es el inventario promedio por dia que tiene cada tienda?
select 
	date,
	store_id,
	round(avg((initial + final)/2),2)
from stg.inventory
group by
	date,
	store_id
order by
	date;
-- 9. Obtener las ventas netas y el porcentaje de descuento otorgado por producto en Argentina.
select
	product,
	round(sum(sale)-sum(promotion),0) as NetSale,
	round((sum(promotion) / sum(sale))*100,2) as PerDisscount
from stg.order_line_sale ols
left join stg.store_master sm
on ols.store = sm.store_id
where sm.country = 'Argentina'
group by
	product;
-- 10. Las tablas "market_count" y "super_store_count" representan dos sistemas distintos que usa la empresa para contar la cantidad de gente que ingresa a tienda, uno para las tiendas de Latinoamerica y otro para Europa. Obtener en una unica tabla, las entradas a tienda de ambos sistemas.
select
	store_id,
	TO_DATE(CAST(date AS VARCHAR), 'YYYYMMDD') date,
	traffic
from stg.market_count 
union all
select
	store_id,
	TO_DATE(date, 'YYYY-MM-DD') date,
	traffic
from stg.super_store_count
order by
	store_id,
	date;
-- 11. Cuales son los productos disponibles para la venta (activos) de la marca Phillips?
select *
from stg.product_master
where name like '%PHILIPS%'
and is_active = 'true';
-- 12. Obtener el monto vendido por tienda y moneda y ordenarlo de mayor a menor por valor nominal de las ventas (sin importar la moneda).
select 
	store,
	round(sum(sale),0) sale,
	currency
from stg.order_line_sale
group by 
	store,
	currency
order by sale desc;
-- 13. Cual es el precio promedio de venta de cada producto en las distintas monedas? Recorda que los valores de venta, impuesto, descuentos y creditos es por el total de la linea.
select
	ols.product,
	ols.currency,
	avg(sale+coalesce(tax,0)-coalesce(promotion,0)-coalesce(credit,0)/quantity) as AVGPrice
from stg.order_line_sale ols
group by
	ols.product,
	ols.currency;
-- 14. Cual es la tasa de impuestos que se pago por cada orden de venta?
Select
	order_number,
	round((sum(coalesce(tax,0)) / sum(sale))*100,2) TaxRate
from stg.order_line_sale
group by
	order_number;
-- ## Semana 2 - Parte A
-- 1. Mostrar nombre y codigo de producto, categoria y color para todos los productos de la marca Philips y Samsung, mostrando la leyenda "Unknown" cuando no hay un color disponible
select 
	name,
	product_code,
	category,
	coalesce(color,'unknown') color -- tambien podemos utilizar el CASE WHEN color IS NULL -- THEN 'Unknown' --ELSE color -- END AS color
from stg.product_master pm
where upper(name) like '%PHILIPS%'
or upper(name) like '%SAMSUNG%';
-- 2. Calcular las ventas brutas y los impuestos pagados por pais y provincia en la moneda correspondiente.
select 
	country,
	province,
	round(sum(sale),2) Gross_sale,
	round(sum(tax),2) Tax,
	currency
from stg.order_line_sale ols
left join stg.store_master sm
on ols.store = sm.store_id
group by
	country,
	province,
	currency;
-- 3. Calcular las ventas totales por subcategoria de producto para cada moneda ordenados por subcategoria y moneda.
select 
	subcategory,
	round(sum(sale),0) Sale,
	currency
from stg.order_line_sale ols
left join stg.product_master pm
on ols.product = pm.product_code
group by 
	subcategory,
	currency
order by
	subcategory,
	currency;
-- 4. Calcular las unidades vendidas por subcategoria de producto y la concatenacion de pais, provincia; usar guion como separador y usarla para ordernar el resultado.
select 
	pm.subcategory,
	concat(sm.country,'-',sm.province) Pais_Provincia,
	sum(ols.quantity) Unidades_Vendidas
from stg.order_line_sale ols
left join stg.product_master pm
on pm.product_code = ols.product
left join stg.store_master sm
on ols.Store = sm.store_id
group by
	pm.subcategory,
	Pais_Provincia
order by
	Pais_Provincia;
-- 5. Mostrar una vista donde sea vea el nombre de tienda y la cantidad de entradas de personas que hubo desde la fecha de apertura para el sistema "super_store".
select 
	sm.name tienda,
	sum(ssc.Traffic) entradas
from stg.store_master sm
inner join stg.super_store_count ssc
on sm.store_id = ssc.store_id
and sm.star_date <= cast(ssc.date as date)
group by
	tienda
order by
	tienda  
-- 6. Cual es el nivel de inventario promedio en cada mes a nivel de codigo de producto y tienda; mostrar el resultado con el nombre de la tienda.
select 
	sm.name Tienda,
	i.item_id CodigoProducto,
	to_char(i.date, 'mm') Mes,
	round(avg((i.initial + i.final)/2),2) InventarioPromedio
from stg.inventory i
left join stg.store_master sm
on i.store_id = sm.store_id
group by
	Tienda,
	CodigoProducto,
	Mes;  
-- 7. Calcular la cantidad de unidades vendidas por material. Para los productos que no tengan material usar 'Unknown', homogeneizar los textos si es necesario.
select 
	case
		when material is null then 'unknown'
		when material = 'PLASTICO' then lower(material)
		else material
		end as material_nuevo,
	sum(ols.quantity) as cantidad_vendida
from stg.order_line_sale ols
left join stg.product_master pm
on ols.product = pm.product_code
group by
	material_nuevo
-- 8. Mostrar la tabla order_line_sales agregando una columna que represente el valor de venta bruta en cada linea convertido a dolares usando la tabla de tipo de cambio.
 select ols.*
 ,case
		when currency = 'ARS' then (coalesce(sale,0) /fx_rate_usd_peso)
		when currency = 'EUR' then (coalesce(sale,0) /fx_rate_usd_eur)
		when currency = 'URU' then (coalesce(sale,0) /fx_rate_usd_uru)
		else sale
	end as VentasUSD
from stg.order_line_sale ols
left join stg.monthly_average_fx_rate fx
on date_trunc('month',ols.date) = fx.month
;
-- 9. Calcular cantidad de ventas totales de la empresa en dolares.
  
-- 10. Mostrar en la tabla de ventas el margen de venta por cada linea. Siendo margen = (venta - descuento) - costo expresado en dolares.
  
-- 11. Calcular la cantidad de items distintos de cada subsubcategoria que se llevan por numero de orden.
  

-- ## Semana 2 - Parte B

-- 1. Crear un backup de la tabla product_master. Utilizar un esquema llamada "bkp" y agregar un prefijo al nombre de la tabla con la fecha del backup en forma de numero entero.
  
-- 2. Hacer un update a la nueva tabla (creada en el punto anterior) de product_master agregando la leyendo "N/A" para los valores null de material y color. Pueden utilizarse dos sentencias.
  
-- 3. Hacer un update a la tabla del punto anterior, actualizando la columa "is_active", desactivando todos los productos en la subsubcategoria "Control Remoto".
  
-- 4. Agregar una nueva columna a la tabla anterior llamada "is_local" indicando los productos producidos en Argentina y fuera de Argentina.
  
-- 5. Agregar una nueva columna a la tabla de ventas llamada "line_key" que resulte ser la concatenacion de el numero de orden y el codigo de producto.
  
-- 6. Crear una tabla llamada "employees" (por el momento vacia) que tenga un id (creado de forma incremental), name, surname, start_date, end_name, phone, country, province, store_id, position. Decidir cual es el tipo de dato mas acorde.
  
-- 7. Insertar nuevos valores a la tabla "employees" para los siguientes 4 empleados:
    -- Juan Perez, 2022-01-01, telefono +541113869867, Argentina, Santa Fe, tienda 2, Vendedor.
    -- Catalina Garcia, 2022-03-01, Argentina, Buenos Aires, tienda 2, Representante Comercial
    -- Ana Valdez, desde 2020-02-21 hasta 2022-03-01, España, Madrid, tienda 8, Jefe Logistica
    -- Fernando Moralez, 2022-04-04, España, Valencia, tienda 9, Vendedor.

  
-- 8. Crear un backup de la tabla "cost" agregandole una columna que se llame "last_updated_ts" que sea el momento exacto en el cual estemos realizando el backup en formato datetime.
  
-- 9. En caso de hacer un cambio que deba revertirse en la tabla order_line_sale y debemos volver la tabla a su estado original, como lo harias? Responder con palabras que sentencia utilizarias. (no hace falta usar codigo)
