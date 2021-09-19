package render;

import org.lwjgl.glfw.GLFWVidMode;
import org.lwjgl.opengl.GL;
import org.lwjgl.system.MemoryUtil;

import static org.lwjgl.glfw.GLFW.*;
import static org.lwjgl.opengl.GL11.*;

/**
 * Initializes the GLFW library to be able to create a new window for OpenGL
 * to render into.
 *
 * @author Marco Di Rienzo
 */
public class WindowManager {
	public long window;
	private int width;
	private int height;
	private String title;

	/**
	 * Init GLFW and set the following window properties:
	 * <ul>
	 *     <li>created window will be hidden,
	 *     call {@link #showWindow()} to make it visible</li>
	 *     <li>created window cannot be resized</li>
	 * </ul>
	 * @param width the width of the window
	 * @param height the height of the window
	 * @param title the title of the window
	 * @throws IllegalStateException if GLFW cannot be initialized.
	 */
	public WindowManager(int width, int height, String title) throws IllegalStateException {
		if (!glfwInit())
			throw new IllegalStateException("Unable to initialize GLFW");

		glfwDefaultWindowHints();
		glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
		glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
		// OpenGL 4.3 to support compute shaders
		glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
		glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
		glfwWindowHint(GLFW_VISIBLE, GL_FALSE);
		glfwWindowHint(GLFW_RESIZABLE, GL_FALSE);

		this.width = width;
		this.height = height;
		this.title = title;
	}

	/**
	 * Creates a new window and sets it as the current OpenGL context.
	 */
	public void createWindow() throws IllegalStateException, AssertionError {
		window = glfwCreateWindow(width, height, title, MemoryUtil.NULL, MemoryUtil.NULL);
		if (window == MemoryUtil.NULL) {
			throw new AssertionError("Failed to create the GLFW window");
		}

		// center window on the screen
		GLFWVidMode vidmode = glfwGetVideoMode(glfwGetPrimaryMonitor());
		if (vidmode == null) {
			throw new AssertionError("Failed to get primary monitor");
		}
		glfwSetWindowPos(window, (vidmode.width() - width) / 2, (vidmode.height() - height) / 2);

		glfwMakeContextCurrent(window);
		glfwSwapInterval(0);
		GL.createCapabilities();
	}

	/**
	 * Makes the created window visible.
	 */
	public void showWindow() {
		glfwShowWindow(window);
	}

	/**
	 * Processes all pending events and swaps the front and back buffers
	 * of this window.
	 */
	public void update() {
		glfwPollEvents();
		glfwSwapBuffers(window);
	}

	/**
	 * @return the value of {@link org.lwjgl.glfw.GLFW#glfwWindowShouldClose(long)}
	 * for this window.
	 */
	public boolean shouldClose() {
		return glfwWindowShouldClose(window);
	}

	/**
	 * Calls {@link org.lwjgl.glfw.GLFW#glfwDestroyWindow(long)} on this window.
	 */
	public void destroyWindow() {
		glfwDestroyWindow(window);
	}

	/**
	 * Calls {@link org.lwjgl.glfw.GLFW#glfwTerminate()}
	 */
	public void terminate() {
		glfwTerminate();
	}
}
