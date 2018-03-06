CREATE OR REPLACE PACKAGE BODY xxfnd_generic_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AR.03.01/fndc/1.0.0/install/sql/XXFND_GENERIC_PKG.pkb 2558 2017-09-19 04:46:44Z svnuser $ */
/*******************************************************************
**
** CEMLI ID: FND.03.01
**
** Description: Program to update email address after sanitization
**
** Change History:
**
** Date        Who                  Comments
** 17/08/2017  Joy Pinto                Initial build.
**
*******************************************************************/
g_debug_flag               VARCHAR2(1) := 'N';

PROCEDURE debug_msg
(
   p_message               IN VARCHAR2
) IS
BEGIN
   IF nvl(g_debug_flag, 'N') = 'Y' THEN
      fnd_file.put_line(fnd_file.log, p_message);
   END IF;
END debug_msg;

PROCEDURE output_msg
(
   p_message               IN VARCHAR2
) IS
BEGIN
   fnd_file.put_line(fnd_file.output, p_message);
END output_msg;

PROCEDURE email_update
(
   p_errbuff           OUT VARCHAR2,
   p_retcode           OUT NUMBER,
   p_object            IN  VARCHAR2,
   p_email_address     IN  VARCHAR2,
   p_debug             IN  VARCHAR2
)
IS
   -- Local Variables 
   -- ----------------------- 
   ln_object_version_number       PER_ALL_PEOPLE_F.OBJECT_VERSION_NUMBER%TYPE  := 7; 
   lc_dt_ud_mode                  VARCHAR2(100)                                                                                     := NULL; 
   ln_assignment_id               PER_ALL_ASSIGNMENTS_F.ASSIGNMENT_ID%TYPE;
   lc_employee_number             PER_ALL_PEOPLE_F.EMPLOYEE_NUMBER%TYPE ;
  
   -- Out Variables for Find Date Track Mode API 
   -- ---------------------------------------------------------------- 
   lb_correction                  BOOLEAN; 
   lb_update                      BOOLEAN; 
   lb_update_override             BOOLEAN;  
   lb_update_change_insert        BOOLEAN;

   -- Out Variables for Update Employee API 
   -- ----------------------------------------------------------- 
   ld_effective_start_date        DATE; 
   ld_effective_end_date          DATE; 
   lc_full_name                   PER_ALL_PEOPLE_F.FULL_NAME%TYPE; 
   ln_comment_id                  PER_ALL_PEOPLE_F.COMMENT_ID%TYPE;  
   lb_name_combination_warning    BOOLEAN; 
   lb_assign_payroll_warning      BOOLEAN; 
   lb_orig_hire_warning           BOOLEAN;
   lv_new_email_address           VARCHAR2(1000) := p_email_address;
   ln_count                       NUMBER  := 0;
   lv_instance                    VARCHAR2(100);
   
   CURSOR get_emp_details IS
   SELECT * 
   FROM   per_all_people_f
   WHERE  trunc(SYSDATE) between effective_start_date and effective_end_date
   AND    employee_number IS NOT NULL;   
   
   CURSOR c_user_email IS
      SELECT * FROM FND_USER
      WHERE  TRUNC(SYSDATE) BETWEEN nvl(START_DATE,'01-JAN-1951') AND nvl(END_DATE,'31-DEC-4712');
      
   CURSOR c_instance_name IS
      SELECT instance_name 
      FROM   v$instance;
BEGIN
   g_debug_flag := nvl(p_debug,'N');
   OPEN  c_instance_name;
   FETCH c_instance_name INTO lv_instance;
   CLOSE c_instance_name;
   
   IF lv_instance != 'ERPRPOD' THEN
   
   IF UPPER(nvl(p_object,'ALL')) = 'ALL' OR UPPER(nvl(p_object,'ALL')) = 'USERS' THEN
   
      debug_msg('Update USERS Email Start');
      
      -- Update FND_USER Email
      FOR c_rec IN c_user_email LOOP
      BEGIN  
         fnd_user_pkg.updateuser
         (  x_user_name               => c_rec.user_name,
            x_owner                   => NULL,
            x_email_address           => lv_new_email_address
         );
         COMMIT; 
         ln_count := ln_count+1;
      EXCEPTION WHEN OTHERS THEN
         debug_msg('Unable to update email address for user :'||c_rec.user_name||'Error message is : '||SQLERRM);
      END; 
      
      END LOOP;
      
      output_msg('Number of user Emails Updated : '||ln_count);      
      debug_msg('Number of user Emails Updated : '||ln_count);
      debug_msg('Update USERS Email End');
      
   END IF;
   
   IF UPPER(nvl(p_object,'ALL')) = 'ALL' OR UPPER(nvl(p_object,'ALL')) = 'EMPLOYEES' THEN
      ln_count := 0;
      debug_msg('Update EMPLOYEES Email Start');
      
      FOR c_rec IN get_emp_details LOOP
      BEGIN  
         lc_employee_number := c_rec.employee_number;
         ln_object_version_number := c_rec.object_version_number;

         -- Update Employee API
         -- ---------------------------------  
         hr_person_api.update_person
         (       -- Input Data Elements
            -- ------------------------------
            p_effective_date                => c_rec.effective_start_date,
            p_datetrack_update_mode         => 'CORRECTION',
            p_person_id                     => c_rec.person_id,
            -- Output Data Elements
            -- ----------------------------------
           p_employee_number                => lc_employee_number,
           p_email_address                  => lv_new_email_address,
           p_object_version_number          => ln_object_version_number,
           p_effective_start_date           => ld_effective_start_date,
           p_effective_end_date             => ld_effective_end_date,
           p_full_name                      => lc_full_name,
           p_comment_id                     => ln_comment_id,
           p_name_combination_warning       => lb_name_combination_warning,
           p_assign_payroll_warning         => lb_assign_payroll_warning,
           p_orig_hire_warning              => lb_orig_hire_warning
          
          );
    
          COMMIT; 
          ln_count := ln_count+1;
      EXCEPTION WHEN OTHERS THEN
         debug_msg('Unable to update email address for employee number :'||lc_employee_number||'Error message is : '||SQLERRM);
      END;    
      END LOOP;
      
      -- Fixed for the cases where email address update is failing
      
      debug_msg('Update Missing EMPLOYEES Email Start');
      
      UPDATE PER_ALL_PEOPLE_F
        SET  EMAIL_ADDRESS = lv_new_email_address ,  
             LAST_UPDATE_DATE = SYSDATE,
             LAST_UPDATED_BY = fnd_global.user_id
      WHERE  TRUNC(SYSDATE) BETWEEN EFFECTIVE_START_DATE AND EFFECTIVE_END_DATE
      AND    UPPER(EMAIL_ADDRESS) <> UPPER(lv_new_email_address);
      
      debug_msg('Update Missing EMPLOYEES Email End');
      
      ln_count := ln_count+SQL%ROWCOUNT;
      
      output_msg('Number of EMPLOYEES Emails Updated : '||ln_count);      
      debug_msg('Number of EMPLOYEES Emails Updated : '||ln_count);
      debug_msg('Update EMPLOYEES Email End');
      
      COMMIT;
   
   END IF;   
   IF UPPER(nvl(p_object,'ALL')) = 'ALL' OR UPPER(nvl(p_object,'ALL')) = 'CUSTOMERS' THEN 
      
      UPDATE HZ_CUST_ACCT_SITES_ALL
      SET ATTRIBUTE2 = lv_new_email_address,
          LAST_UPDATE_DATE = SYSDATE,
          LAST_UPDATED_BY = fnd_global.user_id;
      
      output_msg('Number of CUSTOMERS Updated : '||SQL%ROWCOUNT);
      
      IF SQL%ROWCOUNT > 0 THEN 
         COMMIT;
      END IF;
       
   END IF;
   IF UPPER(nvl(p_object,'ALL')) = 'ALL' OR UPPER(nvl(p_object,'ALL')) = 'AR INVOICES' THEN
      
      UPDATE RA_CUSTOMER_TRX_ALL
      SET ATTRIBUTE8 = lv_new_email_address,
          LAST_UPDATE_DATE = SYSDATE,
          LAST_UPDATED_BY = fnd_global.user_id;
      
      output_msg('Number of AR INVOICES Updated : '||SQL%ROWCOUNT);
      
      IF SQL%ROWCOUNT > 0 THEN 
         COMMIT;
      END IF;
       
   END IF;
   -- Added AR Transaction Type as per MD 050 comment 21-Aug-2017
   IF UPPER(nvl(p_object,'ALL')) = 'ALL' OR UPPER(nvl(p_object,'ALL')) = 'AR TRANSACTION TYPES' THEN
      
      UPDATE RA_CUST_TRX_TYPES_ALL
      SET    ATTRIBUTE14 = lv_new_email_address,
             LAST_UPDATE_DATE = SYSDATE,
             LAST_UPDATED_BY = fnd_global.user_id
      WHERE  UPPER(ATTRIBUTE_CATEGORY) = UPPER('Agriculture Feeder Systems');
      
      output_msg('Number of AR TRANSACTION TYPES Updated : '||SQL%ROWCOUNT);
      
      IF SQL%ROWCOUNT > 0 THEN 
         COMMIT;
      END IF;
       
   END IF;   
   IF UPPER(nvl(p_object,'ALL')) = 'ALL' OR UPPER(nvl(p_object,'ALL')) = 'VENDOR SITES' THEN
      
        UPDATE PO_VENDOR_SITES_ALL
        SET ATTRIBUTE3 = lv_new_email_address,
            LAST_UPDATE_DATE = SYSDATE,
            LAST_UPDATED_BY = fnd_global.user_id;
      
      output_msg('Number of VENDOR SITES Updated : '||SQL%ROWCOUNT); 
      
      IF SQL%ROWCOUNT > 0 THEN 
         COMMIT;
      END IF;
            
   END IF;
   
   ELSE
   output_msg('This script should not be run in Production');
   debug_msg('This script should not be run in Production');
   p_retcode := 2;
   END IF;
   
EXCEPTION
WHEN OTHERS THEN
   debug_msg('Unexpected Error encountered in the program  : '||SQLERRM);
END email_update;
END xxfnd_generic_pkg;
/