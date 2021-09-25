package runner;

import model.Model;
import org.joml.Matrix4f;
import org.joml.Vector3f;
import org.lwjgl.BufferUtils;
import org.lwjgl.opengl.GL30C;
import org.lwjgl.opengl.GL42C;
import render.Renderer;
import render.WindowManager;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.IntBuffer;

import static org.lwjgl.opengl.GL11.*;
import static org.lwjgl.opengl.GL15C.GL_READ_WRITE;
import static org.lwjgl.opengl.GL20.*;
import static org.lwjgl.opengl.GL20.glGetUniformLocation;
import static org.lwjgl.opengl.GL20C.glUniform3f;
import static org.lwjgl.opengl.GL20C.glUseProgram;
import static org.lwjgl.opengl.GL30.GL_RGBA32F;
import static org.lwjgl.opengl.GL42.glBindImageTexture;
import static org.lwjgl.opengl.GL42C.GL_SHADER_IMAGE_ACCESS_BARRIER_BIT;
import static org.lwjgl.opengl.GL42C.glMemoryBarrier;
import static org.lwjgl.opengl.GL43.GL_COMPUTE_WORK_GROUP_SIZE;
import static org.lwjgl.opengl.GL43C.glDispatchCompute;
import static utils.Utils.*;
import static render.ModelManager.*;

/**
 * Entry point for the ray tracing program.
 * Creates all the necessary OpenGL programs and renders the
 * results on the screen.
 *
 * @author Marco Di Rienzo
 */
public class MainLoop {
	private static final int WIDTH = 1080;
	private static final int HEIGHT = 720;
	private static final String TITLE = "Ray Tracing";

	private WindowManager windowManager;

	private final float FOV = 45.0f; // [0, 180] degrees
	private final float Z_NEAR = 1f, Z_FAR = 2f;
	private final Matrix4f viewMatrix = new Matrix4f();
	private final Matrix4f projMatrix = new Matrix4f();
	private final Matrix4f invViewProjMatrix = new Matrix4f();
	private final Vector3f tmp = new Vector3f();

	/**
	 * Struct holding the vectors defining the Eye.<br>
	 * Representation of the eye frame as described in
	 * Lecture 03-B "Frames in Graphics", slide 25.
	 */
	private static class Eye {
		public static final Vector3f position = new Vector3f(50f, 52f, 215.6f);
		public static final Vector3f lookAt = new Vector3f(50f, 30f, -1f);
		public static final Vector3f up = new Vector3f(0.0f, 1.0f, 0.0f);
	}

	/**
	 * Struct to hold the OpenGL <i>quad</i> program and its variables.
	 * Also hold the full-screen quad model that will be textured
	 * with the colors computed by the <i>raytracing</i> program.
	 */
	private static class QuadProgram {
		public static int program;
		public static int aPosition;
		public static int texture;
		public static Model model;
	}

	/**
	 * Struct to hold the OpenGL <i>raytracing</i> program and its variables.
	 * The program runs a
	 * <a href="https://www.khronos.org/opengl/wiki/Compute_Shader">compute shader</a>,
	 * so also hold the number of threads per work group to be later used to
	 * compute the total number of work groups, just like we would do in CUDA.
	 */
	private static class RayTracingProgram {
		public static int program;
		public static int u_Eye, u_Ray00, u_Ray01, u_Ray10, u_Ray11;
		public static int workGroupSizeX, workGroupSizeY; // in CUDA this would be the block size
	}

	/**
	 * Creates a quadrilateral which occupies the entire window.
	 * @param aVar the shader attribute variable location
	 * @return the quad {@link Model}
	 */
	private Model createFullScreenQuad(int aVar) {
		float[] quadVertices = {
				-1f, -1f,
				1f, -1f,
				-1f,  1f,
				1f,  1f
		};

		int vao = initVAO();
		bindVAO(vao);
		int vbo = initVBO(quadVertices);
		initAttributeVariable(aVar, vbo, 2, 0, 0);
		unbindVAO();
		return new Model(vao, 4, GL_TRIANGLE_STRIP);
	}

	/**
	 * Creates the OpenGL program that renders the quad and maps
	 * a texture onto it.
	 */
	private void createQuadProgram() throws IOException {
		QuadProgram.program = createProgram(
				readFile("shaders/quad.vert"),
				readFile("shaders/quad.frag"));

		// save attribute variable location and make it point to the quad model
		QuadProgram.aPosition = glGetAttribLocation(QuadProgram.program, "a_Position");
		QuadProgram.model = createFullScreenQuad(QuadProgram.aPosition);

		// create a texture object that will serve as our framebuffer
		QuadProgram.texture = glGenTextures();
		glBindTexture(GL_TEXTURE_2D, QuadProgram.texture);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		ByteBuffer black = null; // init the texture to all black
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, WIDTH, HEIGHT, 0, GL_RGBA, GL_FLOAT, black);
		glBindTexture(GL_TEXTURE_2D, 0);
	}

	/**
	 * Creates the OpenGL program that runs the ray tracing compute shader.
	 * This program is responsible for coloring the texture which will then
	 * be mapped on the full-screen quad.
	 */
	private void createRayTracingProgram() throws IOException {
		RayTracingProgram.program = createComputeProgram(
				readFile("shaders/random.glsl"),
				readFile("shaders/raytracing.glsl"));
		glUseProgram(RayTracingProgram.program);

		// get the number of threads per work group that we specified in the shader
		IntBuffer workGroupSize = BufferUtils.createIntBuffer(3);
		glGetProgramiv(RayTracingProgram.program, GL_COMPUTE_WORK_GROUP_SIZE, workGroupSize);
		RayTracingProgram.workGroupSizeX = workGroupSize.get(0);
		RayTracingProgram.workGroupSizeY = workGroupSize.get(1);

		// save uniform variables location
		RayTracingProgram.u_Eye = glGetUniformLocation(RayTracingProgram.program, "eye");
		RayTracingProgram.u_Ray00 = glGetUniformLocation(RayTracingProgram.program, "ray00");
		RayTracingProgram.u_Ray01 = glGetUniformLocation(RayTracingProgram.program, "ray01");
		RayTracingProgram.u_Ray10 = glGetUniformLocation(RayTracingProgram.program, "ray10");
		RayTracingProgram.u_Ray11 = glGetUniformLocation(RayTracingProgram.program, "ray11");
		glUseProgram(0);
	}

	private void init() throws IOException {
		windowManager = new WindowManager(WIDTH, HEIGHT, TITLE);
		windowManager.createWindow();

		createQuadProgram();
		createRayTracingProgram();

		windowManager.showWindow();
	}

	/**
	 * Prepares the ray tracing program and runs it.
	 */
	private void trace() {
		glUseProgram(RayTracingProgram.program);

		// set the viewProjMatrix as we did in the labs
		projMatrix.setPerspective(
				(float) Math.toRadians(FOV),
				(float) WIDTH / HEIGHT,
				Z_NEAR, Z_FAR);
		viewMatrix.setLookAt(Eye.position, Eye.lookAt, Eye.up);

		// set the eye position and frustum uniform variables (world coordinates)
		glUniform3f(RayTracingProgram.u_Eye, Eye.position.x, Eye.position.y, Eye.position.z);

		/*
		 * Our frustum is defined by the four rays originating from the eye and passing
		 * through the near plane corners as described in:
		 * https://github.com/LWJGL/lwjgl3-wiki/wiki/2.6.1.-Ray-tracing-with-OpenGL-Compute-Shaders-%28Part-I%29#camera
		 * The corners of our window are in normalized device coordinates, so they would be:
		 * (-1,-1), (-1,1), (1,-1) and (1,1)
		 * Those corners, though, are clip coordinates introduced in Lecture 04-B "Camera Model: Projection",
		 * thus we must first convert them to world coordinates to then find the rays.
		 * We know that (clip coord) = ProjMatrix * ViewMatrix * (world coord)
		 * => (world coord) = (clip coord) * (ProjMatrix * ViewMatrix)^(-1)
		 * we also need to divide them by the 4th coordinate because in clip coordinates
		 * it is not necessarily a zero or a one: (world coord affine) = (world coord) / w.
		 * Finally, we subtract the corner and the eye to obtain the ray vector.
		 */

		// corner (-1,-1)
		tmp.set(-1, -1, 0);
		// invViewProjMatrix = (projMatrix * viewMatrix)^(-1)
		projMatrix.invertPerspectiveView(viewMatrix, invViewProjMatrix);
		// corner * invViewProjMatrix; corner /= corner.w
		tmp.mulProject(invViewProjMatrix);
		// ray = corner - eye
		tmp.sub(Eye.position);
		// push to shader
		glUniform3f(RayTracingProgram.u_Ray00, tmp.x, tmp.y, tmp.z);

		// do the same for all the corners
		tmp.set(-1, 1, 0).mulProject(invViewProjMatrix).sub(Eye.position);
		glUniform3f(RayTracingProgram.u_Ray01, tmp.x, tmp.y, tmp.z);
		tmp.set(1, -1, 0).mulProject(invViewProjMatrix).sub(Eye.position);
		glUniform3f(RayTracingProgram.u_Ray10, tmp.x, tmp.y, tmp.z);
		tmp.set(1, 1, 0).mulProject(invViewProjMatrix).sub(Eye.position);
		glUniform3f(RayTracingProgram.u_Ray11, tmp.x, tmp.y, tmp.z);

		// bind our texture to the framebuffer (bound in the shader to image unit 0)
		glBindImageTexture(0, QuadProgram.texture, 0, false, 0, GL_WRITE_ONLY, GL_RGBA32F);

		/*
		 * Compute the total number of work groups:
		 * calculating a pixel color is independent of every other pixel, thus we can assign
		 * each pixel to a different thread to obtain max parallelization, to do this
		 * we divide the window dimension by the size of the work group to obtain the
		 * number of work groups needed to cover the entire image.
		 * Since this number must be an integer, we round up the result, but this will likely
		 * produce a number of threads greater than the total number of pixels in the window,
		 * so in the shader we must check for boundary conditions and terminate the thread
		 * in case its assigned pixel is out of the window. This is again exactly like CUDA.
		 */
		int numWorkGroupsX = (int) Math.ceil((double) WIDTH / RayTracingProgram.workGroupSizeX);
		int numWorkGroupsY = (int) Math.ceil((double) HEIGHT / RayTracingProgram.workGroupSizeY);

		// invoke the compute shader with calculated size
		glDispatchCompute(numWorkGroupsX, numWorkGroupsY, 1);

		/*
		 * Before proceeding to render the texture on our full-screen quad,
		 * we need to make sure that the texture is ready, i.e. all the threads
		 * we started have completed their writing operations on the texture framebuffer.
		 * To do so, we set a barrier on the shader imageStore, which we use as
		 * the last instruction of our shader.
		 * https://www.khronos.org/registry/OpenGL-Refpages/gl4/html/glMemoryBarrier.xhtml
		 */
		glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);

		// reset bindings
		GL42C.glBindImageTexture(0, 0, 0, false, 0, GL_READ_WRITE, GL30C.GL_RGBA32F);
		glUseProgram(0);
	}

	/**
	 * Render the texture computed by the ray tracing program on the full-screen quad.
	 */
	private void renderQuad() {
		glUseProgram(QuadProgram.program);

		glBindTexture(GL_TEXTURE_2D, QuadProgram.texture);
		Renderer.render(QuadProgram.model);
		glBindTexture(GL_TEXTURE_2D, 0);

		glUseProgram(0);
	}

	/**
	 * Every new frame, color the texture based on our scene and map
	 * it on the full-screen quad, then update the window.
	 */
	private void loop() {
		while (!windowManager.shouldClose()) {
			trace();
			renderQuad();
			windowManager.update();
		}
	}

	private void run() {
		try {
			init();
			loop();

			windowManager.destroyWindow();
		} catch (Throwable e) {
			e.printStackTrace();
		} finally {
			deleteVAOsVBOs();
			windowManager.terminate();
		}
	}

	public static void main(String[] args) {
		new MainLoop().run();
	}
}
