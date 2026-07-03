Based on the tutorial, here are the practical tasks you can perform on your local machine to master Dockerizing a project:

### **1. Environment Setup (1:09 - 4:45)**
*   **Install Docker:** Ensure *Docker Desktop* is installed on your operating system (Windows, Mac, or Linux).
*   **Verify Installation:** Once installed, open your terminal and verify by running `docker --version` or checking the GUI status.

### **2. Prepare the Application (6:45 - 8:12)**
*   **Clone a Sample Project:** Practice using `git clone <repository-url>` to pull a sample application to your local workspace.
*   **Navigate the Structure:** Use `ls` to explore the repository files (e.g., `package.json`, `index.js`) to understand what components need to be included in your container.

### **3. Writing the Dockerfile (8:20 - 17:15)**
*   **Create the File:** Use `touch Dockerfile` and edit it using a text editor (like `vi`).
*   **Implement Best Practices:**
    *   Define the base image (`FROM node:18-alpine`).
    *   Set the working directory (`WORKDIR /app`).
    *   Copy files (`COPY . .`).
    *   Install dependencies (`RUN yarn install --production`).
    *   Specify startup commands (`CMD ["node", "src/index.js"]`).
    *   Expose the application port (`EXPOSE 3000`).

### **4. Build and Run (17:28 - 30:50)**
*   **Build the Image:** Run `docker build -t <your-image-name> .` to create your custom Docker image.
*   **Inspect Layers:** Observe how Docker creates the image in layers during the build process.
*   **Run a Container:** Execute the image using `docker run -d -p 3000:3000 <your-image-name>` to run it in detached mode.
*   **Verify Running Status:** Use `docker ps` to see your active container.

### **5. Troubleshooting & Practice (31:36 - 32:45)**
*   **Interactive Shell:** Use `docker exec -it <container-id> sh` to jump into your running container and explore the file system inside.
*   **Experiment:** Try making small changes to the application code, rebuilding the image, and observing how the layer cache (or rebuild process) behaves.

By completing these steps, you will gain hands-on experience in the entire lifecycle of containerizing an application, which is crucial for your CKA certification journey.