import os
import cv2
import numpy as np
import pickle
from sqlalchemy.orm import Session
from app.database import SessionLocal, engine
from app.models import Person, Base
from app.face_encoder import FaceEncoder

# Create the tables if they don't exist
Base.metadata.create_all(bind=engine)

def train_from_dataset():
    """
    Trains the face recognition model from a local dataset folder.
    The dataset folder should be structured as follows:
    dataset/
    ├── person_A/
    │   ├── image1.jpg
    │   ├── image2.png
    │   └── ...
    └── person_B/
        ├── image3.jpg
        └── ...
    """
    db: Session = SessionLocal()
    encoder = FaceEncoder()
    dataset_path = "dataset"

    if not os.path.exists(dataset_path):
        print(f"Error: The '{dataset_path}' folder does not exist.")
        return

    person_folders = [f for f in os.scandir(dataset_path) if f.is_dir()]
    
    # Start person IDs from the max existing ID + 1
    max_id = db.query(Person.id).order_by(Person.id.desc()).first()
    person_id_counter = (max_id[0] if max_id else 0) + 1

    for person_folder in person_folders:
        person_name = person_folder.name
        embeddings = []
        
        print(f"Training on images for {person_name}...")

        for image_name in os.listdir(person_folder.path):
            image_path = os.path.join(person_folder.path, image_name)
            
            img = cv2.imread(image_path)
            if img is None:
                print(f"Warning: Could not read image {image_path}. Skipping.")
                continue

            # Encode the face in the image
            faces = encoder.app.get(img)
            if len(faces) > 0:
                emb = encoder.l2_normalize(faces[0].embedding)
                embeddings.append(emb)
            else:
                print(f"Warning: No face found in {image_path}. Skipping.")

        if not embeddings:
            print(f"Error: No valid faces found for {person_name}. Skipping.")
            continue

        avg_embedding = np.mean(embeddings, axis=0)
        serialized_embedding = pickle.dumps(avg_embedding)

        # Check if person already exists
        existing_person = db.query(Person).filter_by(name=person_name).first()
        if existing_person:
            existing_person.embedding = serialized_embedding
            print(f"Updating existing person: {person_name}")
        else:
            person = Person(id=person_id_counter, name=person_name, embedding=serialized_embedding)
            db.add(person)
            print(f"Adding new person: {person_name} with ID: {person_id_counter}")
            person_id_counter += 1
    
    db.commit()
    db.close()
    print("\nTraining complete!")

if __name__ == "__main__":
    train_from_dataset()
