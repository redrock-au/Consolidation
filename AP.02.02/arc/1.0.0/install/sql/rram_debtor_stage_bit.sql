-- -------------------------------------------------------------------------------------
-- $Header: svn://d02584/consolrepos/branches/AP.02.02/arc/1.0.0/install/sql/rram_debtor_stage_bit.sql 1607 2017-07-10 01:20:42Z svnuser $
-- Purpose:  Table creation script for trigger rram_debtor_stage_bit
-- Project:  Arrah (RRAM / Oracle Finance Integration)
-- Date:     Feb 2015
-- -------------------------------------------------------------------------------------
create or replace trigger rram_debtor_stage_bit
before insert on rram_debtor_stage
for each row
begin
    select rram_debtor_stage_s1.nextval 
      into :new.stage_id
      from dual;

    if :new.creation_date is null then
        :new.creation_date := sysdate;
    end if;

    if :new.interface_status is null then
        :new.interface_status := 'N';
    end if;
end;
/


