CREATE OR REPLACE PACKAGE xxint_common_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AP.02.01/fndc/1.0.0/install/sql/XXINT_COMMON_PKG.pks 2770 2017-10-10 23:47:18Z svnuser $ */

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

g_object_type       VARCHAR2(150);

TYPE control_record_type IS RECORD
(
   application_id           xxint_interface_ctl.application_id%TYPE,
   interface_request_id     xxint_interface_ctl.interface_request_id%TYPE,
   interface_program_id     xxint_interface_ctl.interface_program_id%TYPE,
   file_name                xxint_interface_ctl.file_name%TYPE,
   sub_request_id           xxint_interface_ctl.sub_request_id%TYPE,
   sub_request_program_id   xxint_interface_ctl.sub_request_program_id%TYPE,
   status                   xxint_interface_ctl.status%TYPE,
   error_message            xxint_interface_ctl.error_message%TYPE,
   org_id                   xxint_interface_ctl.org_id%TYPE
);

TYPE t_files_type IS TABLE OF VARCHAR2(240) INDEX BY binary_integer;

/*
----------------------------------------------------------
-- Function
--    Interface Path
-- Description
--    Returns the interface directory path for 
--    the given application, source, and whether
--    its inbound or outbound.
----------------------------------------------------------
*/
FUNCTION interface_path
(
   p_application     IN  VARCHAR2,
   p_source          IN  VARCHAR2,
   p_in_out          IN  VARCHAR2 DEFAULT 'INBOUND',
   p_archive         IN  VARCHAR2 DEFAULT 'N',
   p_message         OUT VARCHAR2
)
RETURN VARCHAR2;

/*
----------------------------------------------------------
-- Procedure 
--    purge_interface_data
-- Description
--    Purges data from an interface framework table
--    p_table_name must be a valid interface framework table
--    of the name 'XX%INTERFACE_TFM'
--    Data will be deleted if the CREATION_DATE is older than
--    (SYSDATE - p_retention_period)
----------------------------------------------------------
*/
PROCEDURE purge_interface_data
(
   p_table_name            IN VARCHAR2,
   p_retention_period      IN NUMBER
);

/*
----------------------------------------------------------
-- Procedure 
--    Interface Request
-- Description
--    Stores and updates XXINT_INTERFACE_CTL table of
--    information relating to sub-requests that perform 
--    certain operations.
--    Purpose is to keep track of concurrent programs 
--    spawned by the main interface program.
----------------------------------------------------------
*/
PROCEDURE interface_request
(
   p_control_rec   IN OUT NOCOPY control_record_type
);

/*
----------------------------------------------------------
-- Procedure
--    Get Error Message
-- Description
--    Is a function to separate the error message
--    from the error code.
----------------------------------------------------------
*/
PROCEDURE get_error_message
(
   p_error_message  IN  VARCHAR2,
   p_code           OUT VARCHAR2,
   p_message        OUT VARCHAR2
);

/*
----------------------------------------------------------
-- Procedure
--    Get Error Message
-- Description
--    Is a function that concatenates error messages from
--    dot_int_run_phase_errors table.
----------------------------------------------------------
*/
PROCEDURE get_error_message
(
   p_run_id          IN  NUMBER,
   p_run_phase_id    IN  NUMBER,
   p_record_id       IN  NUMBER,
   p_separator       IN  VARCHAR2 DEFAULT '-',
   p_error_message   OUT VARCHAR2
);

/*
----------------------------------------------------------
-- Function
--    Strip Value
-- Description
--    Removes control and non-printable characters 
--    from the string value passed on to this function.
----------------------------------------------------------
*/
FUNCTION strip_value
(
   p_value    VARCHAR2
)
RETURN VARCHAR2;

FUNCTION file_copy 
(
   p_from_path  IN  VARCHAR2,
   p_to_path    IN  VARCHAR2
) 
RETURN NUMBER;

/*
----------------------------------------------------------
-- Function
--    File Delete
-- Description
--    Deletes the given file
----------------------------------------------------------
*/

FUNCTION file_delete 
(
   p_file_name_path  IN  VARCHAR2
) 
RETURN NUMBER;

END xxint_common_pkg;
/
