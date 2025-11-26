from fastapi import FastAPI, UploadFile, Form, File,Request
from fastapi.responses import HTMLResponse,FileResponse, JSONResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session
from app.database import Base, engine, SessionLocal
from app.models import Person
from app.face_encoder import FaceEncoder
import numpy as np
import pickle
import uuid
import os
import cv2
import pandas as pd

app = FastAPI()
Base.metadata.create_all(bind=engine)
templates = Jinja2Templates(directory="templates")
encoder = FaceEncoder()

@app.get("/", response_class=HTMLResponse)
async def home(request: Request):
    return templates.TemplateResponse("train.html", {"request": request})
@app.post("/train/")
async def train_person(
    person_id: int = Form(...),
    name: str = Form(...),
    files: list[UploadFile] = File(...)
):
    db: Session = SessionLocal()
    
    embeddings = []

    for file in files:
        contents = await file.read()
        emb = encoder.encode_image(contents)
        if emb is not None:
            embeddings.append(emb)

    if not embeddings:
        return {"error": f"No valid faces found for {name}"}

    avg_embedding = np.mean(embeddings, axis=0)
    serialized = pickle.dumps(avg_embedding)

    person = Person(id=person_id, name=name, embedding=serialized)
    db.merge(person)  # upsert
    db.commit()
    db.close()

    return {"message": f"✅ {name} (ID={person_id}) trained successfully!"}

@app.get("/recognize-page", response_class=HTMLResponse)
async def recognize_page(request: Request):
    return templates.TemplateResponse("recognize.html", {"request": request})

@app.post("/recognize/")
async def recognize_faces(files: list[UploadFile] = File(...)):
    db: Session = SessionLocal()
    all_recognition_results = []

    for file in files:
        contents = await file.read()
        npimg = np.frombuffer(contents, np.uint8)
        img = cv2.imdecode(npimg, cv2.IMREAD_COLOR)

        # Get all known embeddings from DB (moved inside loop for demo, can be outside if not changing per file)
        persons = db.query(Person).all()
        known_embeddings = []
        all_names = []
        for p in persons:
            emb = pickle.loads(p.embedding)
            known_embeddings.append(emb)
            all_names.append(p.name)

        known_embeddings = np.array(known_embeddings)
        
        # Initialize attendance for current image
        attendance = {name: "Absent" for name in all_names}
        recognized_names_current_image = []

        # Detect faces in the uploaded image
        faces = encoder.app.get(img)
        threshold_cos = 0.4  # tweak for sensitivity

        for face in faces:
            emb = encoder.l2_normalize(face.embedding)
            cos_sim = np.dot(known_embeddings, emb)
            idx = np.argmax(cos_sim)
            max_sim = cos_sim[idx]

            name = "Unknown"
            if max_sim > threshold_cos:
                name = all_names[idx]
                if name not in recognized_names_current_image:
                    recognized_names_current_image.append(name)
                    attendance[name] = "Present"
                    print(f"Recognized: {name}")
            
            # Draw rectangle and name on the image
            x1, y1, x2, y2 = map(int, face.bbox)
            cv2.rectangle(img, (x1, y1), (x2, y2), (0, 255, 0), 2)
            cv2.putText(img, f"{name}", (x1, y1 - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)

        # Save result image for current file
        image_path = f"recognized_{uuid.uuid4().hex}.jpg"
        cv2.imwrite(image_path, img)

        all_recognition_results.append({
            "filename": file.filename,
            "recognized_names": recognized_names_current_image,
            "image_file": image_path,
            "attendance": attendance
        })
    
    db.close()

    # Generate a single Excel file summarizing attendance across all images
    # This logic needs to be refined based on how attendance for multiple images should be aggregated.
    # For now, it will just take the attendance from the last processed image.
    # A more robust solution would involve combining attendance from all images.
    combined_attendance = {}
    for result in all_recognition_results:
        for name, status in result["attendance"].items():
            if name not in combined_attendance:
                combined_attendance[name] = status
            elif status == "Present":
                combined_attendance[name] = "Present"

    df = pd.DataFrame(list(combined_attendance.items()), columns=["Name", "Status"])
    excel_path = "attendance.xlsx"
    df.to_excel(excel_path, index=False)


    return JSONResponse(content={
        "message": "Recognition processing complete for all images.",
        "results": all_recognition_results, "overall_attendance_excel": excel_path
    })