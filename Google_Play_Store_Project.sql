create database if not exists google;
use google;
truncate table playstore;   /*as all the rows were not loaded, we truncated it and now we just have the table*/

-- bring data from an external file to our existing table playstore 
-- infile statement is used for this purpose, it is used to add the daily transaction data to table
-- by default infile statement is disabled. 
-- go the Services and stop the MySQL80 service.
-- Go to C:\ProgramData\MySQL\MySQL Server 8.0, edit the my file with 'local_infile=ON'
-- start MYSQL80 service again and restart PC

load data infile 'D:/playstore.csv'
into table playstore
fields terminated by ','
optionally enclosed by '"'
lines terminated by '\r\n'
ignore 1 rows;

-- 1. You are working as a market analyst for a mobile app development company. Your task is to identify the most promising categories (top 5) for launching 
-- new free apps based on their average ratings.
select category, round(avg(rating),2) as 'rating'
from playstore where type = 'Free'
group by category order by rating desc limit 5;

-- 2. As a business strategist for a mobile app company, your objective is to pinpoint the three categories that generate the most revenue from paid apps. 
-- This calculation is based on the product of the app price and its number of installations.
select category, round(avg(price*installs),2) as 'revenue' from playstore where type = 'paid'
group by category order by revenue desc limit 3;

-- 3. As a data analyst for a gaming company, you're tasked with calculating the percentage of games within each category. This information will help the 
-- company understand the distribution of gaming apps across different categories.
select category, (100*count(*))/(select count(*) from playstore) as 'percentage' from playstore
group by category order by percentage desc;

-- 4. As a data analyst at a mobile app-focused market research firm you’ll recommend whether the company should develop paid or free apps for each 
-- category based on the ratings of that category.

select *, rank() over(partition by category order by rating desc) from 
(select category, type, avg(rating) as 'rating' from playstore
group by category, type order by category)t;

with t1 as
(
select category, avg(rating) as 'paid_rating' from playstore where type = 'paid' group by category
),
t2 as 
(
select category, avg(rating) as 'free_rating' from playstore where type = 'free' group by category
)
select a.category, a.paid_rating, b.free_rating, if(a.paid_rating > b.free_rating, 'go for paid', 'go for free') as 'decision'
from t1 as a join t2 as b on a.category = b.category;

-- 5. Suppose you're a database administrator your databases have been hacked and hackers are changing price of certain apps on 
-- the database, it is taking long for IT team to neutralize the hack, however you as a responsible manager don’t want your data to 
-- be changed, do some measure where the changes in price can be recorded as you can’t stop hackers from making changes.

-- created a table to record the changes done on the table
create table pricechangelog(
app varchar(255),
old_price decimal(10,2),
new_price decimal(10,2),
operation_type varchar(255),
operation_date timestamp
);

-- creating backup of playstore table
create table play as 
select * from playstore;

-- creating a trigger
DELIMITER //
create trigger price_change_log
after update
on play
for each row
begin
	insert into pricechangelog(app, old_price, new_price, operation_type, operation_date)
    values(new.app, old.price, new.price, 'update', current_timestamp);
end;
// 

-- change certain things in play table
update play
set price = 4 where app = 'Infinite Painter';

update play
set price = 5 where app = 'Sketch - Draw & Paint';

-- see the changes in play table
select * from pricechangelog;

-- 6. Your IT team have neutralized the threat; however, hackers have made some changes in the prices, but because of your measure you 
-- have noted the changes, now you want correct data to be inserted into the database again.
-- update + join
select * from play as a
join pricechangelog as b 
on a.app = b.app; -- step 1

drop trigger price_change_log;

update play as a join pricechangelog as b on a.app = b.app
set a.price = b.old_price;  -- step 2

-- 7. As a data person you are assigned the task of investigating the CORRELATION between two numeric factors: app ratings and the quantity of reviews.
-- sum((x-x')*(y-y')) / sqrt( sum((x-x')^2) * sum((y-y')^2) )
set @x = (select round(avg(rating),2) from playstore);
set @y = (select round(avg(reviews),2) from playstore);
select @x,@y;

with cte as (
select *, (rat*rat) as 'ratsq', (rev*rev) as 'revsq' from 
(
select rating, @x, round((rating-@x),2) as 'rat', reviews, @y, round((reviews-@y),2) as 'rev' from playstore
)t )

select @numerator := sum(rat*rev), @deno_1 := sum(ratsq), @deno_2 := sum(revsq) from cte;
select round((@numerator/(sqrt(@deno_1*@deno_2))),4) as 'correlation_coeff';

-- 8. Your boss noticed  that some rows in genres columns have multiple genres in them, which was creating issue when developing the recommender system 
-- from the data he/she assigned you the task to clean the genres column and make two genres out of it, rows that have only one genre will have other column as blank.
select * from playstore;

Delimiter //
create function f_name (a varchar(255))
returns varchar(255)
deterministic -- give this term when the function returns an output
begin
	set @l = locate(';',a);
    set @s = if(@l>0 , left(a,@l-1), a);
    return @s;
end;
// 

Delimiter //
create function l_name (a varchar(255))
returns varchar(255)
deterministic -- give this term when the function returns an output
begin
	set @l = locate(';',a);
    set @s = if(@l=0 ,' ',substring(a,@l+1,length(a)));
    return @s;
end;
// 

select genres, f_name(genres) as 'first_name', l_name(genres) as 'last_name' from playstore;

-- 9. Your senior manager wants to know which apps are not performing as par in their particular category, however he is not interested in handling too many files 
-- or list for every  category and he/she assigned  you with a task of creating a dynamic tool where he/she  can input a category of apps he/she  interested in  and your 
-- tool then provides real-time feedback by displaying apps within that category that have ratings lower than the average rating for that specific category.

-- generalized query(all together)
select app, category, rating from playstore p1 where rating < (select round(avg(rating),2) from playstore p2 where p1.category = p2.category);

-- procedure
delimiter //
create procedure lessratingsapps(in categ varchar(50))
begin
		set @avg_rating = (select round(avg(rating),2) from playstore p where category = categ);
        select * from playstore where category = categ and rating < @avg_rating;
end
//

call lessratingsapps('TRAVEL_AND_LOCAL');





