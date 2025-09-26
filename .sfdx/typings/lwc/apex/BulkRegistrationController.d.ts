declare module "@salesforce/apex/BulkRegistrationController.getAttendees" {
  export default function getAttendees(param: {searchTerm: any, sortBy: any, sortDirection: any}): Promise<any>;
}
declare module "@salesforce/apex/BulkRegistrationController.getEventDetails" {
  export default function getEventDetails(param: {eventId: any}): Promise<any>;
}
declare module "@salesforce/apex/BulkRegistrationController.createBulkRegistrations" {
  export default function createBulkRegistrations(param: {eventId: any, attendeeIds: any}): Promise<any>;
}
declare module "@salesforce/apex/BulkRegistrationController.getEventRegistrations" {
  export default function getEventRegistrations(param: {eventId: any}): Promise<any>;
}
