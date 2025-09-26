declare module "@salesforce/apex/EventLeadEmailController.getEventDetails" {
  export default function getEventDetails(param: {eventId: any}): Promise<any>;
}
declare module "@salesforce/apex/EventLeadEmailController.getLeadsForEvent" {
  export default function getLeadsForEvent(param: {eventId: any, status: any, interest: any}): Promise<any>;
}
declare module "@salesforce/apex/EventLeadEmailController.sendEventInvitations" {
  export default function sendEventInvitations(param: {leadIds: any, eventId: any}): Promise<any>;
}
declare module "@salesforce/apex/EventLeadEmailController.getLeadStatistics" {
  export default function getLeadStatistics(param: {eventId: any}): Promise<any>;
}
