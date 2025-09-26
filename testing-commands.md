# EventEase Testing Commands

## Quick Test Execution

### 1. Run All Tests
```bash
sf apex run test --test-level RunLocalTests --result-format human
```

### 2. Run Specific Test Classes
```bash
# Integration Tests
sf apex run test --class-names "EventEaseIntegrationTest" --result-format human

# Security Tests  
sf apex run test --class-names "EventEaseSecurityAndEdgeCaseTest" --result-format human

# Batch Tests
sf apex run test --class-names "EventWeeklySummaryBatchEnhancedTest" --result-format human

# Trigger Tests
sf apex run test --class-names "RegistrationTriggerHandlerTest" --result-format human
```

### 3. Run Tests with Coverage
```bash
sf apex run test --test-level RunLocalTests --code-coverage --result-format human
```

### 4. Run Tests in VS Code
- Open Command Palette (Ctrl+Shift+P)
- Type: "SFDX: Run Apex Tests"
- Select test class or run all

### 5. Developer Console Method
1. Setup → Developer Console
2. Test → New Run
3. Select test classes
4. Click "Run"

## Test Results Analysis

### Current Coverage (from memories):
- **Overall Coverage: 98%**
- **RegistrationTriggerHandler: 98%**
- **EventWeeklySummaryBatch: 100%**
- **All Triggers: 100%**

### Test Categories:
1. **Unit Tests**: Individual method testing
2. **Integration Tests**: End-to-end workflows  
3. **Performance Tests**: Bulk operations (200+ records)
4. **Security Tests**: Data integrity validation
5. **Edge Cases**: Boundary conditions
6. **Negative Tests**: Error handling

## Manual Testing Checklist

### 1. Event Creation
- [ ] Create In-Person event
- [ ] Create Virtual event  
- [ ] Verify all fields visible
- [ ] Test capacity validation

### 2. Attendee Management
- [ ] Create attendee records
- [ ] Verify field visibility
- [ ] Test email validation

### 3. Registration Process
- [ ] Create event-attendee registrations
- [ ] Test capacity limits
- [ ] Verify duplicate prevention
- [ ] Check email notifications

### 4. Feedback System
- [ ] Create feedback records
- [ ] Test rating validation
- [ ] Verify event linkage

### 5. Web-to-Lead Integration
- [ ] Submit web form
- [ ] Verify lead creation
- [ ] Test lead conversion
- [ ] Check attendee creation

## Troubleshooting

### Common Issues:
1. **Field Visibility**: Check profile permissions
2. **Test Failures**: Review validation rules
3. **Coverage Issues**: Add more test scenarios
4. **Performance**: Optimize bulk operations

### Debug Commands:
```bash
# Check deployment status
sf project deploy validate --source-dir force-app

# View test results
sf apex get test --test-run-id [TEST_RUN_ID]

# Check code coverage
sf apex get test --code-coverage --test-run-id [TEST_RUN_ID]
```
