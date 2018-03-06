drop table payadj0
/
drop table paytemp2
/
drop table payadj6
/
drop table payadj4
/
drop table payadj1
/
drop table payadj2
/
drop table payadj5
/
drop table payadj5a
/
drop table payadj7
/
drop table payadj4b
/
drop table payadj4c
/
drop table payadj7b
/
drop table paycre1
/
drop table paycre2
/
drop table paycre3
/
start $PRODS/set_org_cont
create table payadj6 (segment1 varchar2(1),
                   segment2 varchar2(5),
                   segment3 varchar2(3),
                   segment4 varchar2(4),
                   segment5 varchar2(4),
                   segment6 varchar2(4),
                   segment7 varchar2(8),
                   description varchar2(20),
                   je_batch_id number(15),
                   amount number(19,3))
/
create table payadj2 (amount number(19,3),
                      segment1 varchar2(1),
                      code_combination_id number(15),
                      je_batch_id number(15))
/
create table payadj0 as
select je_header_id,je_batch_id,je_category
from gl_je_headers
where actual_flag='A'
and set_of_books_id = 1
and (je_batch_id = &1 or ( &1 = 0
                           and je_source = 'Payables'
                           and posted_date is null))
/
create table paytemp2 as
select a.source_id,a.source_table,to_number(a.reference2) ref2,
to_number(a.reference3) ref3,
nvl(a.entered_dr,0)-nvl(a.entered_cr,0) amt,
a.code_combination_id,a.ae_line_type_code ,c.event_type_code, 
e.je_batch_id
from ap.ap_ae_lines_all a,gl_import_references b,ap.ap_accounting_events_all c,ap.ap_ae_headers_all d, payadj0 e
where b.je_header_id = e.je_header_id
and b.je_header_id in (select je_header_id from payadj0)
and a.gl_sl_link_id=b.gl_sl_link_id
and b.gl_sl_link_table='APECL'
and a.ae_header_id=d.ae_header_id
and d.accounting_event_id=c.accounting_event_id
and a.org_id=101
--and nvl(a.entered_dr,0)-nvl(a.entered_cr,0)!=0
/
create index paytemp2_n1 on paytemp2(ae_line_type_code,event_type_code)
/
create table payadj1 as
select sum(-amt) amount,b.segment1,
a.code_combination_id,a.je_batch_id
from paytemp2 a ,gl_code_combinations b
where a.ae_line_type_code != 'LIABILITY'
and a.event_type_code like 'INVOICE%'
and a.code_combination_id=b.code_combination_id
group by b.segment1,a.code_combination_id,a.je_batch_id
/
--create table payadj2 as
insert into payadj2
select sum(amt) amount,b.segment1,
a.code_combination_id,a.je_batch_id
from paytemp2 a,gl_code_combinations b,
      ap_invoice_distributions c
where a.ae_line_type_code != 'LIABILITY'
and a.ae_line_type_code != 'CHARGE'
and a.ae_line_type_code != 'IPV'
and a.ae_line_type_code != 'AP ACCRUAL'
and a.ae_line_type_code != 'FREIGHT'
and a.event_type_code like 'INVOICE%'
and a.ref2=c.invoice_id
and c.distribution_line_number=(select min(distribution_line_number)
from ap_invoice_distributions d
where d.invoice_id=c.invoice_id)
and c.dist_code_combination_id=b.code_combination_id
group by b.segment1,a.code_combination_id,a.je_batch_id
/
create table payadj4b as
select a.source_id inv_pmt_id,a.ref2 invoice_id,a.amt,
a.code_combination_id,
       b.source_id check_id,b.amt check_amt,b.code_combination_id check_ccid,
       a.je_batch_id,a.event_type_code
from paytemp2 a,paytemp2 b,ap_invoice_payments c
where a.ae_line_type_code='LIABILITY'
and (a.event_type_code='PAYMENT' or a.event_type_code='PAYMENT CANCELLATION')
and a.source_id=c.invoice_payment_id
and b.ae_line_type_code!='LIABILITY'
and (b.event_type_code='PAYMENT' or b.event_type_code='PAYMENT CANCELLATION')
and b.je_batch_id=a.je_batch_id
and c.check_id=b.ref3
/
create table payadj4c as
select d.segment1,b.invoice_id,
sum(decode(b.event_type_code,'PAYMENT CANCELLATION',-c.amount,c.amount)) amount,
       b.check_ccid bank_ccid,b.code_combination_id liab_ccid,b.je_batch_id
from payadj4b b,ap_invoice_distributions c, gl_code_combinations d,
     ap_accounting_events e
where b.invoice_id=c.invoice_id
and substr(c.posted_flag,1,1)='Y'
and c.dist_code_combination_id=d.code_combination_id
and c.accounting_event_id=e.accounting_event_id
and e.event_type_code !='INVOICE CANCELLATION'
group by d.segment1,b.invoice_id,b.check_ccid,b.code_combination_id ,
         b.je_batch_id
/
update payadj4c a set (segment1)=
(select b.segment1 from gl_code_combinations b,ap_invoice_distributions c
where a.invoice_id=c.invoice_id
and c.distribution_line_number=(select min(distribution_line_number)
from ap_invoice_distributions d
where d.invoice_id=c.invoice_id)
and c.dist_code_combination_id=b.code_combination_id)
where a.segment1='Y'
/
create table payadj4 as
select segment1,sum(amount) amount,
       bank_ccid,liab_ccid,je_batch_id
from payadj4c
group by segment1,bank_ccid,liab_ccid,je_batch_id
/
create table payadj5a as
select a.ref2 invoice_id,decode(sign(c.amount),1,a.amt,-a.amt) amt,
c.asset_code_combination_id,d.segment1,a.je_batch_id
from paytemp2 a,ap_invoices b,ap_invoice_payments c,gl_code_combinations d
where a.ref2 in (
select ref2  from paytemp2 where event_type_code = 'INVOICE ADJUSTMENT'
minus select ref2 from paytemp2 where event_type_code = 'PAYMENT')
and a.ae_line_type_code != 'LIABILITY'
and a.ref2=b.invoice_id
and a.ref2=c.invoice_id
and b.payment_status_flag='Y'
and a.code_combination_id=d.code_combination_id
and c.asset_code_combination_id is not null
/
update payadj5a a set (segment1)=
(select b.segment1 from gl_code_combinations b,ap_invoice_distributions c
where a.invoice_id=c.invoice_id
and c.distribution_line_number=(select min(distribution_line_number)
from ap_invoice_distributions d
where d.invoice_id=c.invoice_id)
and c.dist_code_combination_id=b.code_combination_id)
where a.segment1='Y'
/
create table payadj5 as
select sum(amt) amt, asset_code_combination_id,segment1,je_batch_id
from payadj5a
group by asset_code_combination_id,segment1,je_batch_id
having sum(amt) != 0
/
create table payadj7b as
select a.ref3 check_id,a.amt check_amount,d.segment1,
sign(a.amt)*c.amount amount,
c.line_type_lookup_code,c.invoice_id,a.je_batch_id
from paytemp2 a ,ap_invoice_payments b,ap_invoice_distributions c, 
gl_code_combinations d
where a.ref3=b.check_id
and a.ae_line_type_code='CASH CLEARING'
and a.event_type_code like 'PAYMENT%CLEARING'
and b.invoice_id=c.invoice_id
and c.dist_code_combination_id=d.code_combination_id
and substr(c.posted_flag,1,1)='Y'
/
update payadj7b a set (segment1)=
(select b.segment1 from gl_code_combinations b,ap_invoice_distributions c
 where a.invoice_id=c.invoice_id
 and c.distribution_line_number=(select min(distribution_line_number)
from ap_invoice_distributions d
where d.invoice_id=c.invoice_id)
 and c.dist_code_combination_id=b.code_combination_id)
where a.segment1='Y'
and a.line_type_lookup_code not in ( 'ITEM','MISCELLANEOUS')
/
create table payadj7 as
select a.check_id,a.amount,a.segment1,0 bank_ccid,
0 cash_ccid,a.je_batch_id
from payadj7b a
where a.check_id in (select b.ref3 from paytemp2 b
where a.je_batch_id=b.je_batch_id
and b.ae_line_type_code!='CASH'
and b.event_type_code like 'PAYMENT%CLEARING')
and a.check_id in ( select c.ref3 from paytemp2 c
where a.je_batch_id=c.je_batch_id
and c.ae_line_type_code='CASH'
and c.event_type_code like 'PAYMENT%CLEARING')
and a.segment1 not in ('P','H','R')
/
update payadj7 a set (bank_ccid,cash_ccid)=
(select distinct b.code_combination_id,c.code_combination_id
from paytemp2  b,paytemp2  c
where a.check_id=b.ref3
and a.je_batch_id=b.je_batch_id
and b.ae_line_type_code!='CASH'
and b.event_type_code like 'PAYMENT%CLEARING'
and a.check_id=c.ref3
and a.je_batch_id=c.je_batch_id
and c.ae_line_type_code='CASH'
and c.event_type_code like 'PAYMENT%CLEARING')
/
insert into payadj1
select -amount,segment1,code_combination_id,je_batch_id
from payadj2
/
insert into payadj1
select sum(amount),'Y',code_combination_id,je_batch_id
from payadj2
group by code_combination_id,je_batch_id
/
insert into payadj6
select a.segment1,decode(a.segment1,'Q','30101','30101'),
        '000',
        decode(a.segment1,'S','2520','M','2520','B','2520','F','2520',
               'G','2520','0000'),
        '0000','0000',
       '00000008' ,'Liability',a.je_batch_id,sum(a.amount)
from payadj1 a,gl_code_combinations b
where a.code_combination_id=b.code_combination_id
group by a.segment1,decode(a.segment1,'Q','30101','30101'),
       a.je_batch_id
having sum(amount) != 0
/
insert into payadj6
select  'Y','30101','000','0000','0000','0000','00000009',
'Liability',a.je_batch_id,-sum(a.amount)
from payadj1 a,gl_code_combinations b
where a.code_combination_id=b.code_combination_id
group by 'Y','30101','000','0000','0000','0000','00000009',
'Liability',a.je_batch_id
having sum(a.amount) != 0
/
insert into payadj6
select a.segment1,b.segment2,'000','0000','0000','0000','00000008','TAX DIST',
a.je_batch_id,a.amount
from payadj2 a,gl.gl_code_combinations b
where a.code_combination_id=b.code_combination_id
/ 
insert into payadj6
select 'Y',b.segment2,'000','0000','0000','0000','00000009','TAX DIST',
a.je_batch_id,sum(-a.amount)
from payadj2 a,gl.gl_code_combinations b
where a.code_combination_id=b.code_combination_id
group by 'Y',b.segment2,'000','0000','0000','0000','00000009','TAX DIST',
a.je_batch_id
/
insert into payadj6
select a.segment1,decode(a.segment1,'Q','30101','30101'),
        b.segment3,
        decode(a.segment1,'S','2520','M','2520','B','2520','F','2520',
               'G','2520','0000'),
        b.segment5,b.segment6,
       '00000008' ,'Payments',a.je_batch_id,sum(a.amount)
from payadj4 a,gl_code_combinations b
where a.liab_ccid=b.code_combination_id
and a.amount != 0
group by a.segment1,b.segment3,b.segment5,b.segment6,
       '00000008' ,'Payments',a.je_batch_id
/
insert into payadj6
select b.segment1,b.segment2,b.segment3,b.segment4,b.segment5,b.segment6,
       '00000009','Payments',a.je_batch_id,-sum(a.amount)
from payadj4 a,gl_code_combinations b
where a.liab_ccid=b.code_combination_id
and a.amount != 0
group by b.segment1,b.segment2,b.segment3,b.segment4,b.segment5,b.segment6,
       '00000009','Payments',a.je_batch_id
/
insert into payadj6
select a.segment1,
       decode(b.segment2,'10322','10322','92012','92012','10303','10303',
       decode(a.segment1,'E','10401','R','10401','H','10401','M','10401',
              'F','10401','P','10401', 'Q',b.segment2,'G',b.segment2,'10379')),
--                        'P','10401', 'Q',b.segment2,'10379')),
        b.segment3,b.segment4,b.segment5,b.segment6,
       substr(b.segment7,1,1)||'BANK008' ,'Payments',a.je_batch_id,
-sum(a.amount)
from payadj4 a,gl_code_combinations b
where a.bank_ccid=b.code_combination_id
and a.amount != 0
group by a.segment1,b.segment2,b.segment3,b.segment4,b.segment5,b.segment6,
       substr(b.segment7,1,1)||'BANK008' ,'Payments',a.je_batch_id
/
insert into payadj6
select b.segment1,b.segment2,b.segment3,b.segment4,b.segment5,b.segment6,
       substr(b.segment7,1,1)||'BANK009' ,'Payments',a.je_batch_id,sum(a.amount)
from payadj4 a,gl_code_combinations b
where a.bank_ccid=b.code_combination_id
and a.amount != 0
group by b.segment1,b.segment2,b.segment3,b.segment4,b.segment5,b.segment6,
       substr(b.segment7,1,1)||'BANK009' ,'Payments',a.je_batch_id
/
insert into payadj6
select a.segment1,
decode(b.segment2,'10322','10322','92012','92012','10303','10303',
   decode(a.segment1,'E','10401','R','10401','H','10401','M','10401',
                     'F','10401','P','10401','Q', b.segment2,'G',b.segment2,'10379')),
--                               'P','10401','Q', b.segment2,'10379')),
segment3,segment4,segment5,segment6,
substr(b.segment7,1,1)||'BANK008' ,
'DIST ADJ',je_batch_id,sum(-amt)
from payadj5 a,gl_code_combinations b
where a.asset_code_combination_id=b.code_combination_id
and amt != 0
group by a.segment1,b.segment2,b.segment3,b.segment4,b.segment5,b.segment6,
       substr(b.segment7,1,1)||'BANK008' ,a.je_batch_id
/
insert into payadj6
select b.segment1,b.segment2,b.segment3,b.segment4,b.segment5,b.segment6,
substr(b.segment7,1,5)||'009','CASH CLEARING', a.je_batch_id,
sum(-a.amount)
from payadj7 a,gl_code_combinations b
where a.bank_ccid=b.code_combination_id
and b.segment2 not in ('10419','10427','10411','10435')
and a.segment1 != 'E'
group by b.segment1,b.segment2,b.segment3,b.segment4,b.segment5,b.segment6,
substr(b.segment7,1,5)||'009','CASH CLEARING', a.je_batch_id
/
insert into payadj6
select a.segment1,b.segment2,b.segment3,b.segment4,b.segment5,b.segment6,
substr(b.segment7,1,5)||'008','CASH CLEARING', a.je_batch_id,
sum(a.amount)
from payadj7 a,gl_code_combinations b
where a.bank_ccid=b.code_combination_id
and b.segment2 not in ('10419','10427','10411','10435')
group by a.segment1,b.segment2,b.segment3,b.segment4,b.segment5,b.segment6,
substr(b.segment7,1,5)||'008','CASH CLEARING', a.je_batch_id
/
INSERT INTO payadj6
SELECT b.segment1,
       DECODE(SUBSTR(b.segment7, 1, 1), 'M', '74501', 'U', '45501', 'L', '45501', 'D', '45501', 'T', '45501', '45001'),
       b.segment3,
       b.segment4,
       b.segment5,
       b.segment6,
       SUBSTR(b.segment7, 1, 5) || '009',
       'CASH',
       a.je_batch_id,
       SUM(a.amount)
FROM   payadj7 a,
       gl_code_combinations b
WHERE  a.cash_ccid = b.code_combination_id
AND    b.segment2 NOT IN ('10419', '10427', '10411', '10435')
-- arellanod 24/10/2017
-- AND    (b.segment7 NOT LIKE 'E%' OR b.segment7 NOT LIKE 'F%')
AND    b.segment7 NOT LIKE 'E%' 
GROUP  BY b.segment1,
          DECODE(SUBSTR(b.segment7, 1, 1), 'M', '74501', 'U', '45501', 'L', '45501', 'D', '45501', 'T', '45501', '45001'),
          b.segment3,
          b.segment4,
          b.segment5,
          b.segment6,
          SUBSTR(b.segment7, 1, 5) || '009',
          'CASH',
          a.je_batch_id
/
INSERT INTO payadj6
SELECT a.segment1,
       DECODE(a.segment1, 'M', '74501', 'U', '45501', 'L', '45501', 'D', '45501', 'T', '45501', 'E', '10401',
              --         'F','10401','L','45501','D','45501','T','45501','E','10401', -- arellanod 25/10/2017
              --         'F','10322'
              '45001'),
       DECODE(a.segment1, 'M', '703', b.segment3),
       b.segment4,
       DECODE(a.segment1, 'M', '6460', b.segment5),
       b.segment6,
       SUBSTR(b.segment7, 1, 5) || DECODE(a.segment1, 'E', '000', '008'),
       'CASH',
       a.je_batch_id,
       SUM(-a.amount)
FROM   payadj7              a,
       gl_code_combinations b
WHERE  a.cash_ccid = b.code_combination_id
AND    b.segment2 NOT IN ('10419', '10427', '10411', '10435')
GROUP  BY a.segment1,
       DECODE(a.segment1, 'M', '74501', 'U', '45501', 'L', '45501', 'D', '45501', 'T', '45501', 'E', '10401',
              --         'F','10401','L','45501','D','45501','T','45501','E','10401', -- arellanod 25/10/2017
              --         'F','10322'
              '45001'),
          DECODE(a.segment1, 'M', '703', b.segment3),
          b.segment4,
          DECODE(a.segment1, 'M', '6460', b.segment5),
          b.segment6,
          SUBSTR(b.segment7, 1, 5) || DECODE(a.segment1, 'E', '000', '008'),
          'CASH',
          a.je_batch_id
/
insert into payadj6
select a.segment1,'92010','000','0000','0000','0000',
'0000000'||substr(a.segment7,8,1),'Intercomp',a.je_batch_id,sum(-amount)
from payadj6 a
group by a.segment1,'92010','000','0000','0000','0000',
'0000000'||substr(a.segment7,8,1),'Intercomp',a.je_batch_id
/
create table paycre1 as
select a.ref2,a.ref3,a.amt, a.je_batch_id, b.credit_card_trx_id
from paytemp2 a ,ap_invoice_distributions b
where a.ae_line_type_code != 'LIABILITY'
and a.event_type_code like 'INVOICE%'
and a.code_combination_id=219157
and a.ref2=b.invoice_id
and a.ref3=b.distribution_line_number
/
create table paycre2 as
select a.ref2,a.ref3,a.amt, a.je_batch_id, a.credit_card_trx_id,
d.employee_id,nvl(c.default_code_comb_id,524098) default_code_comb_id
from paycre1 a,ap_credit_card_trxns b,per_assignments_f c,ap_cards d
where a.credit_card_trx_id is not null
and a.credit_card_trx_id=b.trx_id
and b.card_number=d.card_number
and d.employee_id=c.person_id
and nvl(c.effective_end_date ,sysdate+1)>sysdate
/
insert into doi_credit_card_trxns
select ref2,ref3,amt,je_batch_id,credit_card_trx_id,employee_id,
default_code_comb_id,null,null
from paycre2
where credit_card_trx_id not in (select trx_id from  doi_credit_card_trxns)
/
create table paycre3 as
select distinct a.ref2,a.je_batch_id, d.trx_id,d.amt amount,
--select distinct a.ref2,a.je_batch_id, c.credit_card_trx_id,c.amount,
d.employee_id,d.ccid
from paycre1 a,ap_expense_report_headers b,ap_expense_report_lines c,
doi_credit_card_trxns d
where a.credit_card_trx_id is null
and a.ref2=b.vouchno
and b.report_header_id=c.report_header_id
and  c.credit_card_trx_id=d.trx_id
/
insert into gl.gl_interface (
 STATUS                    , SET_OF_BOOKS_ID           ,
 USER_JE_SOURCE_NAME       , USER_JE_CATEGORY_NAME          ,
 ACCOUNTING_DATE           , CURRENCY_CODE             ,
 DATE_CREATED              , CREATED_BY                ,
 ACTUAL_FLAG               , 
 SEGMENT1                  , SEGMENT2                 , 
 SEGMENT3                 , SEGMENT4                 ,
 SEGMENT5                 , SEGMENT6                 , 
 SEGMENT7                 ,
 ENTERED_DR                , 
 ENTERED_CR                ,
 reference10)
select
 'NEW', 1, 
 'Payables Adjustment' , 'Payables Adjustment', 
 sysdate, 'AUD',
 SYSDATE , 3, 
 'A', 
 segment1,segment2,
 segment3,segment4,
 segment5,segment6,
 segment7,
 decode(sign(amount),1,amount,null),
  decode(sign(amount),-1,-amount,null),
 description||' '||ltrim(to_char(je_batch_id))
 from payadj6
 where amount != 0
/
insert into gl.gl_interface (
 STATUS                    , SET_OF_BOOKS_ID           ,
 USER_JE_SOURCE_NAME       , USER_JE_CATEGORY_NAME          ,
 ACCOUNTING_DATE           , CURRENCY_CODE             ,
 DATE_CREATED              , CREATED_BY                ,
 ACTUAL_FLAG               , 
 code_combination_id,
 ENTERED_DR                , 
 ENTERED_CR                ,
 reference10)
select
 'NEW', 1, 
 'Payables Adjustment' , 'Payables Adjustment', 
 sysdate, 'AUD',
 SYSDATE , 3, 
 'A', 
 219157,
 decode(sign(sum(-amt)),1,sum(-amt),null),
  decode(sign(sum(-amt)),-1,-sum(-amt),null),
 'Credit Card Adjustment '||ltrim(to_char(je_batch_id))
 from paycre2
 group by je_batch_id 
 having sum(amt) != 0
/
insert into gl.gl_interface (
 STATUS                    , SET_OF_BOOKS_ID           ,
 USER_JE_SOURCE_NAME       , USER_JE_CATEGORY_NAME          ,
 ACCOUNTING_DATE           , CURRENCY_CODE             ,
 DATE_CREATED              , CREATED_BY                ,
 ACTUAL_FLAG               , 
 code_combination_id,
 ENTERED_DR                , 
 ENTERED_CR                ,
 reference10)
select
 'NEW', 1, 
 'Payables Adjustment' , 'Payables Adjustment', 
 sysdate, 'AUD',
 SYSDATE , 3, 
 'A', 
 default_code_comb_id,
 decode(sign(sum(amt)),1,sum(amt),null),
  decode(sign(sum(amt)),-1,-sum(amt),null),
 'Credit Card Adjustment '||ltrim(to_char(je_batch_id))
 from paycre2
 group by default_code_comb_id,je_batch_id
 having sum(amt) != 0
/
insert into gl.gl_interface (
 STATUS                    , SET_OF_BOOKS_ID           ,
 USER_JE_SOURCE_NAME       , USER_JE_CATEGORY_NAME          ,
 ACCOUNTING_DATE           , CURRENCY_CODE             ,
 DATE_CREATED              , CREATED_BY                ,
 ACTUAL_FLAG               , 
 code_combination_id,
 ENTERED_DR                , 
 ENTERED_CR                ,
 reference10)
select
 'NEW', 1, 
 'Payables Adjustment' , 'Payables Adjustment', 
 sysdate, 'AUD',
 SYSDATE , 3, 
 'A', 
 219157,
 decode(sign(sum(amount)),1,sum(amount),null),
  decode(sign(sum(amount)),-1,-sum(amount),null),
 'Credit Card Adjustment '||ltrim(to_char(je_batch_id))
 from paycre3
 group by je_batch_id
 having sum(amount) != 0
/
insert into gl.gl_interface (
 STATUS                    , SET_OF_BOOKS_ID           ,
 USER_JE_SOURCE_NAME       , USER_JE_CATEGORY_NAME          ,
 ACCOUNTING_DATE           , CURRENCY_CODE             ,
 DATE_CREATED              , CREATED_BY                ,
 ACTUAL_FLAG               , 
 code_combination_id,
 ENTERED_DR                , 
 ENTERED_CR                ,
 reference10)
select
 'NEW', 1, 
 'Payables Adjustment' , 'Payables Adjustment', 
 sysdate, 'AUD',
 SYSDATE , 3, 
 'A', 
 ccid,
 decode(sign(sum(-amount)),1,sum(-amount),null),
  decode(sign(sum(-amount)),-1,-sum(-amount),null),
 'Credit Card Adjustment '||ltrim(to_char(je_batch_id))
 from paycre3
 group by ccid,je_batch_id
 having sum(-amount) != 0
/
exit;
