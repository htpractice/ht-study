# **Jenkins the CI/CD Tool**
# The Concept CI-CD
# CI
- **Continuous Integration**
    - CI involves taking code from a repository, packaging it, and preparing it for deployment. 
    - Think of it like wrapping a gift, where you gather all the pieces, assemble them, and ensure everything is in order.
    - Key steps in CI include `cloning the repository`, `running tests` (unit and integration), and `performing security checks` to ensure the code is ready for deployment.
    - CI process is where we test your code like Unit test, integration test, etc.
# CD
- **Continuous Delievery**
    - Continuous Delivery means that after the CI process, `there is a manual step (like clicking a button)` to deploy the code.
    - This ensures that the deployment is controlled and intentional.
- **Continuous Deployment**
    - Continuous Deployment automates the entire process, where code is `automatically deployed` to the system after passing through CI, with `no human intervention required`.
- **Key Pieces**
    - Automated Deployment:
        The process of automatically deploying code to a production environment after it has passed all tests in the CI process.
    - Manual Intervention:
        In Continuous Delivery, there is typically a manual step (like clicking a button) to trigger the deployment, ensuring that the deployment is intentional.
    - Authentication:
        Ensuring that the system or environment where the code is being deployed is secure and that the necessary credentials are in place.
    - Post-Deployment Testing:
        Running tests after deployment to verify that the application is functioning as expected in the production environment.
    - Monitoring and Feedback:
        Continuously monitoring the application post-deployment to catch any issues early and gather feedback for future improvements.
# Drawbacks if no CI/CD
- **Increased Errors**:
    Without CI, code changes may not be tested thoroughly, leading to bugs and errors in production. This can result in a poor user experience and increased downtime.
- **Longer Deployment Times**:
    Without CD, deploying code can become a manual and time-consuming process, delaying the release of new features or fixes.
- **Integration Issues**:
    Developers may face challenges when integrating their code with others, leading to conflicts and inconsistencies that are harder to resolve later.
- **Lack of Visibility**:
    Without automated processes, it becomes difficult to track the status of code changes, making it challenging to identify where issues arise.
- **Reduced Collaboration**:
    CI/CD encourages collaboration among team members. Without it, communication may suffer, leading to siloed work and inefficiencies.

# **Why Jenkins?**
# Introduction
- Jenkins is a widely-used open-source automation server that facilitates continuous integration (CI) and continuous delivery (CD) in software development. 
- It allows developers to automate the [building], [testing], and [deployment] of applications, enabling them to detect errors and bugs early in the development process.
- Integrating with various version control systems, Jenkins helps streamline the development workflow, ensuring that code changes are automatically tested and deployed.

# Features
- **Continuous Integration**:
    - Automatically builds and tests code changes as they are committed to the repository.
- **Plugins**:
    - Supports a wide range of plugins to extend its functionality, allowing integration with various tools and services.
- **Pipelines**:
    - Enables the creation of complex workflows for building, testing, and deploying applications.
- **User Managemen**t:
    - Provides features for managing users and teams, ensuring secure access to the Jenkins environment.

# Benefits:
- Early detection of bugs and errors.
- Faster deployment cycles.
- Improved collaboration among development teams.

# Administering Jenkins:
- When it comes to administering jenkins we need to follow fe principles for Jenkins to seamlessly integrate and deliever or deploy
    1. Backup
        - This refers to creating copies of Jenkins data, configurations, and job information.
        - Backups are essential to prevent data loss in case of system failures or errors.
        - Regular backups ensure that you can recover your Jenkins environment if something goes wrong.
        - Types
            - Full Backup: Full data backup
            - Incremental Backup: Backup of only newley added data over previous backed-up data
            - Snapshots: Point in time backup

    2. Restore
        - This is the process of retrieving and reinstating data from backups.
        - If Jenkins server encounters issues or data loss, restore process brings back the system to its previous state using the backup copies.

    3. Monitor
        - Monitoring involves keeping an eye on the performance and health of the Jenkins server.
        - This includes tracking system metrics, job statuses, and error logs.
        - Effective monitoring helps identify issues early, allowing for timely troubleshooting and maintenance.

    4. Scale
        - Scaling refers to the ability to increase or decrease the resources allocated to Jenkins based on demand.
        - If more users or jobs are added, you may need to scale up (add more servers or resources) to handle the increased load efficiently.

    5. Manage
        - Management encompasses the ongoing tasks required to keep Jenkins running smoothly.
        - This includes applying updates, managing user permissions, configuring plugins, and ensuring that the system is secure and efficient.
        - Regular management is crucial for maintaining the overall health of the Jenkins environment.
        
- The most critical component to back up in Jenkins is the Jenkins home folder. where we have jenkins config file and jobs folder.
    1. Configuration Files:
        - These include the `config.xml` file, which contains the configuration settings for Jenkins itself.
    2. Jobs Folder:
        - This folder contains all your `job` configurations and pipelines.
        - Losing this data could mean losing all your continuous integration and continuous delivery (CI/CD) pipelines.

# Jenkins Pipeline
- Building Multistage pipeline
    1. Clone/Build
        pulling a git repo and building a code
    2. Test
        testing a code on test instances or test env
    3. Deploy
        Deploying a code in production env
    4. Cleanup
        Cleanup the env for next pipeline run

- To build a pipeline we need a Jenkins file which has following important components.
    1. Agents
        - Specifies where the pipeline should run
        - example
            agent any  // Use any available agent
            agent { label 'linux' } // Use a specific agent labeled 'linux'

    2. Environment Variables
        - Define global variables accessible across all pipeline stages
        - Used to store cresentials, configuration, values, or custom paths.
        - example
            environment {
                APP_ENV = 'production'
                AWS_REGION = 'us-east-1'
            }
    
    3. Stages & Steps
        - Stages : Logical blocks of pipeline yhat group steps together.
        - Steps : Individual tasks executed within a stage, like running shell commands or tests
        - example
            stage ('Build') {
                steps {
                    script {
                    app = docker.build("adminturneddevops/go-webapp-sample")
                    }
                }
            }

    4. Post Actions
        - Defines actions after pipeline execution
        - example
            post {
                success {
                    echo 'Pipeline completed successfully'
                }
                failure {
                    echo 'Pipeline failed!'
                }
            }
