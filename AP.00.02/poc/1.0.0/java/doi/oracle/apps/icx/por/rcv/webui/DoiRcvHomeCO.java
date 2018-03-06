package doi.oracle.apps.icx.por.rcv.webui;
// **********************************************************************
// doi.oracle.apps.icx.por.rcv.webui.DoiRcvHomeCO
//
//
// Joy Pinto 27-APR-2017
//
// Custom version of oracle.apps.icx.por.rcv.webui.DoiRcvHomeCO
//
//
// **********************************************************************
/* $Header: svn://d02584/consolrepos/branches/AP.00.02/poc/1.0.0/java/doi/oracle/apps/icx/por/rcv/webui/DoiRcvHomeCO.java 1161 2017-06-23 00:14:22Z svnuser $ */
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import oracle.apps.fnd.framework.OAException;
import oracle.apps.fnd.framework.OAApplicationModule;
import oracle.apps.fnd.framework.webui.OAPageContext;
import oracle.apps.fnd.framework.webui.beans.OAWebBean;
import oracle.apps.fnd.framework.webui.beans.table.OATableBean;
import oracle.apps.fnd.framework.webui.beans.layout.OABulletedListBean;
import oracle.apps.fnd.framework.webui.beans.layout.OAPageLayoutBean;
import oracle.apps.fnd.framework.webui.beans.OAStaticStyledTextBean;
import oracle.apps.icx.por.rcv.webui.RcvHomeCO;

public class DoiRcvHomeCO extends RcvHomeCO {

    public void processRequest(OAPageContext oapagecontext, OAWebBean oawebbean) 
    {
        super.processRequest(oapagecontext, oawebbean); 
        if (isOrgKofaxEnabled(oawebbean,oapagecontext).equals("Y")) 
        {
          OAPageLayoutBean oaPageLayoutBean = (OAPageLayoutBean) oawebbean;          
          OABulletedListBean t = (OABulletedListBean) oaPageLayoutBean.findChildRecursive("ReceiveReturnBulletedList");
          OAStaticStyledTextBean receiveItemsLink1Col = (OAStaticStyledTextBean) t.findChildRecursive("ReceiveItemsLink1");
          receiveItemsLink1Col.setDestination("OA.jsp?OAFunc=ICXPOR_RCV_REQS_PAGE&porOrigin=ICXPOR_RCV_HOME_PAGE");
        } 
         
      
    }

    public void processFormRequest(OAPageContext oapagecontext, OAWebBean oawebbean) 
    {

        super.processFormRequest(oapagecontext, oawebbean);
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

    public DoiRcvHomeCO() {}

}