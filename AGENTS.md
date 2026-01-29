# Understanding the project

To understand the project, you may first wish to refer to the initial document, being the prompt that was used to create it. You may find it at: ./AI/PROMPT.txt

## How to extend the project

The project is based on the principle of modules, which implement the `Gather` project-specific verb, and the `Install` verb.

To understand the structure of the modules, how an implementation of them looks, and the project-specific shared functions, you may refer to:
- ./AI/EXTENDING.md
- ./Shared/HerFiles.Shared.psm1

And the directory:
- ./Shared/Modules

## Code quality

- No external libraries unless absolutely necessary.
- NEVER respond to prompts with "y", "yes", etc, when running `Install` verbs. DO NOT modify user files without a backup and without confirmation from the user.