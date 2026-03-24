# Testing

This document provides an overview of the testing strategy for the Apex AI application.

## Testing Strategy

The testing strategy for Apex AI includes three levels of testing:

1.  **Unit Tests:** These tests focus on testing individual functions and classes in isolation.
2.  **Widget Tests:** These tests focus on testing individual Flutter widgets.
3.  **Integration Tests:** These tests focus on testing the complete application flow, including the UI, services, and backend integration.

## Unit and Widget Tests

Unit and widget tests are located in the `test` directory. You can run them using the following command:

```bash
flutter test
```

## Integration Tests

Integration tests are located in the `integration_test` directory. These tests are designed to run on a real device or a simulator/emulator.

### Running Integration Tests

To run the integration tests, you can use the `flutter drive` command. For example, to run the `app_flow_test.dart` test, you can use the following command:

```bash
flutter drive 
  --driver=test_driver/integration_test.dart 
  --target=integration_test/app_flow_test.dart
```

### Screenshot Capture

The project includes a script for capturing screenshots of the app during integration tests. The script is located at `qa/capture_screen.sh`. This script uses `flutter drive` to run a test and then uses Playwright to take a screenshot of the app.

For more information on how to use the screenshot capture script, please refer to the script itself.
