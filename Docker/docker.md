# **Introduction**
    - Docker is an open platform that enables developers and system administrators to build, ship, and run applications in lightweight, portable containers. These containers encapsulate an application and its dependencies, ensuring consistent performance across various environments, whether on local machines, data center VMs, or the cloud. By leveraging containerization, Docker simplifies the development process, enhances collaboration between teams, and streamlines deployment, making it a vital tool in modern software development and DevOps practices.

# **Overview**
-  With Docker, the *developers* and *operations* teams work hand in hand to transform the guide into a DockerFile with both of their requirements. This DockerFile is then used to create an image for their applications. This image can now run on any host with Docker installed on it and is guaranteed to run the same way everywhere. So the Ops team can now simply use the image to deploy the application since the image was already working when the developer built it and operations have not modified it.
- Docker consists of three main components:
    Docker daemon : manages Docker objects like images and containers
    REST API server : serves as an interface that allows programs to communicate with the Docker daemon.
    Docker CLI : Allows users to interact with the daemon through commands.
- Docker works on a concept called as ***process ID namespaces***
    - *Isolation*: Each container has its own PID namespace, which means that processes inside the container can have the same PID as processes on the host or in other containers without conflict. For example, a process in a container can have a PID of 1, which is the root process for that container.
    - *Independent Process Trees*: When a container is created, it appears to have its own independent set of processes. The container believes it is the only system running, with its own root process tree starting from PID 1.
    - *Underlying Host*: Although the processes in the container are isolated, they are still running on the underlying host system. The host can see all processes, but the container only sees its own processes.


# **Containers**
- Conatiners share the `same OS kernel`, making them `lightweight and faster` to boot compared to **virtual machines**, which require separate operating systems for each instance.
- A Docker container is a lightweight, standalone, and executable package that runs a specific application and its dependencies in an isolated environment on host machine.
- By default, containers can utilize all available resources on the host, but Docker employs control groups (Cgroups) to limit resource allocation.
- Users can restrict CPU and memory usage for containers using options like --cpus and --memory during the container run command. *docker run --cpu=.5 <image_name>* or *docker run --memory=100m <image_name>*

- *Managing Containers*
    - To stop a running container, use the *docker stop* command followed by the container ID or name. You can verify the status with *docker ps*.
    - To permanently remove a stopped container, use the *docker rm* command, and to see available images, use docker images.
    - **Container Management Commands**
        - *docker run <image>*
            - Runs a container from the specified image. If the image is not available locally, it pulls it from Docker Hub.
            - Runs a conatiner in foreground
        - *docker run -d <image>*
            - Runs a container in detached mode, allowing it to run in the background.
        - *docker stop <container_id or container_name>*
            - Stops a running container using its ID or name.
        - *docker rm <container_id or container_name>*
            - Permanently removes a stopped or exited container.
        - *docker exec <container_id> <command>*
            - Executes a command inside a running container.
        - *docker attach <container_id>*
            - Attaches to a running container to view its output.
    - **Container Status Commands**
        - *docker ps*
            - Lists all running containers along with their basic information.
        - *docker ps -a*
            - Lists all containers, including those that have exited.
    - **Running Containers**
        - *docker build .*
            - Build the docker image from the Dockerfile
        - *docker tag -t <account_name>/<image_name>:<version>*
            - Tag the image with account name (latest if version not provided)
        - *docker run -itd <image_name>*
            - Run the docker conatiner from the Docker image
    - **Attaching Volumes**
        - *docker volume create my_volume*
            - Create a volume
        - *docker run -v my_volume:/path/in/container my_image*
            - Run a container with the volume
    - A Docker container lives as long as the main process (PID 1) inside it is running. If this process exits, stops, or crashes, the container will also stop and its status will change to "exited." This emphasizes the relationship between the container's lifecycle and the main process running inside it.

# **Images**
- Images are nothing but the blueprint for running conatiners i.e a step by step guide on how to run any application.
- They contain code to run the application, runtime, libraries and environment variables.
- Once these steps are added to file and used to build the image, we can't change the image its immutable.
- ***Layered architecture of Docker images***
    - Docker images are built in layers, where each instruction in the Dockerfile creates a new layer that only contains changes from the previous one.
    - eg: Image has 5 layers, and a container based on that image adds 2 more layers = 7 layers
    - This architecture allows Docker to reuse layers from existing images, speeding up the build process and saving disk space.

- *Managing Images*
    - The *docker rmi* command removes an image, but ensure no containers are using it first.
    - Use the *docker pull* command to download an image without running a container, which is useful for preparing images in advance.
    - **Image Management Commands**
        - *docker images*
            - Displays a list of available images on the host along with their sizes.
        - *docker rmi <image>*
            - Removes an image from the host, provided no containers are using it.
        - *docker pull <image>*
            - Downloads an image from Docker Hub without running a container.
        - *docker images -f dangling=true*
            - Lists all the dangling i.e not associated with any tag.
        - *docker image prune* 
            - removes all dangling images
- Creating Images
    - File used to build image is called Dockerfile
    - To modify the behaviour of docker container we can use env variables or command line arguments which will override CMD
    - Example: Building a image for running python app using env variable
               FROM python:3.8                
               # Set environment variable
               ENV APP_COLOR=blue
               
               # Copy application code
               COPY app.py /app.py
               
               # Run the application
               CMD ["python", "/app.py"]

- Dockerfile
    - A Dockerfile is a text file that contains instructions for setting up your application, including installing dependencies and specifying the entry point.
    - Instructions : 
            - *FROM*: Sets the base image for the container.
            - *WORKDIR*: Establishes the working directory inside the container.
            - *COPY*: Transfers files from your local machine to the container.
            - *RUN*: Executes commands to install dependencies.
            - *EXPOSE*: Documents the port the application listens on.
            - *ENTRYPOINT*: Main command that will always run when the container starts. Can be overwritten from cli using *docker run --entrypoint*
            - *CMD*: Specifies the command to run when the container starts, can be overriden from cli and also serves as arg for entrypoint
    - Dockerfile is used to build images using *docker build*
    - These custom images are used to run the containers *docker run <image_name>*

- Images Vs Conatiners
- **Images**
    - Static templates used to create containers.
    - Immutable, can't be changed once created.
    - Stored in registeries
    - Serves as blueprint for the conatiners.

- **Conatiners**  
    - Running instances of docker images.
    - Stop, Start or Modify container.
    - Operates in isolated env.
    - They are removed when no longer needed

# Storage
- Docker's storage structure
    - Docker stores its data in a specific folder structure located at */var/lib/docker*, which includes folders for `containers`, `images`, and `volumes`.
    - Each type of data (containers, images, volumes) is organized into its respective folder for easy management.
    - Docker images are built in layers, where each instruction in the Dockerfile creates a new layer that only contains changes from the previous one.
    - When a container is created from an image, a new writable layer is added on top, allowing for changes and data storage during the container's life.
    - To persist data beyond the container's lifecycle, Docker uses volumes, which can be created and mounted to store data safely, even if the container is destroyed.
- Docker storage is termed as Volumes and is used for
    - Data Persistence:
        - Use volumes to store data generated by your applications, such as databases. This ensures that even if the container is stopped or removed, the data remains intact.
        - Example: If you're running a MySQL database in a container, you can create a volume to store the database files, so they are not lost when the container is deleted.
    - Sharing Data Between Containers:
        - Volumes allow multiple containers to share the same data. This is useful for microservices that need to access common data.
        - Example: If you have a web application and a backend service that both need access to the same configuration files, you can mount a volume that both containers can read from.
    - Easier Backups and Migrations:
        - Since volumes are stored outside the container's filesystem, you can easily back up the data or migrate it to another environment.
        - Example: You can create a backup of your volume data using Docker commands, making it easier to restore or move to a different server.
    - Development and Testing:
        - During development, you can mount your local project directory as a volume in the container. This allows you to make changes to your code locally and see the effects immediately in the running container.
        - Example: If you're developing a web application, you can mount your local code directory to the container's web server directory, enabling real-time updates.
- Types of mounting
    1. Volume Mounting:
        - Docker allows you to create volumes that can be mounted into containers. 
        - This enables data persistence beyond the container's lifecycle.
        - Volumes can be created manually or automatically by Docker when a container is run.
        - *docker run -v my_volume:/path/in/container my_image*
    2. Bind Mounting:
        - This mechanism allows you to mount a directory from the host system into the container.
        - This is useful for sharing files between the host and the container, such as during development.
        - *docker run -v /hostpath:/path/in/container my_image*
    3. Storage Drivers:
        - Docker uses storage drivers to manage the layered architecture and file operations.
        - Different storage drivers (like aufs, overlay, and device mapper) provide various performance and stability characteristics, depending on the underlying operating system.

# Network
**Types of Docker Networks**
- By default docker automatically creates three networks: Bridge, Host, and None.
    1. *Bridge*
        - Bridge network is the default, allowing containers to communicate internally using an IP address in the 172.17 range.
    2. *Host*
        - The Host network removes network isolation, making containers accessible externally without port mapping, but limits the ability to run multiple containers on the same port.
    3. *None*
        - Isolated network if used by conatiner no on can communicate with that container, no ingress no egress.

**Creating Custom Networks**
- Docker allows the creation of custom internal networks using the command `docker network create`, specifying the driver and subnet for isolation.
- To view existing networks, the command `docker network ls` can be used.

**Conatiner Communication**
- Containers can communicate using their names,using Docker's ***built-in DNS***, which resolves container names to IP addresses.
- Network settings and IP addresses of containers can be inspected using the `docker inspect <container_id>`.

**Built-in DNS**
- Docker provides built in DNS running on 127.0.0.11 also called as ***Embedded DNS***
- It allows containers to resolve IP's and names internally.
- Using conatiner names make it easy to work even if the container restarts with new IP
- DNS service operates within the network namespace of the container, providing a level of isolation and security.

# Registery
- Understanding Docker Registry
    - A Docker registry is a central repository where Docker images are stored, similar to clouds from which containers (the rain) are pulled.
    - The default registry is Docker Hub (docker.io), but other registries like Google’s Registry (gcr.io) also exist for specific use cases.

- Image Naming and Access
    - Docker images follow a naming convention, with the format being `library/image-name` for official images, such as `library/nginx`.
    - To access private images, users must log in to the private registry using the docker login command before pulling or pushing images.
                image: <Registery>/<user/org account_name>/<image/Repository>
            ex: image: gcr.io/kubernetes-e2e-test-images/dsutils

- Creating a Private Registry
    - Organizations can set up their own private registries using the Docker registry image, which runs on port 5000.
    - Images can be tagged with the private registry URL and pushed to it, allowing access from within the network.
    - create a private Docker registry, follow these steps:
        - Run the Docker Registry Image:
            *docker run -d -p 5000:5000 --name registry registry:2*
            - This command runs the registry in detached mode (-d), mapping port 5000 on your host to port 5000 on the registry container.

        - Tag Your Image:
            *docker tag your-image localhost:5000/your-image*
        
        - Push Your Image to the Registry:
            *docker push localhost:5000/your-image*

        - Pulling Images from Your Private Registry:
            *docker pull localhost:5000/your-image*
















            






