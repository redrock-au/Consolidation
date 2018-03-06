create or replace PACKAGE FAC_ACCT_GEN AS
/* $Header: svn://d02584/consolrepos/branches/AP.02.02/fac/1.0.0/install/sql/FAC_ACCT_GEN.pks 1024 2017-06-21 01:05:52Z svnuser $ */

   procedure def_cost_centre(itemtype  IN   VARCHAR2,
                     itemkey   IN   VARCHAR2,
                     actid     IN   NUMBER,
                     funcmode  IN   VARCHAR2,
                     resultout OUT  VARCHAR2);

end FAC_ACCT_GEN;
