create or replace
package rram_debtor_pkg
as
/* $Header: svn://d02584/consolrepos/branches/AR.00.01/arc/1.0.0/install/sql/RRAM_DEBTOR_PKS.pls 1492 2017-07-05 07:01:42Z svnuser $ */
-- ============================================================================
--
--  PROGRAM:	  RRAM_DEBTOR_PKS.pls
--
--  DESCRIPTION:
--	Creates package spec rram_debtor_pkg.
--		  This package implements the Oracle side of the RRAM Debtor Interface.
--
--  AUTHOR	DATE		    COMMENT
--  ----------- ----------  ----------------------------------------------------
--  sryan	13/01/2015	initial
-- ============================================================================

    -- Global constants
    G_INT_STATUS_NEW		    constant varchar2(1) := 'N';
    G_INT_STATUS_PROCESSED	constant varchar2(1) := 'P';
    G_INT_STATUS_ERROR		  constant varchar2(1) := 'E';

    -- ------------------------------------------------------------------------
    --	Procedure
    --	    import_debtors
    --	Purpose
    --	    Implements the main logic of the debtor interface
    --	Parameters
    --	    p_debug	  Debug flag (Y|N) to output additional flow information
    --	    p_errors	  Boolean flag to indicate existence of errors
    --	Author	    Date		    Comment
    --	----------  ----------	-----------------------------------------------
    --	sryan	    13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure import_debtors(
	p_debug 	in varchar2 default 'N',
	p_errors	out boolean);

    -- ------------------------------------------------------------------------
    --	Procedure
    --	    import_debtors_cp
    --	Purpose
    --	    Concurrent program wrapper to call procedure import_debtors
    --	    This program implements concurrent program RRAM_IMPORT_DEBTORS
    --	Parameters
    --	    p_errbuf	  Standard OUT parameter for the program completion message
    --	    p_retcode	  Standard OUT parameter for the program completion status
    --			  (0=normal, 1=warning, 2=error)
    --	    p_debug	  Debug flag (Y|N) to output additional flow information to
    --			  the log file
    --	Author	    Date		    Comment
    --	----------  ----------	-----------------------------------------------
    --	sryan	    13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure import_debtors_cp(
	p_errbuf		    out varchar2,
      	p_retcode		    out number,
	p_debug 	      in varchar2 default 'N');

    -- ------------------------------------------------------------------------
    --	Procedure
    --	    submit_import_debtors
    --	Purpose
    --	    Program wrapper to submit the RRAM Import Debtors concurrent
    --	    program (RRAM_IMPORT_DEBTORS)
    --	Parameters
    --	    p_user	      User name from fnd_users
    --	    p_resp_id	      Responsibility Id
    --	    p_resp_appl_id    Responsibility Application Id
    --	    p_debug	      Debug flag (Y|N) to output additional flow information to
    --			      the log file
    --	    p_request_id      Returned concurrent request id OR error message
    --	Author	    Date		    Comment
    --	----------  ----------	-----------------------------------------------
    --	sryan	    13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure submit_import_debtors(
	p_user		      in varchar2,
      	p_resp_id		    in number,
      	p_resp_appl_id	      in number,
	p_debug 	      in varchar2 default 'N');

    procedure submit_import_debtors(
	p_user		      in varchar2,
      	p_resp_id		    in number,
      	p_resp_appl_id	      in number,
	p_debug 	      in varchar2 default 'N',
	p_request_id	     out number);

end rram_debtor_pkg;
/
show error
