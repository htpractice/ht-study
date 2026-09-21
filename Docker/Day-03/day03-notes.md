This video (Day 3/40 of the CKA course) provides a comprehensive guide on **Multi-Stage Docker Builds**, a best practice for optimizing container images by reducing their size and enhancing security. 

### **What is a Multi-Stage Docker Build?**
It is a technique that uses multiple `FROM` statements in a single `Dockerfile`. It allows you to use a heavy image for building your application and then copy only the necessary artifacts into a lightweight, final production image.

### **Key Steps Demonstrated**
1.  **Defining Stages:** (3:28) The video uses `FROM node:18-alpine AS installer` to handle the build process, including downloading dependencies and running `npm run build`.
2.  **Deployment Stage:** (5:45) A second stage is defined using `FROM nginx:latest AS deployer`. This image serves the static website.
3.  **Copying Artifacts:** (6:05) Only the final build folder (containing static files) is copied from the `installer` stage to the `nginx` web directory (`/usr/share/nginx/html`). This excludes heavy `node_modules` and source files from the final container.

### **Benefits**
*   **Performance:** Significantly reduces the final image size (195 MB in this example compared to standard builds).
*   **Security:** Minimizes the attack surface by including only the essential files required for runtime (8:44).
*   **Isolation:** Separates the build-time environment from the production runtime environment.

### **Essential Docker Commands Covered**
*   `docker build -t <image-name> .`: Builds the image using the `Dockerfile` (9:13).
*   `docker image rm <image-id>`: Cleans up unused images to save disk space (11:04).
*   `docker run -d -p 3000:80 <image-name>`: Runs the container in detached mode, mapping ports (12:26).
*   `docker logs <container-id>`: Essential for troubleshooting application issues (13:03).
*   `docker exec -it <container-id> sh`: Accesses the container's shell for inspection (13:30).
*   `docker inspect <container-id>`: Views detailed container configurations, including IP addresses and port exposures (16:20).

### **Best Practice Tip**
*   Always aim to run containers as a **non-root user** to further improve security (17:39).