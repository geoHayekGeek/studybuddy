# main.py
from fastapi import FastAPI, UploadFile, File, Form, Depends, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import create_engine, Column, Integer, String, Text, Boolean, ForeignKey, Float, DateTime
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session, relationship
from pydantic import BaseModel
from typing import List, Optional
import httpx
import os
import uuid
import base64
import PyPDF2
import io
from datetime import datetime
import json
from fastapi.responses import JSONResponse
from passlib.context import CryptContext
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
from datetime import timedelta
from fastapi import Security

# Dependency for database session
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

SECRET_KEY = "P@ssw0rd@123"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

def create_access_token(data: dict, expires_delta: timedelta = None):
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=15))
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

def get_current_user(token: str = Security(oauth2_scheme), db: Session = Depends(get_db)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user = db.query(User).filter(User.email == payload["sub"]).first()
        if user is None:
            raise HTTPException(status_code=401, detail="Invalid token")
        return user
    except JWTError:
        raise HTTPException(status_code=401, detail="Could not validate credentials")

# PostgreSQL Connection
DATABASE_URL = "postgresql://neondb_owner:npg_z2IrcCUFq4vJ@ep-divine-feather-a23opx11-pooler.eu-central-1.aws.neon.tech/neondb?sslmode=require"

# Create SQLAlchemy engine and session
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Configure DeepSeek API
OPENROUTER_API_KEY = "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"
OPENROUTER_API_URL = "https://openrouter.ai/api/v1/chat/completions"
DEEPSEEK_MODEL_NAME = "deepseek/deepseek-chat-v3-0324:free"

#pass hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

# Database Models
class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    email = Column(String, unique=True, index=True)
    hashed_password = Column(String)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    documents = relationship("Document", back_populates="owner")
    quizzes = relationship("Quiz", back_populates="owner")
    quiz_attempts = relationship("QuizAttempt", back_populates="user")


class Document(Base):
    __tablename__ = "documents"
    
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, index=True)
    content_type = Column(String)  # "text", "image", "file"
    content = Column(Text)  # For text or base64 encoded content
    file_path = Column(String, nullable=True)  # For file storage path if needed
    summary = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    user_id = Column(Integer, ForeignKey("users.id"))
    
    owner = relationship("User", back_populates="documents")
    questions = relationship("Question", back_populates="document")


class Question(Base):
    __tablename__ = "questions"
    
    id = Column(Integer, primary_key=True, index=True)
    document_id = Column(Integer, ForeignKey("documents.id"))
    question_text = Column(Text)
    answer = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    document = relationship("Document", back_populates="questions")


class Quiz(Base):
    __tablename__ = "quizzes"
    
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, index=True)
    description = Column(Text, nullable=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    created_at = Column(DateTime, default=datetime.utcnow)
    
    owner = relationship("User", back_populates="quizzes")
    questions = relationship("QuizQuestion", back_populates="quiz")
    attempts = relationship("QuizAttempt", back_populates="quiz")


class QuizQuestion(Base):
    __tablename__ = "quiz_questions"
    
    id = Column(Integer, primary_key=True, index=True)
    quiz_id = Column(Integer, ForeignKey("quizzes.id"))
    question_text = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    quiz = relationship("Quiz", back_populates="questions")
    options = relationship("QuizOption", back_populates="question")


class QuizOption(Base):
    __tablename__ = "quiz_options"
    
    id = Column(Integer, primary_key=True, index=True)
    question_id = Column(Integer, ForeignKey("quiz_questions.id"))
    option_text = Column(Text)
    is_correct = Column(Boolean, default=False)
    
    question = relationship("QuizQuestion", back_populates="options")


class QuizAttempt(Base):
    __tablename__ = "quiz_attempts"
    
    id = Column(Integer, primary_key=True, index=True)
    quiz_id = Column(Integer, ForeignKey("quizzes.id"))
    user_id = Column(Integer, ForeignKey("users.id"))
    score = Column(Float)
    completed_at = Column(DateTime, default=datetime.utcnow)
    
    quiz = relationship("Quiz", back_populates="attempts")
    user = relationship("User", back_populates="quiz_attempts")
    answers = relationship("QuizAttemptAnswer", back_populates="attempt")


class QuizAttemptAnswer(Base):
    __tablename__ = "quiz_attempt_answers"
    
    id = Column(Integer, primary_key=True, index=True)
    attempt_id = Column(Integer, ForeignKey("quiz_attempts.id"))
    question_id = Column(Integer, ForeignKey("quiz_questions.id"))
    selected_option_id = Column(Integer, ForeignKey("quiz_options.id"))
    is_correct = Column(Boolean)
    
    attempt = relationship("QuizAttempt", back_populates="answers")


# Create all tables
Base.metadata.create_all(bind=engine)

# Pydantic models for API
class UserCreate(BaseModel):
    username: str
    email: str
    password: str


class UserResponse(BaseModel):
    id: int
    username: str
    email: str
    created_at: datetime
    
    class Config:
        orm_mode = True


class DocumentCreate(BaseModel):
    title: str
    content_type: str
    content: Optional[str] = None


class DocumentResponse(BaseModel):
    id: int
    title: str
    content_type: str
    summary: Optional[str] = None
    created_at: datetime
    
    class Config:
        orm_mode = True


class QuestionCreate(BaseModel):
    document_id: int
    question_text: str


class QuestionResponse(BaseModel):
    id: int
    question_text: str
    answer: str
    
    class Config:
        orm_mode = True


class QuizOptionCreate(BaseModel):
    option_text: str
    is_correct: bool


class QuizQuestionCreate(BaseModel):
    question_text: str
    options: List[QuizOptionCreate]


class QuizCreate(BaseModel):
    title: str
    description: Optional[str] = None
    questions: List[QuizQuestionCreate]


class QuizOptionResponse(BaseModel):
    id: int
    option_text: str
    is_correct: Optional[bool] = None
    
    class Config:
        orm_mode = True


class QuizQuestionResponse(BaseModel):
    id: int
    question_text: str
    options: List[QuizOptionResponse]
    
    class Config:
        orm_mode = True


class QuizResponse(BaseModel):
    id: int
    title: str
    description: Optional[str] = None
    questions: List[QuizQuestionResponse]
    
    class Config:
        orm_mode = True


class QuizAttemptCreate(BaseModel):
    # Remove quiz_id (get it from path parameter)
    answers: List[dict]


class QuizAttemptResponse(BaseModel):
    id: int
    quiz_id: int
    score: float
    completed_at: datetime
    answers: List[dict]  # Extended with correctness info
    
    class Config:
        orm_mode = True


class SummaryRequest(BaseModel):
    document_id: int


class QuestionRequest(BaseModel):
    document_id: int
    question: str
    
class GenerateQuizRequest(BaseModel):
    document_id: int
    num_questions: int = 15


# Initialize FastAPI app
app = FastAPI(title="AI Learning Backend")

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Adjust for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.post("/token")
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == form_data.username).first()
    if not user or not pwd_context.verify(form_data.password, user.hashed_password):
        raise HTTPException(status_code=400, detail="Invalid credentials")
    access_token = create_access_token(data={"sub": user.email})
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user_id": user.id,  # Add this line
        "email": user.email,  # Add this line
        "username": user.username  # Add this line
    }

# API routes
@app.post("/users/", response_model=UserResponse)
async def create_user(user: UserCreate, db: Session = Depends(get_db)):
    # In a real application, you should hash the password
    db_user = User(
        username=user.username,
        email=user.email,
        hashed_password=hash_password(user.password)  # ✅ Hashed password
)
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user


@app.post("/documents/text/", response_model=DocumentResponse)
async def create_text_document(
    background_tasks: BackgroundTasks,
    title: str = Form(...),
    file: UploadFile = File(...),  # Changed from files to file
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)  # Get user from auth
):
    try:
        # Read file content
        file_content = await file.read()
        
        # Process based on file type
        processed_content = ""
        if file.filename.lower().endswith('.pdf'):
            try:
                pdf_reader = PyPDF2.PdfReader(io.BytesIO(file_content))
                processed_content = "\n".join([page.extract_text() for page in pdf_reader.pages])
            except Exception:
                processed_content = f"Binary PDF content from {file.filename}"
        elif file.content_type.startswith('text/'):
            processed_content = file_content.decode()
        else:
            processed_content = f"File content from {file.filename}"

        # Create document
        db_document = Document(
            title=title,
            content_type="text",
            content=processed_content,
            user_id=current_user.id  # Use authenticated user
        )
        
        db.add(db_document)
        db.commit()
        db.refresh(db_document)
        
        background_tasks.add_task(generate_summary, db_document.id, db)
        return db_document
        
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Document processing error: {str(e)}")

@app.post("/documents/image/", response_model=DocumentResponse)
async def create_image_document(
    background_tasks: BackgroundTasks,
    title: str = Form(...),
    image: UploadFile = File(...),
    user_id: int = Form(...),
    db: Session = Depends(get_db)
):
    # Read and encode image
    image_content = await image.read()
    encoded_image = base64.b64encode(image_content).decode('utf-8')
    
    db_document = Document(
        title=title,
        content_type="image",
        content=encoded_image,
        user_id=user_id
    )
    db.add(db_document)
    db.commit()
    db.refresh(db_document)
    
    # Process image in background (OCR or image analysis could be added here)
    background_tasks.add_task(process_image, db_document.id, db)
    
    return db_document


@app.post("/documents/file/", response_model=DocumentResponse)
async def create_file_document(
    background_tasks: BackgroundTasks,
    title: str = Form(...),
    file: UploadFile = File(...),
    user_id: int = Form(...),
    db: Session = Depends(get_db)
):
    # Save file
    file_contents = await file.read()
    file_id = str(uuid.uuid4())
    file_extension = os.path.splitext(file.filename)[1]
    file_path = f"uploads/{file_id}{file_extension}"
    
    # Ensure uploads directory exists
    os.makedirs("uploads", exist_ok=True)
    
    with open(file_path, "wb") as f:
        f.write(file_contents)
    
    # Store reference in database
    db_document = Document(
        title=title,
        content_type="file",
        file_path=file_path,
        user_id=user_id
    )
    db.add(db_document)
    db.commit()
    db.refresh(db_document)
    
    # Process file in background
    background_tasks.add_task(process_file, db_document.id, db)
    
    return db_document


@app.get("/documents/", response_model=List[DocumentResponse])
async def get_documents(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return db.query(Document).filter(Document.user_id == user.id).all()


@app.get("/documents/{document_id}", response_model=DocumentResponse)
async def get_document(document_id: int, db: Session = Depends(get_db)):
    document = db.query(Document).filter(Document.id == document_id).first()
    if not document:
        raise HTTPException(status_code=404, detail="Document not found")
    return document


@app.post("/documents/{document_id}/summary", response_model=DocumentResponse)
async def request_summary(document_id: int, db: Session = Depends(get_db)):
    document = db.query(Document).filter(Document.id == document_id).first()
    if not document:
        raise HTTPException(status_code=404, detail="Document not found")
    
    if not document.summary:
        # Generate summary
        summary = await generate_summary_with_ai(document)
        document.summary = summary
        db.commit()
        db.refresh(document)
    
    return document


@app.post("/documents/{document_id}/question", response_model=QuestionResponse)
async def ask_question(
    document_id: int, 
    question_req: QuestionRequest, 
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    document = db.query(Document).filter(
        Document.id == document_id,
        Document.user_id == current_user.id
    ).first()
    
    if not document:
        raise HTTPException(status_code=404, detail="Document not found")
    
    if not document.content and not document.file_path:
        raise HTTPException(
            status_code=400,
            detail="Document has no content to analyze"
        )
    
    # Check if question already exists in database
    existing_question = (
        db.query(Question)
        .filter(
            Question.document_id == document_id,
            Question.question_text == question_req.question
        )
        .first()
    )
    
    if existing_question:
        return existing_question
    
    # Generate answer with AI
    answer = await generate_answer_with_ai(document, question_req.question)
    
    # Save question and answer
    db_question = Question(
        document_id=document_id,
        question_text=question_req.question,
        answer=answer
    )
    db.add(db_question)
    db.commit()
    db.refresh(db_question)
    
    return db_question


@app.post("/quizzes/", response_model=QuizResponse)
async def create_quiz(quiz: QuizCreate, user_id: int, db: Session = Depends(get_db)):
    # Create quiz
    db_quiz = Quiz(
        title=quiz.title,
        description=quiz.description,
        user_id=user_id
    )
    db.add(db_quiz)
    db.commit()
    db.refresh(db_quiz)
    
    # Add questions and options
    for question_data in quiz.questions:
        db_question = QuizQuestion(
            quiz_id=db_quiz.id,
            question_text=question_data.question_text
        )
        db.add(db_question)
        db.commit()
        db.refresh(db_question)
        
        for option_data in question_data.options:
            db_option = QuizOption(
                question_id=db_question.id,
                option_text=option_data.option_text,
                is_correct=option_data.is_correct
            )
            db.add(db_option)
    
    db.commit()
    
    # Return the quiz with questions and options
    return get_quiz_by_id(db_quiz.id, db)


@app.get("/quizzes/", response_model=List[QuizResponse])
async def get_quizzes(user_id: int, db: Session = Depends(get_db)):
    quizzes = db.query(Quiz).filter(Quiz.user_id == user_id).all()
    result = []
    
    for quiz in quizzes:
        result.append(get_quiz_by_id(quiz.id, db))
    
    return result


@app.get("/quizzes/{quiz_id}", response_model=QuizResponse)
async def get_quiz(quiz_id: int, db: Session = Depends(get_db)):
    print(get_quiz_by_id(quiz_id, db))
    return get_quiz_by_id(quiz_id, db)


@app.post("/quizzes/{quiz_id}/attempt", response_model=QuizAttemptResponse)
async def submit_quiz_attempt(
    quiz_id: int,
    attempt: QuizAttemptCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Validate quiz exists
    quiz = db.query(Quiz).filter(Quiz.id == quiz_id).first()
    if not quiz:
        raise HTTPException(status_code=404, detail="Quiz not found")
    
    # Create attempt
    db_attempt = QuizAttempt(
        quiz_id=quiz_id,
        user_id=current_user.id,  # Changed here
        score=0.0
    )
    db.add(db_attempt)
    db.commit()
    db.refresh(db_attempt)
    
    # Process answers
    correct_count = 0
    total_questions = 0
    answers_with_feedback = []
    
    for answer in attempt.answers:
        question_id = answer.get("question_id")
        selected_option_id = answer.get("selected_option_id")
        
        # Validate question exists
        question = db.query(QuizQuestion).filter(QuizQuestion.id == question_id).first()
        if not question:
            continue
        
        # Validate option exists
        option = db.query(QuizOption).filter(QuizOption.id == selected_option_id).first()
        if not option:
            continue
        
        # Check if answer is correct
        is_correct = option.is_correct
        
        # Save answer
        db_answer = QuizAttemptAnswer(
            attempt_id=db_attempt.id,
            question_id=question_id,
            selected_option_id=selected_option_id,
            is_correct=is_correct
        )
        db.add(db_answer)
        
        # Update counters
        if is_correct:
            correct_count += 1
        total_questions += 1
        
        # Get correct option for feedback
        correct_option = db.query(QuizOption).filter(
            QuizOption.question_id == question_id,
            QuizOption.is_correct == True
        ).first()
        
        # Prepare answer with feedback
        answers_with_feedback.append({
            "question_id": question_id,
            "question_text": question.question_text,
            "selected_option_id": selected_option_id,
            "selected_option_text": option.option_text,
            "is_correct": is_correct,
            "correct_option_id": correct_option.id if correct_option else None,
            "correct_option_text": correct_option.option_text if correct_option else None
        })
    
    # Calculate score
    score = (correct_count / total_questions * 100) if total_questions > 0 else 0
    db_attempt.score = score
    db.commit()
    
    # Return attempt with detailed feedback
    return {
        "id": db_attempt.id,
        "quiz_id": quiz_id,
        "score": score,
        "completed_at": db_attempt.completed_at,
        "answers": answers_with_feedback
    }

@app.post("/documents/generate-quiz", response_model=QuizResponse)
async def generate_quiz_from_document(
    request: GenerateQuizRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    document = db.query(Document).filter(
        Document.id == request.document_id,
        Document.user_id == current_user.id
    ).first()
    
    if not document:
        raise HTTPException(status_code=404, detail="Document not found")
    
    quiz_data = await generate_quiz_with_ai(document, request.num_questions)
    
    db_quiz = Quiz(
        title=f"Quiz on {document.title}",
        description=f"Generated from: {document.title}",
        user_id=current_user.id
    )
    db.add(db_quiz)
    db.commit()
    
    for question_data in quiz_data:
        db_question = QuizQuestion(
            quiz_id=db_quiz.id,
            question_text=question_data["question"]
        )
        db.add(db_question)
        db.commit()
        
        for option in question_data["options"]:
            db_option = QuizOption(
                question_id=db_question.id,
                option_text=option["text"],
                is_correct=option["is_correct"]
            )
            db.add(db_option)
    
    db.commit()
    return get_quiz_by_id(db_quiz.id, db)

@app.post("/documents/{document_id}/generate-quiz", response_model=QuizResponse)
async def generate_quiz_from_document(
    document_id: int,
    request: GenerateQuizRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    document = db.query(Document).filter(
        Document.id == document_id,
        Document.user_id == current_user.id
    ).first()
    
    if not document:
        raise HTTPException(status_code=404, detail="Document not found")
    
    quiz_data = await generate_quiz_with_ai(document, request.num_questions)
    
    db_quiz = Quiz(
        title=f"Quiz on {document.title}",
        description=f"Generated from: {document.title}",
        user_id=current_user.id
    )
    db.add(db_quiz)
    db.commit()
    
    for question_data in quiz_data:
        db_question = QuizQuestion(
            quiz_id=db_quiz.id,
            question_text=question_data["question"]
        )
        db.add(db_question)
        db.commit()
        
        for option in question_data["options"]:
            db_option = QuizOption(
                question_id=db_question.id,
                option_text=option["text"],
                is_correct=option["is_correct"]
            )
            db.add(db_option)
    
    db.commit()
    return get_quiz_by_id(db_quiz.id, db)

# Helper functions
def get_quiz_by_id(quiz_id: int, db: Session):
    quiz = db.query(Quiz).filter(Quiz.id == quiz_id).first()
    if not quiz:
        raise HTTPException(status_code=404, detail="Quiz not found")
    
    questions = db.query(QuizQuestion).filter(QuizQuestion.quiz_id == quiz_id).all()
    quiz_data = {
        "id": quiz.id,
        "title": quiz.title,
        "description": quiz.description,
        "questions": []
    }
    
    for question in questions:
        options = db.query(QuizOption).filter(QuizOption.question_id == question.id).all()
        question_data = {
            "id": question.id,
            "question_text": question.question_text,
            "options": []
        }
        
        for option in options:
            question_data["options"].append({
                "id": option.id,
                "option_text": option.option_text,
                "is_correct": option.is_correct
            })
        
        quiz_data["questions"].append(question_data)
    
    return quiz_data


async def generate_summary(document_id: int, db: Session):
    """Background task to generate summary"""
    document = db.query(Document).filter(Document.id == document_id).first()
    if not document:
        return
    
    summary = await generate_summary_with_ai(document)
    document.summary = summary
    db.commit()


async def process_image(document_id: int, db: Session):
    """Background task to process image"""
    document = db.query(Document).filter(Document.id == document_id).first()
    if not document:
        return
    
    # Here you could implement OCR or image analysis
    # For now, we'll just generate a placeholder summary
    summary = await generate_summary_with_ai(document)
    document.summary = summary
    db.commit()


async def process_file(document_id: int, db: Session):
    """Background task to process file"""
    document = db.query(Document).filter(Document.id == document_id).first()
    if not document:
        return
    
    # Read file content
    if document.file_path and os.path.exists(document.file_path):
        with open(document.file_path, "rb") as f:
            file_content = f.read()
            
        # Extract text from file (simplified)
        # In a real app, you'd use appropriate libraries based on file type
        try:
            document.content = file_content.decode('utf-8')
        except:
            document.content = "Binary file content"
    
    # Generate summary
    summary = await generate_summary_with_ai(document)
    document.summary = summary
    db.commit()


async def generate_summary_with_ai(document):
    """Generate summary using OpenRouter API"""
    try:
        content = ""
        if document.content_type == "text":
            content = document.content
        elif document.content_type == "image":
            content = "Image content: [Base64 encoded image]"
        elif document.content_type == "file":
            content = document.content or "File content"
        
        prompt = f"Generate a comprehensive summary of the following content:\n\n{content}"
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                OPENROUTER_API_URL,
                headers={
                    "Authorization": f"Bearer {OPENROUTER_API_KEY}",
                    "Content-Type": "application/json",
                    "HTTP-Referer": "https://your-domain.com",
                    "X-Title": "AI Learning Platform"
                },
                json={
                    "model": DEEPSEEK_MODEL_NAME,
                    "messages": [
                        {"role": "system", "content": "You are a helpful assistant that generates concise summaries."},
                        {"role": "user", "content": prompt}
                    ],
                    "temperature": 0.3
                },
                timeout=30.0
            )
            
            result = response.json()
            summary = result.get("choices", [{}])[0].get("message", {}).get("content", "")
            return summary
    
    except Exception as e:
        print(f"Error generating summary: {str(e)}")
        return f"Failed to generate summary: {str(e)}"


async def generate_answer_with_ai(document, question):
    """Generate answer to question using OpenRouter API"""
    try:
        # Get the document content
        content = document.content if document.content else "No content available"
        
        prompt = f"""Based on the following document content, answer the question:
        
        Document Title: {document.title}
        Content:
        {content}
        
        Question: {question}
        
        Please provide a clear and concise answer.
        """
            
        async with httpx.AsyncClient() as client:
            response = await client.post(
                OPENROUTER_API_URL,
                headers={
                    "Authorization": f"Bearer {OPENROUTER_API_KEY}",
                    "Content-Type": "application/json",
                    "HTTP-Referer": "https://your-domain.com",
                    "X-Title": "AI Learning Platform"
                },
                json={
                    "model": DEEPSEEK_MODEL_NAME,
                    "messages": [
                        {"role": "system", "content": "You are a helpful assistant that provides accurate answers based on the given content."},
                        {"role": "user", "content": prompt}
                    ],
                    "temperature": 0.3
                },
                timeout=30.0
            )
            
            result = response.json()
            answer = result.get("choices", [{}])[0].get("message", {}).get("content", "")
            return answer
        
    except Exception as e:
        print(f"Error generating answer: {str(e)}")
        return f"Failed to generate answer: {str(e)}"


async def generate_quiz_with_ai(document, num_questions=15):
    """Generate quiz questions with OpenRouter API"""
    try:
        content = ""
        if document.content_type == "text":
            content = document.content
        elif document.content_type == "image":
            content = "Image content: [Base64 encoded image]"
        elif document.content_type == "file":
            content = document.content or "File content"
        
        prompt = f"""Based on the following content, generate {num_questions} multiple-choice quiz questions.
        
        Content: {content}
        
        For each question:
        1. Create a clear question
        2. Provide 4 answer options (A, B, C, D)
        3. Mark exactly one option as correct
        
        Format your response as a JSON array with the following structure:
        [
            {{
                "question": "Question text",
                "options": [
                    {{"text": "Option A text", "is_correct": true}},
                    {{"text": "Option B text", "is_correct": false}},
                    {{"text": "Option C text", "is_correct": false}},
                    {{"text": "Option D text", "is_correct": false}}
                ]
            }},
            ... more questions ...
        ]
        """
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                OPENROUTER_API_URL,
                headers={
                    "Authorization": f"Bearer {OPENROUTER_API_KEY}",
                    "Content-Type": "application/json",
                    "HTTP-Referer": "https://your-domain.com",
                    "X-Title": "AI Learning Platform"
                },
                json={
                    "model": DEEPSEEK_MODEL_NAME,
                    "messages": [
                        {"role": "system", "content": "You are a helpful assistant that generates high-quality quiz questions."},
                        {"role": "user", "content": prompt}
                    ],
                    "temperature": 0.7
                },
                timeout=30.0
            )
            
            result = response.json()
            response_text = result.get("choices", [{}])[0].get("message", {}).get("content", "")
            
            # Extract JSON from response
            try:
                start_idx = response_text.find('[')
                end_idx = response_text.rfind(']') + 1
                
                if start_idx >= 0 and end_idx > start_idx:
                    json_str = response_text[start_idx:end_idx]
                    quiz_data = json.loads(json_str)
                    return quiz_data
                else:
                    return generate_fallback_quiz(num_questions)
            except json.JSONDecodeError:
                return generate_fallback_quiz(num_questions)
    
    except Exception as e:
        print(f"Error generating quiz: {str(e)}")
        return generate_fallback_quiz(num_questions)


def generate_fallback_quiz(num_questions=15):
    """Generate fallback quiz if AI generation fails"""
    quiz = []
    
    for i in range(1, num_questions + 1):
        quiz.append({
            "question": f"Sample question {i}?",
            "options": [
                {"text": "Option A", "is_correct": i % 4 == 0},
                {"text": "Option B", "is_correct": i % 4 == 1},
                {"text": "Option C", "is_correct": i % 4 == 2},
                {"text": "Option D", "is_correct": i % 4 == 3}
            ]
        })
    
    return quiz


# Main entry point
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)