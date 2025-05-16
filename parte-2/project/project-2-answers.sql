create view viz.order_sale_line as
 -- select 
;
create or replace view if not exists as viz.order_line_sale 

with cte_product_sold as ( -- calcula la ventas por año en store y producto

select
	extract(year from ols.date) as year,
	ols.store as store,
	ols.product as product,
	sum(ols.quantity) as qty_sold
from stg.order_line_sale ols
group by
	extract(year from ols.date),
	ols.store,
	ols.product
order by
extract(year from ols.date),
	ols.store,
	ols.product
),

cte_shrinkage as ( --Calcula las pérdidas por producto

select
	sk.year,
	sk.store_id,
	sk.item_id,
	sk.quantity,
	sk.quantity * c.product_cost_usd as total_cost,
	((sk.quantity * c.product_cost_usd) / ps.qty_sold) as lost_per_item
from stg.Shrinkage sk
left join stg.cost c
on sk.item_id = c.product_code
left join cte_product_sold ps
on sk.year = ps.year
and sk.item_id = ps.product
and sk.store_id = ps.store
order by
	sk.year,
	sk.store_id,
	sk.item_id
)


cte_sales_usd as (

select 
	ols.*,
	pm.*,
	sm.country as store_country,
	sm.province as store_province,
	sm.name as store_name,
	sp.name as supplier_name,
	d.day,
	d.month,
	d.month_label,
	d.year,
	d.fiscal_year,
	d.fiscal_quarter_label,
	case
		when currency = 'ARS' then (coalesce(sale,0) / fx_rate_usd_peso)
		when currency = 'EUR' then (coalesce(sale,0) / fx_rate_usd_eur) 
		when currency = 'URU' then (coalesce(sale,0) / fx_rate_usd_uru)
		else sale 
	end gross_sale_USD,
	case
		when currency = 'ARS' then (coalesce(promotion,0) / fx_rate_usd_peso)
		when currency = 'EUR' then (coalesce(promotion,0) / fx_rate_usd_eur)
		when currency = 'URU' then (coalesce(promotion,0) / fx_rate_usd_uru)
		else promotion 
	end promotion_USD,
	case
		when currency = 'ARS' then (coalesce(credit,0) / fx_rate_usd_peso)
		when currency = 'EUR' then (coalesce(credit,0) / fx_rate_usd_eur) 
		when currency = 'URU' then (coalesce(credit,0) / fx_rate_usd_uru)
		else credit 
	end credit_USD,
	case
		when currency = 'ARS' then (coalesce(tax,0) / fx_rate_usd_peso)
		when currency = 'EUR' then (coalesce(tax,0) / fx_rate_usd_eur) 
		when currency = 'URU' then (coalesce(tax,0) / fx_rate_usd_uru)
		else tax
	end tax_USD, -- continuar 
	
	
	
-- joins para one big table y tomar sacar todas las métricas
from stg.order_line_sale ols
left join stg.product_master pm
on ols.product = pm.product_code
left join stg.cost cs
on ols.product = cs.product_code
left join stg.store_master sm
on ols.store = sm.store_id
left join stg.monthly_average_fx_rate fx
on date_trunc('month', ols.date) = fx.month
left join stg.supplier sp
on ols.product = sp.product_id
left join stg.shrinkage sk
on (extract(year from ols.date) = sk.year)
and ols.store = sk.store_id
and ols.product = sk.item_id
left join stg.return_movements rm
on ols.order_number = rm.order_id
and ols.product = rm.item
and rm.movement_id = 2
left join stg.date d
on ols.date = d.date
where sp.is_primary = true
)


/*Select * 
from cte_shrinkage*/
