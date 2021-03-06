/*$Header: svn://d02584/consolrepos/branches/AP.02.02/poc/1.0.0/install/sql/POC_ENQUIRIES_CONTACT_LOV_V.sql 1607 2017-07-10 01:20:42Z svnuser $*/
CREATE OR REPLACE VIEW 
   apps.poc_enquiries_contact_lov_v
				(employee_id,
				details
				)
AS
   SELECT employee_id,
          rtrim(ltrim(first_name||' '||last_name||'  Tel: '||work_telephone)) as Details
   FROM   hr_employees_current_v
   ORDER BY first_name,
            last_name
/
