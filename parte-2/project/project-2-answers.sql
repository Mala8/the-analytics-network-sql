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

/*Select * 
from cte_shrinkage*/
