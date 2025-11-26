import os
from sqlalchemy.orm import Session
from app.database import SessionLocal, engine
from app.models import Person, Base

def clean_database():
    """
    Removes people from the database that are not present in the dataset folder.
    """
    db: Session = SessionLocal()
    dataset_path = "dataset"

    if not os.path.exists(dataset_path):
        print(f"Error: The '{dataset_path}' folder does not exist.")
        return

    # Get the names of the people from the dataset folder
    dataset_person_names = {f.name for f in os.scandir(dataset_path) if f.is_dir()}
    
    if not dataset_person_names:
        print("The dataset folder is empty. No people to keep.")
        # For safety, we'll just exit if the dataset is empty.
        return

    print(f"People to keep (from dataset folder): {', '.join(dataset_person_names)}")

    # Get all people from the database
    db_persons = db.query(Person).all()
    
    removed_count = 0
    print("\nChecking database for people to remove...")
    for person in db_persons:
        if person.name not in dataset_person_names:
            print(f" - Removing {person.name} (ID: {person.id})")
            db.delete(person)
            removed_count += 1
    
    if removed_count > 0:
        db.commit()
        print(f"\nSuccessfully removed {removed_count} people from the database.")
    else:
        print("\nDatabase is already in sync with the dataset folder. No one was removed.")

    db.close()

if __name__ == "__main__":
    clean_database()
