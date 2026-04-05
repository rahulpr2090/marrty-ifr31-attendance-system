# Contributing to Marrty IFR31

First off, thank you for considering contributing to Marrty IFR31! It's people like you that make open-source software such a great community.

## Where do I go from here?

If you've noticed a bug or have a feature request, make sure to check our [Issues](../../issues) to see if someone else has already reported it or requested it. If not, feel free to open a new issue!

## How to Contribute

### 1. Fork & Create a Branch
1. Fork the repository on GitHub.
2. Clone your fork locally.
3. Create a new branch for your feature or bugfix:  
   `git checkout -b feature/my-awesome-feature` (or `bugfix/fix-that-bug`)

### 2. Make Changes
- **Backend:** Ensure your TypeScript code is well-formatted and uses the Zod validators defined in `src/lib/validators.ts`. Follow the existing Lambda handler patterns.
- **App:** Follow Flutter best practices, use Riverpod for state management, and ensure the UI looks great in both light and dark modes.

### 3. Commit your Changes
Commit your changes with clear, descriptive commit messages.

### 4. Push and Open a Pull Request (PR)
Push your branch to your fork and open a Pull Request against the `main` branch of this repository. Provide a clear description of what your PR does.

## Code of Conduct
Please be respectful and constructive in all interactions within this project. Harassment or abusive behavior will not be tolerated.
