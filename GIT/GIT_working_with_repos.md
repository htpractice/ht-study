# GIT Branches
- A branch is a pointer to the last commit in a Git repository, allowing developers to work on features or fixes independently. The default branch is called "master."
- When a new developer joins, they can create their own branch (e.g., "Sarah") to work on new features without impacting the master branch.

- Creating and managing branches
    - To create a new branch, use the command: git checkout -b branch_name. This command creates and switches to the new branch simultaneously.
    - You can list all branches with git branch, switch branches with git checkout branch_name, and delete a branch with git branch -d branch_name.

- Understanding HEAD in Git
    - The HEAD in Git indicates the current position in the repository, pointing to the last commit in the branch you are on.
    - When switching branches, the HEAD moves to reflect the last commit of the new branch.
    - HEAD is a reference that points to the current commit in your repository.
        - Current Position:
            HEAD indicates where you are currently working in the Git repository. It points to the last commit in the branch you have checked out.
        - Branch Switching:
            When you switch branches using the command `git checkout branch_name`, the HEAD moves to point to the last commit of that new branch.
        - Detached HEAD:
            If you check out a specific commit (not a branch), you enter a "detached HEAD" state. This means HEAD points directly to a commit rather than a branch, and any new commits made in this state will not belong to any branch unless you create a new branch from there.

- How to manage merging changes from multiple branches in Git, follow these key steps:
    1. **Ensure Code is Ready for Merging**:
       - Before merging, ensure that the code in the feature branch is complete and tested.
    
    2. **Switch to the Target Branch**:
       - Use the command: ```git checkout master``` (or the branch you want to merge into).
    
    3. **Merge the Feature Branch**:
       - Execute the command: ```git merge feature_branch_name```. This will merge the changes from the specified feature branch into the current branch.
    
    4. **Resolve Conflicts (if any)**:
       - If there are conflicts (when changes in both branches affect the same lines of code), Git will notify you. You'll need to manually resolve these conflicts in the affected files, then stage the resolved files using ```git add file_name```.
    
    5. **Complete the Merge**:
       - After resolving conflicts, finalize the merge with: ```git commit```. This creates a new commit that includes the merged changes.
    
    6. **Push Changes to Remote Repository**:
       - Finally, push the updated branch to the remote repository using: ```git push origin master```.
    
    By following these steps, you can effectively manage merging changes from multiple developers working on different branches. Keep practicing these commands to become more comfortable with the merging process!

# GIT Merge
- INTRODUCTION: 
    This material focuses on the process of merging branches in Git, specifically how to integrate changes from a feature branch into the master branch using the `git merge` command.

- Merging branches in Git
    - To merge a feature branch (e.g., `feature/sign up`) into the master branch, you first need to check out the master branch and then use the command `git merge feature/sign up`.
    - There are two types of merges: fast forward and no fast forward.

- Fast forward merge
    - A fast forward merge occurs when the current branch has no additional commits compared to the branch being merged. In this case, Git directly integrates the commits without creating a new commit.
    - This type of merge is efficient and keeps the commit history clean, as it simply moves the master branch pointer forward.

- No fast forward merge
    - A no fast forward merge happens when there are additional commits on the current branch. Git creates a new merge commit that points to both the current branch and the branch being merged.
    - This ensures that all changes are preserved, and the master branch now contains all the updates from the feature branch.

Remember, practice is key! Engage with the labs to solidify your understanding of these concepts. You're doing great, and I'm here to support your learning journey!

# Working with Remote Repositories
- Introduction:
    - Remote repositories allow you to store your code on platforms like GitHub, GitLab, and Bitbucket, enabling collaboration and version control.
    - You can push your local code to a remote repository and pull updates back to your local machine.
    - If the remote repo is public but in read-only , to push the changes user needs to be collaborator or a member of the project.
    - Initializing a remote repository in Git sets up a destination that allows for the synchronization of changes from a local repository to a remote server, facilitating collaboration and version control across different environments.

- Adding Remote Repo:
    - A connection string is a URL that tells Git where your remote repository is located.
    - You can add a remote repository to your local project using the command `git remote add origin <connection-string>` to simplify future interactions.
        - eg : `git remote add origin http://git.example.com/sarah/story-blog.git`

- Managing Remote Repo:
    - You can list all your remote repositories with the command `git remote -v`.
    - To work with the remote repository, you can fetch and push data, allowing for seamless updates between your local project and the hosted repository.

- Cloning the Remote Repo:
    - The process of cloning a remote repository using Git, which allows new team members to access all project data on their local.
    - Clone a remote repository to access all its data locally using the `git clone` command followed by the SSH link of the repository.
        - eg: `git clone git@github.com:account/remote-repo.git`

- Pushing to Remote Repo:
    - To keep local and remote repositories in sync, you need to push data from your local repository to the remote repository using the git push command.
    - The git push command requires two arguments: 
        1. the alias of the remote repository (commonly referred to as "origin") `git push alias`
        2. the current branch you are working on, which is typically the "master" branch if no branches have been created yet. `git push alias current-branch`
            - eg : `git push origin master`

- Creating Pull Requests:
    - Once the changes are pushed, we create a request to merge the commited changes to master/main branch post review and feedback.
    - From UI we can create a merge request for review and merge.
    - Merging can be done only if you have Permissions to merge.

- Fetching and Pulling:
    - We can update our local Git repository to reflect changes made in the remote origin master branch, using `git fetch` and `git merge`.
        - `git fetch origin master` : This will **fetch** and update my origin master brach (which is remote) in my local repo
        - `git merge origin/master` : This will **update** my local master branch to point to latest changes made on origin master (which is remote)

    - We can update our local Git repository to reflect changes made in the remote origin master branch, using single command `git pull`
        - `git pull origin master` : This will **fetch** and **merge** the origin master (remote) into local master branch

- Merge Conflicts:
    - A merge conflict happens when two people change the same part of a file in different ways, and Git doesn't know which change to keep. 
    1. **Identify the Conflict**:
        When you try to merge branches, Git will notify you of a conflict and mark the files that have issues.
    
    2. **Open the Conflicted File**:
        Open the file in a code editor. You will see conflict markers that look like this:
                <<<<<<< HEAD
                Your changes
                =======
                Their changes
                >>>>>>> branch-name

    3. **Review the Changes**:
        Look at the changes made by both parties. Decide which changes to keep or how to combine them.

    4. **Edit the File**:
        Remove the conflict markers and make the necessary edits to keep the desired changes.

    5. **Save the File**:
        After editing, save the file.
    
    6. **Add the Resolved File**:
        Use the command `git add <filename>` to stage the resolved file.

    7. **Complete the Merge**:
        Finally, run `git commit` to complete the merge process. This will create a new commit that includes the resolved changes.

- Forking:
    - Forking a Git repository allows you to create your own copy of an original project, enabling you to make changes without affecting the original codebase, where you do not have write permissions to edit.
    - Forking is done from UI where we can click on repo we have read accesss to and fork it.
    - Steps to fork a repositiory
        1. **Navigate to the Repository**:
            - Go to the GitHub page of the repository you want to fork.
            
        2. **Click on the Fork Button**:
            - In the upper right corner of the repository page, click the Fork button. This creates a copy of the repository in your own GitHub account.

        3. **Clone the Forked Repository**:
            - Use the following command to clone your forked repository to your local machine:
                    `git clone https://github.com/your-username/repository-name.git`
            
        4. **Create a New Branch**:
            - Navigate into the cloned repository:
                    cd repository-name
            - Create a new branch for your changes:
                    git checkout -b your-branch-name
        
        5. **Make Changes**:
            - Edit files and make the necessary changes in your local repository.
        
        6. **Commit Your Changes**:
            - Stage your changes:
                    git add .
            - Commit your changes with a descriptive message:
                    git commit -m "Description of changes"
        
        7. **Push Changes to Your Fork**:
            - Push your changes to your forked repository on GitHub:
                        git push origin your-branch-name

        8. **Create a Pull Request**:
            - Go back to the original repository on GitHub.
            - Click on the Pull Requests tab.
            - Click on New Pull Request.
            - Select your branch from the forked repository and submit the pull request.