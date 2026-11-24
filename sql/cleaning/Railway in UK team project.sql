create table railway(
Transaction_ID varchar(32),
Date_of_Purchase DATE,
Time_of_Purchase TIME,
Purchase_Type varchar(32),
Payment_Method varchar(32),
Railcard varchar(32),
Ticket_Class varchar(32),
Ticket_Type varchar(32),
Price INT,
Departure_Station varchar(100),
Arrival_Destination varchar(100),
Date_of_Journey date,
Departure_Time time,
Arrival_Time time,
Actual_Arrival_Time time,
Journey_Status varchar(32),
Reason_for_Delay varchar(100),
Refund_Request varchar(10)
);


select transaction_id, count(*) duplicate_count
from railway
group by transaction_id
having count(*) > 1;

select distinct date_of_purchase ASC
from railway
order by date_of_purchase;

select *
from railway
where date_of_journey::text !~ '^[0-9-]+$';

select * 
from railway 
where transaction_id is null

select * 
from railway 
where refund_request is null;

select *
from railway
where actual_arrival_time::text !~ '^[0-9]{2}:[0-9]{2}:[0-9]{2}$';

select distinct ticket_type , count(purchase_type) as count_type
from railway
group by ticket_type
order by ticket_type ASC;

select distinct refund_request , count(refund_request) as count_type
from railway
group by refund_request
order by refund_request ASC;

select * from railway ;

SELECT *
FROM railway
WHERE refund_request = ''
   OR TRIM(refund_request) = '';

select distinct railcard
from railway 
order by railcard asc;

select min(price), max(price)
from railway;

select *
from railway 
where price = 1;

select *
from railway
where arrival_time > actual_arrival_time;

update railway
set reason_for_delay = 'No Delay'
where reason_for_delay is null;

select *
from railway
where reason_for_delay = 'No Delay';

update railway
set railcard = null
where railcard = 'None';




