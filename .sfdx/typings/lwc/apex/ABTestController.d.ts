declare module "@salesforce/apex/ABTestController.getActiveTest" {
  export default function getActiveTest(param: {testType: any}): Promise<any>;
}
declare module "@salesforce/apex/ABTestController.assignUserToVariant" {
  export default function assignUserToVariant(param: {testId: any, userId: any}): Promise<any>;
}
declare module "@salesforce/apex/ABTestController.trackConversion" {
  export default function trackConversion(param: {testId: any, userId: any, conversionType: any}): Promise<any>;
}
declare module "@salesforce/apex/ABTestController.getTestAnalytics" {
  export default function getTestAnalytics(param: {testId: any}): Promise<any>;
}
