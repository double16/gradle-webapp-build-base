# gradle-webapp-build-base

Gradle build base intended for building web applications based on the JVM and common frontend technologies. Brings in the latest versions of:

* Gradle
* OpenJDK
* Ruby
* Python
* Docker
* Docker Compose
* Kubernetes via k3s, Helm

The Dockerfile is heavily a combination of the Docker `library` repositories of `openjdk`, `gradle`, `ruby`, `python`.

There are scripts to save and restore Docker images into `/home/gradle/docker`. They are named `docker-image-save.sh` and `docker-image-restore.sh`. `docker-image-save.sh` arguments allow a repository prefix to ignore as the first argument, and the second argument to specify a prefix for private repos.

Docker-in-Docker can be started with the `start-dind.sh` script. Requires privileged mode.

Kubernetes can be started using `start-k3s.sh`. Requires privileged mode.

If you want to save some resources you can keep Docker and K3S resources across containers. Use a `docker-compose.yaml` like the following:

```yaml
version: "2.4"

volumes:
  docker:
  k3s-server:

services:
  ci:
    image: pdouble16/gradle-webapp-build-base:latest
    privileged: true
    volumes:
      - docker:/var/lib/docker
      - k3s-server:/var/lib/rancher/k3s
```
