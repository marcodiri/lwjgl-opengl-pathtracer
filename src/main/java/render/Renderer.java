package render;

import model.Model;

import static org.lwjgl.opengl.GL11.*;
import static org.lwjgl.opengl.GL30.glBindVertexArray;

/**
 * Utility functions to render a {@link Model} with OpenGL.
 *
 * @author Marco Di Rienzo
 */
public class Renderer {
	/**
	 * Clears the buffer bit.
	 */
	public static void clearBufferBit() {
		glClearColor(0, 0, 0, 1);
		glClear(GL_COLOR_BUFFER_BIT);
	}

	/**
	 * Renders a {@link Model}.
	 * @param model the {@link Model} to render
	 */
	public static void render(Model model) {
		glBindVertexArray(model.getVaoID());
		glDrawArrays(model.getDrawMode(), 0, model.getVertexCount());
		glBindVertexArray(0);
	}
}
