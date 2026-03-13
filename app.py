from fastapi import (FastAPI, Request, Form,
                     Depends, HTTPException, status,
                     Cookie, Response, UploadFile,
                     File, WebSocket, WebSocketDisconnect, Header, Query, Body)
from fastapi.responses import HTMLResponse, RedirectResponse, FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.security import OAuth2PasswordBearer
from starlette.middleware.base import BaseHTTPMiddleware
from jose import JWTError, jwt
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_, func, desc, text
from sqlalchemy.orm.attributes import flag_modified
from passlib.context import CryptContext
from pathlib import Path
import hashlib
import random
import string
import asyncio
from datetime import datetime, timedelta
import re
import os
import shutil
import asyncio
import json
import jwt
from uuid import uuid4
import uuid
from typing import Optional, List, Dict, Any, Set
from pydantic import BaseModel, EmailStr, field_validator  # Важно: field_validator для Pydantic v2
from docx import Document
from docx.shared import Inches, Pt, Cm
from docx.enum.text import WD_ALIGN_PARAGRAPH
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from openpyxl import Workbook
from openpyxl.chart import BarChart, PieChart, Reference
from openpyxl.styles import Font, Alignment
import shutil
import io
import tempfile
from apscheduler.schedulers.background import BackgroundScheduler

from database import SessionLocal, User, Property, PropertyPhoto, Application, Contract, Message, AuditLog
from schemas import (
    UserRegisterStep1, UserRegisterStep2, UserRegisterStep3,
    UserProfileUpdate, PasswordRecoveryRequest, PasswordRecoveryVerify,
    PasswordRecoveryReset, PropertyCreate, ApplicationCreate,
    ApplicationResponse, MessageCreate
)
from reports import (
    generate_contract_docx,  # правильное имя функции
    generate_act_pdf,
    generate_agent_stats_excel
)

# ==================== НАСТРОЙКИ ====================
BASE_DIR = Path(__file__).resolve().parent
SECRET_KEY = "your-secret-key-here-change-in-production"  # В продакшене сменить!
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

UPLOAD_DIR = BASE_DIR / "static" / "uploads"
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

app = FastAPI(title="RentEase", version="2.0")

# Статика и шаблоны
static_dir = BASE_DIR / "static"
templates_dir = BASE_DIR / "templates"
static_dir.mkdir(exist_ok=True)
templates_dir.mkdir(exist_ok=True)

# Подключаем статику с кэшированием (оптимизация)
from starlette.staticfiles import StaticFiles as StarletteStaticFiles
class CachedStaticFiles(StarletteStaticFiles):
    async def get_response(self, path: str, scope):
        response = await super().get_response(path, scope)
        response.headers['Cache-Control'] = 'public, max-age=3600'
        return response

app.mount("/static", CachedStaticFiles(directory=str(static_dir)), name="static")
templates = Jinja2Templates(directory=str(templates_dir))

resources_dir = BASE_DIR / "resources"
resources_dir.mkdir(exist_ok=True)
app.mount("/resources", CachedStaticFiles(directory=str(resources_dir)), name="resources")

# Контекст для хеширования паролей
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token", auto_error=False)

TEMP_DIR = BASE_DIR / "temp"
TEMP_DIR.mkdir(exist_ok=True)

def cleanup_temp_files():
    """Очистка временных файлов старше 1 часа"""
    temp_dir = BASE_DIR / "temp"
    if temp_dir.exists():
        now = datetime.now()
        for file in temp_dir.glob("*"):
            if file.is_file():
                file_time = datetime.fromtimestamp(file.stat().st_mtime)
                if (now - file_time).seconds > 3600:  # 1 час
                    file.unlink()

# Запускаем планировщик для очистки
scheduler = BackgroundScheduler()
scheduler.add_job(cleanup_temp_files, 'interval', hours=1)
scheduler.start()

# ==================== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ====================

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()



def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def verify_token(token: str):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            return None
        return email
    except JWTError:
        return None


async def get_current_user(
        token: Optional[str] = Cookie(None, alias="access_token"),
        authorization: Optional[str] = Header(None),
        db: Session = Depends(get_db)
):
    # Пробуем получить токен из разных мест
    access_token = token

    # Если нет в куках, пробуем из заголовка
    if not access_token and authorization:
        if authorization.startswith("Bearer "):
            access_token = authorization.replace("Bearer ", "")

    if not access_token:
        print("❌ Нет токена ни в куках, ни в заголовке")
        return None

    try:
        payload = jwt.decode(access_token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")

        if email is None:
            return None

        user = db.query(User).filter(User.email == email).first()

        if user:
            # Обновляем время последней активности
            user.last_activity = datetime.utcnow()
            db.commit()
            print(f"✅ Найден пользователь: {user.email} (ID: {user.user_id})")
            return user
        else:
            print(f"❌ Пользователь с email {email} не найден")
            return None

    except jwt.ExpiredSignatureError:
        print("❌ Токен истек")
        return None
    except jwt.JWTError as e:
        print(f"❌ Ошибка валидации токена: {e}")
        return None

# Добавьте эту функцию после get_db()
def get_db_with_audit(current_user: User = Depends(get_current_user)):
    db = SessionLocal()
    try:
        if current_user:
            # Устанавливаем ID пользователя для триггеров аудита
            db.execute(text(f"SELECT set_current_user_id({current_user.user_id})"))
        else:
            # Если пользователь не авторизован, устанавливаем NULL
            db.execute(text("SELECT set_current_user_id(NULL)"))
        yield db
    finally:
        db.close()

def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return hash_password(plain_password) == hashed_password


def generate_code() -> str:
    return ''.join(random.choices(string.digits, k=8))


def validate_email(email: str) -> bool:
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return re.match(pattern, email) is not None


def get_properties_from_db(db: Session, limit: int = 6):
    properties = db.query(Property).filter(Property.status == 'active').order_by(Property.created_at.desc()).limit(
        limit).all()
    for prop in properties:
        main_photo = db.query(PropertyPhoto).filter(
            PropertyPhoto.property_id == prop.property_id,
            PropertyPhoto.is_main == True
        ).first()
        prop.main_photo_url = main_photo.url if main_photo else "/resources/placeholder-image.png"
    return properties


def get_default_cities():
    return [{"id": 1, "name": "Москва"}, {"id": 2, "name": "Санкт-Петербург"},
            {"id": 3, "name": "Новосибирск"}, {"id": 4, "name": "Екатеринбург"},
            {"id": 5, "name": "Казань"}]


def get_user_initials(user: User):
    if user.full_name:
        parts = user.full_name.split()
        if len(parts) >= 2:
            return f"{parts[0][0]}{parts[1][0]}".upper()
        return parts[0][0].upper()
    return user.email[0].upper()


async def save_upload_file(upload_file: UploadFile, subdir: str = "") -> str:
    try:
        # Генерация уникального имени файла
        file_extension = os.path.splitext(upload_file.filename)[1]
        if not file_extension:
            file_extension = '.jpg'  # расширение по умолчанию

        file_name = f"{uuid4().hex}{file_extension}"
        file_path = UPLOAD_DIR / subdir / file_name
        file_path.parent.mkdir(parents=True, exist_ok=True)

        # Читаем и сохраняем файл
        content = await upload_file.read()
        with open(file_path, "wb") as buffer:
            buffer.write(content)

        print(f"✅ Файл сохранён: {file_path}")
        # Возвращаем URL для доступа через статику
        return f"/static/uploads/{subdir}/{file_name}"
    except Exception as e:
        print(f"❌ Ошибка сохранения файла: {e}")
        raise

# ==================== PYDANTIC СХЕМЫ ====================

class PropertyCreate(BaseModel):
    title: str
    description: Optional[str] = None
    address: str
    city: str
    property_type: str
    area: float
    rooms: int
    price: float
    interval_pay: str


class ApplicationCreate(BaseModel):
    property_id: int
    desired_date: str
    duration_days: int
    message: Optional[str] = None


class MessageCreate(BaseModel):
    to_user_id: int
    content: str

# ==================== WEBSOCKET ДЛЯ ОНЛАЙН СТАТУСА ====================

# Хранилище активных соединений
class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[int, WebSocket] = {}
        self.online_users: Set[int] = set()

    async def connect(self, websocket: WebSocket, user_id: int):
        await websocket.accept()
        self.active_connections[user_id] = websocket
        self.online_users.add(user_id)
        print(f"✅ Пользователь {user_id} подключился. Онлайн: {self.online_users}")
        # Оповещаем всех о новом онлайн пользователе
        await self.broadcast_online_status(user_id, True)

    def disconnect(self, user_id: int):
        if user_id in self.active_connections:
            del self.active_connections[user_id]
        if user_id in self.online_users:
            self.online_users.remove(user_id)
        print(f"❌ Пользователь {user_id} отключился. Онлайн: {self.online_users}")

    async def broadcast_online_status(self, user_id: int, is_online: bool):
        """Отправить всем подключенным клиентам обновление статуса"""
        message = json.dumps({
            "type": "status_update",
            "user_id": user_id,
            "is_online": is_online
        })
        print(f"📢 Рассылка статуса: пользователь {user_id} = {is_online}")
        print(f"   Активные соединения: {list(self.active_connections.keys())}")

        # Отправляем всем активным соединениям
        for uid, connection in self.active_connections.items():
            try:
                await connection.send_text(message)
                print(f"   -> Отправлено пользователю {uid}")
            except Exception as e:
                print(f"   ❌ Ошибка отправки пользователю {uid}: {e}")

    async def send_personal_message(self, user_id: int, message: str):
        """Отправить сообщение конкретному пользователю"""
        if user_id in self.active_connections:
            try:
                await self.active_connections[user_id].send_text(message)
            except:
                pass

manager = ConnectionManager()

@app.websocket("/ws/{user_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: int):
    await manager.connect(websocket, user_id)
    try:
        while True:
            # Ждём сообщения от клиента (можно использовать для ping-pong)
            data = await websocket.receive_text()
            # Обрабатываем полученные сообщения (например, ping)
            if data == "ping":
                await websocket.send_text("pong")
    except WebSocketDisconnect:
        manager.disconnect(user_id)
        await manager.broadcast_online_status(user_id, False)


class AuthMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        # Пропускаем статические файлы и открытые эндпоинты
        if request.url.path in ["/", "/register", "/recovery", "/api/login"] or \
                request.url.path.startswith("/static/") or \
                request.url.path.startswith("/resources/"):
            return await call_next(request)

        # Проверяем токен из разных источников
        token = request.cookies.get("access_token")

        # Если нет в куках, пробуем из заголовка Authorization
        if not token:
            auth_header = request.headers.get("Authorization")
            if auth_header and auth_header.startswith("Bearer "):
                token = auth_header.replace("Bearer ", "")

        if token:
            try:
                payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
                request.state.user_email = payload.get("sub")
                request.state.user_id = payload.get("user_id")
            except jwt.ExpiredSignatureError:
                # Токен истек, но не блокируем сразу
                pass
            except jwt.JWTError:
                pass

        response = await call_next(request)
        return response

class DBSessionMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        response = await call_next(request)
        return response

# Подключаем middleware
app.add_middleware(AuthMiddleware)

# ==================== ОСНОВНЫЕ МАРШРУТЫ ====================

@app.get("/", response_class=HTMLResponse)
async def home_page(
    request: Request,
    page: int = 1,
    per_page: int = 12,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    try:
        query = db.query(Property).filter(Property.status == 'active').order_by(Property.created_at.desc())
        total = query.count()
        properties = query.offset((page - 1) * per_page).limit(per_page).all()

        for prop in properties:
            main_photo = db.query(PropertyPhoto).filter(
                PropertyPhoto.property_id == prop.property_id,
                PropertyPhoto.is_main == True
            ).first()
            prop.main_photo_url = main_photo.url if main_photo else "/resources/placeholder-image.png"
    except Exception as e:
        print(f"Ошибка получения данных из БД: {e}")
        properties = []
        total = 0

    cities = get_default_cities()
    total_pages = (total + per_page - 1) // per_page if per_page > 0 else 1

    return templates.TemplateResponse("index.html", {
        "request": request,
        "properties": properties,
        "cities": cities,
        "current_user": current_user,
        "user_initials": get_user_initials(current_user) if current_user else None,
        "page": page,
        "per_page": per_page,
        "total": total,
        "total_pages": total_pages
    })


@app.get("/register", response_class=HTMLResponse)
async def register_page(request: Request, current_user: User = Depends(get_current_user)):
    if current_user:
        return RedirectResponse("/")
    return templates.TemplateResponse("register.html", {"request": request})


@app.get("/recovery", response_class=HTMLResponse)
async def recovery_page(request: Request, current_user: User = Depends(get_current_user)):
    if current_user:
        return RedirectResponse("/")
    return templates.TemplateResponse("recovery.html", {"request": request})

# ==================== ВОССТАНОВЛЕНИЕ ПАРОЛЯ ====================

@app.post("/api/recovery/request")
async def recovery_request(
    email: str = Form(...),
    db: Session = Depends(get_db)
):
    """Запрос на восстановление пароля"""
    user = db.query(User).filter(User.email == email).first()

    if not user:
        # Не сообщаем, что пользователь не найден (безопасность)
        return {"success": True, "message": "Если пользователь существует, код будет отправлен"}

    # Генерируем код
    code = ''.join(random.choices(string.digits, k=8))

    # Сохраняем код восстановления
    if not hasattr(app.state, "recovery_codes"):
        app.state.recovery_codes = {}

    app.state.recovery_codes[email] = {
        "code": code,
        "expires": datetime.now() + timedelta(minutes=5)
    }

    print(f"🔐 Код восстановления для {email}: {code}")

    return {"success": True, "message": "Код отправлен", "email": email}

@app.post("/api/recovery/verify")
async def recovery_verify(
    email: str = Form(...),
    code: str = Form(...)
):
    """Проверка кода восстановления"""
    code = code.replace('-', '')

    if not hasattr(app.state, "recovery_codes") or email not in app.state.recovery_codes:
        return {"success": False, "message": "Код не найден или истек"}

    recovery_data = app.state.recovery_codes[email]

    if datetime.now() > recovery_data["expires"]:
        del app.state.recovery_codes[email]
        return {"success": False, "message": "Код истек"}

    if recovery_data["code"] != code:
        return {"success": False, "message": "Неверный код"}

    return {"success": True, "email": email}

@app.post("/api/recovery/reset")
async def recovery_reset(
    email: str = Form(...),
    password: str = Form(...),
    db: Session = Depends(get_db)
):
    """Сброс пароля"""
    if len(password) < 8:
        return {"success": False, "message": "Пароль должен быть не менее 8 символов"}

    user = db.query(User).filter(User.email == email).first()
    if not user:
        return {"success": False, "message": "Пользователь не найден"}

    # Обновляем пароль
    user.password_hash = hash_password(password)
    db.commit()

    # Очищаем код восстановления
    if hasattr(app.state, "recovery_codes") and email in app.state.recovery_codes:
        del app.state.recovery_codes[email]

    return {"success": True, "message": "Пароль успешно изменен"}

@app.post("/api/recovery/resend")
async def recovery_resend(email: str = Form(...)):
    """Повторная отправка кода восстановления"""
    if not hasattr(app.state, "recovery_codes") or email not in app.state.recovery_codes:
        return {"success": False, "message": "Сессия истекла"}

    new_code = ''.join(random.choices(string.digits, k=8))
    app.state.recovery_codes[email]["code"] = new_code
    app.state.recovery_codes[email]["expires"] = datetime.now() + timedelta(minutes=5)

    print(f"🔐 Новый код для {email}: {new_code}")

    return {"success": True, "message": "Новый код отправлен"}

# ==================== РЕГИСТРАЦИЯ ====================

@app.post("/api/register/step1")
async def register_step1(
    email: str = Form(...),
    password: str = Form(...),
    phone: str = Form(None),
    db: Session = Depends(get_db)
):
    """Шаг 1: Проверка email и создание временного пользователя"""
    print(f"📝 Регистрация шаг 1 для email: {email}")

    # Валидация email
    if not re.match(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$', email):
        return {"success": False, "message": "Некорректный email"}

    # Проверка пароля
    if len(password) < 8:
        return {"success": False, "message": "Пароль должен быть не менее 8 символов"}
    if not re.search(r'[a-zA-Z]', password):
        return {"success": False, "message": "Пароль должен содержать хотя бы одну букву"}
    if not re.search(r'\d', password):
        return {"success": False, "message": "Пароль должен содержать хотя бы одну цифру"}

    # Проверка телефона (если есть)
    if phone:
        digits = re.sub(r'\D', '', phone)
        if len(digits) != 11 or digits[0] not in ['7', '8']:
            return {"success": False, "message": "Некорректный номер телефона"}

    # Проверка существования пользователя
    existing_user = db.query(User).filter(User.email == email).first()
    if existing_user:
        return {"success": False, "message": "Пользователь с таким email уже существует"}

    # Генерируем код подтверждения
    code = ''.join(random.choices(string.digits, k=8))
    print(f"📧 Код подтверждения для {email}: {code}")

    # Сохраняем во временное хранилище
    if not hasattr(app.state, "temp_users"):
        app.state.temp_users = {}

    app.state.temp_users[email] = {
        "email": email,
        "password_hash": hash_password(password),
        "phone": phone,
        "code": code,
        "code_expires": datetime.now() + timedelta(minutes=5)
    }

    return {"success": True, "email": email, "message": "Код подтверждения отправлен"}

@app.post("/api/register/step2")
async def register_step2(
    email: str = Form(...),
    code: str = Form(...)
):
    """Шаг 2: Проверка кода подтверждения"""
    # Убираем дефисы из кода
    code = code.replace('-', '')

    print(f"📝 Проверка кода для email: {email}, код: {code}")

    if not hasattr(app.state, "temp_users") or email not in app.state.temp_users:
        return {"success": False, "message": "Сессия истекла, начните регистрацию заново"}

    temp_user = app.state.temp_users[email]

    if datetime.now() > temp_user["code_expires"]:
        del app.state.temp_users[email]
        return {"success": False, "message": "Код истек, запросите новый"}

    if temp_user["code"] != code:
        return {"success": False, "message": "Неверный код подтверждения"}

    return {"success": True, "email": email}

@app.post("/api/register/step3")
async def register_step3(
    email: str = Form(...),
    name: str = Form(None),
    surname: str = Form(None),
    patronymic: str = Form(None),
    passport: str = Form(None),
    inn: str = Form(None),
    avatar: UploadFile = File(None),
    db: Session = Depends(get_db)
):
    """Шаг 3: Сохранение личных данных и завершение регистрации"""
    print(f"📝 Регистрация шаг 3 для email: {email}")

    if not hasattr(app.state, "temp_users") or email not in app.state.temp_users:
        return {"success": False, "message": "Сессия истекла, начните регистрацию заново"}

    temp_user = app.state.temp_users[email]

    # Создаем контактную информацию
    contact_info = {}
    if passport:
        contact_info["passport"] = passport
    if inn:
        contact_info["inn"] = inn
    if temp_user.get("phone"):
        contact_info["phone"] = temp_user["phone"]

    # Формируем полное имя
    full_name_parts = []
    if surname:
        full_name_parts.append(surname)
    if name:
        full_name_parts.append(name)
    if patronymic:
        full_name_parts.append(patronymic)

    full_name = " ".join(full_name_parts) if full_name_parts else email.split('@')[0]

    # Создаем нового пользователя
    new_user = User(
        email=email,
        password_hash=temp_user["password_hash"],
        full_name=full_name,
        user_type="tenant",  # По умолчанию арендатор
        contact_info=contact_info,
        is_active=True,
        created_at=datetime.now()
    )

    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    # Если загружена аватарка, сохраняем её
    if avatar and avatar.filename:
        try:
            avatar_url = await save_upload_file(avatar, subdir="avatars")
            new_user.avatar_url = avatar_url
            db.commit()
            print(f"✅ Аватар сохранён: {avatar_url}")
        except Exception as e:
            print(f"❌ Ошибка сохранения аватара: {e}")

    # Очищаем временные данные
    del app.state.temp_users[email]

    return {"success": True, "message": "Регистрация успешно завершена"}

@app.post("/api/register/resend-code")
async def resend_code(email: str = Form(...)):
    """Повторная отправка кода подтверждения"""
    if not hasattr(app.state, "temp_users") or email not in app.state.temp_users:
        return {"success": False, "message": "Сессия истекла"}

    new_code = ''.join(random.choices(string.digits, k=8))
    app.state.temp_users[email]["code"] = new_code
    app.state.temp_users[email]["code_expires"] = datetime.now() + timedelta(minutes=5)

    print(f"📧 Новый код для {email}: {new_code}")

    return {"success": True, "message": "Новый код отправлен"}


@app.delete("/api/user/avatar")
async def delete_avatar(
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db)
):
    if not current_user:
        raise HTTPException(401, "Не авторизован")

    # Удаляем файл, если он существует
    if current_user.avatar_url:
        file_path = BASE_DIR / current_user.avatar_url.lstrip('/')
        if file_path.exists():
            file_path.unlink()

    current_user.avatar_url = None
    db.commit()

    return {"success": True}


@app.put("/api/user/profile")
async def update_user_profile(
    full_name: str = Form(None),
    birth_date: str = Form(None),
    phone: str = Form(None),
    city: str = Form(None),
    passport: str = Form(None),
    inn: str = Form(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    if not current_user:
        raise HTTPException(401, "Не авторизован")

    print("\n" + "="*50)
    print("🔵 ЗАПРОС НА ОБНОВЛЕНИЕ ПРОФИЛЯ")
    print(f"👤 Пользователь: {current_user.email} (ID: {current_user.user_id})")
    print(f"📨 Полученные данные:")
    print(f"   full_name: {full_name}")
    print(f"   birth_date: {birth_date}")
    print(f"   phone: {phone}")
    print(f"   city: {city}")
    print(f"   passport: {passport}")
    print(f"   inn: {inn}")

    # Обновляем обычное поле full_name
    if full_name is not None:
        current_user.full_name = full_name

    # Создаём новый словарь из старых данных (чтобы не потерять существующие поля)
    # Если contact_info был None, создаём пустой словарь
    old_contact = current_user.contact_info or {}
    new_contact = dict(old_contact)  # копируем

    # Обновляем только те поля, которые пришли
    if birth_date is not None:
        new_contact["birth_date"] = birth_date
    if phone is not None:
        new_contact["phone"] = phone
    if city is not None:
        new_contact["city"] = city
    if passport is not None:
        new_contact["passport"] = passport
    if inn is not None:
        new_contact["inn"] = inn

    # Присваиваем целиком – это гарантирует, что SQLAlchemy заметит изменение
    current_user.contact_info = new_contact

    print(f"📦 Старый contact_info: {old_contact}")
    print(f"📦 Новый contact_info: {new_contact}")

    try:
        db.commit()
        print("✅ Изменения сохранены в БД")
        # Принудительно обновляем объект из БД для проверки
        db.refresh(current_user)
        print(f"📊 После refresh contact_info = {current_user.contact_info}")
    except Exception as e:
        print(f"❌ Ошибка при commit: {e}")
        db.rollback()
        raise HTTPException(500, f"Ошибка базы данных: {str(e)}")

    print("="*50 + "\n")
    return {"success": True, "message": "Профиль успешно обновлён"}


# ==================== ВХОД ====================

@app.post("/api/login")
async def login(
        response: Response,
        email: str = Form(...),
        password: str = Form(...),
        db: Session = Depends(get_db)
):
    user = db.query(User).filter(User.email == email).first()

    if not user or not verify_password(password, user.password_hash):
        return JSONResponse(
            status_code=401,
            content={"success": False, "message": "Неверный email или пароль"}
        )

    if not user.is_active:
        return JSONResponse(
            status_code=403,
            content={"success": False, "message": "Аккаунт деактивирован"}
        )

    # Создаем токен
    access_token = create_access_token(data={"sub": user.email, "user_id": user.user_id})

    # Устанавливаем куку с максимальными параметрами безопасности
    response.set_cookie(
        key="access_token",
        value=access_token,
        httponly=True,
        max_age=ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        expires=ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        path="/",
        secure=False,  # Для localhost можно False, для продакшена True
        samesite="lax"
    )

    # Также возвращаем токен в теле ответа для надежности
    return {
        "success": True,
        "message": "Вход выполнен успешно",
        "access_token": access_token,  # Дублируем для надежности
        "user": {
            "id": user.user_id,
            "email": user.email,
            "name": user.full_name,
            "type": user.user_type
        }
    }


# ==================== ВЫХОД ====================

@app.post("/api/logout")
async def logout(response: Response):
    response.delete_cookie("access_token")
    return {"success": True, "message": "Выход выполнен успешно"}


# ==================== АДМИН-ПАНЕЛЬ ====================

@app.get("/api/admin/users")
async def get_users(
        page: int = 1,
        per_page: int = 20,
        search: Optional[str] = None,
        user_type: Optional[str] = None,
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db)
):
    """Список пользователей для администратора"""
    if not current_user or current_user.user_type != 'admin':
        raise HTTPException(status_code=403, detail="Только для администраторов")

    query = db.query(User)

    if search:
        query = query.filter(
            or_(
                User.email.ilike(f"%{search}%"),
                User.full_name.ilike(f"%{search}%")
            )
        )
    if user_type:
        query = query.filter(User.user_type == user_type)

    total = query.count()
    users = query.order_by(User.user_id).offset((page - 1) * per_page).limit(per_page).all()

    return {
        "users": [{
            "id": u.user_id,
            "email": u.email,
            "full_name": u.full_name,
            "user_type": u.user_type,
            "is_active": u.is_active,
            "avatar_url": u.avatar_url,
            "created_at": u.created_at.isoformat() if u.created_at else None
        } for u in users],
        "total": total,
        "page": page,
        "per_page": per_page,
        "total_pages": (total + per_page - 1) // per_page
    }


@app.get("/api/admin/users/{user_id}")
async def get_user_by_id(
        user_id: int,
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db)
):
    """Получить данные пользователя по ID (для админа)"""
    if not current_user or current_user.user_type != 'admin':
        raise HTTPException(status_code=403, detail="Только для администраторов")

    user = db.query(User).filter(User.user_id == user_id).first()
    if not user:
        raise HTTPException(404, "Пользователь не найден")

    return {
        "id": user.user_id,
        "email": user.email,
        "full_name": user.full_name,
        "user_type": user.user_type,
        "is_active": user.is_active,
        "avatar_url": user.avatar_url,
        "contact_info": user.contact_info,
        "created_at": user.created_at.isoformat() if user.created_at else None
    }

@app.patch("/api/admin/users/{user_id}/toggle-block")
async def toggle_user_block(
        user_id: int,
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db)
):
    """Блокировка/разблокировка пользователя"""
    if not current_user or current_user.user_type != 'admin':
        raise HTTPException(status_code=403, detail="Только для администраторов")

    user = db.query(User).filter(User.user_id == user_id).first()
    if not user:
        raise HTTPException(404, "Пользователь не найден")

    user.is_active = not user.is_active
    db.commit()

    # Логируем действие
    log_action(db, current_user.user_id, 'TOGGLE_BLOCK', 'user', user_id,
               {'is_active': user.is_active}, request=None)

    return {"success": True, "is_active": user.is_active}


@app.get("/api/admin/properties")
async def get_all_properties(
        page: int = 1,
        per_page: int = 20,
        search: Optional[str] = None,
        city: Optional[str] = None,
        status: Optional[str] = None,
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db)
):
    """Список всех объектов для администратора"""
    if not current_user or current_user.user_type != 'admin':
        raise HTTPException(status_code=403, detail="Только для администраторов")

    query = db.query(Property).join(User, Property.owner_id == User.user_id)

    if search:
        query = query.filter(
            or_(
                Property.title.ilike(f"%{search}%"),
                Property.address.ilike(f"%{search}%"),
                User.email.ilike(f"%{search}%"),
                User.full_name.ilike(f"%{search}%")
            )
        )
    if city:
        query = query.filter(Property.city.ilike(f"%{city}%"))
    if status:
        query = query.filter(Property.status == status)

    total = query.count()
    properties = query.order_by(Property.property_id.desc()).offset((page - 1) * per_page).limit(per_page).all()

    result = []
    for prop in properties:
        owner = db.query(User).filter(User.user_id == prop.owner_id).first()
        main_photo = db.query(PropertyPhoto).filter(
            PropertyPhoto.property_id == prop.property_id,
            PropertyPhoto.is_main == True
        ).first()

        result.append({
            "property_id": prop.property_id,
            "title": prop.title,
            "address": prop.address,
            "city": prop.city,
            "property_type": prop.property_type,
            "area": float(prop.area) if prop.area else None,
            "rooms": prop.rooms,
            "price": float(prop.price) if prop.price else None,
            "interval_pay": prop.interval_pay,
            "status": prop.status,
            "created_at": prop.created_at.isoformat() if prop.created_at else None,
            "owner": {
                "id": owner.user_id if owner else None,
                "name": owner.full_name if owner else None,
                "email": owner.email if owner else None
            },
            "main_photo": main_photo.url if main_photo else "/resources/placeholder-image.png"
        })

    return {
        "properties": result,
        "total": total,
        "page": page,
        "per_page": per_page,
        "total_pages": (total + per_page - 1) // per_page
    }


@app.delete("/api/admin/properties/{property_id}")
async def admin_delete_property(
        property_id: int,
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db)
):
    """Удаление объекта администратором"""
    if not current_user or current_user.user_type != 'admin':
        raise HTTPException(status_code=403, detail="Только для администраторов")

    prop = db.query(Property).filter(Property.property_id == property_id).first()
    if not prop:
        raise HTTPException(404, "Объект не найден")

    # Логируем действие перед удалением
    log_action(db, current_user.user_id, 'ADMIN_DELETE', 'property', property_id,
               {'title': prop.title, 'owner_id': prop.owner_id}, request=None)

    db.delete(prop)
    db.commit()

    return {"success": True, "message": "Объект удалён"}


@app.patch("/api/admin/properties/{property_id}/status")
async def admin_update_property_status(
        property_id: int,
        status: str = Body(..., embed=True),
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db)
):
    """Изменение статуса объекта администратором"""
    if not current_user or current_user.user_type != 'admin':
        raise HTTPException(status_code=403, detail="Только для администраторов")

    if status not in ['draft', 'active', 'rented', 'archived']:
        raise HTTPException(400, "Недопустимый статус")

    prop = db.query(Property).filter(Property.property_id == property_id).first()
    if not prop:
        raise HTTPException(404, "Объект не найден")

    old_status = prop.status
    prop.status = status
    db.commit()

    log_action(db, current_user.user_id, 'ADMIN_UPDATE_STATUS', 'property', property_id,
               {'old_status': old_status, 'new_status': status}, request=None)

    return {"success": True, "status": status}


@app.get("/api/admin/stats")
async def get_admin_stats(
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db)
):
    """Общая статистика для админ-панели"""
    if not current_user or current_user.user_type != 'admin':
        raise HTTPException(status_code=403, detail="Только для администраторов")

    total_users = db.query(User).count()
    total_properties = db.query(Property).count()
    total_applications = db.query(Application).count()
    total_contracts = db.query(Contract).count()

    active_properties = db.query(Property).filter(Property.status == 'active').count()
    pending_applications = db.query(Application).filter(Application.status == 'pending').count()

    users_by_type = db.query(
        User.user_type,
        func.count(User.user_id).label('count')
    ).group_by(User.user_type).all()

    return {
        "total_users": total_users,
        "total_properties": total_properties,
        "total_applications": total_applications,
        "total_contracts": total_contracts,
        "active_properties": active_properties,
        "pending_applications": pending_applications,
        "users_by_type": [{"type": ut[0], "count": ut[1]} for ut in users_by_type]
    }



# ==================== ПОИСК И ФИЛЬТРАЦИЯ ====================

@app.get("/search", response_class=HTMLResponse)
async def search_properties(
        request: Request,
        search: Optional[str] = None,
        city: Optional[str] = None,
        property_type: Optional[str] = None,
        rooms: Optional[str] = None,
        min_price: Optional[str] = None,  # меняем на str, потом конвертируем
        max_price: Optional[str] = None,
        min_area: Optional[str] = None,
        max_area: Optional[str] = None,
        page: int = 1,
        per_page: int = 12,
        db: Session = Depends(get_db),
        current_user: User = Depends(get_current_user)
):
    try:
        print(f"Параметры поиска: search={search}, city={city}, type={property_type}, rooms={rooms}")

        query = db.query(Property).filter(Property.status == 'active')

        # Конвертируем строки в числа, если они есть
        try:
            min_price_val = float(min_price) if min_price else None
            max_price_val = float(max_price) if max_price else None
            min_area_val = float(min_area) if min_area else None
            max_area_val = float(max_area) if max_area else None
        except ValueError:
            # Если не удалось преобразовать, игнорируем эти фильтры
            min_price_val = max_price_val = min_area_val = max_area_val = None

        if search:
            query = query.filter(
                or_(
                    Property.title.ilike(f"%{search}%"),
                    Property.address.ilike(f"%{search}%"),
                    Property.description.ilike(f"%{search}%")
                )
            )
        if city:
            query = query.filter(Property.city.ilike(f"%{city}%"))
        if property_type and property_type != "all":
            query = query.filter(Property.property_type == property_type)
        if rooms and rooms != "all":
            if rooms == "4":
                query = query.filter(Property.rooms >= 4)
            else:
                try:
                    query = query.filter(Property.rooms == int(rooms))
                except:
                    pass
        if min_price_val is not None:
            query = query.filter(Property.price >= min_price_val)
        if max_price_val is not None:
            query = query.filter(Property.price <= max_price_val)
        if min_area_val is not None:
            query = query.filter(Property.area >= min_area_val)
        if max_area_val is not None:
            query = query.filter(Property.area <= max_area_val)

        total = query.count()
        properties = query.order_by(Property.created_at.desc()).offset((page - 1) * per_page).limit(per_page).all()

        for prop in properties:
            main_photo = db.query(PropertyPhoto).filter(
                PropertyPhoto.property_id == prop.property_id,
                PropertyPhoto.is_main == True
            ).first()
            prop.main_photo_url = main_photo.url if main_photo else "/resources/placeholder-image.png"

        total_pages = (total + per_page - 1) // per_page if per_page > 0 else 1

        return templates.TemplateResponse(
            "index.html",
            {
                "request": request,
                "properties": properties,
                "cities": get_default_cities(),
                "search_text": search,
                "search_city": city,
                "search_type": property_type,
                "search_rooms": rooms,
                "search_min_price": min_price,
                "search_max_price": max_price,
                "search_min_area": min_area,
                "search_max_area": max_area,
                "current_user": current_user,
                "user_initials": get_user_initials(current_user) if current_user else None,
                "page": page,
                "per_page": per_page,
                "total": total,
                "total_pages": total_pages
            }
        )
    except Exception as e:
        print(f"Ошибка поиска: {e}")
        import traceback
        traceback.print_exc()
        # В случае ошибки возвращаем пустой результат
        return templates.TemplateResponse(
            "index.html",
            {
                "request": request,
                "properties": [],
                "cities": get_default_cities(),
                "current_user": current_user,
                "user_initials": get_user_initials(current_user) if current_user else None,
                "page": 1,
                "per_page": per_page,
                "total": 0,
                "total_pages": 1
            }
        )

@app.get("/search", response_class=HTMLResponse)
async def search_properties_get(
        request: Request,
        search: str = None,
        city: str = None,
        property_type: str = None,
        rooms: str = None,
        min_price: float = None,
        max_price: float = None,
        min_area: float = None,
        max_area: float = None,
        db: Session = Depends(get_db),
        current_user: User = Depends(get_current_user)
):
    # Для prefetch просто редиректим на главную
    return RedirectResponse(url="/", status_code=302)


@app.get("/api/cities/search")
async def search_cities_api(query: str = ""):
    all_cities = ["Москва", "Санкт-Петербург", "Новосибирск", "Екатеринбург", "Казань",
                  "Нижний Новгород", "Челябинск", "Самара", "Омск", "Ростов-на-Дону",
                  "Уфа", "Красноярск", "Пермь", "Воронеж", "Волгоград", "Краснодар",
                  "Саратов", "Тюмень", "Тольятти", "Ижевск"]
    if query and len(query) >= 2:
        filtered = [city for city in all_cities if query.lower() in city.lower()]
        return filtered[:10]
    return []


# ==================== ДЕТАЛЬНАЯ ИНФОРМАЦИЯ ОБ ОБЪЕКТЕ ====================

@app.get("/api/property/{property_id}")
async def get_property_api(property_id: int, db: Session = Depends(get_db_with_audit)):

    property_obj = (
        db.query(Property)
        .filter(Property.property_id == property_id)
        .first()
    )

    if not property_obj:
        raise HTTPException(status_code=404, detail="Объект не найден")

    photos = (
        db.query(PropertyPhoto)
        .filter(PropertyPhoto.property_id == property_id)
        .order_by(PropertyPhoto.sequence_number)
        .all()
    )

    owner = (
        db.query(User)
        .filter(User.user_id == property_obj.owner_id)
        .first()
    )

    return {
        "property_id": property_obj.property_id,
        "title": property_obj.title,
        "description": property_obj.description,
        "address": property_obj.address,
        "city": property_obj.city,
        "property_type": property_obj.property_type,
        "area": float(property_obj.area) if property_obj.area else None,
        "rooms": property_obj.rooms,
        "price": float(property_obj.price) if property_obj.price else None,
        "interval_pay": property_obj.interval_pay,
        "status": property_obj.status,

        "photos": [
            {
                "photo_id": photo.photo_id,
                "url": photo.url,
                "is_main": photo.is_main,
                "sequence_number": photo.sequence_number
            }
            for photo in photos
        ],

        "owner": {
            "user_id": owner.user_id,
            "full_name": owner.full_name,
            "email": owner.email,
            "contact_info": owner.contact_info if owner.contact_info else {}
        } if owner else None
    }


# ==================== УПРАВЛЕНИЕ ОБЪЕКТАМИ ====================

@app.get("/api/my/properties")
async def get_my_properties(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if not current_user:
        raise HTTPException(status_code=401, detail="Не авторизован")

    # Владелец или агент видят объекты, где они указаны в owner_id
    if current_user.user_type in ['owner', 'agent']:
        properties = db.query(Property).filter(Property.owner_id == current_user.user_id).all()
    else:
        properties = []

    for prop in properties:
        main_photo = db.query(PropertyPhoto).filter(
            PropertyPhoto.property_id == prop.property_id,
            PropertyPhoto.is_main == True
        ).first()
        prop.main_photo_url = main_photo.url if main_photo else "/resources/placeholder-image.png"

    return properties


@app.post("/api/properties")
async def create_property(
        request: Request,
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db)
):

    if not current_user:
        raise HTTPException(401, "Не авторизован")

    form = await request.form()

    import json

    photo_order = json.loads(form.get("photo_order", "[]"))
    new_photo_tmp_ids = json.loads(form.get("new_photo_tmp_ids", "[]"))

    files = form.getlist("photos")   # ← ВАЖНО

    # ===== создаём объект =====

    prop = Property(
        owner_id=current_user.user_id,
        title=form.get("title"),
        description=form.get("description"),
        address=form.get("address"),
        city=form.get("city"),
        property_type=form.get("property_type"),
        area=float(form.get("area")),
        rooms=int(form.get("rooms") or 0),
        price=float(form.get("price")),
        interval_pay=form.get("interval_pay"),
        status=form.get("status", "draft")
    )

    db.add(prop)
    db.flush()

    property_id = prop.property_id

    # ===== сохраняем все фото =====

    tmp_to_photo_id = {}

    for tmp_id, file in zip(new_photo_tmp_ids, files):

        url = await save_upload_file(
            file,
            subdir=f"properties/{property_id}"
        )

        photo = PropertyPhoto(
            property_id=property_id,
            url=url,
            sequence_number=0,
            is_main=False
        )

        db.add(photo)
        db.flush()

        tmp_to_photo_id[tmp_id] = photo.photo_id

    # ===== reorder =====

    for idx, item in enumerate(photo_order):

        if item["type"] == "new":

            photo_id = tmp_to_photo_id.get(item["id"])

            if not photo_id:
                continue

            photo = db.query(PropertyPhoto).filter(
                PropertyPhoto.photo_id == photo_id
            ).first()

            if photo:

                photo.sequence_number = idx + 1
                photo.is_main = idx == 0

    db.commit()

    return {
        "success": True,
        "property_id": property_id,
        "photo_count": len(files)
    }


@app.put("/api/properties/{property_id}")
async def update_property(
        property_id: int,
        request: Request,
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db)
):

    if not current_user:
        raise HTTPException(401, "Не авторизован")

    prop = db.query(Property).filter(Property.property_id == property_id).first()
    if not prop:
        raise HTTPException(404, "Объект не найден")

    if prop.owner_id != current_user.user_id and current_user.user_type != "admin":
        raise HTTPException(403, "Нет прав")

    try:

        form = await request.form()

        import json

        # =========================
        # ПОЛЯ ОБЪЕКТА
        # =========================

        prop.title = form.get("title")
        prop.description = form.get("description")
        prop.address = form.get("address")
        prop.city = form.get("city")
        prop.property_type = form.get("property_type")

        prop.area = float(form.get("area"))
        prop.rooms = int(form.get("rooms") or 0)
        prop.price = float(form.get("price"))
        prop.interval_pay = form.get("interval_pay")

        prop.status = form.get("status", prop.status)

        # =========================
        # ПАРСИНГ ДАННЫХ ФОТО
        # =========================

        photo_order = json.loads(form.get("photo_order", "[]"))
        deleted_ids = json.loads(form.get("deleted_photos", "[]"))
        new_photo_tmp_ids = json.loads(form.get("new_photo_tmp_ids", "[]"))

        # =========================
        # УДАЛЕНИЕ ФОТО
        # =========================

        for pid in deleted_ids:

            photo = db.query(PropertyPhoto).filter(
                PropertyPhoto.photo_id == pid,
                PropertyPhoto.property_id == property_id
            ).first()

            if photo:

                file_path = BASE_DIR / photo.url.lstrip("/")

                if file_path.exists():
                    file_path.unlink()

                db.delete(photo)

        # =========================
        # СБОР НОВЫХ ФАЙЛОВ
        # =========================

        new_files = form.getlist("photos")

        tmp_id_to_photo_id = {}

        # =========================
        # СОХРАНЕНИЕ НОВЫХ ФОТО
        # =========================

        for tmp_id, file in zip(new_photo_tmp_ids, new_files):

            url = await save_upload_file(
                file,
                subdir=f"properties/{property_id}"
            )

            photo = PropertyPhoto(
                property_id=property_id,
                url=url,
                is_main=False,
                sequence_number=0
            )

            db.add(photo)
            db.flush()

            tmp_id_to_photo_id[tmp_id] = photo.photo_id

        # =========================
        # СБРОС MAIN PHOTO
        # =========================

        db.query(PropertyPhoto).filter(
            PropertyPhoto.property_id == property_id
        ).update({"is_main": False})

        # =========================
        # REORDER ФОТО
        # =========================

        for idx, item in enumerate(photo_order):

            if item["type"] == "existing":
                photo_id = item["id"]

            else:
                photo_id = tmp_id_to_photo_id.get(item["id"])

            if not photo_id:
                continue

            photo = db.query(PropertyPhoto).filter(
                PropertyPhoto.photo_id == photo_id
            ).first()

            if photo:

                photo.sequence_number = idx + 1
                photo.is_main = idx == 0

        db.commit()

        photo_count = db.query(PropertyPhoto).filter(
            PropertyPhoto.property_id == property_id
        ).count()

        return {
            "success": True,
            "photo_count": photo_count
        }

    except Exception as e:

        db.rollback()
        print("❌ Ошибка update_property:", e)

        raise HTTPException(
            status_code=500,
            detail=f"Ошибка сервера: {str(e)}"
        )

@app.delete("/api/properties/{property_id}")
async def delete_property(
    property_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    if not current_user:
        raise HTTPException(401, "Не авторизован")

    prop = db.query(Property).filter(Property.property_id == property_id).first()
    if not prop:
        raise HTTPException(404, "Объект не найден")

    # Проверка прав - только владелец может удалять
    if prop.owner_id != current_user.user_id:
        raise HTTPException(403, "Нет прав на удаление")


    db.delete(prop)
    db.commit()

    return {"success": True}

@app.post("/api/properties/{property_id}/photos")
async def upload_property_photos(
    property_id: int,
    photos: List[UploadFile] = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    print(f"\n📸 ЗАГРУЗКА ФОТО ДЛЯ ОБЪЕКТА ID={property_id}")

    if not current_user:
        raise HTTPException(status_code=401, detail="Не авторизован")

    # Проверяем существование объекта
    property = db.query(Property).filter(Property.property_id == property_id).first()
    if not property:
        raise HTTPException(404, "Объект не найден")

    # Проверка прав
    if property.owner_id != current_user.user_id:
        raise HTTPException(403, "Нет прав на редактирование этого объекта")

    saved_count = 0
    uploaded_urls = []

    # Получаем текущее максимальное значение sequence_number
    max_seq = db.query(func.max(PropertyPhoto.sequence_number)).filter(
        PropertyPhoto.property_id == property_id
    ).scalar() or 0

    for idx, photo in enumerate(photos):
        if photo and photo.filename:
            try:
                print(f"  Обработка фото {idx + 1}: {photo.filename}")
                file_url = await save_upload_file(photo, subdir=f"properties/{property_id}")
                is_main = (max_seq + idx == 0)  # первое фото будет главным, если ещё нет фото

                photo_entry = PropertyPhoto(
                    property_id=property_id,
                    url=file_url,
                    is_main=is_main,
                    sequence_number=max_seq + idx + 1
                )
                db.add(photo_entry)
                saved_count += 1
                uploaded_urls.append(file_url)
                print(f"    ✅ Фото сохранено: {file_url}")
            except Exception as e:
                print(f"    ❌ Ошибка: {e}")

    if saved_count > 0:
        db.commit()
        print(f"✅ Сохранено {saved_count} фотографий в БД")


    return {
        "success": True,
        "uploaded": saved_count,
        "urls": uploaded_urls
    }


@app.delete("/api/properties/{property_id}/photos/{photo_id}")
async def delete_property_photo(
        property_id: int,
        photo_id: int,
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db)
):
    """Удаление фотографии объекта"""
    if not current_user:
        raise HTTPException(401, "Не авторизован")

    # Проверяем существование объекта
    property = db.query(Property).filter(Property.property_id == property_id).first()
    if not property:
        raise HTTPException(404, "Объект не найден")

    # Проверка прав
    if property.owner_id != current_user.user_id and current_user.user_type != 'admin':
        raise HTTPException(403, "Нет прав на редактирование этого объекта")

    # Находим фото
    photo = db.query(PropertyPhoto).filter(
        PropertyPhoto.photo_id == photo_id,
        PropertyPhoto.property_id == property_id
    ).first()

    if not photo:
        raise HTTPException(404, "Фотография не найдена")

    # Удаляем файл
    try:
        file_path = BASE_DIR / photo.url.lstrip('/')
        if file_path.exists():
            file_path.unlink()
    except Exception as e:
        print(f"Ошибка удаления файла: {e}")

    # Удаляем запись из БД
    db.delete(photo)
    db.commit()

    return {"success": True}

@app.get("/api/property/{property_id}/responsible")
async def get_property_responsible(property_id: int, db: Session = Depends(get_db)):
    """Получить информацию об ответственной стороне (собственник или агент)"""
    property = db.query(Property).filter(Property.property_id == property_id).first()
    if not property:
        raise HTTPException(404, "Объект не найден")

    # Получаем владельца (который может быть как собственником, так и агентом)
    owner = db.query(User).filter(User.user_id == property.owner_id).first()
    if not owner:
        raise HTTPException(404, "Ответственная сторона не найдена")

    return {
        "id": owner.user_id,
        "name": owner.full_name,
        "email": owner.email,
        "phone": owner.contact_info.get("phone") if owner.contact_info else None,
        "type": owner.user_type,  # может быть 'owner' или 'agent'
        "avatar": owner.avatar_url
    }

# ==================== УПРАВЛЕНИЕ ЗАЯВКАМИ ====================

@app.get("/api/my/applications")
async def get_my_applications(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if not current_user:
        raise HTTPException(status_code=401, detail="Не авторизован")

    if current_user.user_type == 'tenant':
        # Арендатор видит свои заявки
        applications = db.query(Application).filter(
            Application.tenant_id == current_user.user_id
        ).all()

    elif current_user.user_type == 'owner':
        # Собственник видит заявки на свои объекты
        applications = db.query(Application).join(
            Property, Application.property_id == Property.property_id
        ).filter(
            Property.owner_id == current_user.user_id
        ).all()

    elif current_user.user_type == 'agent':
        # Агент видит заявки на объекты, которые он ведёт
        applications = db.query(Application).join(
            Property, Application.property_id == Property.property_id
        ).filter(
            Property.owner_id == current_user.user_id
        ).all()
    else:
        applications = []

    result = []
    for app in applications:
        property = db.query(Property).filter(Property.property_id == app.property_id).first()
        tenant = db.query(User).filter(User.user_id == app.tenant_id).first()

        # Получаем главное фото
        main_photo = db.query(PropertyPhoto).filter(
            PropertyPhoto.property_id == app.property_id,
            PropertyPhoto.is_main == True
        ).first()

        # Определяем, кто ответственный за объект (для отображения)
        responsible_party = None
        if property.owner_id:
            owner = db.query(User).filter(User.user_id == property.owner_id).first()
            responsible_party = {
                "id": owner.user_id,
                "name": owner.full_name,
                "type": "owner"
            }
        elif property.agent_id:
            agent = db.query(User).filter(User.user_id == property.agent_id).first()
            responsible_party = {
                "id": agent.user_id,
                "name": agent.full_name,
                "type": "agent"
            }

        result.append({
            "application_id": app.application_id,
            "property_id": app.property_id,
            "property_title": property.title if property else None,
            "property_address": property.address if property else None,
            "property_photo": main_photo.url if main_photo else None,
            "price": float(property.price) if property and property.price else 0,
            "interval_pay": property.interval_pay if property else None,
            "tenant_name": tenant.full_name if tenant else None,
            "tenant_email": tenant.email if tenant else None,
            "desired_date": app.desired_date.isoformat() if app.desired_date else None,
            "duration_days": app.duration_days,
            "message": app.message,
            "answer": app.answer,
            "status": app.status,
            "created_at": app.created_at.isoformat() if app.created_at else None,
            "responded_at": app.responded_at.isoformat() if app.responded_at else None,
            "responsible_party": responsible_party  # Кто отвечает за объект
        })

    return result


@app.post("/api/applications")
async def create_application(app_data: ApplicationCreate, current_user: User = Depends(get_current_user),
                             db: Session = Depends(get_db)):
    if not current_user:
        raise HTTPException(status_code=401, detail="Не авторизован")

    # Только арендаторы могут создавать заявки
    if current_user.user_type != 'tenant':
        raise HTTPException(403, "Только арендаторы могут создавать заявки")

    # Проверяем, что объект существует и активен
    property = db.query(Property).filter(
        Property.property_id == app_data.property_id,
        Property.status == 'active'  # Только активные объекты
    ).first()
    if not property:
        raise HTTPException(400, "Объект недоступен для аренды")

    # Проверяем, нет ли уже активной заявки от этого арендатора на этот объект
    existing_app = db.query(Application).filter(
        Application.property_id == app_data.property_id,
        Application.tenant_id == current_user.user_id,
        Application.status.in_(['pending', 'approved'])
    ).first()
    if existing_app:
        raise HTTPException(400, "У вас уже есть активная заявка на этот объект")

    try:
        desired_date = datetime.strptime(app_data.desired_date, "%Y-%m-%d").date()
    except:
        raise HTTPException(400, "Неверный формат даты")

    new_app = Application(
        property_id=app_data.property_id,
        tenant_id=current_user.user_id,
        desired_date=desired_date,
        duration_days=app_data.duration_days,
        message=app_data.message,
        status='pending',
        created_at=datetime.now()
    )
    db.add(new_app)
    db.commit()
    db.refresh(new_app)


    return {"success": True, "application_id": new_app.application_id}


@app.get("/api/applications/{app_id}")
async def get_application(app_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if not current_user:
        raise HTTPException(status_code=401, detail="Не авторизован")

    app = db.query(Application).filter(Application.application_id == app_id).first()
    if not app:
        raise HTTPException(404, "Заявка не найдена")

    property = db.query(Property).filter(Property.property_id == app.property_id).first()

    # Проверка доступа
    if not (app.tenant_id == current_user.user_id or
            property.owner_id == current_user.user_id or
            property.agent_id == current_user.user_id):
        raise HTTPException(403, "Нет доступа")

    tenant = db.query(User).filter(User.user_id == app.tenant_id).first()

    # Получаем главное фото
    main_photo = db.query(PropertyPhoto).filter(
        PropertyPhoto.property_id == app.property_id,
        PropertyPhoto.is_main == True
    ).first()

    return {
        "application_id": app.application_id,
        "property_id": app.property_id,
        "property_title": property.title if property else None,
        "property_address": property.address if property else None,
        "property_city": property.city if property else None,
        "property_photo": main_photo.url if main_photo else None,
        "price": float(property.price) if property and property.price else 0,  # ДОБАВЛЕНО
        "interval_pay": property.interval_pay if property else None,  # ДОБАВЛЕНО
        "tenant_name": tenant.full_name if tenant else None,
        "tenant_email": tenant.email if tenant else None,
        "desired_date": app.desired_date.isoformat() if app.desired_date else None,
        "duration_days": app.duration_days,
        "message": app.message,
        "answer": app.answer,
        "status": app.status,
        "created_at": app.created_at.isoformat() if app.created_at else None
    }


@app.post("/api/applications/{app_id}/cancel")
async def cancel_application(app_id: int, current_user: User = Depends(get_current_user),
                             db: Session = Depends(get_db)):
    if not current_user:
        raise HTTPException(status_code=401, detail="Не авторизован")
    app = db.query(Application).filter(
        Application.application_id == app_id,
        Application.tenant_id == current_user.user_id
    ).first()
    if not app:
        raise HTTPException(404, "Заявка не найдена")
    if app.status not in ['pending', 'approved']:
        raise HTTPException(400, "Заявку нельзя отменить")
    app.status = 'cancelled'
    db.commit()
    return {"success": True}


@app.post("/api/applications/{app_id}/respond")
async def respond_application(
        app_id: int,
        status: str = Form(...),
        answer: str = Form(None),
        duration_days: Optional[int] = Form(None),
        desired_date: Optional[str] = Form(None),
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db)
):
    if not current_user:
        raise HTTPException(status_code=401, detail="Не авторизован")

    if current_user.user_type not in ['owner', 'agent']:
        raise HTTPException(403, "Только собственники и агенты могут отвечать на заявки")

    app = db.query(Application).filter(Application.application_id == app_id).first()
    if not app:
        raise HTTPException(404, "Заявка не найдена")

    property = db.query(Property).filter(Property.property_id == app.property_id).first()
    if not property:
        raise HTTPException(404, "Объект не найден")

    # Проверка прав
    if property.owner_id != current_user.user_id:
        raise HTTPException(403, "У вас нет прав для ответа на эту заявку")

    if app.status != 'pending':
        raise HTTPException(400, f"Нельзя ответить на заявку в статусе {app.status}")

    # Обновляем заявку
    app.status = status
    app.answer = answer
    app.responded_at = datetime.now()

    if duration_days is not None and duration_days > 0:
        app.duration_days = duration_days

    if desired_date:
        try:
            app.desired_date = datetime.strptime(desired_date, "%Y-%m-%d").date()
        except:
            pass

    db.commit()

    # Создаём уведомление арендатору
    notification_content = f"**Заявка {status}** на объект '{property.title}'. "
    if answer:
        notification_content += f"Ответ: {answer}"

    notification = Message(
        from_user_id=None,  # системное
        to_user_id=app.tenant_id,
        content=notification_content,
        is_read=False,
        created_at=datetime.now()
    )
    db.add(notification)
    db.commit()

    return {"success": True}

# ==================== УПРАВЛЕНИЕ ДОГОВОРАМИ ====================

@app.post("/api/applications/{app_id}/create-contract")
async def create_contract(app_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if not current_user:
        raise HTTPException(status_code=401, detail="Не авторизован")
    if current_user.user_type not in ['owner', 'agent']:
        raise HTTPException(403, "Только собственники и агенты могут создавать договоры")
    app = db.query(Application).filter(Application.application_id == app_id).first()
    if not app or app.status != 'approved':
        raise HTTPException(400, "Заявка не одобрена")
    existing = db.query(Contract).filter(Contract.application_id == app_id).first()
    if existing:
        raise HTTPException(400, "Договор уже существует")
    months = max(1, app.duration_days // 30)
    total = float(app.property.price) * months
    year = datetime.now().year
    contract_count = db.query(Contract).filter(
        func.extract('year', Contract.created_at) == year
    ).count()
    contract_number = f"Д-{year}-{contract_count + 1:06d}"
    contract = Contract(
        application_id=app_id,
        property_id=app.property_id,
        tenant_id=app.tenant_id,
        owner_id=app.property.owner_id,
        contract_type='lease',
        start_date=app.desired_date,
        end_date=app.desired_date + timedelta(days=app.duration_days),
        total_amount=total,
        signing_status='draft',
        contract_number=contract_number
    )
    db.add(contract)
    db.commit()
    db.refresh(contract)
    return {"success": True, "contract_id": contract.contract_id}


@app.get("/api/my/contracts")
async def get_my_contracts(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Получить договоры для текущего пользователя (все)"""
    if not current_user:
        raise HTTPException(status_code=401, detail="Не авторизован")

    # Базовый запрос с JOIN
    query = db.query(
        Contract, Application, Property, PropertyPhoto
    ).join(
        Application, Contract.application_id == Application.application_id
    ).join(
        Property, Application.property_id == Property.property_id
    ).outerjoin(
        PropertyPhoto, (PropertyPhoto.property_id == Property.property_id) & (PropertyPhoto.is_main == True)
    )

    results = query.all()

    result = []
    for contract, app, property, photo in results:
        # Определяем, является ли текущий пользователь стороной договора
        is_tenant = (app.tenant_id == current_user.user_id)
        is_owner = (property.owner_id == current_user.user_id)

        if not (is_tenant or is_owner):
            continue  # Пропускаем, если пользователь не имеет отношения к договору

        contract_number = f"Д-{contract.contract_id:06d}"

        result.append({
            "contract_id": contract.contract_id,
            "contract_number": contract_number,
            "property_id": property.property_id,
            "property_title": property.title if property else None,
            "property_address": property.address if property else None,
            "property_photo": photo.url if photo else "/resources/placeholder-image.png",
            "start_date": contract.start_date.isoformat() if contract.start_date else None,
            "end_date": contract.end_date.isoformat() if contract.end_date else None,
            "total_amount": float(contract.total_amount) if contract.total_amount else 0,
            "signing_status": contract.signing_status,
            "tenant_signed": contract.tenant_signed,
            "owner_signed": contract.owner_signed,
            "created_at": contract.created_at.isoformat() if contract.created_at else None,
            "is_tenant": is_tenant,  # флаг для фронтенда
            "is_owner": is_owner
        })

    return result


@app.get("/api/contracts/{contract_id}")
async def get_contract(contract_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if not current_user:
        raise HTTPException(status_code=401, detail="Не авторизован")

    # Получаем договор
    contract = db.query(Contract).filter(Contract.contract_id == contract_id).first()
    if not contract:
        raise HTTPException(404, "Договор не найден")

    # Получаем связанную заявку
    app = db.query(Application).filter(Application.application_id == contract.application_id).first()
    if not app:
        raise HTTPException(404, "Связанная заявка не найдена")

    # Получаем объект недвижимости через заявку
    property = db.query(Property).filter(Property.property_id == app.property_id).first()
    if not property:
        raise HTTPException(404, "Объект недвижимости не найден")

    # Получаем пользователей
    tenant = db.query(User).filter(User.user_id == app.tenant_id).first()
    owner = db.query(User).filter(User.user_id == property.owner_id).first()

    # Проверка доступа
    has_access = False
    if current_user.user_type == 'tenant':
        has_access = (app.tenant_id == current_user.user_id)
    elif current_user.user_type in ['owner', 'agent']:
        has_access = (property.owner_id == current_user.user_id)

    if not has_access:
        raise HTTPException(403, "Нет доступа к договору")

    # Получаем главное фото
    main_photo = db.query(PropertyPhoto).filter(
        PropertyPhoto.property_id == property.property_id,
        PropertyPhoto.is_main == True
    ).first()

    # Генерируем номер из ID
    contract_number = f"Д-{contract.contract_id:06d}"

    return {
        "contract_id": contract.contract_id,
        "contract_number": contract_number,
        "property_id": property.property_id,
        "property_title": property.title if property else None,
        "property_address": property.address if property else None,
        "property_city": property.city if property else None,
        "property_type": property.property_type if property else None,
        "property_rooms": property.rooms if property else None,
        "property_area": float(property.area) if property and property.area else None,
        "property_photo": main_photo.url if main_photo else None,
        "start_date": contract.start_date.isoformat() if contract.start_date else None,
        "end_date": contract.end_date.isoformat() if contract.end_date else None,
        "total_amount": float(contract.total_amount) if contract.total_amount else 0,
        "signing_status": contract.signing_status,
        "tenant_id": app.tenant_id,
        "tenant_name": tenant.full_name if tenant else None,
        "tenant_email": tenant.email if tenant else None,
        "owner_id": property.owner_id,
        "owner_name": owner.full_name if owner else None,
        "owner_email": owner.email if owner else None,
        "tenant_signed": contract.tenant_signed,
        "owner_signed": contract.owner_signed,
        "created_at": contract.created_at.isoformat() if contract.created_at else None
    }

@app.post("/api/contracts/{contract_id}/sign")
async def sign_contract(contract_id: int, current_user: User = Depends(get_current_user),
                        db: Session = Depends(get_db)):
    if not current_user:
        raise HTTPException(status_code=401, detail="Не авторизован")

    contract = db.query(Contract).filter(Contract.contract_id == contract_id).first()
    if not contract:
        raise HTTPException(404, "Договор не найден")

    app = contract.application
    if not app:
        raise HTTPException(404, "Связанная заявка не найдена")

    property = app.property
    if not property:
        raise HTTPException(404, "Объект недвижимости не найден")

    # Определяем, кто подписывает
    if current_user.user_id == app.tenant_id:
        if contract.tenant_signed:
            raise HTTPException(400, "Вы уже подписали этот договор")
        contract.tenant_signed = True
        # Если есть поле с датой подписания
    elif current_user.user_id == property.owner_id:
        if contract.owner_signed:
            raise HTTPException(400, "Вы уже подписали этот договор")
        contract.owner_signed = True
    else:
        raise HTTPException(403, "Вы не являетесь стороной договора")

    db.commit()


    return {"success": True}

@app.post("/api/contracts/{contract_id}/cancel")
async def cancel_contract(
    contract_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    if not current_user:
        raise HTTPException(status_code=401, detail="Не авторизован")

    contract = db.query(Contract).filter(Contract.contract_id == contract_id).first()
    if not contract:
        raise HTTPException(404, "Договор не найден")

    app = db.query(Application).filter(Application.application_id == contract.application_id).first()
    if not app:
        raise HTTPException(404, "Связанная заявка не найдена")

    property = db.query(Property).filter(Property.property_id == app.property_id).first()
    if not property:
        raise HTTPException(404, "Объект не найден")

    # Проверка прав (только собственник или агент могут отменить)
    if property.owner_id != current_user.user_id:
        raise HTTPException(403, "Только собственник может отменить договор")

    if contract.signing_status == 'cancelled':
        raise HTTPException(400, "Договор уже отменён")

    contract.signing_status = 'cancelled'
    db.commit()

    # Создаём уведомление арендатору
    notification = Message(
        from_user_id=None,
        to_user_id=app.tenant_id,
        content=f"**Договор отменён** на объект '{property.title}'. Договор №{contract.contract_id}",
        is_read=False,
        created_at=datetime.now()
    )
    db.add(notification)
    db.commit()

    return {"success": True}

# ==================== СООБЩЕНИЯ ====================

@app.get("/api/my/dialogs")
async def get_dialogs(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if not current_user:
        raise HTTPException(status_code=401, detail="Не авторизован")

    # Получаем всех пользователей, с которыми был диалог (только личные сообщения)
    sent = db.query(Message.to_user_id).filter(
        Message.from_user_id == current_user.user_id,
        Message.from_user_id.isnot(None)  # Только личные сообщения
    ).distinct().all()

    received = db.query(Message.from_user_id).filter(
        Message.to_user_id == current_user.user_id,
        Message.from_user_id.isnot(None)  # Только личные сообщения
    ).distinct().all()

    # Объединяем ID собеседников
    user_ids = set()
    for r in sent:
        if r[0] is not None:
            user_ids.add(r[0])
    for r in received:
        if r[0] is not None:
            user_ids.add(r[0])

    dialogs = []
    for uid in user_ids:
        # Получаем последнее сообщение в диалоге (только личные)
        last_msg = db.query(Message).filter(
            ((Message.from_user_id == current_user.user_id) & (Message.to_user_id == uid)) |
            ((Message.from_user_id == uid) & (Message.to_user_id == current_user.user_id)),
            Message.from_user_id.isnot(None)  # Только личные сообщения
        ).order_by(Message.created_at.desc()).first()

        if last_msg:
            other_user = db.query(User).filter(User.user_id == uid).first()
            if other_user:
                # Считаем непрочитанные сообщения (только личные)
                unread_count = db.query(Message).filter(
                    Message.from_user_id == uid,
                    Message.to_user_id == current_user.user_id,
                    Message.is_read == False,
                    Message.from_user_id.isnot(None)  # Только личные сообщения
                ).count()

                dialogs.append({
                    "user_id": uid,
                    "user_name": other_user.full_name if other_user else "Пользователь",
                    "user_initials": get_user_initials(other_user) if other_user else "??",
                    "avatar_url": other_user.avatar_url if other_user else None,
                    "last_message": last_msg.content[:50] + "..." if len(last_msg.content) > 50 else last_msg.content,
                    "last_time": last_msg.created_at.isoformat() if last_msg.created_at else None,
                    "unread": unread_count
                })

    # Сортируем по времени последнего сообщения (сначала новые)
    dialogs.sort(key=lambda x: x.get("last_time") or "", reverse=True)

    return dialogs


@app.get("/api/user/{user_id}/status")
async def get_user_status(user_id: int, current_user: User = Depends(get_current_user)):
    """Получить онлайн-статус пользователя"""
    if not current_user:
        raise HTTPException(status_code=401, detail="Не авторизован")

    is_online = user_id in manager.online_users

    return {
        "user_id": user_id,
        "is_online": is_online
    }

@app.get("/api/user/profile")
async def get_user_profile(current_user: User = Depends(get_current_user)):
    if not current_user:
        raise HTTPException(status_code=401, detail="Не авторизован")

    # Убеждаемся, что contact_info - словарь
    contact_info = current_user.contact_info
    if contact_info is None:
        contact_info = {}
    elif isinstance(contact_info, str):
        # Если вдруг строка - парсим
        try:
            import json
            contact_info = json.loads(contact_info)
        except:
            contact_info = {}

    print(f"📤 Отправка профиля пользователя {current_user.email}")
    print(f"   contact_info: {contact_info}")

    return {
        "id": current_user.user_id,
        "email": current_user.email,
        "full_name": current_user.full_name,
        "user_type": current_user.user_type,
        "avatar_url": current_user.avatar_url,
        "contact_info": contact_info,
        "created_at": current_user.created_at.isoformat() if current_user.created_at else None
    }


@app.get("/api/user/{user_id}")
async def get_user_info(user_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if not current_user:
        raise HTTPException(status_code=401, detail="Не авторизован")
    user = db.query(User).filter(User.user_id == user_id).first()
    if not user:
        raise HTTPException(404, "Пользователь не найден")

    # Упрощённая проверка онлайн-статуса
    five_minutes_ago = datetime.now() - timedelta(minutes=5)
    recent_activity = db.query(Message).filter(
        (Message.from_user_id == user_id) & (Message.created_at >= five_minutes_ago)
    ).first()
    is_online = recent_activity is not None

    return {
        "user_id": user.user_id,
        "full_name": user.full_name,
        "email": user.email,
        "avatar_url": user.avatar_url,
        "user_type": user.user_type,
        "is_online": is_online,
        "last_seen": None
    }


@app.get("/api/messages")
async def get_messages(chat_with: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if not current_user:
        raise HTTPException(status_code=401, detail="Не авторизован")

    # Получаем только личные сообщения (from_user_id IS NOT NULL)
    messages = db.query(Message).filter(
        ((Message.from_user_id == current_user.user_id) & (Message.to_user_id == chat_with)) |
        ((Message.from_user_id == chat_with) & (Message.to_user_id == current_user.user_id)),
        Message.from_user_id.isnot(None)  # Только личные сообщения
    ).order_by(Message.created_at).all()

    # Помечаем сообщения как прочитанные
    for msg in messages:
        if msg.to_user_id == current_user.user_id and not msg.is_read:
            msg.is_read = True
    db.commit()

    other_user = db.query(User).filter(User.user_id == chat_with).first()

    return {
        "messages": [
            {
                "id": msg.message_id,
                "from_user_id": msg.from_user_id,
                "to_user_id": msg.to_user_id,
                "content": msg.content,
                "created_at": msg.created_at.isoformat() if msg.created_at else None,
                "is_read": msg.is_read,
                "is_mine": msg.from_user_id == current_user.user_id
            }
            for msg in messages
        ],
        "other_user": {
            "id": other_user.user_id if other_user else None,
            "name": other_user.full_name if other_user else None,
            "initials": get_user_initials(other_user) if other_user else None
        }
    }


@app.post("/api/messages")
async def send_message(msg: MessageCreate, current_user: User = Depends(get_current_user),
                       db: Session = Depends(get_db)):
    if not current_user:
        raise HTTPException(status_code=401, detail="Не авторизован")
    new_msg = Message(
        from_user_id=current_user.user_id,
        to_user_id=msg.to_user_id,
        content=msg.content
    )
    db.add(new_msg)
    db.commit()
    return {"success": True, "message_id": new_msg.message_id}


@app.delete("/api/dialogs/{user_id}")
async def delete_dialog(user_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Удалить диалог с пользователем (только личные сообщения)"""
    if not current_user:
        raise HTTPException(status_code=401, detail="Не авторизован")

    # Проверяем, есть ли сообщения с этим пользователем (только личные)
    messages = db.query(Message).filter(
        ((Message.from_user_id == current_user.user_id) & (Message.to_user_id == user_id)) |
        ((Message.from_user_id == user_id) & (Message.to_user_id == current_user.user_id)),
        Message.from_user_id.isnot(None)  # Только личные сообщения
    ).all()

    if not messages:
        return {"success": True, "message": "Диалог пуст"}

    # Удаляем все сообщения между пользователями
    for msg in messages:
        db.delete(msg)

    db.commit()

    return {"success": True, "message": "Диалог удалён"}

# ==================== ПРОФИЛЬ ПОЛЬЗОВАТЕЛЯ ====================




@app.post("/api/user/avatar")
async def upload_avatar(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    if not current_user:
        raise HTTPException(401, "Не авторизован")
    if not file.content_type.startswith('image/'):
        raise HTTPException(400, "Файл должен быть изображением")
    file_url = await save_upload_file(file, subdir="avatars")
    current_user.avatar_url = file_url
    db.commit()
    return {"url": file_url}


@app.put("/api/user/profile")
async def update_user_profile(
        full_name: str = Form(None),
        birth_date: str = Form(None),
        phone: str = Form(None),
        city: str = Form(None),
        passport: str = Form(None),
        inn: str = Form(None),
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db)
):
    if not current_user:
        raise HTTPException(401, "Не авторизован")

    if full_name is not None:
        current_user.full_name = full_name

    # Инициализируем contact_info если его нет
    if not current_user.contact_info:
        current_user.contact_info = {}
    elif isinstance(current_user.contact_info, dict):
        # Если это словарь - работаем с ним
        pass
    else:
        # Если это строка или что-то ещё - конвертируем
        try:
            import json
            current_user.contact_info = json.loads(current_user.contact_info)
        except:
            current_user.contact_info = {}

    # Обновляем только те поля, которые пришли в запросе
    if birth_date is not None:
        current_user.contact_info["birth_date"] = birth_date
    if phone is not None:
        current_user.contact_info["phone"] = phone
    if city is not None:
        current_user.contact_info["city"] = city
    if passport is not None:
        current_user.contact_info["passport"] = passport
    if inn is not None:
        current_user.contact_info["inn"] = inn

    print(f"📝 Обновление профиля пользователя {current_user.email}")
    print(f"   contact_info после обновления: {current_user.contact_info}")

    flag_modified(current_user, "contact_info")

    db.commit()

    return {"success": True, "message": "Профиль успешно обновлён"}


# ==================== СТАТИСТИКА ДЛЯ АГЕНТА ====================

@app.get("/api/agent/stats")
async def agent_stats(
        months: int = 6,
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db)
):
    """Ежемесячная статистика агента"""
    if not current_user or current_user.user_type != 'agent':
        raise HTTPException(status_code=403, detail="Только для агентов")

    try:
        print(f"Запрос статистики для агента {current_user.user_id} за {months} месяцев")
        result = db.execute(
            text("SELECT * FROM get_agent_monthly_stats(:aid, :months)"),
            {"aid": current_user.user_id, "months": months}
        ).fetchall()

        return [dict(r._mapping) for r in result]
    except Exception as e:
        print(f"Ошибка статистики: {e}")
        return []


@app.get("/api/agent/performance")
async def agent_performance(
        months: int = 6,
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db)
):
    """KPI агента"""
    if not current_user or current_user.user_type != 'agent':
        raise HTTPException(status_code=403, detail="Только для агентов")

    try:
        print(f"Запрос KPI для агента {current_user.user_id} за {months} месяцев")
        result = db.execute(
            text("SELECT * FROM get_agent_performance_stats(:aid, :months)"),
            {"aid": current_user.user_id, "months": months}
        ).first()

        if not result:
            return {}
        return dict(result._mapping)
    except Exception as e:
        print(f"Ошибка KPI: {e}")
        return {}

@app.get("/api/agent/rejection-reasons")
async def agent_rejection_stats(
    days: int = Query(90, description="Количество дней для анализа"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Статистика по статусам заявок для круговой диаграммы"""
    if not current_user or current_user.user_type != 'agent':
        raise HTTPException(status_code=403, detail="Только для агентов")

    try:
        print(f"Запрос статусов за {days} дней для агента {current_user.user_id}")
        result = db.execute(
            text("SELECT * FROM get_agent_application_status_stats(:aid, :days)"),
            {"aid": current_user.user_id, "days": days}
        ).fetchall()

        return [dict(r._mapping) for r in result]
    except Exception as e:
        print(f"Ошибка загрузки статусов: {e}")
        return []

@app.get("/api/agent/rejection-reasons")
async def rejection_reasons(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    if not current_user or current_user.user_type != 'agent':
        raise HTTPException(status_code=403, detail="Только для агентов")

    ninety_days_ago = datetime.now() - timedelta(days=90)

    # Статистика по статусам заявок
    status_counts = db.query(
        Application.status,
        func.count(Application.application_id).label('count')
    ).join(Property, Application.property_id == Property.property_id).filter(
        Property.owner_id == current_user.user_id,
        Application.created_at >= ninety_days_ago
    ).group_by(Application.status).all()

    return [{"status": r.status, "count": r.count} for r in status_counts]

# ==================== АУДИТ ЛОГ ====================

@app.get("/api/admin/audit-logs")
async def get_audit_logs(
        request: Request,
        page: int = 1,
        per_page: int = 50,
        user_id: Optional[int] = None,
        action: Optional[str] = None,
        entity_type: Optional[str] = None,
        date_from: Optional[str] = None,
        date_to: Optional[str] = None,
        search: Optional[str] = None,
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db_with_audit)
):
    """Получить аудит логи с фильтрацией (только для admin)"""
    if not current_user or current_user.user_type != 'admin':
        raise HTTPException(status_code=403, detail="Только для администраторов")

    # Базовый запрос
    query = db.query(AuditLog).join(User, AuditLog.user_id == User.user_id, isouter=True)

    # Фильтры
    if user_id:
        query = query.filter(AuditLog.user_id == user_id)

    if action:
        query = query.filter(AuditLog.action == action)

    if entity_type:
        query = query.filter(AuditLog.entity_type == entity_type)

    if date_from:
        try:
            date_from_obj = datetime.strptime(date_from, "%Y-%m-%d")
            query = query.filter(AuditLog.created_at >= date_from_obj)
        except:
            pass

    if date_to:
        try:
            date_to_obj = datetime.strptime(date_to, "%Y-%m-%d") + timedelta(days=1)
            query = query.filter(AuditLog.created_at <= date_to_obj)
        except:
            pass

    if search:
        query = query.filter(
            or_(
                AuditLog.action.ilike(f"%{search}%"),
                AuditLog.entity_type.ilike(f"%{search}%"),
                User.email.ilike(f"%{search}%"),
                User.full_name.ilike(f"%{search}%")
            )
        )

    # Пагинация
    total = query.count()
    logs = query.order_by(AuditLog.created_at.desc()).offset((page - 1) * per_page).limit(per_page).all()

    # Формируем результат
    result = []
    for log in logs:
        # Получаем название объекта для entity_id
        entity_name = get_entity_name(db, log.entity_type, log.entity_id)

        # Форматируем действие
        action_display = get_action_display(log.action)

        # Форматируем тип объекта
        entity_type_display = get_entity_type_display(log.entity_type)

        # Форматируем изменения для отображения
        changes = format_changes_for_display(log.details)

        # Получаем IP из details если есть
        ip_address = log.details.get('ip_address') if log.details else None

        result.append({
            "log_id": log.log_id,
            "user_id": log.user_id,
            "user_email": log.user.email if log.user else "Система",
            "user_name": log.user.full_name if log.user else "Система",
            "action": log.action,
            "action_display": action_display,
            "entity_type": log.entity_type,
            "entity_type_display": entity_type_display,
            "entity_id": log.entity_id,
            "entity_name": entity_name,
            "changes": changes,
            "ip_address": ip_address or "Неизвестно",
            "created_at": log.created_at.isoformat() if log.created_at else None,
            "details": log.details
        })

    return {
        "logs": result,
        "total": total,
        "page": page,
        "per_page": per_page,
        "total_pages": (total + per_page - 1) // per_page
    }


# Вспомогательные функции для форматирования

def get_action_display(action: str) -> str:
    """Возвращает человеко-читаемое название действия"""
    actions_map = {
        'INSERT': '➕ Добавление',
        'UPDATE': '✏️ Изменение',
        'DELETE': '🗑️ Удаление',
        'TOGGLE_BLOCK': '🔒 Блокировка/Разблокировка',
        'ADMIN_DELETE': '🗑️ Удаление (админ)',
        'ADMIN_UPDATE_STATUS': '🔄 Изменение статуса',
        'SIGN': '✍️ Подписание',
        'LOGIN': '🔑 Вход',
        'LOGOUT': '🚪 Выход',
        'REGISTER': '📝 Регистрация'
    }
    return actions_map.get(action, action)


def get_entity_type_display(entity_type: str) -> str:
    """Возвращает человеко-читаемое название типа объекта"""
    types_map = {
        'applications': '📋 Заявка',
        'properties': '🏠 Объект',
        'contracts': '📄 Договор',
        'users': '👤 Пользователь',
        'messages': '💬 Сообщение',
        'audit_logs': '📊 Аудит-лог'
    }
    return types_map.get(entity_type, entity_type)


def get_entity_name(db: Session, entity_type: str, entity_id: Optional[int]) -> str:
    """Получает название/заголовок объекта по его ID"""
    if not entity_id:
        return ""

    try:
        if entity_type == 'applications':
            app = db.query(Application).filter(Application.application_id == entity_id).first()
            if app:
                property = db.query(Property).filter(Property.property_id == app.property_id).first()
                return f"Заявка #{entity_id} на '{property.title if property else 'объект'}'"

        elif entity_type == 'properties':
            prop = db.query(Property).filter(Property.property_id == entity_id).first()
            return prop.title if prop else f"Объект #{entity_id}"

        elif entity_type == 'contracts':
            contract = db.query(Contract).filter(Contract.contract_id == entity_id).first()
            if contract:
                return f"Договор #{contract.contract_id}"
            return f"Договор #{entity_id}"

        elif entity_type == 'users':
            user = db.query(User).filter(User.user_id == entity_id).first()
            return user.full_name if user else f"Пользователь #{entity_id}"

        elif entity_type == 'messages':
            return f"Сообщение #{entity_id}"

    except Exception as e:
        print(f"Ошибка получения имени объекта: {e}")

    return ""


def format_changes_for_display(details: Optional[dict]) -> str:
    """Форматирует изменения для отображения"""
    if not details:
        return "—"

    changes = details.get('changes')
    if not changes:
        return "—"

    changes_list = []
    for field, values in changes.items():
        if isinstance(values, dict):
            old_val = values.get('old', '')
            new_val = values.get('new', '')

            # Форматируем названия полей
            field_display = get_field_display(field)

            # Сокращаем длинные значения
            old_str = str(old_val)[:50] + "..." if len(str(old_val)) > 50 else str(old_val)
            new_str = str(new_val)[:50] + "..." if len(str(new_val)) > 50 else str(new_val)

            if old_str and new_str:
                changes_list.append(f"{field_display}: {old_str} → {new_str}")
            elif new_str:
                changes_list.append(f"{field_display}: {new_str}")

    return ", ".join(changes_list) if changes_list else "—"


def get_field_display(field: str) -> str:
    """Возвращает человеко-читаемое название поля"""
    fields_map = {
        'title': 'Название',
        'description': 'Описание',
        'address': 'Адрес',
        'city': 'Город',
        'price': 'Цена',
        'area': 'Площадь',
        'rooms': 'Комнаты',
        'status': 'Статус',
        'user_type': 'Тип пользователя',
        'full_name': 'Имя',
        'email': 'Email',
        'phone': 'Телефон',
        'is_active': 'Активность',
        'interval_pay': 'Интервал оплаты',
        'property_type': 'Тип недвижимости',
        'desired_date': 'Желаемая дата',
        'duration_days': 'Длительность',
        'answer': 'Ответ',
        'responded_at': 'Дата ответа',
        'signing_status': 'Статус подписания',
        'total_amount': 'Сумма',
        'start_date': 'Дата начала',
        'end_date': 'Дата окончания',
        'tenant_signed': 'Подпись арендатора',
        'owner_signed': 'Подпись собственника',
        'content': 'Содержание',
        'is_read': 'Прочитано'
    }
    return fields_map.get(field, field)

@app.get("/api/admin/audit-logs/filters")
async def get_audit_filters(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Получить доступные фильтры для аудита"""
    if not current_user or current_user.user_type != 'admin':
        raise HTTPException(status_code=403, detail="Только для администраторов")

    # Уникальные действия
    actions = db.query(AuditLog.action).distinct().all()
    actions = [a[0] for a in actions if a[0]]

    # Уникальные типы сущностей
    entity_types = db.query(AuditLog.entity_type).distinct().all()
    entity_types = [e[0] for e in entity_types if e[0]]

    # Пользователи
    users = db.query(User.user_id, User.email, User.full_name).filter(User.user_type != 'admin').all()
    users = [{"id": u[0], "email": u[1], "name": u[2]} for u in users]

    return {
        "actions": actions,
        "entity_types": entity_types,
        "users": users
    }

# Функция для логирования действий
def log_action(
    db: Session,
    user_id: Optional[int],
    action: str,
    entity_type: str,
    entity_id: Optional[int] = None,
    changes: Optional[dict] = None,
    request: Optional[Request] = None
):
    """Создать запись в аудит логе"""
    details = {}

    if changes:
        details['changes'] = changes

    if request:
        details['ip_address'] = request.client.host if request.client else None
        details['user_agent'] = request.headers.get('user-agent')

    log = AuditLog(
        user_id=user_id,
        action=action,
        entity_type=entity_type,
        entity_id=entity_id,
        details=details if details else None
    )
    db.add(log)
    db.commit()

@app.get("/admin/audit", response_class=HTMLResponse)
async def admin_audit_page(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Страница аудит-лога для администратора"""
    if not current_user or current_user.user_type != 'admin':
        return RedirectResponse(url="/")

    return templates.TemplateResponse("admin_audit.html", {
        "request": request,
        "current_user": current_user,
        "user_initials": get_user_initials(current_user)
    })



# ==================== ГЕНЕРАЦИЯ ДОКУМЕНТОВ ====================

@app.post("/api/contracts/{contract_id}/generate-contract")
async def generate_contract_document(
    contract_id: int,
    format: str = Query("docx", regex="^(docx)$"),  # только docx
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Генерация договора аренды в Word"""
    if not current_user:
        raise HTTPException(status_code=401, detail="Не авторизован")

    contract = db.query(Contract).filter(Contract.contract_id == contract_id).first()
    if not contract:
        raise HTTPException(404, "Договор не найден")

    # Получаем связанные данные через application -> property
    app = db.query(Application).filter(Application.application_id == contract.application_id).first()
    if not app:
        raise HTTPException(404, "Заявка не найдена")

    property = db.query(Property).filter(Property.property_id == app.property_id).first()
    if not property:
        raise HTTPException(404, "Объект не найден")

    tenant = db.query(User).filter(User.user_id == app.tenant_id).first()
    owner = db.query(User).filter(User.user_id == property.owner_id).first()

    # Проверка прав
    if not (current_user.user_id == app.tenant_id or current_user.user_id == property.owner_id):
        raise HTTPException(403, "Нет доступа к договору")

    # Подготовка данных
    today = datetime.now()
    months = ["января", "февраля", "марта", "апреля", "мая", "июня",
              "июля", "августа", "сентября", "октября", "ноября", "декабря"]

    contract_data = {
        "number": f"Д-{contract.contract_id}",
        "day": today.strftime("%d"),
        "month": months[today.month - 1],
        "year": today.strftime("%Y"),
        "start_day": contract.start_date.strftime("%d") if contract.start_date else "___",
        "start_month": months[contract.start_date.month - 1] if contract.start_date else "_____",
        "start_year": contract.start_date.strftime("%Y") if contract.start_date else "___",
        "end_day": contract.end_date.strftime("%d") if contract.end_date else "___",
        "end_month": months[contract.end_date.month - 1] if contract.end_date else "_____",
        "end_year": contract.end_date.strftime("%Y") if contract.end_date else "___",
        "duration_months": str((contract.end_date.year - contract.start_date.year) * 12 +
                               (contract.end_date.month - contract.start_date.month)) if contract.end_date and contract.start_date else "___",
        "monthly_price": str(int(property.price)) if property.price else "___",
        "payment_day": "10",
        "deposit": str(int(property.price) * 2) if property.price else "___",
        "purpose": "проживания" if property.property_type in ['apartment', 'house'] else "коммерческой деятельности",
        "tenant_signed": contract.tenant_signed,
        "owner_signed": contract.owner_signed
    }

    tenant_contact = tenant.contact_info if tenant else {}
    owner_contact = owner.contact_info if owner else {}

    tenant_data = {
        "name": tenant.full_name if tenant else "___________",
        "rep": tenant.full_name if tenant else "___________",
        "basis": "паспорта",
        "passport": tenant_contact.get("passport", "___________")
    }

    owner_data = {
        "name": owner.full_name if owner else "___________",
        "rep": owner.full_name if owner else "___________",
        "basis": "паспорта",
        "passport": owner_contact.get("passport", "___________")
    }

    property_data = {
        "address": property.address if property else "_______________",
        "city": property.city if property else "Москва",
        "area": str(property.area) if property and property.area else "___",
        "rooms": str(property.rooms) if property and property.rooms else "___",
        "type": property.property_type if property else "apartment",
        "interval": property.interval_pay if property else "month"
    }

    # Генерируем файл
    try:
        file_path = generate_contract_docx(contract_data, property_data, tenant_data, owner_data)
        filename = f"contract_{contract.contract_id}.docx"
        media_type = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"

        return FileResponse(
            path=file_path,
            filename=filename,
            media_type=media_type
        )
    except Exception as e:
        raise HTTPException(500, f"Ошибка генерации договора: {str(e)}")


@app.post("/api/contracts/{contract_id}/generate-act")
async def generate_act_document(
    contract_id: int,
    format: str = Query("pdf", regex="^(pdf)$"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Генерация акта приема-передачи в PDF"""
    if not current_user:
        raise HTTPException(status_code=401, detail="Не авторизован")

    contract = db.query(Contract).filter(Contract.contract_id == contract_id).first()
    if not contract:
        raise HTTPException(404, "Договор не найден")

    app = db.query(Application).filter(Application.application_id == contract.application_id).first()
    if not app:
        raise HTTPException(404, "Заявка не найдена")

    property = db.query(Property).filter(Property.property_id == app.property_id).first()
    if not property:
        raise HTTPException(404, "Объект не найден")

    tenant = db.query(User).filter(User.user_id == app.tenant_id).first()
    owner = db.query(User).filter(User.user_id == property.owner_id).first()

    if not (current_user.user_id == app.tenant_id or current_user.user_id == property.owner_id):
        raise HTTPException(403, "Нет доступа к акту")

    today = datetime.now()
    months = ["января", "февраля", "марта", "апреля", "мая", "июня",
              "июля", "августа", "сентября", "октября", "ноября", "декабря"]

    contract_data = {
        "number": f"Д-{contract.contract_id}",
        "day": today.strftime("%d"),
        "month": months[today.month - 1],
        "year": today.strftime("%Y"),
        "start_day": contract.start_date.strftime("%d") if contract.start_date else "___",
        "start_month": months[contract.start_date.month - 1] if contract.start_date else "_____",
        "start_year": contract.start_date.strftime("%Y") if contract.start_date else "___",
        "purpose": "проживания" if property.property_type in ['apartment', 'house'] else "коммерческой деятельности",
        "tenant_signed": contract.tenant_signed,
        "owner_signed": contract.owner_signed
    }

    tenant_contact = tenant.contact_info if tenant else {}
    owner_contact = owner.contact_info if owner else {}

    tenant_data = {
        "name": tenant.full_name if tenant else "___________",
        "rep": tenant.full_name if tenant else "___________",
        "basis": "паспорта",
        "passport": tenant_contact.get("passport", "___________")
    }

    owner_data = {
        "name": owner.full_name if owner else "___________",
        "rep": owner.full_name if owner else "___________",
        "basis": "паспорта",
        "passport": owner_contact.get("passport", "___________")
    }

    property_data = {
        "address": property.address if property else "_______________",
        "city": property.city if property else "Москва",
        "area": str(property.area) if property and property.area else "___"
    }

    try:
        file_path = generate_act_pdf(contract_data, property_data, tenant_data, owner_data)
        filename = f"act_{contract.contract_id}.pdf"
        return FileResponse(path=file_path, filename=filename, media_type="application/pdf")
    except Exception as e:
        raise HTTPException(500, f"Ошибка генерации акта: {str(e)}")

@app.get("/api/agent/export-stats")
async def export_agent_stats(
    months: int = 6,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Экспорт статистики агента в Excel"""
    if not current_user or current_user.user_type != 'agent':
        raise HTTPException(status_code=403, detail="Только для агентов")

    try:
        # Получаем данные через функции БД
        monthly = db.execute(
            text("SELECT * FROM get_agent_monthly_stats(:aid, :months)"),
            {"aid": current_user.user_id, "months": months}
        ).fetchall()

        perf = db.execute(
            text("SELECT * FROM get_agent_performance_stats(:aid, :months)"),
            {"aid": current_user.user_id, "months": months}
        ).first()

        status = db.execute(
            text("SELECT * FROM get_agent_application_status_stats(:aid, 90)"),
            {"aid": current_user.user_id}
        ).fetchall()

        # Используем функцию из reports.py
        from reports import generate_agent_stats_excel
        file_path = generate_agent_stats_excel(current_user.user_id, months, monthly, perf, status)

        return FileResponse(
            path=file_path,
            filename=f"agent_stats_{current_user.user_id}_{months}months.xlsx",
            media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        )

    except Exception as e:
        print(f"Ошибка экспорта: {e}")
        raise HTTPException(500, f"Ошибка экспорта: {str(e)}")

# ==================== ЗАПУСК ====================

if __name__ == "__main__":
    import uvicorn
    print("=" * 50)
    print("🚀 Запуск RentEase на http://localhost:8000")
    print("=" * 50)
    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=True)