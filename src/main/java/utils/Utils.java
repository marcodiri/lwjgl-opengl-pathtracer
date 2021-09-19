package utils;

import java.io.IOException;
import java.nio.charset.Charset;
import java.nio.file.Files;
import java.nio.file.Paths;

import static org.lwjgl.opengl.GL20.*;
import static org.lwjgl.opengl.GL20.glGetShaderInfoLog;
import static org.lwjgl.opengl.GL43.GL_COMPUTE_SHADER;

// Based on cuon-utils.js (c) 2012 kanda and matsuda
/**
 * Utility functions for creating OpenGL programs.
 *
 * @author Marco Di Rienzo
 */
public class Utils {
	/**
	 * Read file at <i>path</i> into a string.
	 * @param path the path to the file to be read
	 * @param encoding the encoding of the file
	 * @return a string with the file content
	 * @throws IOException if an I/O error occurs reading from the stream
	 */
	// source: https://stackoverflow.com/a/326440
	public static String readFile(String path, Charset encoding) throws IOException {
		byte[] encoded = Files.readAllBytes(Paths.get(path));
		return new String(encoded, encoding);
	}

	/**
	 * Read file at <i>path</i> into a string encoded with the default
	 * charset of this Java virtual machine.
	 * @param path the path to the file to be read
	 * @return a string with the file content
	 * @throws IOException if an I/O error occurs reading from the stream
	 * @see #readFile(String, Charset)
	 */
	public static String readFile(String path) throws IOException {
		return readFile(path, Charset.defaultCharset());
	}

	/**
	 * Creates a shader object.
	 * @param type the type of the shader object to be created
	 * @param source shader program (string)
	 * @return the shader object id
	 * @throws AssertionError if failed to compile the shader program
	 */
	public static int loadShader(int type, String source) throws AssertionError {
		int shader = glCreateShader(type);
		glShaderSource(shader, source);
		glCompileShader(shader);
		int compiled = glGetShaderi(shader, GL_COMPILE_STATUS);
		if (compiled == 0) {
			String error = glGetShaderInfoLog(shader);
			throw new AssertionError("Failed to compile shader: " + error);
		}
		return shader;
	}

	private static int createProgram(int[] types, String[] sources) {
		if (types.length != sources.length) {
			throw new IllegalArgumentException("The length of the arguments must match");
		}

		int program = glCreateProgram();

		int[] shaders = new int[types.length];
		for (int i=0; i < types.length; i++) {
			shaders[i] = loadShader(types[i], sources[i]);
			glAttachShader(program, shaders[i]);
		}

		glLinkProgram(program);
		int linked = glGetProgrami(program, GL_LINK_STATUS);
		if (linked == 0) {
			String error = glGetProgramInfoLog(program);
			glDeleteProgram(program);
			for (int s : shaders)
				glDeleteShader(s);
			throw new AssertionError("Failed to link program: " + error);
		}
		return program;
	}

	/**
	 * Create an OpenGL program object with given vertex and fragment shaders.
	 * @param vShader the vertex shader program (string)
	 * @param fShader the fragment shader program (string)
	 * @return the program object id
	 */
	public static int createProgram(String vShader, String fShader) {
		return createProgram(
				new int[]{GL_VERTEX_SHADER, GL_FRAGMENT_SHADER},
				new String[]{vShader, fShader});
	}

	/**
	 * Create an OpenGL program object with given compute shader.
	 * @param cShader the compute shader program (string)
	 * @return the program object id
	 */
	public static int createComputeProgram(String cShader) {
		return createProgram(
				new int[]{GL_COMPUTE_SHADER},
				new String[]{cShader});
	}
}
