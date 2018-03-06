package doi.oracle.apps.icx.por.rcv.server;
// **********************************************************************
// doi.oracle.apps.icx.por.rcv.webui.DoiReceiveItemsAMImpl.java
//
//
// Joy Pinto 27-APR-2017
//
// Java Implementation for the Custom AM DoiReceiveItemsAM
//
//
// **********************************************************************
/* $Header: svn://d02584/consolrepos/branches/AP.01.01/poc/1.0.0/java/doi/oracle/apps/icx/por/rcv/server/DoiReceiveItemsAMImpl.java 1173 2017-06-23 00:56:04Z svnuser $ */
import oracle.apps.fnd.framework.server.OAApplicationModuleImpl;
//  ---------------------------------------------------------------
//  --    File generated by Oracle Business Components for Java.
//  ---------------------------------------------------------------

  public class DoiReceiveItemsAMImpl extends OAApplicationModuleImpl
{
  /**
   *
   * This is the default constructor (do not remove)
   */
  public DoiReceiveItemsAMImpl()
  {
  }

  /**
   *
   * Sample main for debugging Business Components code using the tester.
   */
  public static void main(String[] args)
  {
    launchTester("doi.oracle.apps.icx.por.rcv.server", "ReceiveItemsAMExLocal");
  }

  /**
   *
   * Container's getter for DoiInvAttachmentListVO
   */
  public DoiInvAttachmentListVOImpl getDoiInvAttachmentListVO()
  {
    return (DoiInvAttachmentListVOImpl)findViewObject("DoiInvAttachmentListVO");
  }


}
