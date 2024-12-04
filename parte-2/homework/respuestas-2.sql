-- ## Semana 3 - Parte A

-- 1.Crear una vista con el resultado del ejercicio donde unimos la cantidad de gente que ingresa a tienda usando los dos sistemas.(tablas market_count y super_store_count)
-- . Nombrar a la lista `stg.vw_store_traffic`
-- . Las columnas son `store_id`, `date`, `traffic`
create or replace view stg.vw_store_traffic as (
select
	mc.store_id,
	TO_DATE(CAST(mc.date AS VARCHAR), 'YYYYMMDD') date,
	mc.traffic
from stg.market_count mc
union all
select
	ssc.store_id,
	TO_DATE(ssc.date, 'YYYY-MM-DD') date,
	ssc.traffic
from stg.super_store_count ssc
order by
	date,
	store_id
);
-- 2. Recibimos otro archivo con ingresos a tiendas de meses anteriores. Subir el archivo a stg.super_store_count_aug y agregarlo a la vista del ejercicio anterior. Cual hubiese sido la diferencia si hubiesemos tenido una tabla? (contestar la ultima pregunta con un texto escrito en forma de comentario)
create table if not exists stg.super_store_count_aug(
	store_id smallint,
	date character varying(10),
	traffic smallint);
	
create or replace view stg.vw_store_traffic as (
select
	mc.store_id,
	TO_DATE(CAST(mc.date AS VARCHAR), 'YYYYMMDD') date,
	mc.traffic
from stg.market_count mc
union all
select
	ssc.store_id,
	TO_DATE(ssc.date, 'YYYY-MM-DD') date,
	ssc.traffic
from stg.super_store_count ssc
union all
select 
	ssca.store_id,
	to_date(ssca.date, 'YYYY-MM-DD') date,
	ssca.traffic
from stg.super_store_count_aug ssca
order by
	date,
	store_id
);
-- 3. Crear una vista con el resultado del ejercicio del ejercicio de la Parte 1 donde calculamos el margen bruto en dolares. Agregarle la columna de ventas, promociones, creditos, impuestos y el costo en dolares para poder reutilizarla en un futuro. Responder con el codigo de creacion de la vista.
-- El nombre de la vista es stg.vw_order_line_sale_usd
-- Los nombres de las nuevas columnas son sale_usd, promotion_usd, credit_usd, tax_usd, y line_cost_usd
create or replace view stg.vw_order_line_sale_usd as (
	
with stg_sales_usd as (
	
SELECT 
	ols.*,
	case -- Convierte sales por el rate de la fecha s/ moneda
		when currency = 'ARS' then (coalesce(sale,0)/fx_rate_usd_peso)
		when currency = 'EUR' then (coalesce(sale,0)/fx_rate_usd_eur)
		when currency = 'URU' then (coalesce(sale,0)/fx_rate_usd_uru)
		else sale
	end as sales_usd,
	case -- convierte promotion por el rate de la fecha s/ moneda
		when currency = 'ARS' then (coalesce(promotion,0)/fx_rate_usd_peso)
		when currency = 'EUR' then (coalesce(promotion,0)/fx_rate_usd_eur)
		when currency = 'URU' then (coalesce(promotion,0)/fx_rate_usd_uru)
		else promotion
	end as promotion_usd,
	case-- convierte credit por el rate de la fecha s/ moneda
		when currency = 'ARS' then (coalesce(credit,0)/fx_rate_usd_peso)
		when currency = 'EUR' then (coalesce(credit,0)/fx_rate_usd_eur)
		when currency = 'URU' then (coalesce(credit,0)/fx_rate_usd_uru)
		else credit
	end as credit_usd,
	case -- convierte Tax por el rate de la fecha s/ moneda
		when currency = 'ARS' then (coalesce(tax,0)/fx_rate_usd_peso)
		when currency = 'EUR' then (coalesce(tax,0)/fx_rate_usd_eur)
		when currency = 'URU' then (coalesce(tax,0)/fx_rate_usd_uru)
		else tax
	end as tax_usd,
	(cs.product_cost_usd * ols.quantity) as line_cost_usd -- calcula el costo en usd por linea
FROM stg.order_line_sale ols	
left join stg.monthly_average_fx_rate fx
on date_trunc('month',ols.date) = fx.month 
left join stg.cost cs 
on ols.product = cs.product_code
left join stg.store_master sm 
on ols.store = sm.store_id
left join stg.product_master pm
on ols.product = pm.product_code
left join stg.supplier sp
on ols.product = sp.product_id
where sp.is_primary = true
)

select * from stg_sales_usd
);
-- 4. Generar una query que me sirva para verificar que el nivel de agregacion de la tabla de ventas (y de la vista) no se haya afectado. Recordas que es el nivel de agregacion/detalle? Lo vimos en la teoria de la parte 1! Nota: La orden M202307319089 parece tener un problema verdad? Lo vamos a solucionar mas adelante.
-- Verificación del nivel de agregación, busqueda de duplicados.
select 
	order_number,
	product,
	count(order_number)
from stg.vw_order_line_sale_usd
group by
	order_number,
	product
HAVING
	count(order_number) >1;

-- Verificar duplicado con windows function row_number
with rn_duplicados as (
select 
	order_number,
	product,
	row_number() over(partition by order_number,product order by product) as rn
from stg.vw_order_line_sale_usd
)
select *
from rn_duplicados
where rn > 1;
	
--Orden duplicada
select *
from stg.vw_order_line_sale_usd
where order_number = 'M202307319089';
-- 5. Calcular el margen bruto a nivel Subcategoria de producto. Usar la vista creada stg.vw_order_line_sale_usd. La columna de margen se llama margin_usd
with margin_usd as(
select ols.*,
	pm.subcategory,
	sales_usd - promotion_usd- line_cost_usd as margin_usd
from stg.vw_order_line_sale_usd ols
left join stg.product_master pm
on ols.product = pm.product_code
)

select 
	subcategory,
	margin_usd
from margin_usd;

-- 6. Calcular la contribucion de las ventas brutas de cada producto al total de la orden.
with cte as(
select ols.*,
	sum(sales_usd) over(partition by order_number order by order_number) as sales_line
from stg.vw_order_line_sale_usd ols
)

select 
	cte.order_number,
	cte.product,
	sales_usd / sales_line as sales_contribution
FROM cte;
-- 7. -- Calcular las ventas por proveedor, para eso cargar la tabla de proveedores por producto. Agregar el nombre el proveedor en la vista del punto stg.vw_order_line_sale_usd. El nombre de la nueva tabla es stg.suppliers

-- creando la tabla
create table if not exists (
product_id character varying (10),
name character varying (255),
is_primary boolean);
-- Reemplazando la vista y agregando el nombre del proveedor
create or replace view stg.vw_order_line_sale_usd as (
	
with stg_sales_usd as (
	
SELECT 
	ols.*,
	case -- Convierte sales por el rate de la fecha s/ moneda
		when currency = 'ARS' then (coalesce(sale,0)/fx_rate_usd_peso)
		when currency = 'EUR' then (coalesce(sale,0)/fx_rate_usd_eur)
		when currency = 'URU' then (coalesce(sale,0)/fx_rate_usd_uru)
		else sale
	end as sales_usd,
	case -- convierte promotion por el rate de la fecha s/ moneda
		when currency = 'ARS' then (coalesce(promotion,0)/fx_rate_usd_peso)
		when currency = 'EUR' then (coalesce(promotion,0)/fx_rate_usd_eur)
		when currency = 'URU' then (coalesce(promotion,0)/fx_rate_usd_uru)
		else promotion
	end as promotion_usd,
	case-- convierte credit por el rate de la fecha s/ moneda
		when currency = 'ARS' then (coalesce(credit,0)/fx_rate_usd_peso)
		when currency = 'EUR' then (coalesce(credit,0)/fx_rate_usd_eur)
		when currency = 'URU' then (coalesce(credit,0)/fx_rate_usd_uru)
		else credit
	end as credit_usd,
	case -- convierte Tax por el rate de la fecha s/ moneda
		when currency = 'ARS' then (coalesce(tax,0)/fx_rate_usd_peso)
		when currency = 'EUR' then (coalesce(tax,0)/fx_rate_usd_eur)
		when currency = 'URU' then (coalesce(tax,0)/fx_rate_usd_uru)
		else tax
	end as tax_usd,
	(cs.product_cost_usd * ols.quantity) as line_cost_usd,-- calcula el costo en usd por linea
	sp.name
FROM stg.order_line_sale ols	
left join stg.monthly_average_fx_rate fx
on date_trunc('month',ols.date) = fx.month 
left join stg.cost cs 
on ols.product = cs.product_code
left join stg.store_master sm 
on ols.store = sm.store_id
left join stg.product_master pm
on ols.product = pm.product_code
left join stg.supplier sp
on ols.product = sp.product_id
where sp.is_primary = true
)

select * from stg_sales_usd
);
-- 8. Verificar que el nivel de detalle de la vista stg.vw_order_line_sale_usd no se haya modificado, en caso contrario que se deberia ajustar? Que decision tomarias para que no se genereren duplicados?
    -- - Se pide correr la query de validacion.
    -- - Modificar la query de creacion de stg.vw_order_line_sale_usd  para que no genere duplicacion de las filas. 
    -- - Explicar brevemente (con palabras escrito tipo comentario) que es lo que sucedia.

-- Query validación de duplicados
select 
	order_number,
	product,
	store,
	date,
	count(order_number)
from stg.vw_order_line_sale_usd
group by
	order_number,
	product,
	store,
	date
having
	count(order_number) >1
-- Se encuenta la orden "M202307319089" que ya estaba duplicada.
-- Para que no se dupliquen se debe colocar la clausula where para los proveedores primarios, de esa forma se tiene los mismos registros que la OLS.
-- Ya que un producto puede tener mas de un proveedor y eso generaría duplicados.


-- ## Semana 3 - Parte B

-- 1. Calcular el porcentaje de valores null de la tabla stg.order_line_sale para la columna creditos y descuentos. (porcentaje de nulls en cada columna)
with count_null as(
select
	sum(case when promotion is null then 1 else 0 end) as promotion_null, -- No tiene en cuenta los null
	sum(case when promotion is not null then 1 else 1 end) as promotion_total, -- Tiene en cuenta los null
	sum(case when credit is null then 1 else 0 end) as credit_null,
	sum(case when credit is not null then 1 else 1 end) as credit_total
from stg.order_line_sale ols
)
select 
	((promotion_null)*1.0 / (promotion_total)*1.0)*100 as per_promotion_null,
	((credit_null)*1.0 / (credit_total)*1.0)*100 as per_credit_null
from count_null;
-- 2. La columna is_walkout se refiere a los clientes que llegaron a la tienda y se fueron con el producto en la mano (es decia habia stock disponible). Responder en una misma query:
   --  - Cuantas ordenes fueron walkout por tienda?
   --  - Cuantas ventas brutas en USD fueron walkout por tienda?
   --  - Cual es el porcentaje de las ventas brutas walkout sobre el total de ventas brutas por tienda?
with walkout as(
select 
	store,
	sum(case when is_walkout = true then 1 else 0 end) as sum_walkout,
	sum(case when is_walkout =true then sale_usd else 0 end) walkout_sales_usd,
	sum(sale_usd) as gross_sales_by_store
from stg.vw_order_line_sale_usd s
group by 
	store
)

select 
	store,
	sum_walkout,
	walkout_sales_usd,
	(walkout_sales_usd / gross_sales_by_store)*1.0 as perc_gross_by_store
from walkout
order by
	store;
-- 3. Siguiendo el nivel de detalle de la tabla ventas, hay una orden que no parece cumplirlo. Como identificarias duplicados utilizando una windows function? 
-- Tenes que generar una forma de excluir los casos duplicados, para este caso particular y a nivel general, si llegan mas ordenes con duplicaciones.
-- Identificar los duplicados.
-- Eliminar las filas duplicadas. Podes usar BEGIN transaction y luego rollback o commit para verificar que se haya hecho correctamente.

select  -- identifica los duplicados
	order_number,
	product,
	date,
	store,
	row_number() over(partition by order_number,product,date, store order by order_number) as rn
from stg.order_line_sale
)
select 
	order_number,
	product,
	date,
	store
from cte_duplicados
where rn > 1;

begin transaction; -- Para iniciar los cambios en la tabla

with cte_duplicados as( -- identifica los duplicados
select 
	order_number,
	product,
	date,
	store,
	row_number() over(partition by order_number,product,date, store order by order_number) as rn
from stg.order_line_sale
)

delete from stg.order_line_sale -- elimina los duplicados
where (order_number, product, date, store)
in (
select 
	order_number,
	product,
	date,
	store
from cte_duplicados
where rn > 1
);

rollback; -- vuelve atras los cambios si hay error o no es correcto

commit; -- confirma los cambios
-- 4. Obtener las ventas totales en USD de productos que NO sean de la categoria TV NI esten en tiendas de Argentina. Modificar la vista stg.vw_order_line_sale_usd con todas las columnas necesarias. 
select 
	product,
	sum(sales_usd)
from stg.vw_order_line_sale_usd
where country != 'Argentina' and subcategory != 'TV'
group by
	product
order by
	product;
-- 5. El gerente de ventas quiere ver el total de unidades vendidas por dia junto con otra columna con la cantidad de unidades vendidas una semana atras y la diferencia entre ambos.Diferencia entre las ventas mas recientes y las mas antiguas para tratar de entender un crecimiento.
with day_sale_week as(
select 
	s2.date as day_sale,
	sum(s2.quantity) as qty_day_sale,
	s1.date as prev_week,
	sum(s1.quantity) as qty_prev_week
from stg.vw_order_line_sale_usd s1
inner join stg.vw_order_line_sale_usd s2
on s1.product = s2.product
and s1.store = s2.store
and s1.date = s2.date - interval '1 week'
group by
	prev_week,
	day_sale
order by
	prev_week
)

select 
	day_sale,
	qty_day_sale,
	prev_week,
	qty_prev_week,
	qty_day_sale - qty_prev_week as diff_qty
from day_sale_week;
-- 6. Crear una vista de inventario con la cantidad de inventario promedio por dia, tienda y producto, que ademas va a contar con los siguientes datos:
/* - Nombre y categorias de producto: `product_name`, `category`, `subcategory`, `subsubcategory`
- Pais y nombre de tienda: `country`, `store_name`
- Costo del inventario por linea (recordar que si la linea dice 4 unidades debe reflejar el costo total de esas 4 unidades): `inventory_cost`
- Inventario promedio: `avg_inventory`
- Una columna llamada `is_last_snapshot` para el inventario de la fecha de la ultima fecha disponible. Esta columna es un campo booleano.
- Ademas vamos a querer calcular una metrica llamada "Average days on hand (DOH)" `days_on_hand` que mide cuantos dias de venta nos alcanza el inventario. Para eso DOH = Unidades en Inventario Promedio / Promedio diario Unidades vendidas ultimos 7 dias.
- El nombre de la vista es `stg.vw_inventory`
- Notas:
    - Antes de crear la columna DOH, conviene crear una columna que refleje el Promedio diario Unidades vendidas ultimos 7 dias. `avg_sales_last_7_days`
    - El nivel de agregacion es dia/tienda/sku.
    - El Promedio diario Unidades vendidas ultimos 7 dias tiene que calcularse para cada dia.
*/
create or replace view stg.vw_inventory as (

with stg_last_snapshot as ( -- calcula la última fecha de la tabla inventario
select 
	max(date) as date
from stg.inventory i
)

, stg_sales as ( -- calcula la cantidad de vendida de la tabla ventas
select
	date,
	store,
	product,
	sum(quantity) as quantity
from stg.order_line_sale s	
group by
	date,
	store,
	product
)
	
,stg_inventory as ( -- tabla inventario con agregaciones
Select 
	i.date,
	pm.product_code,
	sm.store_id,
	pm.name as product_name,
	pm.category, 
	pm.subcategory,
	pm.subsubcategory,
	sm.country,
	sm.name as store_name,
	cs.product_cost_usd,
	i.final * cs.product_cost_usd as inventory_cost,
	i.initial,
	i.final,
	quantity,
	(i.initial + i.final)/2 as avg_inventory,
	case when ls.date is null then False else true end as is_last_snapshot,
	avg(quantity) over(partition by sm.store_id, pm.product_code order by i.date rows between 7 preceding and current row) as sales_last_7_days -- calcula el promedio de ventas de los ultimos 7 días particionado por tienda y producto
from stg.inventory i
left join stg.store_master sm 
on i.store_id = sm.store_id
left join stg.product_master pm
on i.item_id = pm.product_code
left join stg.cost cs
on i.item_id = cs.product_code
left join stg_last_snapshot ls
on i.date = ls.date
left join stg_sales s
on i.date = s.date
and i.store_id = s.store
and i.item_id = s.product
)

select 
	--date,
	--product_code,
	--store_id,
	product_name,
	category, 
	subcategory,
	subsubcategory,
	country,
	store_name,
	product_cost_usd,
	inventory_cost,
	quantity,
	avg_inventory,
	is_last_snapshot,
	sales_last_7_days,
	(avg_inventory / sales_last_7_days) as days_on_hand
from stg_inventory
	); 

-- ## Semana 4 - Parte A

-- 1. Calcular la contribucion de las ventas brutas de cada producto al total de la orden utilizando una window function. Mismo objetivo que el ejercicio de la parte A pero con diferente metodologia.
with gross_sales as(
select 
	order_number,
	product,
	sum(sales_usd) over(partition by order_number) as total_by_order,
	sum(sales_usd) over(partition by order_number, product) as sale_by_order_product
from stg.vw_order_line_sale_usd
)
select 
	order_number,
	product,
	( sale_by_order_prod /sale_by_order ) as contribution_by_order_line
from gross_sales;
-- 2. La regla de pareto nos dice que aproximadamente un 20% de los productos generan un 80% de las ventas. Armar una vista a nivel sku donde se pueda identificar por orden de contribucion, ese 20% aproximado de SKU mas importantes. Nota: En este ejercicios estamos construyendo una tabla que muestra la regla de Pareto. 
-- El nombre de la vista es `stg.vw_pareto`. Las columnas son, `product_code`, `product_name`, `quantity_sold`, `cumulative_contribution_percentage`
Create or replace view as stg.vw_pareto
with cte1 as (
select 
	s.product as product_code,
	pm.name as product_name,
	sum(s.quantity) as quantity_sold
from stg.order_line_sale s
left join stg.product_master pm
on s.product = pm.product_code
group by
	s.product,
	pm.name
)
	
, cte2 as(
SELECT
	product_code,
	product_name,
	quantity_sold,
	sum(quantity_sold) over() as total_qty,
	sum(quantity_sold) over(order by product_code) quantity_running_sum,
	sum(quantity_sold) over(order by product_code)*1.0 / sum(quantity_sold) over()*1.0 as cumulative_contribution_percentage
from cte1
)

select 
	product_code,
	product_name,
	quantity_sold,
	cumulative_contribution_percentage
from cte2
--where cumulative_contribution_percentage <= 0.80 --si queremos ver cuantos productos suman el 80%
order by
	cumulative_contribution_percentage asc;
-- 3. Calcular el crecimiento de ventas por tienda mes a mes, con el valor nominal y el valor % de crecimiento.
with sales_month as(
select 
	cast(date_trunc('month',s.date) as date) as mes,
	sum(quantity) as qty_sold,
	sum(sale) as sale
from stg.vw_order_line_sale_usd s
left join stg.store_master sm 
on s.store = sm.store_id
group by
	cast(date_trunc('month',s.date) as date)
)
select 
	m1.mes,
	m1.qty_sold as previus_month_qty_sold,
	m1.sale as previus_month_sales,
	m2.mes,
	m2.qty_sold as next_month_sold,
	m2.sale as next_month_sales,
	m2.qty_sold - m1.qty_sold as diff_qty_by_month, -- Diferencia cantidades vendidas mensuales
	(m2.qty_sold - m1.qty_sold)*1.0 / m1.qty_sold*1.0 as growth_qty,-- Crecimiento mensual
	m2.sale - m1.sale as diff_sale_by_month, -- Diferencia monto vendidas mensuales
	(m2.sale - m1.sale)*1.0 / m1.sale*1.0 as growth_sale-- Crecimiento monto mensual
from sales_month m1
inner join sales_month m2 -- Self Join 
on m1.mes = m2.mes - interval '1 month'; -- Se comprar con un mes anterior para sacar la métrica;

-- 4. Crear una vista a partir de la tabla return_movements que este a nivel Orden de venta, item y que contenga las siguientes columnas:
/* - Orden `order_number`
- Sku `item`
- Cantidad unidated retornadas `quantity`
- Fecha: `date` Se considera la fecha de retorno aquella el cual el cliente la ingresa a nuestro deposito/tienda.
- Valor USD retornado (resulta de la cantidad retornada * valor USD del precio unitario bruto con que se hizo la venta) `sale_returned_usd`
- Features de producto `product_name`, `category`, `subcategory`
- `first_location` (primer lugar registrado, de la columna `from_location`, para la orden/producto)
- `last_location` (el ultimo lugar donde se registro, de la columna `to_location` el producto/orden)
- El nombre de la vista es `stg.vw_returns`*/

-- 5. Crear una tabla calendario llamada stg.date con las fechas del 2022 incluyendo el año fiscal y trimestre fiscal (en ingles Quarter). El año fiscal de la empresa comienza el primero Febrero de cada año y dura 12 meses. Realizar la tabla para 2022 y 2023. La tabla debe contener:
/* - Fecha (date) `date`
- Mes (date) `month`
- Año (date) `year`
- Dia de la semana (text, ejemplo: "Monday") `weekday`
- `is_weekend` (boolean, indicando si es Sabado o Domingo)
- Mes (text, ejemplo: June) `month_label`
- Año fiscal (date) `fiscal_year`
- Año fiscal (text, ejemplo: "FY2022") `fiscal_year_label`
- Trimestre fiscal (text, ejemplo: Q1) `fiscal_quarter_label`
- Fecha del año anterior (date, ejemplo: 2021-01-01 para la fecha 2022-01-01) `date_ly`
- Nota: En general una tabla date es creada para muchos años mas (minimo 10), en este caso vamos a realizarla para el 2022 y 2023 nada mas.. 
*/

-- ## Semana 4 - Parte B

-- 1. Calcular el crecimiento de ventas por tienda mes a mes, con el valor nominal y el valor % de crecimiento. Utilizar self join.

-- 2. Hacer un update a la tabla de stg.product_master agregando una columna llamada brand, con la marca de cada producto con la primer letra en mayuscula. Sabemos que las marcas que tenemos son: Levi's, Tommy Hilfiger, Samsung, Phillips, Acer, JBL y Motorola. En caso de no encontrarse en la lista usar Unknown.

-- 3. Un jefe de area tiene una tabla que contiene datos sobre las principales empresas de distintas industrias en rubros que pueden ser competencia y nos manda por mail la siguiente informacion: (ver informacion en md file)
