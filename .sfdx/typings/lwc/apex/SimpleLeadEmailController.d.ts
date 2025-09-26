declare module "@salesforce/apex/SimpleLeadEmailController.getLeadsByInterest" {
  export default function getLeadsByInterest(param: {eventInterest: any, eventId: any}): Promise<any>;
}
declare module "@salesforce/apex/SimpleLeadEmailController.sendEmailsByInterest" {
  export default function sendEmailsByInterest(param: {eventInterest: any, eventId: any}): Promise<any>;
}
declare module "@salesforce/apex/SimpleLeadEmailController.getLeadStatsByInterest" {
  export default function getLeadStatsByInterest(): Promise<any>;
}
