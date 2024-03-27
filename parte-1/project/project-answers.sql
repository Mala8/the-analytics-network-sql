
-- General
--CTE  ventas General
with stg_sales as (
select
	ols.*,
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
  sum(sales_usd-promotion_usd-total_cost) as margin_usd
from stg_sales ols
group by
	Year,
	Month
order by
	Year,
	Month;

-- - Margen por categoria de producto (USD)

-- - ROI por categoria de producto. ROI = ventas netas / Valor promedio de inventario (USD)

-- - AOV (Average order value), valor promedio de la orden. (USD)

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

