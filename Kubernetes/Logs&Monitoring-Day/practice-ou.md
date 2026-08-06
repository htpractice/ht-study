- Build and Push the app.
❯ docker build -t hthaware2508/order-api-lab:v1 .
[+] Building 4.7s (11/11) FINISHED                                                                                                                                       docker:desktop-linux
 => [internal] load build definition from Dockerfile                                                                                                                                     0.0s
 => => transferring dockerfile: 236B                                                                                                                                                     0.0s
 => [internal] load metadata for docker.io/library/python:3.11-slim                                                                                                                      1.3s
 => [auth] library/python:pull token for registry-1.docker.io                                                                                                                            0.0s
 => [internal] load .dockerignore                                                                                                                                                        0.0s
 => => transferring context: 2B                                                                                                                                                          0.0s
 => [1/5] FROM docker.io/library/python:3.11-slim@sha256:94c50be2dc994b873b55bc123e95e6dbade08095b3dfd790f51c34de3f08cbb7                                                                0.0s
 => => resolve docker.io/library/python:3.11-slim@sha256:94c50be2dc994b873b55bc123e95e6dbade08095b3dfd790f51c34de3f08cbb7                                                                0.0s
 => [internal] load build context                                                                                                                                                        0.0s
 => => transferring context: 3.56kB                                                                                                                                                      0.0s
 => CACHED [2/5] WORKDIR /app                                                                                                                                                            0.0s
 => CACHED [3/5] COPY requirements.txt .                                                                                                                                                 0.0s
 => [4/5] RUN pip install --no-cache-dir -r requirements.txt                                                                                                                             2.6s
 => [5/5] COPY app.py .                                                                                                                                                                  0.0s
 => exporting to image                                                                                                                                                                   0.6s
 => => exporting layers                                                                                                                                                                  0.4s
 => => exporting manifest sha256:4b4060cfc914c1a3be54a7107028312ae7c7c7a0dde63f8ecc428905934fc308                                                                                        0.0s
 => => exporting config sha256:07414ec1346f96f6fa505bdba4971eafc0fd676109ff1845b2e27e276e853783                                                                                          0.0s
 => => exporting attestation manifest sha256:005be2e86faf57056b2750556a40ec45c3ff51cb516b65d75aa0ec480a3f351a                                                                            0.0s
 => => exporting manifest list sha256:96b5782d33070692666a0535e5d6ad6fd511d9dfcf8729ef71cae54e0483abd2                                                                                   0.0s
 => => naming to docker.io/hthaware2508/order-api-lab:v1                                                                                                                                 0.0s
 => => unpacking to docker.io/hthaware2508/order-api-lab:v1                                                                                                                              0.1s

View build details: docker-desktop://dashboard/build/desktop-linux/desktop-linux/iwyke361nee2qkrnk0znfh3cg
❯ docker push hthaware2508/order-api-lab:v1
The push refers to repository [docker.io/hthaware2508/order-api-lab]
e108e17e337e: Pushed
030d1ed27904: Pushed
7655ac2ce854: Pushed
94fb3c845c29: Pushed
445d4b43a272: Pushed
5357ca58bc2c: Pushed
1b7200988f19: Mounted from hthaware2508/ingress-demo-app
f0bd26649fe5: Pushed
c9ec0625cc79: Pushed
v1: digest: sha256:96b5782d33070692666a0535e5d6ad6fd511d9dfcf8729ef71cae54e0483abd2 size: 856


---

- Deploy the app.

❯ kubectl apply -f namespace.yaml
namespace/observability created
namespace/order-api created
❯ kubectl apply -f order-api-deployment.yaml ; kubectl apply -f order-api-service.yaml
deployment.apps/order-api created
service/order-api created
❯ kc get pods -n order-api -w
NAME                        READY   STATUS    RESTARTS   AGE
order-api-84d84c658-bftsd   0/1     Running   0          11s
order-api-84d84c658-cqhhq   0/1     Running   0          11s
order-api-84d84c658-cqhhq   1/1     Running   0          15s
order-api-84d84c658-cqhhq   1/1     Running   0          15s
order-api-84d84c658-bftsd   1/1     Running   0          16s
^C%


---


