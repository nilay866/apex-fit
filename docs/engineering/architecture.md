# Application Architecture

## Overview

The Apex AI application follows a standard Flutter mobile application architecture. It is designed to be modular and scalable, with a clear separation of concerns between the different layers of the application.

## High-Level Architecture

The application is divided into three main layers:

1.  **UI Layer:** This layer is responsible for rendering the user interface and handling user input. It consists of Flutter widgets and screens.
2.  **Service Layer:** This layer provides services to the UI layer, such as data fetching, business logic, and communication with the backend.
3.  **Data Layer:** This layer is responsible for persisting and retrieving data. It communicates with the Supabase backend.

## UI Layer

The UI layer is built using Flutter widgets. The main UI components are:

*   **Screens:** Each screen in the app is represented by a separate widget (e.g., `HomeScreen`, `WorkoutScreen`).
*   **Widgets:** Reusable UI components (e.g., `ApexButton`, `ApexCard`) are located in the `lib/widgets` directory.
*   **MainShell:** The `MainShell` widget is the main entry point for the app's UI after the user logs in. It contains the bottom navigation bar and manages the different screens.

## Service Layer

The service layer consists of the following services:

*   **`SupabaseService`:** This service is responsible for all communication with the Supabase backend. It provides methods for authentication, data fetching, and data manipulation.
*   **`AIService`:** This service is responsible for interacting with the AI coach. It provides methods for getting daily suggestions and other AI-powered features.
*   **`StorageService`:** This service is responsible for storing and retrieving data from the local device storage.

## Data Layer

The data layer is implemented using Supabase. Supabase is a Backend-as-a-Service (BaaS) platform that provides a PostgreSQL database, authentication, and other backend services. The `SupabaseService` in the service layer abstracts the communication with the Supabase backend.
