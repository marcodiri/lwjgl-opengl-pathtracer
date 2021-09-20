# Simple LWGJL OpenGL Path Tracer
This project is a simple **OpenGL** path tracer developed in **Java 8** using the library [LWJGL](https://www.lwjgl.org/), based on the   [Ray tracing with OpenGL guide by Kai Burjack](https://github.com/LWJGL/lwjgl3-wiki/wiki/2.6.1.-Ray-tracing-with-OpenGL-Compute-Shaders-%28Part-I%29)  and on [smallPT by Kevin Beason](http://kevinbeason.com/smallpt/).

## Dependencies
You'll need **Java >= 8** to run the compiled jar.<br />
This project uses **Maven** to manage its dependencies, LWJGL and [JOML](https://github.com/JOML-CI/JOML), that will be automatically downloaded by Maven, when building the jar, in the  `.m2` folder under your user's home directory.
After the build you can remove the downloaded dependencies folders `.m2/repository/org/lwjgl` and `.m2/repository/org/joml`, or remove the `.m2` folder entirely if you do not use Maven yourself.

## Building
1. Clone the repo:
```bash
$ git clone https://github.com/marcodiri/lwjgl-opengl-pathtracer.git
```
2. Build the jar with **Maven** (I suggest using the provided wrapper *mvnw*):
```bash
# Navigate inside the root project directory
$ cd lwjgl-opengl-pathtracer

# Unix
$ ./mvnw clean package

# Windows
$ .\mvnw clean package
```
You'll find the compiled jar in the *target* folder.

## Running
Build the jar following the steps in the [Building](#Building) section.<br />
To launch the application, run the generated *lwjgl-opengl-pathtracer-\*.jar* in the *target* folder:
```bash
$ java -jar target/lwjgl-opengl-pathtracer-1.0-SNAPSHOT.jar
```