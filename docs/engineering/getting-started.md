# Getting Started

This guide provides instructions for setting up the development environment and running the Apex AI application.

## Prerequisites

Before you begin, ensure you have the following installed:

*   [Flutter SDK](https://flutter.dev/docs/get-started/install)
*   A code editor such as [Visual Studio Code](https://code.visualstudio.com/) or [Android Studio](https://developer.android.com/studio).

## Setup

1.  **Clone the repository:**

    ```bash
    git clone https://github.com/your-username/apex-ai.git
    cd apex-ai
    ```

2.  **Install dependencies:**

    ```bash
    flutter pub get
    ```

3.  **Set up Supabase:**

    *   Create a new project on [Supabase](https://supabase.com/).
    *   In your Supabase project, go to the **SQL Editor** and run the SQL script from the `supabase_migration.sql` file in the root of this project.
    *   In your Supabase project, go to **Settings > API**. You will need the **Project URL** and the **`anon` public key**.

4.  **Configure the app:**

    *   In the `lib/main.dart` file, replace the placeholder values for `supabaseUrl` and `supabaseAnonKey` with your Supabase project's URL and anon key.

## Running the App

You can run the app on a simulator/emulator or on a physical device.

1.  **Select a device:**

    *   In your code editor, select the device you want to run the app on.

2.  **Run the app:**

    ```bash
    flutter run
    ```

    The app will launch on the selected device.
