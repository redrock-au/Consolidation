create or replace PACKAGE FAC_ACCT_GEN AS
/* $Header: svn://d02584/consolrepos/branches/AR.03.02/fac/1.0.0/install/sql/FAC_ACCT_GEN.pks 827 2017-06-14 00:03:30Z sryan $ */

   procedure def_cost_centre(itemtype  IN   VARCHAR2,
                     itemkey   IN   VARCHAR2,
                     actid     IN   NUMBER,
                     funcmode  IN   VARCHAR2,
                     resultout OUT  VARCHAR2);

end FAC_ACCT_GEN;
