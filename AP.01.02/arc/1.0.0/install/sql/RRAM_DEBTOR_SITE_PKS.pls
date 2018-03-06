create or replace
package rram_debtor_site_pkg
as
/* $Header: svn://d02584/consolrepos/branches/AP.01.02/arc/1.0.0/install/sql/RRAM_DEBTOR_SITE_PKS.pls 1081 2017-06-21 05:49:47Z svnuser $ */
-- ============================================================================
--
--  PROGRAM:	  RRAM_DEBTOR_SITE_PKS.pls
--
--  DESCRIPTION:
--	Creates package spec rram_debtor_site_pkg.
--		  This package implements the Oracle side of the RRAM Debtor Site Interface.
--
--  AUTHOR	DATE		    COMMENT
--  ----------- ----------  ----------------------------------------------------
--  sryan	13/01/2015	initial
-- ============================================================================

    -- Global constants
    G_INT_STATUS_NEW		    constant varchar2(1) := rram_debtor_pkg.G_INT_STATUS_NEW;
    G_INT_STATUS_PROCESSED	constant varchar2(1) := rram_debtor_pkg.G_INT_STATUS_PROCESSED;
    G_INT_STATUS_ERROR		  constant varchar2(1) := rram_debtor_pkg.G_INT_STATUS_ERROR;

    -- ------------------------------------------------------------------------
    --	Procedure
    --	    import_debtor_sites
    --	Purpose
    --	    Implements the main logic of the debtor site interface
    --	Parameters
    --	    p_debug	  Debug flag (Y|N) to output additional flow information
    --	    p_errors	  Boolean flag to indicate existence of errors
    --	Author	    Date		    Comment
    --	----------  ----------	-----------------------------------------------
    --	sryan	    13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure import_debtor_sites(
	p_debug 	in varchar2 default 'N',
	p_errors	out boolean);

end rram_debtor_site_pkg;
/
show error
