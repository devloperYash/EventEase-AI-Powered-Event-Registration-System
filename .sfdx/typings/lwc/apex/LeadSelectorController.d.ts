declare module "@salesforce/apex/LeadSelectorController.searchLeads" {
  export default function searchLeads(param: {searchTerm: any, eventInterest: any, status: any, eventType: any}): Promise<any>;
}
declare module "@salesforce/apex/LeadSelectorController.sendEmailsToSelectedLeads" {
  export default function sendEmailsToSelectedLeads(param: {leadIds: any, eventId: any}): Promise<any>;
}
declare module "@salesforce/apex/LeadSelectorController.getLeadStatistics" {
  export default function getLeadStatistics(param: {eventId: any}): Promise<any>;
}
declare module "@salesforce/apex/LeadSelectorController.getEventInterests" {
  export default function getEventInterests(): Promise<any>;
}
