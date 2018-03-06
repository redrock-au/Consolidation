-- $Header: svn://d02584/consolrepos/branches/AR.00.02/glc/1.0.0/sql/emprpt.sql 1659 2017-07-11 03:46:55Z svnuser $
-- arguments 1. period
--           2. cost centre (or 000 for ALL)
--           3. spool file name
drop table empcctr
/
drop table empext
/
drop table emprpt
/
drop table paydates
/
column fvset_id new_value fvsid noprint
column fvbook_id new_value fvbid noprint
select doi_request_book_id(&3) fvbook_id from dual
/
--select doi_coa_value_set_id(doi_request_book_id(&3),'Cost Centre') fvset_id
select doi_coa_value_set_id(&fvbid,'Cost Centre') fvset_id
from dual
/
create table empcctr as select a.flex_value_id||' '||substr(a.description,1,55)  p_cdesc,c.flex_value,c.flex_value_id
from apps.fnd_flex_values_vl a, applsys.fnd_flex_value_hierarchies b, apps.fnd_flex_values_vl c
where a.flex_value_set_id = &fvsid
and b.flex_value_set_id = &fvsid
and c.flex_value_set_id = &fvsid
and a.flex_value like decode('&2','000','ALL','&2')
and a.flex_value = b.parent_flex_value
and c.flex_value between b.child_flex_value_low and b.child_flex_value_high
/
insert into empcctr select decode('&2','000','ALL',flex_value||' '||substr(description,1,55)),flex_value,flex_value_id
from apps.fnd_flex_values_vl 
where flex_value_set_id = &fvsid
and summary_flag != 'Y'
and flex_value like decode('&2','000','%','&2')
/
create table empext as
select b.default_effective_date,c.reference_4 pinno,c.reference_6 amount,c.reference_7 cctr,decode(b.je_category,'Adjustment',5,4) col
from gl.gl_je_headers b,gl.gl_import_references c, empcctr f, gl.gl_code_combinations g, gl_je_lines d
where  b.je_source='Payroll'
and b.period_name='&1'
and b.actual_flag='A'
and b.accrual_rev_je_header_id is null
and b.set_of_books_id=&fvbid
and c.je_header_id=b.je_header_id
and c.reference_7=f.flex_value
and c.je_header_id=d.je_header_id
and d.je_line_num=c.je_line_num
and d.code_combination_id=g.code_combination_id
and g.segment7!='PAYMENTS'
/
update empext set col = 1
where default_effective_date = (select min(default_effective_date) from empext
where col < 5)
and col=4
/
update empext set col = 2
where default_effective_date != (select min(default_effective_date) from empext
where col < 5)
and col=4
/
update empext set col = 3
where trunc(default_effective_date) >  
                        (select min(trunc(default_effective_date))
			              from empext
				      where col = 2)
and col=2
/
insert into empext
select a.default_effective_date,'99999999',(nvl(b.entered_dr,0)-nvl(entered_cr,0)) , c.segment3,4
from gl.gl_je_headers a,gl.gl_je_lines b,gl.gl_code_combinations c, empcctr f, gl_je_sources_vl s
where s.user_je_source_name = 'Payroll Accrual' 
and a.je_source=s.je_source_name 
and a.period_name='&1'
and a.actual_flag='A'
--and a.accrual_rev_je_header_id is null
and a.je_header_id=b.je_header_id
and a.set_of_books_id=&fvbid
and c.code_combination_id=b.code_combination_id
and c.segment3=f.flex_value
/
create table paydates as select distinct min(default_effective_date) date1,
min(default_effective_date)+14 date2,max(default_effective_date) date3
from empext
where col < 4
/
update paydates set date3=NULL
where date2=date3
/
create table emprpt
as select b.cctr,0 n_employees,b.pinno,
sum(decode(col,1,amount,NULL)) pay1,
sum(decode(col,2,amount,NULL)) pay2,
sum(decode(col,3,amount,NULL)) pay3,
sum(decode(col,4,amount,NULL)) accrual_amt,
sum(decode(col,5,amount,NULL)) other_amount,
sum(amount) total_amount
from empext b
group by b.cctr,0,b.pinno
/
update emprpt a set (n_employees) = (
select count(b.pinno) 
from emprpt b
where a.cctr=b.cctr
and b.pinno between '00000001' and '99999899'
and pay3 is not null ) 
/
update emprpt a set (n_employees) = (
select count(b.pinno) 
from emprpt b
where a.cctr=b.cctr
and b.pinno between '00000001' and '99999899'
and pay2 is not null ) 
where n_employees = 0
/
set wrap off
set feedback off
set verify off
set term off
set echo off
set flush off
set lines 133
set pages 57
set newpage 0
column n_employees new_value en noprint
column date1 new_value date_1 noprint
column date2 new_value date_2 noprint
column date3 new_value date_3 noprint
column cctr new_value cost_centre noprint
column cdesc new_value cctr_desc noprint
column p_cdesc new_value p_cctr_desc noprint
column amount1 format 99,999,990.00
column amount2 format 99,999,990.00
column amount3 format 99,999,990.00
column accrual_amt format 99,999,990.00
column other_amount format 99,999,990.00
column total_amount format 99,999,990.00
column name format A30
column pin_no format A10
BREAK on cctr skip page
COMPUTE SUM OF amount1 amount2 amount3 other_amount accrual_amt total_amount ON cctr 
select date1,date2,date3 from paydates
/
spool emprpt.&3
TTITLE center 'Employees Salary Pin Number Report Period Ending &1' skip 1 center '=======================================================' skip 1 center 'Cost Center Range: ' p_cctr_desc skip 1 center center '---------------------------------------' skip 2 'Cost Center: ' cctr_desc skip 1 'No of Employees : ' en skip 2 '                                               ' date_1 '      ' date_2 '      ' date_3 
select a.cctr, a.cctr||' '||substr(b.description,1,55) cdesc, substr(a.pinno,1,8) pin_no,d.p_cdesc,f.full_name name,a.pay1 amount1,a.pay2 amount2,a.pay3 amount3,a.accrual_amt,a.other_amount,a.total_amount, to_char(a.n_employees) n_employees
from emprpt a, apps.fnd_flex_values_vl b,empcctr d, 
(select employee_number,replace(full_name,' ( )','') full_name  
 from per_all_people_f x
 where effective_end_date = (select max(effective_end_date) from
 per_all_people_f y where  x.person_id=y.person_id)) f
--(select distinct employee_number,
--        replace(full_name,' ( )','') full_name from apps.per_all_people_f
-- where person_type_id=23) f
where a.cctr = b.flex_value
and a.cctr != '099'
and b.flex_value_set_id = &fvsid
and d.flex_value = b.flex_value
and f.employee_number(+)=a.pinno
order by cctr, pinno
/
clear breaks
clear computes
column cost_centre format A30
BREAK on REPORT skip page 
COMPUTE SUM OF employees amount1 amount2 amount3 accrual_amt other_amount total_amount ON REPORT
TTITLE center 'Employees Salary Report Summary Period Ending &1' skip 1 center '====================================================' skip 1 center 'Cost Center Range: ' p_cctr_desc skip 1 center '------------------------------' skip 2 '                                               ' date_1 '      ' date_2 '      ' date_3 
select d.p_cdesc,a.cctr||' '||substr(b.description,1,30) cost_centre, a.n_employees employees, sum(a.pay1) amount1,sum(a.pay2) amount2,sum(a.pay3) amount3,sum(a.accrual_amt) accrual_amt,sum(a.other_amount) other_amount,sum(a.total_amount) total_amount
from emprpt a, apps.fnd_flex_values_vl b, empcctr d
where a.cctr = b.flex_value
and a.cctr != '099'
and b.flex_value_set_id = &fvsid
and d.flex_value = b.flex_value
group by a.cctr||' '||substr(b.description,1,30), d.p_cdesc ,a.n_employees
/
exit;
