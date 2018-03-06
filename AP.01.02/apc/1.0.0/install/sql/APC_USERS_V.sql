/*$Header: svn://d02584/consolrepos/branches/AP.01.02/apc/1.0.0/install/sql/APC_USERS_V.sql 1368 2017-07-02 23:54:39Z svnuser $*/
CREATE OR REPLACE VIEW 
apps.apc_users_v
(
   first_name,
   last_name,
   email_address,
   person_id
) 
AS 
SELECT TRIM(NVL(SUBSTR(ppf.first_name,1,(instr( ppf.first_name, (' ')))), ppf.first_name)) first_name,
       ppf.last_name,
       ppf.email_address, 
       ppf.person_id
FROM   per_all_people_f ppf,
       fnd_user fu,
       per_all_assignments_f paaf,
       per_assignment_status_types past
WHERE  ppf.employee_number IS NOT NULL
AND    ppf.person_id = fu.employee_id
AND    ppf.person_id = paaf.person_id
AND    paaf.assignment_status_type_id = past.assignment_status_type_id
AND    paaf.primary_flag = 'Y'
AND    ppf.email_address IS NOT NULL
AND    (
          (fu.end_date       IS NULL)
          OR(fu.end_date   > SYSDATE)
       )
AND    TRUNC(SYSDATE) between ppf.effective_start_date and ppf.effective_end_date
AND    TRUNC(SYSDATE) between paaf.effective_start_date and paaf.effective_end_date
AND    past.per_system_status in ('ACTIVE_ASSIGN','SUSP_ASSIGN');

 GRANT SELECT ON APPS.apc_users_v TO KOFAX;

 CREATE OR REPLACE SYNONYM KOFAX.apc_users_v FOR APPS.apc_users_v;