rem **********************************************************************
rem $Header: svn://d02584/consolrepos/branches/AP.02.02/apc/1.0.0/sql/APCEFTWB.sql 3150 2017-12-07 22:14:52Z svnuser $
rem CEMLI ID: GL.03.01
rem
rem  %H% %A% %T%
rem
rem Desc      : Westpac Bank Direct Debit file format
rem
rem Input     : CHECKRUN_NAME
rem  
rem Called by : Format Payments
rem
rem History   :
rem
rem Date       Who                  Modification
rem ---------  -------------------  -------------------------------------
rem 21-APR-95  Sarawoot             Create
rem 17-MAY-95  Julian Gittins       Modified for Commonwealth Bank
rem 19-JUN-97  David Musiov         Modified for Westpac Bank Direct Debit
rem 19-SEP-97  John Towns           Modified for ANZ Online Direct Debit
rem 07-JUL-98  John Towns           Added ATO Codes.
rem 07-MAY-99  Andrew Cohen         Modified for Westpac Bank Direct Debit
rem 02-JUL-99  Mercil Lariba        Modified ATO transactions for WB Direct
rem 05-AUG-99  Shannon Ryan         Added extra self balancing trans to 
rem                                 credit trace account by total payment 
rem                                 amount.
rem 25-JAN-01  Stephen Anderson     Updated to 11i.
rem 04-MAR-03  Consultant           Modified for Multi-Org
rem 31-OCT-17  Dario                Change DTPLI to DEDJTR on output file
rem 07-DEC-17  RED ROCK             Apply fix for FSC-5795: GL overnight
rem                                 RUN_AP payment program needs to be 
rem                                 looked at as it does not pick up all
rem                                 Pay Groups. Currently picking up S 
rem                                 Bank only
rem
rem Parameters:
rem &1 Cheque Run Name
rem
rem **********************************************************************

set feedback off
set newpage 0
set linesize 120
set pagesize 0
set heading off
set space 0
set arraysize 1
set verify off
set echo off

rem ********************************************************************
rem  Set Multi-Org
rem ******************************************************************** 
variable v_org_id number
BEGIN
  :v_Org_ID := fnd_profile.value('ORG_ID');
  IF :v_Org_ID IS NOT NULL THEN
    fnd_client_info.set_org_context(:v_Org_ID);
  END IF;
END;
/

rem ********************************************************************
rem  Get CheckRun/EFT Batch Information
rem ******************************************************************** 

variable CHECKRUN_BANK_AC    varchar2(9)
variable CHECKRUN_REMITTER   varchar2(26)
variable BANK_BSB_NO         varchar2(7)
variable PAY_DATE            varchar2(6)
variable EFT_NO              varchar2(6)
variable BANK_HEADER         varchar2(100)
variable BANK_DESC           varchar2(100)

begin
  select  lpad(AC.BANK_ACCOUNT_NUM,9,' '), 
          rpad(UPPER(BANK.DESCRIPTION),26,' '),
          rpad(BANK.BANK_NUM,7,' '), 
          to_char(CHK.CHECK_DATE,'DDMMYY'),
          lpad(nvl(AC.EFT_USER_NUMBER,'000000'),6,'0'),
          AC.ATTRIBUTE8,
          AC.ATTRIBUTE9
    into  :CHECKRUN_BANK_AC, 
          :CHECKRUN_REMITTER, 
          :BANK_BSB_NO, 
          :PAY_DATE,
          :EFT_NO,
          :BANK_HEADER,
          :BANK_DESC
    from  AP_INVOICE_SELECTION_CRITERIA CHK,
          AP_BANK_ACCOUNTS AC,
          AP_BANK_BRANCHES BANK
   where  CHK.BANK_ACCOUNT_NAME = AC.BANK_ACCOUNT_NAME
     and  BANK.BANK_BRANCH_ID = AC.BANK_BRANCH_ID
     and  CHK.CHECKRUN_NAME = '&&1';
end;
/

rem ********************************************************************
rem  Header Record (Type 0)
rem ********************************************************************

set verify off
set heading off
set echo off

select '0' || rpad(' ',17) || '01' || 'WBC' || rpad(' ',7) || RPAD(:BANK_HEADER, 26, ' ') || 
       :EFT_NO || 'SUPPLIER PAY' ||
       :PAY_DATE || rpad(' ',40)
from   dual;

rem ********************************************************************
rem  Detailed Record  formed by union of Non-ATO and ATO records
rem ********************************************************************

select 	'1' 
        || nvl(substr(replace(B.BANK_NUMBER,'-'),1,3),'   ') || '-'
        || nvl(substr(replace(B.BANK_NUM,'-'),1,3),'   ')
        || lpad(substr(nvl(B.BANK_ACCOUNT_NUM, '         '),1,9),9)
	|| ' 50'
	|| ltrim(to_char(A.CHECK_AMOUNT*100,'0000000000'))
        || rpad(substr(b.bank_account_name,1,32),32)
	|| rpad(nvl(substr(c.ATTRIBUTE11,1,18),
	           substr(A.CHECK_NUMBER|| :BANK_DESC || ' ', 1, 18)), 18)
        || :BANK_BSB_NO
        || :CHECKRUN_BANK_AC
        || substr(:CHECKRUN_REMITTER,1,16)
        || '00000000'
from    AP_SELECTED_INVOICE_CHECKS A,
        doi_vendor_bank_details  B,
        PO_VENDOR_SITES C,
        PO_VENDORS D,
        AP_BANK_ACCOUNTS_ALL E
where   C.vendor_site_id = B.vendor_site_id (+)
  and   C.VENDOR_ID = A.VENDOR_ID (+)
  and   C.VENDOR_SITE_CODE = A.VENDOR_SITE_CODE (+)
  and   C.VENDOR_ID = D.VENDOR_ID
  and   E.BANK_ACCOUNT_ID = B.EXTERNAL_BANK_ACCOUNT_ID
  and   A.OK_TO_PAY_FLAG = 'Y'
  and   A.CHECKRUN_NAME = '&&1'
  and   b.external_bank_account_id=a.external_bank_account_id
  order by A.CHECK_NUMBER;

DECLARE
  CURSOR c1 IS
    select asi.checkrun_name,
           asi.invoice_id,
           asi.payment_num,
           asi.invoice_amount,
           asi.discount_amount,
           asi.withholding_amount,
           asi.payment_amount,
           asi.invoice_description
    from   ap_selected_invoices asi
    where  asi.ok_to_pay_flag = 'Y'
    and    asi.checkrun_name = '&&1';
BEGIN
  FOR c1_rec IN c1 LOOP
    insert into APC_EFT_SELECTED_INVOICES_TEMP
      (checkrun_name,
       INVOICE_ID, 
       payment_num,
       invoice_amount, 
       discount_amount,
       withholding_amount,
       payment_amount,
       invoice_description)
    VALUES
      (c1_rec.checkrun_name,
       c1_rec.invoice_id,
       c1_rec.payment_num,
       c1_rec.invoice_amount,
       c1_rec.discount_amount,
       c1_rec.withholding_amount,
       c1_rec.payment_amount,
       c1_rec.invoice_description);
  END LOOP;
  COMMIT;
END;
/

rem ********************************************************************
rem Total Record (Type 7)
rem ********************************************************************

variable record_type_7    varchar2(122)
variable rec_cnt          number
variable total_amt        number 
variable check_run        varchar2(100)

BEGIN
  select sum(CHECK_AMOUNT), 
	 count(*), 
	 CHECKRUN_NAME
  into   :total_amt, 
	 :rec_cnt, 
	 :check_run
  from   AP_SELECTED_INVOICE_CHECKS 
  where  OK_TO_PAY_FLAG = 'Y'
  and    CHECKRUN_NAME = '&&1'
  group by CHECKRUN_NAME;

  :rec_cnt := :rec_cnt + 1; -- to account for the extra self balancing trans

  :record_type_7 :=  '7999-999' || rpad (' ',12) || 
      ltrim(to_char(0,'0000000000')) ||  
      ltrim(to_char(:total_amt*100,'0000000000')) || 
      ltrim(to_char(:total_amt*100,'0000000000')) || 
      rpad(' ',24) || ltrim(to_char(:rec_cnt,'000000')) || 
      rpad(' ',40);
EXCEPTION
  when NO_DATA_FOUND then 
    :record_type_7 :=  '7999-999' || rpad (' ',12) || rpad ('0',30,'0') || 
         rpad (' ',24) || rpad ('0',6,'0') || rpad (' ',40);
END;
/

rem ********************************************************************
rem  Extra self balancing transaction
rem ********************************************************************

select '1' 
       ||rpad(substr(:BANK_BSB_NO,1,7),7)
       ||lpad(substr(nvl(:CHECKRUN_BANK_AC,'         '),1,9),9)
       ||' '
       ||'13'
       ||ltrim(to_char(:total_amt*100,'0000000000'))
       ||rpad(substr(:CHECKRUN_REMITTER,1,32),32)
       ||rpad('CRED PAYS',18)
       ||:BANK_BSB_NO
       ||:CHECKRUN_BANK_AC
       ||substr(:CHECKRUN_REMITTER,1,16)
       || '00000000'
from   dual;

-- ********************************************************************
-- Print out Record Type 7
-- ********************************************************************
--print record_type_7

select :record_type_7 from dual;


-- ********************************************************************
-- Update payment batch status and Delete from temp table  
-- ********************************************************************

update AP_INVOICE_SELECTION_CRITERIA
set    STATUS = 'FORMATTED'
where  CHECKRUN_NAME = '&&1';

delete from AP_CHECKRUN_CONC_PROCESSES
where  CHECKRUN_NAME = '&&1'
and    PROGRAM = 'FORMAT';

-- ********************************************************************
-- Commit changes and exit 
-- ********************************************************************
commit;
exit
