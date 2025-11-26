# Multiface Recognition FastAPI

This project is a face recognition system built with FastAPI that can identify multiple faces in an image. It provides endpoints for training the face recognition model with new individuals and for recognizing faces in uploaded images.

## Prerequisites

-   Python 3.8+
-   pip

## Installation

1.  Clone the repository:
    ```bash
    git clone <repository-url>
    cd Multiface-Recognition-Fastapi
    ```

2.  Install the required Python packages:
    ```bash
    pip install -r requirement.txt
    ```

## Running the Application

To start the FastAPI server, run the following command in the root directory of the project:

```bash
uvicorn app.main:app --reload
```

The application will be available at `http://127.0.0.1:8000`.

## Usage

You can interact with the application through the web interface or by using `curl` to send requests to the API endpoints.

### Training the Model

To train the model with images of a new person, you can use the `/train` endpoint or the web interface at `http://127.0.0.1:8000/`.

**`curl` Example:**

To train a person named "John Doe" with ID 1, using images `john1.jpg` and `john2.jpg`:

```bash
curl -X POST \
  -F "person_id=1" \
  -F "name=John Doe" \
  -F "files=@john1.jpg" \
  -F "files=@john2.jpg" \
  http://127.0.0.1:8000/train/
```

### Recognizing Faces

To recognize faces in one or more images, you can use the `/recognize` endpoint or the web interface at `http://127.0.0.1:8000/recognize-page`.

**`curl` Example for a Single Image:**

```bash
curl -X POST -F "files=@image.jpg" http://127.0.0.1:8000/recognize/
```

**`curl` Example for Multiple Images:**

```bash
curl -X POST \
  -F "files=@image1.jpg" \
  -F "files=@image2.jpg" \
  -F "files=@image3.jpg" \
  http://127.0.0.1:8000/recognize/
```

**Important:** When using `curl`, make sure the image files are in the same directory where you are running the command, or provide the full path to the files.