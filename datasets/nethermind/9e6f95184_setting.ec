commit 9e6f95184c932839e22e23fee5b999dda9f2b57f
Author: Mateusz Jędrzejewski <33068017+matilote@users.noreply.github.com>
Date:   Tue Jul 7 08:33:49 2020 +0000

    removing unnecessary lib, fix hive workflow (#2092)

diff --git a/.github/workflows/hive-docker.yml b/.github/workflows/hive-docker.yml
index 1448733dd..c7bb02928 100644
--- a/.github/workflows/hive-docker.yml
+++ b/.github/workflows/hive-docker.yml
@@ -32,7 +32,7 @@ jobs:
           echo "${DOCKER_PASSWORD}" | docker login --username "${{ steps.settings.outputs.docker_username }}" --password-stdin
       - name: Build & Push image to docker registry
         run: |
-          docker buildx build --platform=linux/amd64 -t "${{ steps.settings.outputs.docker_image }}:alpine" -f Dockerfile_alpine --build-arg GIT_COMMIT=$(git log -1 --format=%h) . --push
+          docker buildx build --platform=linux/amd64 -t "${{ steps.settings.outputs.docker_image }}:alpine" -f Dockerfile --build-arg GIT_COMMIT=$(git log -1 --format=%h) . --push
       - name: Clear
         if: always()
         run: |
diff --git a/Dockerfile b/Dockerfile
index 774d23f3e..19de4f8eb 100644
--- a/Dockerfile
+++ b/Dockerfile
@@ -3,7 +3,7 @@ FROM mcr.microsoft.com/dotnet/core/sdk:3.1-alpine AS build
 
 COPY . .
 RUN echo "@v3.12 http://dl-cdn.alpinelinux.org/alpine/v3.12/main/" >> /etc/apk/repositories && \
-    apk add --no-cache git@v3.12 openssl-dev@v3.12 libssl1.0@v3.12 && \
+    apk add --no-cache git@v3.12 openssl-dev@v3.12 && \
     git submodule update --init src/Dirichlet src/rocksdb-sharp && \
     dotnet publish src/Nethermind/Nethermind.Runner -c release -o out && \
     git describe --tags --always --long > out/git-hash
