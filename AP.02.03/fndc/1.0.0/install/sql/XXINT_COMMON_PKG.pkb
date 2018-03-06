CREATE OR REPLACE PACKAGE BODY xxint_common_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AP.02.03/fndc/1.0.0/install/sql/XXINT_COMMON_PKG.pkb 1806 2017-07-18 00:10:05Z svnuser $ */

/****************************************************************************
**
** CEMLI ID: INT.02.00
**
** Description: Interface Framework Common Program Routines
**
** Change History:
**
** Date        Who                  Comments
** 18/04/2017  ARELLAD (RED ROCK)   Initial build.
**
****************************************************************************/

TYPE t_objects_tab_type IS TABLE OF VARCHAR2(150);

-----------------------
FUNCTION interface_path
(
   p_application     IN  VARCHAR2,
   p_source          IN  VARCHAR2,
   p_in_out          IN  VARCHAR2 DEFAULT 'INBOUND',
   p_archive         IN  VARCHAR2 DEFAULT 'N',
   p_version         IN  NUMBER,
   p_message         OUT VARCHAR2
)
RETURN VARCHAR2
IS
   l_path             VARCHAR2(240);
BEGIN
   IF UPPER(p_in_out) IN ('INBOUND', 'OUTBOUND', 'WORKING') THEN
      SELECT REPLACE(v.description, '$INSTANCE', (SELECT instance_name FROM v$instance))
      INTO   l_path
      FROM   fnd_flex_values_vl v,
             fnd_flex_value_sets s
      WHERE  v.flex_value_set_id = s.flex_value_set_id
      AND    v.enabled_flag = 'Y'
      AND    s.flex_value_set_name = 'XXINT_INTERFACE_PATH'
      AND    v.flex_value = p_application;

      IF p_source IS NOT NULL THEN
         l_path := l_path || '/' || UPPER(p_source);
      END IF;

      IF p_in_out = 'WORKING' THEN
         l_path := l_path || '/' || LOWER(p_in_out);
      ELSE
         IF p_archive = 'Y' THEN
            l_path := l_path || '/' || 'archive';
         END IF;

         l_path := l_path || '/' || LOWER(p_in_out);
      END IF;
   END IF;

   RETURN l_path;
EXCEPTION
   WHEN others THEN
      p_message := SQLERRM;

END interface_path;

-----------------------
FUNCTION interface_path
(
   p_application     IN  VARCHAR2,
   p_source          IN  VARCHAR2,
   p_in_out          IN  VARCHAR2 DEFAULT 'INBOUND',
   p_archive         IN  VARCHAR2 DEFAULT 'N',
   p_message         OUT VARCHAR2
)
RETURN VARCHAR2
IS
   l_path            VARCHAR2(240);
   l_source          VARCHAR2(150);
   l_object          VARCHAR2(150);
   l_instance_name   VARCHAR2(150);
   l_message         VARCHAR2(300);
   t_object_type     t_objects_tab_type := t_objects_tab_type
                                           (
                                           'RENEWALS', 'INVOICES', 'SUPPLIERS',
                                           'PAYMENTS', 'CUSTOMERS', 'ACKNOWLEDGEMENTS',
                                           'RECEIPTS', 'CONTRACTS', 'SEGMENTS', 'JOURNALS',
                                           'REQUISITIONS', 'CASHBAL'
                                           );
BEGIN
   -- Path Structure: 
   --    /NFS/finance/<SOURCE>/<instance>/<direction>/<object_type>
   -- Example:
   --    Source [LIMS, PHC, GEMS, GMS, COA ..]
   --    Instance [contest, erptest, erpprod ..]
   --    Direction [inbound OR outbound]
   --    Object Type [invoices, receipts, customers ..]

   FOR i IN 1 .. t_object_type.COUNT LOOP
     IF t_object_type(i) = xxint_common_pkg.g_object_type THEN
        l_object := LOWER(t_object_type(i));
        EXIT;
     END IF;
   END LOOP;

   IF l_object IS NULL THEN
      p_message := 'Not a valid object';
      RETURN NULL;
   END IF;

   SELECT instance_name
   INTO   l_instance_name
   FROM   v$instance;

   --l_instance_name := 'CONTEST';

   IF l_instance_name = 'CONDEV' THEN
      l_path := interface_path(p_application => p_application,
                               p_source => p_source,
                               p_in_out => p_in_out,
                               p_archive => p_archive,
                               p_version => 1.0,
                               p_message => l_message);

      p_message := l_message;

   ELSE
      SELECT REPLACE(v.description, '$INSTANCE', LOWER(l_instance_name))
      INTO   l_path
      FROM   fnd_flex_values_vl v,
             fnd_flex_value_sets s
      WHERE  v.flex_value_set_id = s.flex_value_set_id
      AND    v.enabled_flag = 'Y'
      AND    s.flex_value_set_name = 'XXINT_INTERFACE_PATH_ALL'
      AND    v.flex_value = p_application;

      IF p_source IS NOT NULL THEN
         IF p_application = 'AP' THEN
            BEGIN
               SELECT NVL(v.tag, v.lookup_code)
               INTO   l_source
               FROM   fnd_lookup_values_vl v,
                      fnd_application a
               WHERE  v.lookup_type = 'SOURCE'
               AND    v.view_application_id = a.application_id
               AND    a.application_short_name = 'SQLAP'
               AND    v.enabled_flag = 'Y'
               AND    v.lookup_code = p_source
               AND    SYSDATE < NVL(v.end_date_active, SYSDATE + 1);
            EXCEPTION
               WHEN no_data_found THEN
                  l_source := p_source;
            END;
         ELSIF p_application = 'AR' THEN
            IF xxint_common_pkg.g_object_type = 'INVOICES' THEN
               IF p_source IN ('LIMS', 'PHC') THEN
                  l_source := p_source;
               ELSE
                  l_source := 'ARCORP';
               END IF;
            ELSE
               CASE p_source
                  WHEN 'RECALL' THEN
                     l_source := 'ARCORP';
                     l_object := 'recall';
                  WHEN 'POS' THEN
                     l_source := 'ARCORP';
                     l_object := 'pos';
                  ELSE
                     l_source := p_source;
               END CASE;
            END IF;
         ELSE
            l_source := p_source;
         END IF;

         l_path := REPLACE(l_path, '$SOURCE', l_source);

      ELSE
         p_message := 'Interface source must not be null';
         RETURN NULL;
      END IF;

      CASE p_in_out
         WHEN 'INBOUND' THEN
            l_path := REPLACE(l_path, '$IN_OUT', LOWER(p_in_out));
         WHEN 'OUTBOUND' THEN
            l_path := REPLACE(l_path, '$IN_OUT', LOWER(p_in_out));
         WHEN 'WORKING' THEN
            l_path := '/usr/tmp';
      END CASE;

      IF NVL(p_archive, 'N') = 'Y' THEN
         l_path := REPLACE(l_path, '$OBJECT', 'archive');
      ELSE
         l_path := REPLACE(l_path, '$OBJECT', LOWER(l_object));
      END IF;

   END IF;

   RETURN l_path;

EXCEPTION
   WHEN others THEN
      p_message := SQLERRM;

END interface_path;

---------------------------
PROCEDURE purge_interface_data
(
   p_table_name            IN VARCHAR2,
   p_retention_period      IN NUMBER
) IS
   PRAGMA       autonomous_transaction;
   l_sql        VARCHAR2(600);
BEGIN
   -- Put in some protection to avoid malicious use
   IF ( p_table_name NOT LIKE 'XX%INTERFACE%TFM' AND p_table_name NOT LIKE 'XX%INTERFACE%STG') THEN
      raise_application_error(-20001, 'Non-Interface Framework table passed in. ' ||
         'The table must be a Common Interface Framework table of the form XX%INTERFACE_TFM or XX%INTERFACE_STG');
   ELSIF ( p_retention_period IS NULL OR p_retention_period < 1 ) THEN
      raise_application_error(-20001, 'A positive retention period (in days) must be provided');
   END IF;
   -- now that we're satisfied the table is a framework table, do the purge
   l_sql := 'DELETE FROM ' || p_table_name || ' WHERE creation_date < (SYSDATE - :1)';
   EXECUTE IMMEDIATE l_sql USING p_retention_period;
   COMMIT;
EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK;
      RAISE;
END purge_interface_data;

---------------------------
PROCEDURE interface_request
(
   p_control_rec   IN OUT NOCOPY control_record_type
)
IS
   CURSOR c_ctl_rec IS
      SELECT application_id,
             interface_request_id,
             interface_program_id,
             file_name,
             sub_request_id,
             sub_request_program_id,
             status,
             error_message,
             org_id
      FROM   xxint_interface_ctl
      WHERE  application_id = p_control_rec.application_id
      AND    interface_request_id = p_control_rec.interface_request_id
      AND    sub_request_id = p_control_rec.sub_request_id;

   r_ctl        c_ctl_rec%ROWTYPE;
   l_user_id    NUMBER := fnd_profile.value('USER_ID');
   l_org_id     NUMBER := fnd_profile.value('ORG_ID');

   PRAGMA       autonomous_transaction;

BEGIN
   IF p_control_rec.interface_program_id IS NULL THEN
     SELECT concurrent_program_id
     INTO   p_control_rec.interface_program_id
     FROM   fnd_concurrent_requests
     WHERE  request_id = p_control_rec.interface_request_id;
   END IF;

   IF p_control_rec.sub_request_program_id IS NULL THEN
     SELECT concurrent_program_id
     INTO   p_control_rec.sub_request_program_id
     FROM   fnd_concurrent_requests
     WHERE  request_id = p_control_rec.sub_request_id;
   END IF;

   IF p_control_rec.org_id IS NULL THEN
      p_control_rec.org_id := l_org_id;
   END IF;

   OPEN c_ctl_rec;
   FETCH c_ctl_rec INTO r_ctl;
   IF c_ctl_rec%FOUND THEN
      UPDATE xxint_interface_ctl
      SET    status = p_control_rec.status,
             error_message = NVL(p_control_rec.error_message, error_message),
             org_id = NVL(org_id, l_org_id),
             last_update_date = SYSDATE,
             last_updated_by = l_user_id
      WHERE  application_id = p_control_rec.application_id
      AND    interface_request_id = p_control_rec.interface_request_id
      AND    sub_request_id = p_control_rec.sub_request_id;
   ELSE
      INSERT INTO xxint_interface_ctl
      VALUES (p_control_rec.application_id,
              p_control_rec.interface_request_id,
              p_control_rec.interface_program_id,
              p_control_rec.file_name,
              p_control_rec.sub_request_id,
              p_control_rec.sub_request_program_id,
              p_control_rec.status,
              p_control_rec.error_message,
              p_control_rec.org_id,
              SYSDATE,
              l_user_id,
              SYSDATE,
              l_user_id);
   END IF;
   CLOSE c_ctl_rec;
   COMMIT;

END interface_request;

---------------------------
PROCEDURE get_error_message
(
   p_error_message  IN  VARCHAR2,
   p_code           OUT VARCHAR2,
   p_message        OUT VARCHAR2
)
IS
   l_b_tag    NUMBER;
   l_e_tag    NUMBER;
BEGIN
   l_b_tag := INSTR(p_error_message, '<', 1, 1);
   l_e_tag := INSTR(p_error_message, '>', 1, 1);

   p_code := SUBSTR(p_error_message, (l_b_tag + 1), (l_e_tag - (l_b_tag + 1)));
   p_message := SUBSTR(p_error_message, (l_e_tag + 1), 1000);

END get_error_message;

---------------------------
PROCEDURE get_error_message
(
   p_run_id          IN  NUMBER,
   p_run_phase_id    IN  NUMBER,
   p_record_id       IN  NUMBER,
   p_separator       IN  VARCHAR2 DEFAULT '-',
   p_error_message   OUT VARCHAR2
)
IS
   l_error_message   VARCHAR2(4000);
BEGIN
   IF p_record_id = 0 THEN
      l_error_message := 'Invalid file format';
   ELSE
      FOR i IN (SELECT err.error_text
                FROM   dot_int_run_phase_errors err
                WHERE  err.run_id = p_run_id
                AND    err.run_phase_id = p_run_phase_id
                AND    err.record_id = p_record_id)
      LOOP
         IF l_error_message IS NOT NULL THEN
            l_error_message := l_error_message || ' ' || p_separator || ' ';
         END IF;
         l_error_message := l_error_message || i.error_text;
      END LOOP;
   END IF;

   p_error_message := l_error_message;
END get_error_message;

--------------------
FUNCTION strip_value
(
   p_value    VARCHAR2
)
RETURN VARCHAR2
IS
BEGIN
   RETURN REGEXP_REPLACE(p_value,'[^[a-z,A-Z,0-9,.]]*');
END strip_value;

------------------
FUNCTION file_copy
(
   p_from_path  IN  VARCHAR2,
   p_to_path    IN  VARCHAR2
)
RETURN NUMBER
AS LANGUAGE JAVA
NAME 'file_util.copy (java.lang.String, java.lang.String) return java.lang.int';

END xxint_common_pkg;
/
