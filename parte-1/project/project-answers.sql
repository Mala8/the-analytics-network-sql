
-- General
--CTE  ventas General
with stg_sales as (
select
	ols.*,
	(cs.product_cost_usd*ols.quantity) as total_cost,
	pm.Category,
	case
		when currency = 'ARS' then (coalesce(sale,0)/fx_rate_usd_peso)
		when currency = 'EUR' then (coalesce(sale,0)/fx_rate_usd_eur)
		when currency = 'URU' then (coalesce(sale,0)/fx_rate_usd_uru)
		else sale
	end as sales_usd,
	case
		when currency = 'ARS' then (coalesce(promotion,0)/fx_rate_usd_peso)
		when currency = 'EUR' then (coalesce(promotion,0)/fx_rate_usd_eur)
		when currency = 'URU' then (coalesce(promotion,0)/fx_rate_usd_uru)
		else promotion
	end as promotion_usd,
	case
		when currency = 'ARS' then (coalesce(credit,0)/fx_rate_usd_peso)
		when currency = 'EUR' then (coalesce(credit,0)/fx_rate_usd_eur)
		when currency = 'URU' then (coalesce(credit,0)/fx_rate_usd_uru)
		else credit
	end as credit_usd,
	case
		when currency = 'ARS' then (coalesce(tax,0)/fx_rate_usd_peso)
		when currency = 'EUR' then (coalesce(tax,0)/fx_rate_usd_eur)
		when currency = 'URU' then (coalesce(tax,0)/fx_rate_usd_uru)
		else tax
	end as tax_usd
from stg.order_line_sale ols
left join stg.monthly_average_fx_rate fx
on date_trunc('month',ols.date) = fx.month
left join stg.store_master sm
on ols.store = sm.store_id
left join stg.product_master pm
on ols.product = pm.product_code
left join stg.cost cs
on ols.product = cs.product_code
left join stg.supplier sp
on ols.product = sp.product_id
where sp.is_primary = true
);
-- - Ventas brutas, netas y margen (USD)
select 
	extract(year from ols.date) as Year,
	extract(month from ols.date) as Month,
	sum(sales_usd) as sales_usd,
	sum(sales_usd-promotion_usd) as net_sales_usd,
  sum(sales_usd-promotion_usd-tax_usd-total_cost) as margin_usd
from stg_sales ols
group by
	Year,
	Month
order by
	Year,
	Month;
-- - Margen por categoria de producto (USD)
select 
	extract(year from ols.date) as Year,
	extract(month from ols.date) as Month,
	category,
  sum(sales_usd-promotion_usd-tax_usd-total_cost) as margin_usd
from stg_sales ols
group by
	Year,
	Month,
	category
order by
	Year,
	Month;
-- - ROI por categoria de producto. ROI = ventas netas / Valor promedio de inventario (USD)
with stg_sales as (
select
	to_char(date,'YYYY-MM') as year_date,
	category,
	sum(case
		when currency = 'ARS' then (coalesce(sale,0)/fx_rate_usd_peso)
		when currency = 'EUR' then (coalesce(sale,0)/fx_rate_usd_eur)
		when currency = 'URU' then (coalesce(sale,0)/fx_rate_usd_uru)
		else sale
	end) as sales_usd,
	sum(case
		when currency = 'ARS' then (coalesce(promotion,0)/fx_rate_usd_peso)
		when currency = 'EUR' then (coalesce(promotion,0)/fx_rate_usd_eur)
		when currency = 'URU' then (coalesce(promotion,0)/fx_rate_usd_uru)
		else promotion
	end) as promotion_usd
from stg.order_line_sale ols
left join stg.monthly_average_fx_rate fx
on date_trunc('month',ols.date) = fx.month
left join stg.store_master sm
on ols.store = sm.store_id
left join stg.product_master pm
on ols.product = pm.product_code
left join stg.cost cs
on ols.product = cs.product_code
group by
	year_date,
	category
)
, stg_inv_prom as (
select
	to_char(date,'YYYY-MM') as year_date,
	category,
	sum((initial+final)*1.00/2) as inv_prom,
	sum(((initial+final)*1.00/2)*product_cost_usd) as inv_prom_cost
from stg.inventory i
left join stg.cost cs
on i.item_id = cs.product_code
left join stg.product_master pm
on i.item_id = pm.product_code
group by
	year_date,
	category
order by
	year_date,
	category
)
select
	s.year_date,
	s.category,
	((s.sales_usd-s.promotion_usd)/ ip.inv_prom_cost ) as ROI
from stg_sales s
left join stg_inv_prom ip
on s.year_date = ip.year_date
and s.category = ip.category
group by
	s.year_date,
	s.category,
	ROI;

-- - AOV (Average order value), valor promedio de la orden. (USD)
with stg_sales as (
select
	date,
	order_number,
	case
		when currency = 'ARS' then (coalesce(sale,0)/fx_rate_usd_peso)
		when currency = 'EUR' then (coalesce(sale,0)/fx_rate_usd_eur)
		when currency = 'URU' then (coalesce(sale,0)/fx_rate_usd_uru)
		else sale
	end as sales_usd,
	case
		when currency = 'ARS' then (coalesce(promotion,0)/fx_rate_usd_peso)
		when currency = 'EUR' then (coalesce(promotion,0)/fx_rate_usd_eur)
		when currency = 'URU' then (coalesce(promotion,0)/fx_rate_usd_uru)
		else promotion
	end as promotion_usd,
	case
		when currency = 'ARS' then (coalesce(credit,0)/fx_rate_usd_peso)
		when currency = 'EUR' then (coalesce(credit,0)/fx_rate_usd_eur)
		when currency = 'URU' then (coalesce(credit,0)/fx_rate_usd_uru)
		else credit
	end as credit_usd,
	case
		when currency = 'ARS' then (coalesce(tax,0)/fx_rate_usd_peso)
		when currency = 'EUR' then (coalesce(tax,0)/fx_rate_usd_eur)
		when currency = 'URU' then (coalesce(tax,0)/fx_rate_usd_uru)
		else tax
	end as tax_usd
from stg.order_line_sale ols
left join stg.monthly_average_fx_rate fx
on date_trunc('month',ols.date) = fx.month
left join stg.store_master sm
on ols.store = sm.store_id
left join stg.product_master pm
on ols.product = pm.product_code
left join stg.cost cs
on ols.product = cs.product_code
left join stg.supplier sp
on ols.product = sp.product_id
where sp.is_primary = true
)

select 
	to_char(s.date,'YYYY-MM') as year_month,
	sum(sales_usd) / count(distinct(order_number)) as AOV
from stg_sales s
group by
	year_month;
-- Contabilidad (USD)
-- - Impuestos pagados

-- - Tasa de impuesto. Impuestos / Ventas netas 

-- - Cantidad de creditos otorgados

-- - Valor pagado final por order de linea. Valor pagado: Venta - descuento + impuesto - credito

-- Supply Chain (USD)
-- - Costo de inventario promedio por tienda

-- - Costo del stock de productos que no se vendieron por tienda

-- - Cantidad y costo de devoluciones


-- Tiendas
-- - Ratio de conversion. Cantidad de ordenes generadas / Cantidad de gente que entra

