
# FROM ubuntu
- Installs the base image
# ADD index.html index.html
- Add files and Folders to the conatiner like COPY
- This has additional functionality of adding remote URL's and extract tar's
# RUN apt-get update
# RUN apt-get install nginx -y
# RUN apt-get install vim -y
- Commits the changes to the filesystem as a new layer.


# EXPOSE 80

# CMD ["nginx", "-g", "daemon off;"]