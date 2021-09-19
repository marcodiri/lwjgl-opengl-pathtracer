package render;

import org.lwjgl.BufferUtils;

import java.nio.FloatBuffer;
import java.util.ArrayList;
import java.util.List;

import static org.lwjgl.opengl.GL15.*;
import static org.lwjgl.opengl.GL20.glEnableVertexAttribArray;
import static org.lwjgl.opengl.GL20.glVertexAttribPointer;
import static org.lwjgl.opengl.GL30.*;

/**
 * Helper functions to create and load Vertex Array Objects.
 *
 * @author Marco Di Rienzo
 */
public class ModelManager {
	private static final List<Integer> vaos = new ArrayList<>();
	private static final List<Integer> vbos = new ArrayList<>();

	// useful constants for stride and offset parameters of initAttributeVariable(...)
	public static final int FLOAT_NUM_BYTES; // sizeof(float) in bytes
	public static final int INT_NUM_BYTES; // sizeof(int) in bytes
	public static final int VEC2_BYTES; // sizeof(vec2) in bytes
	public static final int VEC3_BYTES; // sizeof(vec3) in bytes
	public static final int VEC4_BYTES; // sizeof(vec4) in bytes

	static {
		FLOAT_NUM_BYTES = Float.SIZE / Byte.SIZE;
		INT_NUM_BYTES = Integer.SIZE / Byte.SIZE;
		VEC2_BYTES = 2 * FLOAT_NUM_BYTES;
		VEC3_BYTES = 3 * FLOAT_NUM_BYTES;
		VEC4_BYTES = 4 * FLOAT_NUM_BYTES;
	}

	/**
	 * Generates a Vertex Array Object.
	 * @return the VAO id
	 */
	public static int initVAO() {
		int vao = glGenVertexArrays();
		vaos.add(vao);
		return vao;
	}

	/**
	 * Binds a Vertex Array Object.
	 * @param vao the id of the VAO to be bound
	 */
	public static void bindVAO(int vao) {
		glBindVertexArray(vao);
	}

	/**
	 * Unbinds the current Vertex Array Object.
	 */
	public static void unbindVAO() {
		glBindVertexArray(0);
	}

	/**
	 * Generates a Vertex Buffer Object and stores elements
	 * of the <i>data</i> array in it.
	 * @param data the float array to be stored in the VBO
	 * @return the VBO id
	 */
	public static int initVBO(float[] data) {
		int vbo = glGenBuffers();
		vbos.add(vbo);
		glBindBuffer(GL_ARRAY_BUFFER, vbo);
		FloatBuffer buffer = storeDataInFloatBuffer(data);
		glBufferData(GL_ARRAY_BUFFER, buffer, GL_STATIC_DRAW);
		glBindBuffer(GL_ARRAY_BUFFER, 0);
		return vbo;
	}

	/**
	 * Binds the <i>vbo</i> and makes the vertex attribute array at
	 * the location of the attribute variable <i>aVar</i> point to it,
	 * then enables the vertex attribute array.
	 *
	 * @param aVar the index of the generic vertex attribute to be modified
	 * @param vbo the id of the Vertex Buffer Object to point to
	 * @param size the number of values per vertex that are stored in the <i>vbo</i>
	 * @param stride the byte offset between consecutive generic vertex attributes
	 * @param offset the byte offset of the first component of the first generic vertex attribute
	 */
	public static void initAttributeVariable(int aVar, int vbo, int size, int stride, long offset) {
		glBindBuffer(GL_ARRAY_BUFFER, vbo);
		glVertexAttribPointer(aVar, size, GL_FLOAT, false, stride, offset);
		glEnableVertexAttribArray(aVar);
		glBindBuffer(GL_ARRAY_BUFFER, 0);
	}

	/**
	 * Deletes all VAOs and VBOs created with this class methods.
	 */
	public static void deleteVAOsVBOs() {
		for (int vao : vaos) {
			glDeleteVertexArrays(vao);
		}
		for (int vbo : vbos) {
			glDeleteBuffers(vbo);
		}
	}

	/**
	 * Converts an array of floats into a float buffer.
	 * @param data the array to be stored in the buffer
	 * @return the float buffer
	 */
	public static FloatBuffer storeDataInFloatBuffer(float[] data) {
		FloatBuffer buffer = BufferUtils.createFloatBuffer(data.length);
		buffer.put(data);
		buffer.flip();
		return buffer;
	}
}
