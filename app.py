from fastapi import (FastAPI, Request, Form,
                     Depends, HTTPException, status,
                     Cookie, Response, UploadFile,
                     File, WebSocket, WebSocketDisconnect)
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_, func, desc
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
from uuid import uuid4
from typing import Optional, List, Dict, Any, Set
from pydantic import BaseModel, EmailStr, field_validator  # Важно: field_validator для Pydantic v2

from database import SessionLocal, User, Property, PropertyPhoto, Application, Contract, Message, AuditLog
from schemas import (
    UserRegisterStep1, UserRegisterStep2, UserRegisterStep3,
    UserProfileUpdate, PasswordRecoveryRequest, PasswordRecoveryVerify,
    PasswordRecoveryReset, PropertyCreate, ApplicationCreate,
    ApplicationResponse, MessageCreate
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


async def get_current_user(token: Optional[str] = Cookie(None, alias="access_token"), db: Session = Depends(get_db)):
    if not token:
        print("❌ Нет токена в cookies")
        return None
    email = verify_token(token)
    if not email:
        print("❌ Неверный токен")
        return None
    user = db.query(User).filter(User.email == email).first()
    if user:
        print(f"✅ Найден пользователь: {user.email} (ID: {user.user_id}, тип: {user.user_type})")
    else:
        print(f"❌ Пользователь с email {email} не найден")
    return user


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

# ==================== ОСНОВНЫЕ МАРШРУТЫ ====================

@app.get("/", response_class=HTMLResponse)
async def home_page(request: Request, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    try:
        properties = get_properties_from_db(db)
    except Exception as e:
        print(f"Ошибка получения данных из БД: {e}")
        properties = []
    cities = get_default_cities()

    return templates.TemplateResponse("index.html", {
        "request": request,
        "properties": properties,
        "cities": cities,
        "current_user": current_user,
        "user_initials": get_user_initials(current_user) if current_user else None
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
async def login(response: Response, email: str = Form(...), password: str = Form(...), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == email).first()
    if not user or not verify_password(password, user.password_hash):
        return {"success": False, "message": "Неверный email или пароль"}
    if not user.is_active:
        return {"success": False, "message": "Аккаунт деактивирован"}
    access_token = create_access_token(data={"sub": user.email})
    response.set_cookie(
        key="access_token",
        value=access_token,
        httponly=True,
        max_age=ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        expires=ACCESS_TOKEN_EXPIRE_MINUTES * 60
    )
    return {
        "success": True,
        "message": "Вход выполнен успешно",
        "user": {
            "id": user.user_id,
            "email": user.email,
            "name": user.full_name,
            "type": user.user_type,
            "initials": get_user_initials(user)
        }
    }


# ==================== ВЫХОД ====================

@app.post("/api/logout")
async def logout(response: Response):
    response.delete_cookie("access_token")
    return {"success": True, "message": "Выход выполнен успешно"}


# ==================== ПОИСК И ФИЛЬТРАЦИЯ ====================

@app.post("/search", response_class=HTMLResponse)
async def search_properties(
        request: Request,
        search: str = Form(None),
        city: str = Form(None),
        property_type: str = Form(None),
        rooms: str = Form(None),
        min_price: float = Form(None),
        max_price: float = Form(None),
        min_area: float = Form(None),
        max_area: float = Form(None),
        db: Session = Depends(get_db),
        current_user: User = Depends(get_current_user)
):
    query = db.query(Property).filter(Property.status == 'active')

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
            query = query.filter(Property.rooms == int(rooms))
    if min_price:
        query = query.filter(Property.price >= min_price)
    if max_price:
        query = query.filter(Property.price <= max_price)
    if min_area:
        query = query.filter(Property.area >= min_area)
    if max_area:
        query = query.filter(Property.area <= max_area)

    properties = query.order_by(Property.created_at.desc()).limit(50).all()

    for prop in properties:
        main_photo = db.query(PropertyPhoto).filter(
            PropertyPhoto.property_id == prop.property_id,
            PropertyPhoto.is_main == True
        ).first()
        prop.main_photo_url = main_photo.url if main_photo else "/resources/placeholder-image.png"

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
            "user_initials": get_user_initials(current_user) if current_user else None
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
async def get_property_api(property_id: int, db: Session = Depends(get_db)):
    property = db.query(Property).filter(Property.property_id == property_id).first()
    if not property:
        raise HTTPException(status_code=404, detail="Объект не найден")

    photos = db.query(PropertyPhoto).filter(PropertyPhoto.property_id == property_id).order_by(
        PropertyPhoto.sequence_number).all()
    owner = db.query(User).filter(User.user_id == property.owner_id).first()
    agent = db.query(User).filter(User.user_id == property.agent_id).first() if property.agent_id else None

    return {
        "property_id": property.property_id,
        "title": property.title,
        "description": property.description,
        "address": property.address,
        "city": property.city,
        "property_type": property.property_type,
        "area": float(property.area) if property.area else None,
        "rooms": property.rooms,
        "price": float(property.price) if property.price else None,
        "interval_pay": property.interval_pay,
        "status": property.status,
        "photos": [{"url": photo.url, "is_main": photo.is_main} for photo in photos],
        "owner": {
            "full_name": owner.full_name if owner else None,
            "email": owner.email if owner else None,
            "contact_info": owner.contact_info if owner else {}
        } if owner else None,
        "agent": {
            "full_name": agent.full_name if agent else None,
            "email": agent.email if agent else None,
            "contact_info": agent.contact_info if agent else {}
        } if agent else None
    }


# ==================== УПРАВЛЕНИЕ ОБЪЕКТАМИ ====================

@app.get("/api/my/properties")
async def get_my_properties(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if not current_user:
        raise HTTPException(status_code=401, detail="Не авторизован")

    if current_user.user_type == 'owner':
        properties = db.query(Property).filter(Property.owner_id == current_user.user_id).all()
    elif current_user.user_type == 'agent':
        properties = db.query(Property).filter(Property.agent_id == current_user.user_id).all()
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
    data: PropertyCreate,  # Pydantic валидирует цену, площадь, тип и т.д.
    photos: List[UploadFile] = File(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    print(f"\n🔵 СОЗДАНИЕ ОБЪЕКТА (упрощённо)")
    print(f"👤 Пользователь: {current_user.email if current_user else 'None'}")

    if not current_user:
        raise HTTPException(status_code=401, detail="Не авторизован")

    if not current_user or current_user.user_type not in ['owner', 'agent']:
        raise HTTPException(403, "Недостаточно прав")

    # Создаём объект - данные уже проверены Pydantic
    new_prop = Property(
        owner_id=current_user.user_id if current_user.user_type == 'owner' else None,
        agent_id=current_user.user_id if current_user.user_type == 'agent' else None,
        title=data.title,
        description=data.description,
        address=data.address,
        city=data.city,
        property_type=data.property_type,
        area=data.area,
        rooms=data.rooms,
        price=data.price,
        interval_pay=data.interval_pay,
        status='draft'
        )

    db.add(new_prop)
    db.commit()
    db.refresh(new_prop)

    print(f"✅ Объект создан с ID: {new_prop.property_id}")
    print(f"📊 Данные: {title}, {address}, {city}, {price}")

    # Фотографии игнорируем пока
    if photos:
        print(f"📸 Получено {len(photos)} файлов, но они пока не сохраняются")

    return {"success": True, "property_id": new_prop.property_id}

@app.put("/api/properties/{property_id}")
async def update_property(
    property_id: int,
    title: str = Form(...),
    description: str = Form(None),
    address: str = Form(...),
    city: str = Form(...),
    property_type: str = Form(...),
    area: float = Form(...),
    rooms: int = Form(...),
    price: float = Form(...),
    interval_pay: str = Form(...),
    photos: List[UploadFile] = File(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    if not current_user:
        raise HTTPException(401, "Не авторизован")

    prop = db.query(Property).filter(Property.property_id == property_id).first()
    if not prop:
        raise HTTPException(404, "Объект не найден")

    # ✅ НОВАЯ проверка прав
    if current_user.user_id not in [prop.owner_id, prop.agent_id]:
        raise HTTPException(403, "Нет прав на редактирование")

    prop.title = title
    prop.description = description
    prop.address = address
    prop.city = city
    prop.property_type = property_type
    prop.area = area
    prop.rooms = rooms
    prop.price = price
    prop.interval_pay = interval_pay

    db.commit()

    # обновление фото
    if photos and any(p.filename for p in photos):
        old_photos = db.query(PropertyPhoto).filter(
            PropertyPhoto.property_id == property_id
        ).all()

        for old in old_photos:
            file_path = BASE_DIR / old.url.lstrip('/')
            if file_path.exists():
                file_path.unlink()
            db.delete(old)

        db.commit()

        for idx, photo in enumerate(photos):
            if photo.filename:
                file_url = await save_upload_file(photo, subdir=f"properties/{property_id}")
                db.add(PropertyPhoto(
                    property_id=property_id,
                    url=file_url,
                    is_main=(idx == 0),
                    sequence_number=idx + 1
                ))

        db.commit()

    return {"success": True}


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

    # ✅ НОВАЯ проверка прав
    if current_user.user_id not in [prop.owner_id, prop.agent_id]:
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
    if (current_user.user_type == 'owner' and property.owner_id != current_user.user_id) or \
            (current_user.user_type == 'agent' and property.agent_id != current_user.user_id):
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

# ==================== УПРАВЛЕНИЕ ЗАЯВКАМИ ====================

@app.get("/api/my/applications")
async def get_my_applications(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if not current_user:
        raise HTTPException(status_code=401, detail="Не авторизован")

    if current_user.user_type == 'tenant':
        applications = db.query(Application).filter(Application.tenant_id == current_user.user_id).all()
    elif current_user.user_type in ['owner', 'agent']:
        applications = db.query(Application).join(Property).filter(
            (Property.owner_id == current_user.user_id) | (Property.agent_id == current_user.user_id)
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

        result.append({
            "application_id": app.application_id,
            "property_id": app.property_id,
            "property_title": property.title if property else None,
            "property_address": property.address if property else None,
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
        })

    return result


@app.post("/api/applications")
async def create_application(app_data: ApplicationCreate, current_user: User = Depends(get_current_user),
                             db: Session = Depends(get_db)):
    if not current_user:
        raise HTTPException(status_code=401, detail="Не авторизован")
    if current_user.user_type != 'tenant':
        raise HTTPException(403, "Только арендаторы могут создавать заявки")
    property = db.query(Property).filter(
        Property.property_id == app_data.property_id,
        Property.status == 'active'
    ).first()
    if not property:
        raise HTTPException(400, "Объект недоступен")
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
        status='pending'
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
    if property.owner_id != current_user.user_id and property.agent_id != current_user.user_id:
        raise HTTPException(403, "Нет прав")
    app.status = status
    app.answer = answer
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
    if not current_user:
        raise HTTPException(status_code=401, detail="Не авторизован")

    if current_user.user_type == 'tenant':
        contracts = db.query(Contract).filter(Contract.tenant_id == current_user.user_id).all()
    elif current_user.user_type == 'owner':
        contracts = db.query(Contract).filter(Contract.owner_id == current_user.user_id).all()
    elif current_user.user_type == 'agent':
        contracts = db.query(Contract).join(Property, Contract.property_id == Property.property_id).filter(
            Property.agent_id == current_user.user_id).all()
    else:
        contracts = []

    result = []
    for contract in contracts:
        property = db.query(Property).filter(Property.property_id == contract.property_id).first()

        # Получаем главное фото
        main_photo = db.query(PropertyPhoto).filter(
            PropertyPhoto.property_id == contract.property_id,
            PropertyPhoto.is_main == True
        ).first()

        # Генерируем номер договора из ID
        contract_number = f"Д-{contract.contract_id:06d}"

        result.append({
            "contract_id": contract.contract_id,
            "contract_number": contract_number,
            "property_id": contract.property_id,
            "property_title": property.title if property else None,
            "property_address": property.address if property else None,
            "property_photo": main_photo.url if main_photo else None,
            # contract_type УДАЛЁН
            "start_date": contract.start_date.isoformat() if contract.start_date else None,
            "end_date": contract.end_date.isoformat() if contract.end_date else None,
            "total_amount": float(contract.total_amount) if contract.total_amount else 0,
            "signing_status": contract.signing_status,
            "created_at": contract.created_at.isoformat() if contract.created_at else None
        })
    return result


@app.get("/api/contracts/{contract_id}")
async def get_contract(contract_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if not current_user:
        raise HTTPException(status_code=401, detail="Не авторизован")

    contract = db.query(Contract).filter(Contract.contract_id == contract_id).first()
    if not contract:
        raise HTTPException(404, "Договор не найден")

    property = db.query(Property).filter(Property.property_id == contract.property_id).first()

    # Проверка доступа
    if not (contract.tenant_id == current_user.user_id or
            contract.owner_id == current_user.user_id or
            (property and property.agent_id == current_user.user_id)):
        raise HTTPException(403, "Нет доступа")

    tenant = db.query(User).filter(User.user_id == contract.tenant_id).first()
    owner = db.query(User).filter(User.user_id == contract.owner_id).first()

    # Получаем главное фото
    main_photo = db.query(PropertyPhoto).filter(
        PropertyPhoto.property_id == contract.property_id,
        PropertyPhoto.is_main == True
    ).first()

    # Генерируем номер из ID
    contract_number = f"Д-{contract.contract_id:06d}"

    return {
        "contract_id": contract.contract_id,
        "contract_number": contract_number,
        "property_id": contract.property_id,
        "property_title": property.title if property else None,
        "property_address": property.address if property else None,
        "property_city": property.city if property else None,
        "property_type": property.property_type if property else None,
        "property_rooms": property.rooms if property else None,
        "property_area": float(property.area) if property and property.area else None,
        "property_photo": main_photo.url if main_photo else None,
        # contract_type УДАЛЁН
        "start_date": contract.start_date.isoformat() if contract.start_date else None,
        "end_date": contract.end_date.isoformat() if contract.end_date else None,
        "total_amount": float(contract.total_amount) if contract.total_amount else 0,
        "signing_status": contract.signing_status,
        "tenant_id": contract.tenant_id,
        "tenant_name": tenant.full_name if tenant else None,
        "tenant_email": tenant.email if tenant else None,
        "owner_id": contract.owner_id,
        "owner_name": owner.full_name if owner else None,
        "owner_email": owner.email if owner else None,
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
    if contract.tenant_id == current_user.user_id or contract.owner_id == current_user.user_id:
        contract.signing_status = 'signed'
        db.commit()
        return {"success": True}
    else:
        raise HTTPException(403, "Вы не являетесь стороной договора")


# ==================== СООБЩЕНИЯ ====================

@app.get("/api/my/dialogs")
async def get_dialogs(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if not current_user:
        raise HTTPException(status_code=401, detail="Не авторизован")
    sent = db.query(Message.to_user_id).filter(Message.from_user_id == current_user.user_id).distinct().all()
    received = db.query(Message.from_user_id).filter(Message.to_user_id == current_user.user_id).distinct().all()
    user_ids = set([r[0] for r in sent] + [r[0] for r in received])
    dialogs = []
    for uid in user_ids:
        last_msg = db.query(Message).filter(
            ((Message.from_user_id == current_user.user_id) & (Message.to_user_id == uid)) |
            ((Message.from_user_id == uid) & (Message.to_user_id == current_user.user_id))
        ).order_by(Message.created_at.desc()).first()
        if last_msg:
            other_user = db.query(User).filter(User.user_id == uid).first()
            unread_count = db.query(Message).filter(
                Message.from_user_id == uid,
                Message.to_user_id == current_user.user_id,
                Message.is_read == False
            ).count()
            dialogs.append({
                "user_id": uid,
                "user_name": other_user.full_name if other_user else "Пользователь",
                "user_initials": get_user_initials(other_user) if other_user else "??",
                "avatar_url": other_user.avatar_url if other_user else None,  # <-- добавить
                "last_message": last_msg.content[:50] + "..." if len(last_msg.content) > 50 else last_msg.content,
                "last_time": last_msg.created_at.isoformat() if last_msg.created_at else None,
                "unread": unread_count
            })
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
    messages = db.query(Message).filter(
        ((Message.from_user_id == current_user.user_id) & (Message.to_user_id == chat_with)) |
        ((Message.from_user_id == chat_with) & (Message.to_user_id == current_user.user_id))
    ).order_by(Message.created_at).all()
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
    """Удалить диалог с пользователем"""
    if not current_user:
        raise HTTPException(status_code=401, detail="Не авторизован")

    # Проверяем, есть ли сообщения с этим пользователем
    messages = db.query(Message).filter(
        ((Message.from_user_id == current_user.user_id) & (Message.to_user_id == user_id)) |
        ((Message.from_user_id == user_id) & (Message.to_user_id == current_user.user_id))
    ).all()

    if not messages:
        # Если сообщений нет, возвращаем успех (ничего удалять)
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
    if not current_user or current_user.user_type != 'agent':
        raise HTTPException(status_code=403, detail="Только для агентов")

    start_date = datetime.now() - timedelta(days=30 * months)

    monthly = db.query(
        func.date_trunc('month', Contract.created_at).label('month'),
        func.count(Contract.contract_id).label('deals'),
        func.sum(Contract.total_amount).label('profit')
    ).join(Property, Contract.property_id == Property.property_id).filter(
        Property.agent_id == current_user.user_id,
        Contract.signing_status == 'signed',
        Contract.created_at >= start_date
    ).group_by('month').order_by('month').all()

    result = []
    for r in monthly:
        month_str = r.month.strftime("%Y-%m") if r.month else None
        result.append({
            "month": month_str,
            "deals": r.deals,
            "profit": float(r.profit) if r.profit else 0
        })

    return result


@app.get("/api/agent/performance")
async def agent_performance(
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db)
):
    if not current_user or current_user.user_type != 'agent':
        raise HTTPException(status_code=403, detail="Только для агентов")

    # Общая статистика
    total_deals = db.query(Contract).join(Property).filter(
        Property.agent_id == current_user.user_id,
        Contract.signing_status == 'signed'
    ).count()

    total_profit = db.query(func.sum(Contract.total_amount)).join(Property).filter(
        Property.agent_id == current_user.user_id,
        Contract.signing_status == 'signed'
    ).scalar() or 0

    # Средний доход на объект
    properties_count = db.query(Property).filter(
        Property.agent_id == current_user.user_id
    ).count()

    avg_profit = total_profit / properties_count if properties_count > 0 else 0

    # Загрузка фонда
    active_properties = db.query(Property).filter(
        Property.agent_id == current_user.user_id,
        Property.status == 'active'
    ).count()

    total_managed = db.query(Property).filter(
        Property.agent_id == current_user.user_id
    ).count()

    occupancy_rate = ((total_managed - active_properties) / total_managed * 100) if total_managed > 0 else 0

    # Обработанные заявки
    processed_apps = db.query(Application).join(Property).filter(
        Property.agent_id == current_user.user_id,
        Application.status.in_(['approved', 'rejected'])
    ).count()

    # Среднее время реакции
    avg_response = db.query(
        func.avg(
            func.extract('epoch', Application.responded_at - Application.created_at) / 3600
        )
    ).join(Property).filter(
        Property.agent_id == current_user.user_id,
        Application.responded_at.isnot(None)
    ).scalar() or 0

    # Конверсия
    total_apps = db.query(Application).join(Property).filter(
        Property.agent_id == current_user.user_id
    ).count()

    conversion_rate = (total_deals / total_apps * 100) if total_apps > 0 else 0

    return {
        "total_profit": float(total_profit),
        "avg_profit": float(avg_profit),
        "total_deals": total_deals,
        "occupancy_rate": round(occupancy_rate, 1),
        "processed_applications": processed_apps,
        "avg_response_hours": round(avg_response, 1),
        "conversion_rate": round(conversion_rate, 1)
    }

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
        Property.agent_id == current_user.user_id,
        Application.created_at >= ninety_days_ago
    ).group_by(Application.status).all()

    return [{"status": r.status, "count": r.count} for r in status_counts]


# ==================== ЗАПУСК ====================

if __name__ == "__main__":
    import uvicorn
    print("=" * 50)
    print("🚀 Запуск RentEase на http://localhost:8000")
    print("=" * 50)
    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=True)