# gradle-webapp-build-base

Gradle build base Intended for building web applications based on the JVM and common frontend technologies. Brings in the latest versions of:

* Gradle
* OpenJDK
* Ruby
* Python
* Docker
* Docker Compose

The Dockerfile is heavily a combination of the Docker `library` repositories of `openjdk`, `gradle`, `ruby`, `python`.

There are scripts to save and restore Docker images into `/home/gradle/docker`. They are named `docker-image-save.sh` and `docker-image-restore.sh`. `docker-image-save.sh` arguments allow a repository prefix to ignore as the first argument, and the second argument to specify a prefix for private repos.
