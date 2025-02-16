# **Containers**
- Definition:
    - A Docker container is a lightweight, standalone, and executable package that runs a specific application and its dependencies in an isolated environment.

- Purpose:
    - Containers allow developers to package applications with all necessary components, ensuring that they run consistently across different environments, from development to production.

- Isolation:
    - Each container operates independently, sharing the host system's kernel but maintaining its own filesystem, processes, and network stack. This isolation helps prevent conflicts between applications.

- Creation:
    - Containers are created from Docker images using the docker run command. When a container is started, it is an instance of the image, and it can be modified or stopped without affecting the original image.

- Ephemeral Nature:
    - Containers are typically temporary and can be easily created, destroyed, or recreated. Any changes made to a running container can be discarded unless explicitly saved to a new image.

- Management:
    - Docker provides commands to manage containers, including starting, stopping, and removing them.

# **Working with Conatiners**

- Running Docker Containers
    - You can specify a version of a service by using a **tag**, such as *docker run redis:4.0*, which pulls and runs that specific version.
    - If **no tag** is specified, Docker **defaults to the latest version**, which is governed by the software authors.
    - Commands:
        - Run a specific version of Redis:
            - *docker run redis:4.0*

- Managing Input and Output
    - By default, Docker containers run in non-interactive mode, meaning they do not accept standard input. Use the -i parameter for interactive mode and -t for a pseudo terminal to enable input prompts.
    - Combining -i and -t allows you to interact with the application as intended.
    - Commands:
        - Run a container in interactive with a pseudo terminal
            - *docker run -it <image_name>* 

- Port Mapping and Accessing Applications
    - To access a web application running in a Docker container, you can map container ports to host ports using the -P parameter.
    - Users can access the application through the Docker host's IP and the mapped port, allowing multiple applications to run simultaneously on different ports.
    - Thing to keep in mind is container_port depends on the process running inside the conatiner and is fixed where as host_port can be any free port.
    - Command
        - Map a port on the Docker host to a container port:
            - *docker run -P <host_port>:<container_port>*
        - Accessing the application:
            - *http://<Docker_host_IP>:<mapped_port>*

- Data Persistence in Docker Containers
    - Data created within a container is lost if the container is deleted. To persist data, map a directory on the Docker host to a directory inside the container using the -v option.
    - This ensures that data remains accessible even after the container is removed.
    - We can even mount / but mounting only specific folders saves a the cost which can incure by collecting data from non necessary folders.
    - Commands:
        - Map a directory on the host to a directory in the container:
            - *docker run -v /opt/datadir:/var/lib/mysql <image_name>*


- Container Details and Logs
    - Use the docker inspect command to view detailed information about a container, including its state and configuration.
    - To view logs from a container running in detached mode, use the docker logs command followed by the container ID or name.
    - Commands:
        - Inspect a container for detailed information:
            - *docker inspect <container_name_or_ID>*
        - View logs from a container:
            - *docker logs <container_name_or_ID>*


# **Container Lifecycle**
- When you run a Docker container from an Ubuntu image, it exits immediately because the default command (Bash) requires a terminal to stay alive.
- Containers are designed to run specific tasks or processes, and they exit once those tasks are completed.
- This lifecycle is managed by two instructions specified in Dockerfile while building images for running container.
    - CMD
        - Purpose: Specifies the default command to run when a container starts.
        - Behavior: If you provide a command when running the container, it will replace the CMD instruction.
        - Usage: Typically used for providing default **arguments** to the **ENTRYPOINT** or for simple commands.
        - Example : CMD ["nginx", "-g", "daemon off;"]
                    (If you run *docker run mynginx*, it will execute the CMD. If you run *docker run mynginx* some_other_command, it will replace CMD.)

    - ENTRYPOINT
        - Purpose: Defines the main command that will always run when the container starts.
        - Behavior: Any command-line arguments provided when running the container will be **appended** to the **ENTRYPOINT** command.
        - Usage: Ideal for setting up containers that need to run a specific application or service.
        - Example : ENTRYPOINT ["nginx"]
                    CMD ["-g", "daemon off;"]
                    (Running *docker run mynginx* will execute nginx -g daemon off;. If you run* docker run mynginx some_other_command*, it will execute nginx some_other_command.)

# **Restart Policies**
*   **`no` (default):** The container will not restart automatically.
*   **`always`:** The container will always restart, even if it was manually stopped.
*   **`on-failure`:** The container will restart only if it exits with a non-zero exit code (indicating a failure). It will *not* restart if it was manually stopped using `docker stop`.
*   **`unless-stopped`:** The container will always restart except when it is explicitly stopped.
**Example:**
To run a container with the `on-failure` restart policy:
```bash
docker run --restart on-failure <image_name>
```
Or, if you want to specify a maximum number of restart attempts (e.g., restart a maximum of 5 times):
```bash
docker run --restart on-failure:5 <image_name>
```
