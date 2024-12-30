# INTRODUCTION
- Git is a distributed version control system. It is a tool used to manage the project’s source code history.
- The characteristics of Git are as follows:
    - Provide strong support for non-linear development
    - Are fully distributed
    - Can efficiently handle large projects
    - Have a simple design
- There are two types of Git repositories—local and remote—and the stages of files within a local repository.
- Team members can create their own local repositories and pull data from the remote repository to start working on a project.
- Changes made by team members can be pushed to the remote repository to keep both local and remote repositories synchronized.

# Types of Git Repositories
    - Local Repository
        - A local repository is stored on your own machine, allowing direct access to your files and changes.
    - Remote Rpository
        - A remote repository is typically a centralized server that serves as a backup and facilitates collaboration among team members.

# Stages of Files in a Local Repository
- Working Area:
    - This is where all your active changes are located. Git recognizes that these files have updates, but it hasn't processed them yet.
        - example:
            All untracked file seen after running "git status"
- Staging Area:
    - This area contains new changes that you have marked to be included in the next commit. You prepare your changes here before finalizing them.
        - example:
            sudo git add lion-and-mouse.txt -> Adds the file from working area to stage area

- Committed Files:
    - These are the files that have been saved in the repository. When you commit your changes, you create a snapshot of your project at that point in time.
        - example:
            sudo git commit -m 'Added the lion and mouse story' -> Commits the changes i.e now we have a new version of file ready to be published

# Initializing a Git repository
- To start, navigate to your project folder and initialize Git by typing git init, which creates an empty Git repository in a hidden .git folder.
- You can check the contents of the folder, including hidden files, by using the ls -a command.

- Adding and committing files
    - After creating a new text file, you can check Git's awareness of changes using the git status command, which shows the current state of your repository.
    - To save changes, you first need to stage the file using git add story1.txt, and then commit it with a message using git commit -m "Added first story".

- Understanding Git's structure
    - The default branch in Git is called "master," and until you create new branches, you will remain on this branch.
    - Committing changes allows you to save the current state of your project, making it easy to revert to this state in the future.
different stages a file can be in while using Git, including how to create, stage, and commit files, as well as best practices for maintaining a clean commit history.

- Understanding file states in Git
    - When a new file is created, it starts in the working area in an untracked state. You can move it to the staging area using the git add command.
    - Committing a file requires setting your user name and email with the git config command, and each commit should have a meaningful message.

- Best practices for committing changes
    - It's important to keep commits atomic, meaning each commit should address a single issue or feature to maintain a clean project history.
    - Avoid committing unrelated changes together, as this can complicate the commit history and make it harder to revert specific changes.

- Managing untracked files
    - If you accidentally stage a personal file, you can remove it from tracking using *git rm --cached <file>*, which keeps the file in your directory but removes it from Git's tracking.
    - To permanently ignore certain files, you can use a *.gitignore* file, which should be saved in the repository for team collaboration.

# Practices of GIT COMMIT:
- Good Practices:
    - Atomic Commits: 
        - Each commit should address a single problem or feature. This keeps the commit history clean and understandable.
    - Meaningful Commit Messages:
        - Always provide a clear and concise message that describes what the commit does.
    - Separate Related Changes:
        - If multiple files are changed as part of the same requirement, they can be committed together. However, unrelated changes should be committed separately.

- Bad Practices:
    - Multiple Changes in One Commit:
        - Avoid committing unrelated changes together, as it makes it difficult to understand the purpose of the commit.
    - Inconsistent Commit Messages:
        - Failing to provide meaningful messages can lead to confusion about the commit history.
    - Reverting Commits with Unrelated Changes:
        - If a commit contains multiple unrelated changes, reverting it will also revert changes that may not need to be undone.

# Staging Files in Git:
- Staging Area:
    - The staging area (or index) is where you prepare files before committing them to the repository. Only files in this area will be included in the next commit.

- Adding Files to Staging:
    - Use the git add <file> command to move files from the working directory to the staging area. You can stage multiple files at once by listing them or using wildcards.

- Checking Status:
    - Run git status to see which files are in the staging area, which are modified, and which are untracked.

- Removing Files from Staging:
    - If you need to unstage a file, use the command ```git restore --staged <file>```. This moves the file back to the modified state without losing any changes.

- Committing Staged Changes:
    - Once you have staged the desired changes, use git commit -m "Your commit message" to save those changes to the repository.

- Staging and Modifying:
    - If you modify a file after staging it, the staged version is cached. You can restore the staged version using git restore <file> if needed.

    