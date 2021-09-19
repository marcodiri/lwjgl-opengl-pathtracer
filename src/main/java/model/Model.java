package model;

/**
 * A simple structure storing the information of a model.
 *
 * @author Marco Di Rienzo
 */
public class Model {
	private final int vaoID;
	private final int vertexCount;
	private final int drawMode;

	/**
	 * Create a model storing the information needed to be drawn
	 * @param vaoID the id of the VAO containing the data about all
	 *              the geometry of this model
	 * @param vertexCount the number of vertices of this model
	 * @param drawMode the kind of primitives contained in this model
	 */
	public Model(int vaoID, int vertexCount, int drawMode) {
		this.vaoID = vaoID;
		this.vertexCount = vertexCount;
		this.drawMode = drawMode;
	}

	/**
	 * @return the id of the VAO containing the data about all
	 * the geometry of this model
	 */
	public int getVaoID() {
		return vaoID;
	}

	/**
	 * @return the number of vertices of the model
	 */
	public int getVertexCount() {
		return vertexCount;
	}

	/**
	 * @return the kind of primitives contained in this model
	 */
	public int getDrawMode() {
		return drawMode;
	}
}
