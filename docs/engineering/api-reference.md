# API Reference

This document provides a reference for the `SupabaseService` class, which encapsulates all communication with the Supabase backend.

## Auth

### `signUp(String email, String password, String name)`

Signs up a new user with the given email, password, and name.

*   **`email`**: The user's email address.
*   **`password`**: The user's password.
*   **`name`**: The user's name.
*   **Returns**: An `AuthResponse` object.

### `signIn(String email, String password)`

Signs in an existing user with the given email and password.

*   **`email`**: The user's email address.
*   **`password`**: The user's password.
*   **Returns**: An `AuthResponse` object.

### `signOut()`

Signs out the currently logged-in user.

### `currentUser`

Gets the currently logged-in user.

*   **Returns**: A `User` object or `null` if no user is logged in.

### `accessToken`

Gets the access token for the current session.

*   **Returns**: The access token string or `null` if no user is logged in.

## Profiles

### `getProfile(String userId)`

Retrieves the profile for the given user ID.

*   **`userId`**: The ID of the user.
*   **Returns**: A `Map<String, dynamic>` representing the user's profile, or `null` if the profile is not found.

### `updateProfile(String userId, Map<String, dynamic> data)`

Updates the profile for the given user ID with the provided data.

*   **`userId`**: The ID of the user.
*   **`data`**: A map of the data to update.

## Workouts

### `getWorkouts(String userId)`

Retrieves all workouts for the given user ID.

*   **`userId`**: The ID of the user.
*   **Returns**: A list of `Map<String, dynamic>` objects, where each object represents a workout.

### `createWorkout(String userId, String name, String type)`

Creates a new workout for the given user ID.

*   **`userId`**: The ID of the user.
*   **`name`**: The name of the workout.
*   **`type`**: The type of the workout.
*   **Returns**: A `Map<String, dynamic>` object representing the newly created workout.

### `deleteWorkout(String id)`

Deletes the workout with the given ID.

*   **`id`**: The ID of the workout to delete.

## Exercises

### `createExercises(List<Map<String, dynamic>> exercises)`

Creates a list of new exercises.

*   **`exercises`**: A list of `Map<String, dynamic>` objects, where each object represents an exercise.

## Workout Logs

### `getWorkoutLogs(String userId, {int limit = 14})`

Retrieves the workout logs for the given user ID.

*   **`userId`**: The ID of the user.
*   **`limit`**: The maximum number of logs to retrieve.
*   **Returns**: A list of `Map<String, dynamic>` objects, where each object represents a workout log.

### `getWorkoutLogsSince(String userId, DateTime since)`

Retrieves the workout logs for the given user ID since the given date.

*   **`userId`**: The ID of the user.
*   **`since`**: The date to retrieve logs since.
*   **Returns**: A list of `Map<String, dynamic>` objects, where each object represents a workout log.

### `createWorkoutLog(Map<String, dynamic> log)`

Creates a new workout log.

*   **`log`**: A `Map<String, dynamic>` object representing the workout log.
*   **Returns**: A `Map<String, dynamic>` object representing the newly created workout log.

## Set Logs

### `createSetLogs(List<Map<String, dynamic>> sets)`

Creates a list of new set logs.

*   **`sets`**: A list of `Map<String, dynamic>` objects, where each object represents a set log.

### `getSetLogsSince(String userId, DateTime since)`

Retrieves the set logs for the given user ID since the given date.

*   **`userId`**: The ID of the user.
*   **`since`**: The date to retrieve logs since.
*   **Returns**: A list of `Map<String, dynamic>` objects, where each object represents a set log.

## Nutrition

### `getNutritionLogs(String userId, {int? limit, DateTime? since})`

Retrieve nutrition logs for a user.

*   **`userId`**: The user's ID.
*   **`limit`**: The maximum number of logs to return.
*   **`since`**: The start date for the logs.
*   **Returns**: A list of nutrition logs.

### `createNutritionLog(Map<String, dynamic> log)`

Creates a new nutrition log.

*   **`log`**: The nutrition log to create.

## Water

### `getWaterLogs(String userId, {DateTime? since})`

Retrieves water logs for a given user.

*   **`userId`**: The user's ID.
*   **`since`**: The start date for the logs.
*   **Returns**: A list of water logs.

### `createWaterLog(String userId, int amountMl)`

Creates a new water log.

*   **`userId`**: The user's ID.
*   **`amountMl`**: The amount of water in milliliters.

## Body Weight

### `getBodyWeightLogs(String userId, {int limit = 30})`

Retrieves body weight logs for a given user.

*   **`userId`**: The user's ID.
*   **`limit`**: The maximum number of logs to return.
*   **Returns**: A list of body weight logs.

### `createBodyWeightLog(String userId, double weightKg)`

Creates a new body weight log.

*   **`userId`**: The user's ID.
*   **`weightKg`**: The user's weight in kilograms.

## Progress Photos

### `getProgressPhotos(String userId)`

Retrieves all progress photos for a given user.

*   **`userId`**: The user's ID.
*   **Returns**: A list of progress photos.

### `createProgressPhoto(String userId, String photoData, String? caption)`

Creates a new progress photo.

*   **`userId`**: The user's ID.
*   **`photoData`**: The base64-encoded image data.
*   **`caption`**: An optional caption for the photo.

### `deleteProgressPhoto(String id)`

Deletes a progress photo.

*   **`id`**: The ID of the photo to delete.
