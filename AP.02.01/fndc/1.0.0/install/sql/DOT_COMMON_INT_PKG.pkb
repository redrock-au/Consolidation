create or replace package body dot_common_int_pkg as
/* $Header: svn://d02584/consolrepos/branches/AP.02.01/fndc/1.0.0/install/sql/DOT_COMMON_INT_PKG.pkb 1781 2017-07-14 05:29:33Z svnuser $*/

/****************************************************************************
**
** CEMLI ID: INT.02.00
**
** Description: Common Interface Framework.
**
** Change History:
**
** Date        Who                   Comments
** 18/04/2017  RED ROCK Consulting   
**
****************************************************************************/
-- $Id: $
--
--
gb_debug                        constant boolean := true;
gb_test_mode                    constant boolean := false;
gv_package_name                 constant varchar2(50) := 'dot_common_int_pkg';
--
--
gv_cp_success                   constant varchar2(1) := 0;
gv_cp_warning                   constant varchar2(1) := 1;
gv_cp_error                     constant varchar2(1) := 2;
--
--
/***************************************************************************
**  FUNCTION
**    get_run_id
**
**  DESCRIPTION
**    This API is used to get the interface run id
***************************************************************************/
FUNCTION get_run_id return dot_int_runs.run_id%type
is

l_run_id   dot_int_runs.run_id%type;

-- Get next sequence number
CURSOR  run_id_cur IS
SELECT dot_int_runs_id_s.nextval FROM dual;

BEGIN
OPEN  run_id_cur ;
FETCH  run_id_cur INTO l_run_id;
CLOSE  run_id_cur ;

  RETURN l_run_id;

END get_run_id ;


/***************************************************************************
**  Procedure
**    debug
**
**  DESCRIPTION
**    Writes debug information to either DBMS Output or Debug Table.
**
***************************************************************************/
procedure debug(pv_message in varchar2, pv_proc in varchar2)
is
begin
    --
    if gb_debug then
         --
         if not (gb_test_mode) then
              --
              dot_common_pkg.log (gv_package_name||'.'||pv_proc||' - '||pv_message);
              --
         else
              --
              dbms_output.put_line(gv_package_name||'.'||pv_proc||' - '||pv_message);
              --
         end if;
         --
    end if;
    --
end debug;
--
--
/***************************************************************************
**  FUNCTION
**    writerep
**
**  DESCRIPTION
**    Writes report information to either DBMS Output or CP log file.
**
***************************************************************************/
PROCEDURE writerep (p_msg IN VARCHAR2)
IS
BEGIN
     --
     fnd_file.put_line (fnd_file.output, p_msg);
     --
END writerep;
--
--
/***************************************************************************
**  Procedure
**    submit_request
**
**  DESCRIPTION
**    Generic request submit procudure
**
***************************************************************************/
FUNCTION  submit_request (p_application   IN VARCHAR2 DEFAULT 'FNDC' ,
                           p_program       IN VARCHAR2 DEFAULT NULL ,
                           p_description   IN VARCHAR2 DEFAULT NULL ,
                           p_argument1     IN VARCHAR2 DEFAULT CHR(0) ,
                           p_argument2     IN VARCHAR2 DEFAULT CHR(0) ,
                           p_argument3     IN VARCHAR2 DEFAULT CHR(0) ,
                           p_argument4     IN VARCHAR2 DEFAULT CHR(0) ,
                           p_argument5     IN VARCHAR2 DEFAULT CHR(0) ,
                           p_argument6     IN VARCHAR2 DEFAULT CHR(0) ,
                           p_argument7     IN VARCHAR2 DEFAULT CHR(0) ,
                           p_argument8     IN VARCHAR2 DEFAULT CHR(0) ,
                           p_argument9     IN VARCHAR2 DEFAULT CHR(0) ,
                           p_argument10    IN VARCHAR2 DEFAULT CHR(0) ,
                           p_dev_status   OUT VARCHAR2
                           ) return NUMBER is
v_request_id       NUMBER;
v_phase            VARCHAR2(240);
v_status           VARCHAR2(240);
v_dev_phase        VARCHAR2(240);
v_message1         VARCHAR2(240);
v_result           BOOLEAN;

BEGIN


  v_request_id := fnd_request.submit_request ( p_application
                                               ,p_program
                                               ,p_description
                                               ,NULL          --start_time
                                               ,FALSE         --sub_request
                                               ,p_argument1
                                               ,p_argument2
                                               ,p_argument3
                                               ,p_argument4
                                               ,p_argument5
                                               ,p_argument6
                                               ,p_argument7
                                               ,p_argument8
                                               ,p_argument9
                                               ,p_argument10
                                               );
  COMMIT;

  if (v_request_id != 0) then
    --
    -- Wait for request to finish
    v_result := fnd_concurrent.wait_for_request ( v_request_id         --request_id
                                               ,1                    --interval
                                               ,0                    --max_wait
                                               ,v_phase              --phase
                                               ,v_status             --status
                                               ,v_dev_phase          --dev_phase
                                               ,p_dev_status         --dev_status
                                               ,v_message1           --message
                                               );
  else
    --
    dot_common_pkg.log('Error submitting request:'||fnd_message.get);
    --
  end if;

  --
  RETURN v_request_id;
  --

END submit_request;

/***************************************************************************
**  FUNCTION
**    INITIALISE_RUN
**
**  DESCRIPTION
**    Records interface run results and is representative of a data batch.
**    This API is used to record the start of an interface run.  An interface
**    run may have many phases.  This API will be called at the very first
**    phase of the interface run, prior to the run phase being created.
***************************************************************************/
function  initialise_run (p_int_code	     in dot_int_interfaces.int_code%type
                         ,p_src_code	     in dot_int_data_sources.src_code%type  default null
                         ,p_src_rec_count	 in dot_int_runs.src_rec_count%type default null
                         ,p_src_hash_total in dot_int_runs.src_hash_total%type default null
                         ,p_src_batch_name in dot_int_runs.src_batch_name%type default null
                         ,p_run_id         in dot_int_runs.run_id%type)
return dot_int_runs.run_id%type
is

  l_run_id                      NUMBER;
  l_int_id                      NUMBER;
  l_current_user_id             NUMBER    := nvl(Fnd_Profile.VALUE('USER_ID'),-1);
  l_current_login_id            NUMBER    := nvl(Fnd_Profile.VALUE('LOGIN_ID'),-1);
  l_request_id                  NUMBER    := nvl(FND_PROFILE.VALUE('CONC_REQUEST_ID'),-1);
  l_current_date                DATE;

  e_no_int_id                   EXCEPTION;

  PRAGMA AUTONOMOUS_TRANSACTION;

  -- Cursor to get the interface id
  CURSOR c_get_int_id (b_i_int_code IN VARCHAR2) IS
  SELECT int_id
  FROM   dot_int_interfaces
  WHERE  int_code = b_i_int_code;

BEGIN

  -- Get current date
  SELECT sysdate
  INTO l_current_date
  FROM dual;

  -- If run id is passed in then use that otherwise get the next value from the sequence
  IF p_run_id IS NULL
  THEN
    -- Get next sequence number
    SELECT dot_int_runs_id_s.nextval
    INTO l_run_id
    FROM dual;
  ELSE
    l_run_id := p_run_id;
  END IF;

  --Get interface id
  OPEN c_get_int_id (p_int_code);
  FETCH c_get_int_id INTO l_int_id;
    IF c_get_int_id%NOTFOUND
    THEN
      RAISE e_no_int_id;
    END IF;
  CLOSE c_get_int_id;

  -- Insert into dot_int_runs_table
  INSERT INTO dot_int_runs (run_id
                              ,int_id
                              ,src_rec_count
                              ,src_hash_total
                              ,src_batch_name
                              ,created_by
                              ,creation_date
                              ,last_updated_by
                              ,last_update_date
                              ,last_update_login
                              ,request_id
                              )
                      VALUES  (l_run_id                        --run_id
                              ,l_int_id                        --int_id
                              ,p_src_rec_count                 --src_rec_count
                              ,p_src_hash_total                --src_hash_total
                              ,p_src_batch_name                --src_batch_name
                              ,l_current_user_id               --created_by
                              ,l_current_date                  --creation_date
                              ,l_current_user_id               --last_updated_by
                              ,l_current_date                  --last_update_date
                              ,l_current_login_id              --last_update_login
                              ,l_request_id                    --request_id
                              );

  COMMIT;
  RETURN(l_run_id);

EXCEPTION
WHEN e_no_int_id THEN
  dot_common_pkg.log('ERROR in dot_common_int_pkg.initialise_run: No Interface ID found');
  RAISE;
WHEN OTHERS THEN
  dot_common_pkg.log('ERROR in dot_common_int_pkg.initialise_run: '||SQLERRM);
  RAISE;
end initialise_run;
--
--
/***************************************************************************
**  PROCEDURE
**    UPDATE_RUN
**
**  DESCRIPTION
**    Records interface batch details.  This API is used to record batch
**    details on an existing interface run.  It will be used where the
**    information about the data batch are not available until the data
**    batch has been processed (the majority of cases) and hence cannot
**    be passed in the INITIALISE_RUN API.   This API will be called after
**    the run has been created when the run information is available.
***************************************************************************/
procedure update_run (p_run_id         in dot_int_runs.run_id%type
                     ,p_src_rec_count	 in dot_int_runs.src_rec_count%type
                     ,p_src_hash_total in dot_int_runs.src_hash_total%type
                     ,p_src_batch_name in dot_int_runs.src_batch_name%type)
is
     --
     l_current_date                DATE;
     l_current_user_id             NUMBER    := fnd_profile.VALUE('USER_ID');
     l_current_login_id            NUMBER    := fnd_profile.VALUE('LOGIN_ID');
     l_request_id                  NUMBER    := fnd_profile.VALUE('CONC_REQUEST_ID');
     --
     PRAGMA AUTONOMOUS_TRANSACTION;
     --
BEGIN
     --
     SELECT sysdate
     INTO   l_current_date
     FROM   dual;
     --
     UPDATE dot_int_runs
     SET    src_rec_count     = p_src_rec_count
     ,      src_hash_total    = p_src_hash_total
     ,      src_batch_name    = p_src_batch_name
     ,      last_updated_by   = l_current_user_id
     ,      last_update_date  = l_current_date
     ,      last_update_login = l_current_login_id
     ,      request_id        = l_request_id
     WHERE  run_id            = p_run_id;
     --
     COMMIT;

EXCEPTION
WHEN OTHERS THEN
  dot_common_pkg.log('ERROR in dot_common_int_pkg.update_run: '||SQLERRM);
     --
     --
end update_run;
--
--
/***************************************************************************
**  FUNCTION
**    START_RUN_PHASE
**
**  DESCRIPTION
**    This API is used to record the individual interface phase run.
**    This API will be called at every stage in the interface.
***************************************************************************/
function start_run_phase (p_run_id	                 in dot_int_runs.run_id%type
                          ,p_phase_code	             in dot_int_run_phases.phase_code%type
                          ,p_phase_mode	             in dot_int_run_phases.phase_mode%type
                          ,p_src_code	               in dot_int_data_sources.src_code%type  default null
                          ,p_rec_count	             in dot_int_run_phases.rec_count%type default null
                          ,p_hash_total	             in dot_int_run_phases.hash_total%type default null
                          ,p_batch_name	             in dot_int_run_phases.batch_name%type default null
                          ,p_int_table_name	         in dot_int_run_phases.int_table_name%type
                          ,p_int_table_key_col1	     in dot_int_run_phases.int_table_key_col1%type
                          ,p_int_table_key_col_desc1 in dot_int_run_phases.int_table_key_col_desc1%type
                          ,p_int_table_key_col2	     in dot_int_run_phases.int_table_key_col2%type
                          ,p_int_table_key_col_desc2 in	dot_int_run_phases.int_table_key_col_desc2%type
                          ,p_int_table_key_col3	     in dot_int_run_phases.int_table_key_col3%type
                          ,p_int_table_key_col_desc3 in dot_int_run_phases.int_table_key_col_desc3%type)
return dot_int_run_phases.run_phase_id%type
is

  l_run_phase_id                NUMBER;
  l_current_date                DATE;
  l_current_user_id             NUMBER    := nvl(Fnd_Profile.VALUE('USER_ID'),-1);
  l_current_login_id            NUMBER    := nvl(Fnd_Profile.VALUE('LOGIN_ID'),-1);
  l_request_id                  NUMBER    := nvl(FND_PROFILE.VALUE('CONC_REQUEST_ID'),-1);

  PRAGMA AUTONOMOUS_TRANSACTION;

BEGIN

  -- Get next sequence number
  SELECT dot_int_run_phases_id_s.nextval
  INTO l_run_phase_id
  FROM dual;

  -- Get current date
  SELECT sysdate
  INTO l_current_date
  FROM dual;

  -- Insert record into table
  INSERT INTO dot_int_run_phases (run_phase_id
                                    ,run_id
                                    ,phase_code
                                    ,phase_mode
                                    ,start_date
                                    ,end_date
                                    ,src_code
                                    ,rec_count
                                    ,hash_total
                                    ,batch_name
                                    ,status
                                    ,error_count
                                    ,success_count
                                    ,int_table_name
                                    ,int_table_key_col1
                                    ,int_table_key_col_desc1
                                    ,int_table_key_col2
                                    ,int_table_key_col_desc2
                                    ,int_table_key_col3
                                    ,int_table_key_col_desc3
                                    ,creation_date
                                    ,created_by
                                    ,last_update_date
                                    ,last_updated_by
                                    ,last_update_login
                                    ,request_id
                                     )
                          VALUES   (l_run_phase_id                 --run_phase_id
                                   ,p_run_id                       --run_id
                                   ,p_phase_code                   --phase_code
                                   ,p_phase_mode                   --phase_mode
                                   ,l_current_date                 --start_date
                                   ,NULL                           --end_date
                                   ,p_src_code                     --src_code
                                   ,p_rec_count                    --rec_count
                                   ,p_hash_total                   --hash_total
                                   ,p_batch_name                   --batch_name
                                   ,NULL                           --status
                                   ,NULL                           --error_count
                                   ,NULL                           --success_count
                                   ,p_int_table_name               --int_table_name
                                   ,p_int_table_key_col1           --int_table_key_col1
                                   ,p_int_table_key_col_desc1      --int_table_key_col_desc1
                                   ,p_int_table_key_col2           --int_table_key_col2
                                   ,p_int_table_key_col_desc2      --int_table_key_col_desc2
                                   ,p_int_table_key_col3           --int_table_key_col3
                                   ,p_int_table_key_col_desc3      --int_table_key_col_desc3
                                   ,l_current_date                 --creation_date
                                   ,l_current_user_id              --created_by
                                   ,l_current_date                 --last_update_date
                                   ,l_current_user_id              --last_updated_by
                                   ,l_current_login_id             --last_update_login
                                   ,l_request_id                   --request_id
                                   );

  COMMIT;

  RETURN (l_run_phase_id);

EXCEPTION
WHEN OTHERS THEN
  dot_common_pkg.log('ERROR in dot_common_int_pkg.start_run_phase: '||SQLERRM);
  RETURN NULL;

end start_run_phase;

/***************************************************************************
**  PROCEDURE
**    UPDATE_RUN_PHASE
**
**  DESCRIPTION
**    This API is used to record details of the individual interface phase
**      run where they are not available at the point of starting run phase.
**
***************************************************************************/
procedure update_run_phase (p_run_phase_id     in dot_int_runs.run_id%type
                           ,p_src_code	       in dot_int_data_sources.src_code%type
                           ,p_rec_count	       in dot_int_run_phases.rec_count%type
                           ,p_hash_total	     in dot_int_run_phases.hash_total%type
                           ,p_batch_name	     in dot_int_run_phases.batch_name%type)
is
     --
     l_current_date                DATE;
     l_current_user_id             NUMBER    := nvl(fnd_profile.VALUE('USER_ID'),-1);
     l_current_login_id            NUMBER    := nvl(fnd_profile.VALUE('LOGIN_ID'),-1);
     l_request_id                  NUMBER    := nvl(fnd_profile.VALUE('CONC_REQUEST_ID'),-1);
     --
     PRAGMA AUTONOMOUS_TRANSACTION;
     --
BEGIN
     --
     SELECT sysdate
     INTO   l_current_date
     FROM   dual;
     --
     UPDATE dot_int_run_phases
     SET    end_date          = l_current_date
     ,      src_code          = p_src_code
     ,      rec_count         = p_rec_count
     ,      hash_total        = p_hash_total
     ,      batch_name        = p_batch_name
     ,      last_updated_by   = l_current_user_id
     ,      last_update_date  = l_current_date
     ,      last_update_login = l_current_login_id
     ,      request_id        = l_request_id
     WHERE  run_phase_id      = p_run_phase_id;
     --
     COMMIT;

EXCEPTION
WHEN OTHERS THEN
  dot_common_pkg.log('ERROR in dot_common_int_pkg.update_run_phase: '||SQLERRM);
     --
end update_run_phase;
--
--
/***************************************************************************
**  PROCEDURE
**    END_RUN_PHASE
**
**  DESCRIPTION
**    Records interface phase run results and end of run.  This API is used
**    to record the results of an individual interface phase run.  This API
**    will be called at every stage in the interface, after processing has
**    taken place.
***************************************************************************/
procedure end_run_phase (p_run_phase_id  in dot_int_run_phases.run_phase_id%type
                        ,p_status	       in dot_int_run_phases.status%type
                        ,p_error_count   in dot_int_run_phases.error_count%type
                        ,p_success_count in dot_int_run_phases.success_count%type)
is

  l_current_date                DATE;
  l_current_user_id             NUMBER    := Fnd_Profile.VALUE('USER_ID');
  l_current_login_id            NUMBER    := Fnd_Profile.VALUE('LOGIN_ID');
  l_request_id                  NUMBER    :=FND_PROFILE.VALUE('CONC_REQUEST_ID');

  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN

  -- Get current date
  SELECT sysdate
  INTO l_current_date
  FROM dual;

  UPDATE dot_int_run_phases
  SET end_date          = l_current_date
    ,status            = p_status
    ,error_count       = p_error_count
    ,success_count     = p_success_count
    ,last_updated_by   = l_current_user_id
    ,last_update_date  = l_current_date
    ,last_update_login = l_current_login_id
    ,request_id        = l_request_id
  WHERE run_phase_id = p_run_phase_id;

  COMMIT;

EXCEPTION
WHEN OTHERS THEN
  dot_common_pkg.log('ERROR in dot_common_int_pkg.end_run_phase: '||SQLERRM);
     --
end end_run_phase;
--
--
/***************************************************************************
**  PROCEDURE
**    RAISE_ERROR
**
**  DESCRIPTION
**    Records interface phase run errors.  This API is used to record validation
**    errors as they occur.  Data recorded is used for reporting and data
**    analysis purposes.
***************************************************************************/
procedure raise_error (p_run_id	            in dot_int_runs.run_id%type
                      ,p_run_phase_id	      in dot_int_run_phases.run_phase_id%type
                      ,p_record_id	        in number
                      ,p_msg_code	          in dot_int_messages.msg_code%type
                      ,p_error_text	        in dot_int_run_phase_errors.error_text%type
                      ,p_error_token_val1	  in dot_int_run_phase_errors.error_token_val1%type
                      ,p_error_token_val2	  in dot_int_run_phase_errors.error_token_val2%type
                      ,p_error_token_val3	  in dot_int_run_phase_errors.error_token_val3%type
                      ,p_error_token_val4	  in dot_int_run_phase_errors.error_token_val4%type
                      ,p_error_token_val5   in dot_int_run_phase_errors.error_token_val5%type
                      ,p_int_table_key_val1	in dot_int_run_phase_errors.int_table_key_val1%type
                      ,p_int_table_key_val2	in dot_int_run_phase_errors.int_table_key_val2%type
                      ,p_int_table_key_val3	in dot_int_run_phase_errors.int_table_key_val3%type)
is
  --
  l_run_phase_error_id          NUMBER;
  l_current_date                DATE;
  l_current_user_id             NUMBER    := Fnd_Profile.VALUE('USER_ID');
  l_current_login_id            NUMBER    := Fnd_Profile.VALUE('LOGIN_ID');
  l_request_id                  NUMBER    := FND_PROFILE.VALUE('CONC_REQUEST_ID');
  --
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN

  -- Get next sequence number
  SELECT dot_int_run_phase_err_id_s.nextval
  INTO l_run_phase_error_id
  FROM dual;

  -- Get current date
  SELECT sysdate
  INTO l_current_date
  FROM dual;

  -- Insert record into table
   INSERT INTO dot_int_run_phase_errors  (error_id
                                            ,run_id
                                            ,run_phase_id
                                            ,record_id
                                            ,msg_code
                                            ,error_text
                                            ,error_token_val1
                                            ,error_token_val2
                                            ,error_token_val3
                                            ,error_token_val4
                                            ,error_token_val5
                                            ,int_table_key_val1
                                            ,int_table_key_val2
                                            ,int_table_key_val3
                                            ,created_by
                                            ,creation_date
                                            ,last_updated_by
                                            ,last_update_date
                                            ,last_update_login
                                            ,request_id
                                            )
                                  VALUES    (l_run_phase_error_id              --error_id
                                            ,p_run_id                          --run_id
                                            ,p_run_phase_id                    --run_phase_id
                                            ,p_record_id                       --record_id
                                            ,p_msg_code                        --msg_code
                                            ,p_error_text                      --error_text
                                            ,p_error_token_val1                --error_token_val1
                                            ,p_error_token_val2                --error_token_val2
                                            ,p_error_token_val3                --error_token_val3
                                            ,p_error_token_val4                --error_token_val4
                                            ,p_error_token_val5                --error_token_val5
                                            ,p_int_table_key_val1              --int_table_key_val1
                                            ,p_int_table_key_val2              --int_table_key_val2
                                            ,p_int_table_key_val3              --int_table_key_val3
                                            ,l_current_user_id                 --created_by
                                            ,l_current_date                    --creation_date
                                            ,l_current_user_id                 --last_updated_by
                                            ,l_current_date                    --last_update_date
                                            ,l_current_login_id                --last_update_login
                                            ,l_request_id                      --request_id
                                            );

  COMMIT;

EXCEPTION
WHEN OTHERS THEN
  dot_common_pkg.log('ERROR in dot_common_int_pkg.raise_error: '||SQLERRM);

end raise_error;
--
--
/***************************************************************************
**  FUNCTION
**    GET_INT_TABLE_COUNT
**
**  DESCRIPTION
**    Returns the number of records in a given table for a particular Interface
**    Run Phase.
***************************************************************************/
function get_int_table_count (p_run_phase_id in dot_int_run_phases.run_phase_id%type)
return  number
is
     --
     --
begin
     --
     --
     return 1;
     --
     --
end get_int_table_count;
--
--
/***************************************************************************
**  FUNCTION
**    RECORD_COUNT_VALID
**
**  DESCRIPTION
**    Compares a given record count value with the record count against the
**    run phase.  Returns true if they are equal, else false.
***************************************************************************/
function record_count_valid (p_run_phase_id	in dot_int_run_phases.run_phase_id%type
                            ,p_record_count	in number)
return boolean
is

  l_phase_rec_count       NUMBER;

  -- Cursor to get the record count from the Run Phase table
  CURSOR c_get_phase_rec_count (b_i_run_phase_id IN NUMBER) IS
  SELECT rec_count
  FROM   dot_int_run_phases
  WHERE  run_phase_id = b_i_run_phase_id;

BEGIN

  OPEN c_get_phase_rec_count (p_run_phase_id);
  FETCH c_get_phase_rec_count INTO l_phase_rec_count;
  CLOSE c_get_phase_rec_count;

  IF l_phase_rec_count = p_record_count
  THEN
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END IF;

EXCEPTION
WHEN OTHERS THEN
  dot_common_pkg.log('ERROR in dot_common_int_pkg.record_count_valid: '||SQLERRM);
  RETURN FALSE;

end record_count_valid;
--
--
/***************************************************************************
**  FUNCTION
**    HASH_TOTAL_VALID
**
**  DESCRIPTION
**    Compares a given value with the hash total against the run phase.
**    Returns true if they are equal, else false.
***************************************************************************/
function hash_total_valid (p_run_phase_id	in dot_int_run_phases.run_phase_id%type
                          ,p_hash_total   in Number)
return boolean
is

  l_phase_hash_total     NUMBER;

  -- Cursor to get the Hash Total from the Run Phase table
  CURSOR c_get_hash_total (b_i_run_phase_id IN NUMBER) IS
  SELECT hash_total
  FROM   dot_int_run_phases
  WHERE  run_phase_id = b_i_run_phase_id;

BEGIN

  OPEN c_get_hash_total (p_run_phase_id);
  FETCH c_get_hash_total INTO l_phase_hash_total;
  CLOSE c_get_hash_total;

  IF l_phase_hash_total = p_hash_total
  THEN
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END IF;

EXCEPTION
WHEN OTHERS THEN
  dot_common_pkg.log('ERROR in dot_common_int_pkg.hash_total_valid: '||SQLERRM);
  RETURN FALSE;

end hash_total_valid;
--
--
/***************************************************************************
**  FUNCTION
**    DATA_TYPE_NUMBER
**
**  DESCRIPTION
**    Provides data type check validation.  Returns true if a given value
**    can be converted to a Number data type, else false.
***************************************************************************/
function data_type_number (p_data	      in varchar2
                          )
return BOOLEAN
is

  l_num   NUMBER;

BEGIN

  SELECT TO_NUMBER(p_data)
  INTO l_num
  FROM dual;

  RETURN TRUE;
       --
EXCEPTION
WHEN OTHERS THEN
  RETURN FALSE;

end data_type_number;
--
--
/***************************************************************************
**  FUNCTION
**    DATA_TYPE_DATE
**
**  DESCRIPTION
**    Provides data type check validation.  Returns true if a given value
**    can be converted to a Number data type, else false.
***************************************************************************/
function data_type_date (p_data	         in varchar2
                        ,p_format_string in varchar2)
return boolean
is

  l_date    DATE;

BEGIN

  SELECT TO_DATE(p_data,p_format_string)
  INTO l_date
  FROM dual;

  RETURN TRUE;

EXCEPTION
WHEN OTHERS THEN
  RETURN FALSE;

end data_type_date;
--
/***************************************************************************
**  PROCEDURE
**    ADD_NOTIF_USER
**
**  DESCRIPTION
**    API called to add the Notify option to a concurrent request given a
**      string of one or more recipients separated by ";".
***************************************************************************/

procedure add_notification (pv_user_list  in VARCHAR2 DEFAULT '',
                            pv_on_normal  in VARCHAR2 DEFAULT 'Y',
                            pv_on_warning in VARCHAR2 DEFAULT 'Y',
                            pv_on_error   in VARCHAR2 DEFAULT 'Y') is
     --
     TYPE test_type IS TABLE OF VARCHAR2(100);
     --
     l_string                VARCHAR2(32767);
     l_comma_index           PLS_INTEGER;
     l_index                 PLS_INTEGER := 1;
     l_tab                   test_type := test_type();
     l_boolean               boolean;
     --
begin
     --
     l_string := pv_user_list;
     --
     -- build table of users from semi colon separated list
     --
     if (pv_user_list is not null) then
         --
         loop
              --
              l_comma_index := instr(l_string, ';', l_index);
              --
              if l_comma_index = 0 then
                   --
                   l_tab.extend;
                   l_tab(l_tab.count) := ltrim(trim(SUBSTR(l_string,l_index,length(l_string))));
                   --
                   exit when l_comma_index = 0;
                   --
              end if;
              --
              l_tab.extend;
              l_tab(l_tab.count) := substr(l_string, l_index, l_comma_index - l_index);
              l_index := l_comma_index + 1;
              --
         end loop;
         --
         -- loop through table of users and set notify
         for i in 1..l_tab.COUNT
         loop
              --
              l_boolean := fnd_request.add_notification (user => l_tab(i),
                                                         on_normal  =>pv_on_normal  ,
                                                         on_warning =>pv_on_warning ,
                                                         on_error   =>pv_on_error   );
              --
         end loop;
         --
     end if;
     --
end add_notification;
--
--
/***************************************************************************
**  FUNCTION
**    LAUNCH_ERROR_REPORT
**
**  DESCRIPTION
**    API is used to launch the Common Interface Errors report as a
**    concurrent request.
***************************************************************************/
function launch_error_report (p_run_id       in dot_int_runs.run_id%type
                             ,p_run_phase_id in dot_int_run_phases.run_phase_id%type
                             ,p_notify_user	 in varchar2 default null)
return fnd_concurrent_requests.request_id%type
is

  l_request_id          NUMBER;
  l_err_lay             BOOLEAN;
  l_notif               BOOLEAN;
  l_interface_name      VARCHAR2(240);

  -- Cursor to get the Interface Name
  CURSOR c_get_interface_name (b_i_run_id IN NUMBER) IS
  SELECT inf.int_name
  FROM   dot_int_interfaces inf
        ,dot_int_runs irun
  WHERE irun.int_id = inf.int_id
    AND irun.run_id = b_i_run_id;

begin
  --
  -- Set the report template
  l_err_lay := fnd_request.add_layout('FNDC'
                                     ,'DOT_CMNINT_INT_ERR_RPT'
                                     ,'en'
                                     ,'US'
                                     ,'PDF');

  -- Set the user to be notified
  if (p_notify_user is not null) then
       --
       dot_common_int_pkg.add_notification (pv_user_list => p_notify_user);
       --
  end if;

  -- Get the Interface Name
  OPEN c_get_interface_name (p_run_id);
  FETCH c_get_interface_name INTO l_interface_name;
  CLOSE c_get_interface_name;

  -- Submit the concurrent request
  l_request_id := FND_REQUEST.SUBMIT_REQUEST ('FNDC'                        --application
                                             ,'DOT_CMNINT_INT_ERR_RPT_XML'  --program
                                             ,NULL                          --description
                                             ,NULL                          --start_time
                                             ,FALSE                         --sub_request
                                             ,l_interface_name              --argument1
                                             ,p_run_id                      --argument2
                                             ,p_run_phase_id                --argument3
                                             );

  -- need to commit to submit request.
  commit;
  --
  RETURN l_request_id;

EXCEPTION
WHEN OTHERS THEN
  dot_common_pkg.log('ERROR in dot_common_int_pkg.launch_error_report: '||SQLERRM);
  RETURN NULL;

end launch_error_report;
--
--
/***************************************************************************
**  FUNCTION
**    LAUNCH_RUN_REPORT
**
**  DESCRIPTION
**    API is used to launch the Common Interface Runs report as a
**    concurrent request.
***************************************************************************/
function launch_run_report (p_run_id       in dot_int_runs.run_id%type
                           ,p_notify_user	 in varchar2)
return fnd_concurrent_requests.request_id%type
is
     --
  l_request_id          NUMBER;
  l_run_lay             BOOLEAN;
  l_notif               BOOLEAN;
  l_interface_name      VARCHAR2(240);
     --
  -- Cursor to get the Interface Name
  CURSOR c_get_interface_name (b_i_run_id IN NUMBER) IS
  SELECT inf.int_name
  FROM   dot_int_interfaces inf
        ,dot_int_runs irun
  WHERE irun.int_id = inf.int_id
    AND irun.run_id = b_i_run_id;

BEGIN

  -- Set the report template
  l_run_lay := fnd_request.add_layout('FNDC'
                                     ,'DOT_CMNINT_INT_RUN_RPT'
                                     ,'en'
                                     ,'US'
                                     ,'PDF');

  -- Set the user to be notified
  dot_common_int_pkg.add_notification (pv_user_list => p_notify_user);

  -- Get the Interface Name
  OPEN c_get_interface_name (p_run_id);
  FETCH c_get_interface_name INTO l_interface_name;
  CLOSE c_get_interface_name;

  -- Submit the concurrent request
  l_request_id := fnd_request.submit_request ('FNDC'                        --application
                                             ,'DOT_CMNINT_INT_RUN_RPT_XML'  --program
                                             ,NULL                          --description
                                             ,NULL                          --start_time
                                             ,FALSE                         --sub_request
                                             ,l_interface_name              --argument1
                                             ,p_run_id                      --argument2
                                             );

  RETURN l_request_id;

EXCEPTION
WHEN OTHERS THEN
  dot_common_pkg.log('ERROR in dot_common_int_pkg.launch_run_report: '||SQLERRM);
  RETURN NULL;

end launch_run_report;
--
--
/***************************************************************************
**  FUNCTION
**    MOVE_FILE_PROCESS
**
**  DESCRIPTION
**    With an interface definition data directory structure, moves a file
**    from the “New” directory to the “Process” directory.
***************************************************************************/
function move_file_process (p_data_file_name	        in varchar2
                           ,p_interface_new_dir       in varchar2
                           ,p_interface_process_dir   in varchar2)
return boolean
is

BEGIN

  UTL_FILE.FRENAME(UPPER(p_interface_new_dir)
                  ,p_data_file_name
                  ,UPPER(p_interface_process_dir)
                  ,p_data_file_name
                  ,TRUE);

  RETURN TRUE;

EXCEPTION
WHEN OTHERS THEN
  dot_common_pkg.log('Error in dot_common_int_pkg.move_file_process: '||SQLERRM);
  RETURN FALSE;

end move_file_process;
--
--
/***************************************************************************
**  FUNCTION
**    MOVE_FILE_ARCHIVE
**
**  DESCRIPTION
**    With an interface definition data directory structure, moves a file
**    from the “Process” directory to the “Archive” directory.
***************************************************************************/
function move_file_archive (p_data_file_name	        in varchar2
                           ,p_interface_process_dir   In varchar2
                           ,p_interface_archive_dir   In varchar2
                           ,p_success_flag            In varchar2)  -- 'Y' = success
                                                                    -- 'N' = fail
return boolean
is
  --l_date_time   VARCHAR2(12);
  l_conc_request_id             NUMBER         := FND_GLOBAL.CONC_REQUEST_ID;
  l_target_file_name            VARCHAR2(150);

BEGIN

  -- Get current date/time
  --SELECT to_char(sysdate, 'yymmddhhmiss')
  --INTO l_date_time
  --FROM dual;
  IF p_success_flag = 'Y'
  THEN
    l_target_file_name := p_data_file_name||'_'||l_conc_request_id;
  ELSE
    l_target_file_name := p_data_file_name||'_'||l_conc_request_id||'.err';
  END IF;

  UTL_FILE.FRENAME(UPPER(p_interface_process_dir)
                  ,p_data_file_name
                  ,UPPER(p_interface_archive_dir)
                  ,l_target_file_name
                  ,TRUE);

  RETURN TRUE;

EXCEPTION
WHEN OTHERS THEN
  dot_common_pkg.log('Error in dot_common_int_pkg.move_file_archive: '||SQLERRM);
  RETURN FALSE;

end move_file_archive;
--
--
/***************************************************************************
**  FUNCTION
**    REPOINT_EXT_TABLE
**
**  DESCRIPTION
**    External tables are to be used to read from data files.  An external
**    name definition contains the reference to a particular file.  As there
**    is a requirement to be able to read from files with variable names,
**    the purpose of this API is to “Alter” an external table to point to a
**    new data file.
***************************************************************************/
function repoint_ext_table (p_data_file_name	    in varchar2
                           ,p_external_table_name	in all_tables.table_name%type)
return boolean
is

BEGIN

  EXECUTE IMMEDIATE 'alter table '||p_external_table_name||' location ('''||p_data_file_name||''')';

  RETURN TRUE;

EXCEPTION
WHEN OTHERS THEN
  RETURN FALSE;

end repoint_ext_table;

/***************************************************************************
**  FUNCTION
**    get_files_in_dir
**
**  DESCRIPTION
**    API is used to return an array containing the files that exist within
**    a given directory.
***************************************************************************/
function get_files_in_dir (p_directory_name in varchar2)
return dot_dir_array is
language java
name 'au.net.redrock.common.utils.fileManager.listFiles(java.lang.String) return oracle.sql.ARRAY';


/***************************************************************************
**  FUNCTION
**    CHECK_FILE_EXISTS
**
**  DESCRIPTION
**    API is used to check if a given file exists within a given directory.
**    Returns True or False
***************************************************************************/
function check_file_exists (p_directory_name in	varchar2
                           ,p_file_name      in varchar2)
return boolean
is
  l_handle UTL_FILE.FILE_TYPE;
BEGIN

  l_Handle := UTL_FILE.FOPEN(p_directory_name, p_file_name, 'R');
  UTL_FILE.FCLOSE(l_Handle);

  RETURN TRUE;

EXCEPTION
WHEN OTHERS THEN
  RETURN FALSE;

end check_file_exists;

/***************************************************************************
**  FUNCTION
**    DELETE_LOG_FILES
**
**  DESCRIPTION
**    API is used to check if a given file exists within a given directory.
**    Returns True or False
***************************************************************************/
function delete_log_files (p_directory_name	in varchar2)
return boolean
is
     --
     --
begin
     --

     --UTL_FILE.FREMOVE (p_directory_name);
                 --     ,filename IN VARCHAR2);

     --
     return true;
     --
     --
end delete_log_files;
--
--
/***************************************************************************
**  PROCEDURE
**    GENERIC_RUN_PROCESS
**
**  DESCRIPTION
**    Used to run Common Interface interface programs.
**
**    This program was created as the filename parameter on an interface
**    program cannot change when scheduled.  Therefore standard scheduling
**    functionality cannot be used for interface programs.
**
**    An instance of this program must be scheduled for each individual
**    interface.
**
**    If multiple files are found in the interface directory, these are
**    processed sequentially.
**
**    This procedure is call from the concurrent program named:
**      - "Common Interface Scheduler Process (Custom)"
**
**    Currently this program works only for the following interfaces as the
**      remaining interfaces will be run on an adhoc / manual basis.
**
**      - Chris Payroll - Request Set (Custom)
**      - OIE01 MasterCard - Request Set (Custom)
**
**    If future interfaces are required to be scheduled and submitted
**      via this program, if the parameters passed in are different from those
**      of the interfaces above, this program will have to be amended.  The
**      concurrent program will also need to be amended to allow more
**      parameters to be passed in.
**
***************************************************************************/
procedure generic_run_process (p_o_errbuff          out varchar2
                              ,p_o_retcode          out varchar2
                              ,p_srs_program_name   in  fnd_concurrent_programs.concurrent_program_name%type
                              ,p_srs_directory_name in  all_directories.directory_name%type
                              ,p_i_run_mode         IN  VARCHAR2) IS
     --
     cv_proc_name constant varchar2(25) := 'generic_run_process';
     --
     v_request_id       NUMBER;
     vn_file_count      number := 0;
     v_phase            VARCHAR2(240);
     v_status           VARCHAR2(240);
     v_dev_phase        VARCHAR2(240);
     v_dev_status       VARCHAR2(240);
     v_message1         VARCHAR2(240);
     vb_job_failed      BOOLEAN := false;
     v_result           BOOLEAN;
     --
     conc_program_failure EXCEPTION;
     --
     CURSOR fetch_files_cur (p_directory_name VARCHAR2) IS
     SELECT name file_name
     ,      modified
     ,      file_size
     FROM   table(dot_common_int_pkg.get_files_in_dir(p_directory_name))
     order by modified asc;
     --
     v_file_name VARCHAR2(240);
     --
BEGIN
     --
     debug('p_srs_program_name: '||p_srs_program_name, cv_proc_name);
     debug('p_srs_directory_name : '||p_srs_directory_name , cv_proc_name);
     --
     writerep ('====================================================================');
     writerep (' Common Interface Scheduler Process');
     writerep (' ');
     writerep (' Start Date     : ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
     writerep (' Program Name   : '||p_srs_program_name);
     writerep (' Directory Name : '||p_srs_directory_name);
     writerep (' Run Mode       : '||p_i_run_mode);
     writerep ('====================================================================');
     writerep (' ');
     writerep (' Request ID    Filename                                  Date                  Size          Completion Status');
     writerep (' ============  ========================================  ====================  ============  ==================');
     --
     FOR fetch_files_rec IN fetch_files_cur (p_directory_name => p_srs_directory_name)
     LOOP
          --
          v_file_name := fetch_files_rec.file_name;
          --
          debug('file name: '||fetch_files_rec.file_name, cv_proc_name);
          --
          v_request_id := fnd_request.submit_request ('FNDC'-- p_application
                                                     ,p_srs_program_name -- program shortname
                                                     ,null--p_srs_program_name -- description
                                                     ,NULL          --start_time
                                                     ,FALSE         --sub_request
                                                     ,fetch_files_rec.file_name --p_argument1
                                                     ,p_i_run_mode --p_argument2
                                                     );
          --
          COMMIT;
          --
          -- Wait for request to finish
          v_result := fnd_concurrent.wait_for_request (v_request_id         -- request_id
                                                      ,1                    -- interval
                                                      ,0                    -- max_wait
                                                      ,v_phase              -- phase
                                                      ,v_status             -- status
                                                      ,v_dev_phase          -- dev_phase
                                                      ,v_dev_status         -- dev_status
                                                      ,v_message1           -- message
                                                      );
          --
          writerep(' '||rpad(to_char(v_request_id),12)||
                   '  '||substr(rpad(fetch_files_rec.file_name,40),1,40)||
                   '  '||to_char(fetch_files_rec.modified, 'DD-MON-YYYY HH24:MI:SS')||
                   '  '||substr(rpad(to_char(fetch_files_rec.file_size),12),1,12)||
                   '  '||rpad(v_status,18) );
          --
          IF v_dev_status != 'NORMAL' THEN
               --
               vb_job_failed := true;
               --
          END IF;
          --
          vn_file_count := vn_file_count +1;
          --
     END LOOP;
     --
     if (vn_file_count = 0) then
          --
          writerep(' ');
          writerep(' *** No files found to process ***');
          writerep(' ');
          --
     else
          --
          writerep(' ');
          writerep(' *** End of Report ***');
          writerep(' ');
          --
     end if;
     --
     if (vb_job_failed) then
          --
          p_o_retcode := gv_cp_warning;
          --
     else
          --
          p_o_retcode := gv_cp_success;
          --
     end if;
     --
     writerep (' ');
     writerep (' End Date     : ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
     writerep (' ');
     --
EXCEPTION
     WHEN others THEN
          --
          p_o_retcode := gv_cp_error;
          --
          writerep ('Unexpected error occurred: '||sqlerrm);
          --
END generic_run_process ;
--
--
end dot_common_int_pkg;
/
