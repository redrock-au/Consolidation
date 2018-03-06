package doi.oracle.apps.icx.icatalog.shopping.webui;
// **********************************************************************
// doi.oracle.apps.icx.icatalog.shopping.webui.DoiNonCatalogRequestCO
//
//
// Joy Pinto 27-SEP-2017
//
// Custom version of oracle.apps.icx.icatalog.shopping.webui.NonCatalogRequestCO
//
//
// **********************************************************************
/*$Header: svn://d02584/consolrepos/branches/AP.02.01/poc/1.0.0/java/doi/oracle/apps/icx/icatalog/shopping/webui/DoiNonCatalogRequestCO.java 2622 2017-09-28 06:13:21Z svnuser $*/

import oracle.apps.fnd.framework.webui.OAPageContext;
import oracle.apps.fnd.framework.webui.beans.OAWebBean;
import oracle.apps.fnd.framework.webui.beans.message.OAMessageChoiceBean;
import oracle.apps.icx.icatalog.shopping.webui.NonCatalogRequestCO;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import oracle.apps.fnd.framework.OAException;
import oracle.apps.fnd.framework.OAApplicationModule;
import com.sun.java.util.collections.ArrayList;

public class DoiNonCatalogRequestCO extends NonCatalogRequestCO {

    public void processRequest(OAPageContext oapagecontext, OAWebBean oawebbean)
    {
        super.processRequest(oapagecontext, oawebbean);
           if (isOrgKofaxEnabled(oawebbean,oapagecontext).equals("Y"))
           {
              String defaultValue = "TOTAL_AMOUNT";
              OAMessageChoiceBean ItemType = (OAMessageChoiceBean)oawebbean.findChildRecursive("ItemType");
              //ItemType.setDefaultValue("TOTAL_AMOUNT");
              ItemType.setValue(oapagecontext, defaultValue);
              handleItemTypePPR(oapagecontext, oawebbean);
           }

    }

    public void processFormRequest(OAPageContext oapagecontext, OAWebBean oawebbean)
    {

        super.processFormRequest(oapagecontext, oawebbean);
    }

      protected void handleItemTypePPR(OAPageContext paramOAPageContext, OAWebBean paramOAWebBean)
  {
    OAApplicationModule localOAApplicationModule = paramOAPageContext.getApplicationModule(paramOAWebBean);


    ArrayList localArrayList = new ArrayList(2);
    localArrayList.add(0, "pprItemType");
    localArrayList.add(1, "N");
    executeServerCommand(paramOAPageContext, localOAApplicationModule, "NoncatRequestSvrCmd", localArrayList);
  }

    public String isOrgKofaxEnabled(OAWebBean oawebbean,OAPageContext oapagecontext)
    {
     String iskofaxEnabled = "";
     PreparedStatement ps = null;
     OAApplicationModule am = oapagecontext.getApplicationModule(oawebbean);
        try {
            ps = am.getOADBTransaction().getJdbcConnection().prepareStatement("select nvl(fnd_profile.VALUE_SPECIFIC(NAME => 'POC_KOFAX_ENABLED',ORG_ID => :1),'N') kofax_enabled from dual");
            ps.setInt(1, oapagecontext.getOrgId());
            ResultSet rs = ps.executeQuery();
            if (rs.next()) {
                if (rs.getString("kofax_enabled") != null) {
                    iskofaxEnabled = rs.getString("kofax_enabled");
                }
            }
          } catch (SQLException sq) {
            throw new OAException("Custom Exception " + sq, OAException.ERROR);
                                    }
        finally
        {
            try {
                ps.close();
            } catch (Exception e) {
                throw new OAException("Custom Exception " + e, OAException.ERROR);
            }
        }

        return iskofaxEnabled;
    }

    public DoiNonCatalogRequestCO() {}

}