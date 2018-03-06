create or replace PACKAGE BODY FAC_ACCT_GEN AS
/* $Header: svn://d02584/consolrepos/branches/AR.01.02/fac/1.0.0/install/sql/FAC_ACCT_GEN.pkb 827 2017-06-14 00:03:30Z sryan $ */

   /***************************************************************************
    *
    * Procedure:  def_cost_centre
    *
    **************************************************************************/
   procedure def_cost_centre(itemtype  IN   VARCHAR2,
                     itemkey   IN   VARCHAR2,
                     actid     IN   NUMBER,
                     funcmode  IN   VARCHAR2,
                     resultout OUT  VARCHAR2)
   is
      v_progress           varchar2(200);
      v_bk_type_code       fa_book_controls.book_type_code%TYPE;
      v_flag               fa_book_controls.attribute1%TYPE;
      CURSOR csr_get_bk_dff_attr1
           (p_bk_type_code fa_book_controls.book_type_code%TYPE) IS
      SELECT nvl(attribute1,'N')
      FROM fa_book_controls
      WHERE book_type_code = p_bk_type_code;
   begin

      -- Do nothing in cancel or timeout mode
      if (funcmode <> wf_engine.eng_run) then
         resultout := wf_engine.eng_null;
         return;
      end if;

      v_bk_type_code := wf_engine.GetItemAttrtext(
                              itemtype => itemtype,
                              itemkey  => itemkey,
                              aname    => 'BOOK_TYPE_CODE');

      OPEN csr_get_bk_dff_attr1(v_bk_type_code);
      FETCH csr_get_bk_dff_attr1
       INTO v_flag;
      CLOSE csr_get_bk_dff_attr1;

      IF nvl(v_flag,'N') = 'N' THEN
        resultout := 'COMPLETE:F';
      ELSE
        resultout := 'COMPLETE:T';
      END IF;

   exception
      when others then
         wf_core.context('FAC_ACCT_GEN','def_cost_centre',v_progress);
         raise;
   end def_cost_centre;

end FAC_ACCT_GEN;
