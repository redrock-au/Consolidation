-- -------------------------------------------------------------------------------------
-- $Header: svn://d02584/consolrepos/branches/AR.02.03/arc/1.0.0/install/sql/rram_site_stage_bit.sql 1451 2017-07-04 23:01:51Z svnuser $
-- Purpose:  Table creation script for trigger rram_site_stage_bit
-- Project:  Arrah (RRAM / Oracle Finance Integration)
-- Date:     Feb 2015
-- -------------------------------------------------------------------------------------
create or replace trigger rram_site_stage_bit
before insert on rram_site_stage
for each row
begin
    select rram_site_stage_s1.nextval 
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

