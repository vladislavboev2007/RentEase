from fastapi import FastAPI, Request, Form, Depends, HTTPException, status
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session
from sqlalchemy import or_
from pathlib import Path
import hashlib
import random
import string
from datetime import datetime, timedelta
import re

from database import SessionLocal, User, Property, PropertyPhoto, Application, Contract

# Получаем корневую директорию проекта
BASE_DIR = Path(__file__).resolve().parent

app = FastAPI(title="RentEase", version="2.0")

# Настраиваем статические файлы и шаблоны
static_dir = BASE_DIR / "static"
templates_dir = BASE_DIR / "templates"
static_dir.mkdir(exist_ok=True)
templates_dir.mkdir(exist_ok=True)

app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")
templates = Jinja2Templates(directory=str(templates_dir))


# ==================== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ====================

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def hash_password(password: str) -> str:
    """Хеширование пароля"""
    return hashlib.sha256(password.encode()).hexdigest()


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Проверка пароля"""
    return hash_password(plain_password) == hashed_password


def generate_code() -> str:
    """Генерация 8-значного кода подтверждения"""
    return ''.join(random.choices(string.digits, k=8))


def validate_email(email: str) -> bool:
    """Валидация email"""
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return re.match(pattern, email) is not None


def get_mock_properties(db: Session = None):
    """Получение объектов для главной страницы"""
    if db:
        properties = db.query(Property).filter(Property.status == 'active').limit(6).all()
        for prop in properties:
            photo = db.query(PropertyPhoto).filter(
                PropertyPhoto.property_id == prop.property_id,
                PropertyPhoto.is_main == True
            ).first()
            prop.main_photo_url = photo.url if photo else "/static/placeholder-image.png"
        return properties
    else:
        # Тестовые данные без БД
        return [
            {
                "property_id": 1,
                "title": "Уютная квартира в центре",
                "address": "ул. Тверская, д. 10",
                "city": "Москва",
                "rooms": 2,
                "area": 65.5,
                "price": 45000,
                "property_type": "apartment",
                "status": "active",
                "main_photo_url": "/static/placeholder-image.png",
                "interval_pay": "month",
                "created_at": datetime.now()
            },
            {
                "property_id": 2,
                "title": "Современный лофт",
                "address": "Невский пр., д. 25",
                "city": "Санкт-Петербург",
                "rooms": 3,
                "area": 95.0,
                "price": 75000,
                "property_type": "apartment",
                "status": "active",
                "main_photo_url": "/static/placeholder-image.png",
                "interval_pay": "month",
                "created_at": datetime.now()
            }
        ]


# В app.py замените функцию get_mock_properties() на:

def get_properties_from_db(db: Session, limit: int = 6):
    """Получение объектов из БД для главной страницы"""
    properties = db.query(Property).filter(Property.status == 'active').order_by(Property.created_at.desc()).limit(
        limit).all()

    for prop in properties:
        main_photo = db.query(PropertyPhoto).filter(
            PropertyPhoto.property_id == prop.property_id,
            PropertyPhoto.is_main == True
        ).first()
        prop.main_photo_url = main_photo.url if main_photo else "/static/placeholder-image.png"

    return properties

def get_default_cities():
    return [
        {"id": 1, "name": "Москва"},
        {"id": 2, "name": "Санкт-Петербург"},
        {"id": 3, "name": "Новосибирск"},
        {"id": 4, "name": "Екатеринбург"},
        {"id": 5, "name": "Казань"}
    ]


# ==================== ОСНОВНЫЕ МАРШРУТЫ ====================

@app.get("/", response_class=HTMLResponse)
async def home_page(request: Request, db: Session = Depends(get_db)):
    """Главная страница с объектами"""
    try:
        properties = get_properties_from_db(db)
    except Exception as e:
        print(f"Ошибка получения данных из БД: {e}")
        properties = get_mock_properties()  # fallback на тестовые данные

    cities = get_default_cities()

    return templates.TemplateResponse(
        "index.html",
        {
            "request": request,
            "properties": properties,
            "cities": cities
        }
    )


# ==================== РЕГИСТРАЦИЯ ====================

@app.get("/register", response_class=HTMLResponse)
async def register_page(request: Request):
    """Страница регистрации"""
    return templates.TemplateResponse(
        "register.html",
        {"request": request}
    )


@app.post("/api/register/step1")
async def register_step1(
        email: str = Form(...),
        password: str = Form(...),
        phone: str = Form(None),
        db: Session = Depends(get_db)
):
    """Шаг 1: Проверка email и создание временного пользователя"""
    # Валидация email
    if not validate_email(email):
        return {"success": False, "message": "Некорректный email"}

    # Проверка пароля
    if len(password) < 8:
        return {"success": False, "message": "Пароль должен быть не менее 8 символов"}

    # Проверка существования пользователя
    existing_user = db.query(User).filter(User.email == email).first()
    if existing_user:
        return {"success": False, "message": "Пользователь с таким email уже существует"}

    # Генерируем код подтверждения
    code = generate_code()

    # В реальном приложении здесь отправка email
    print(f"📧 Код подтверждения для {email}: {code}")

    # Сохраняем в сессии или временном хранилище
    # Для простоты используем глобальный словарь (в продакшене использовать Redis)
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
        code: str = Form(...),
        db: Session = Depends(get_db)
):
    """Шаг 2: Проверка кода подтверждения"""
    # Убираем дефисы из кода
    code = code.replace('-', '')

    # Проверяем временного пользователя
    if not hasattr(app.state, "temp_users") or email not in app.state.temp_users:
        return {"success": False, "message": "Сессия истекла, начните регистрацию заново"}

    temp_user = app.state.temp_users[email]

    # Проверка срока действия кода
    if datetime.now() > temp_user["code_expires"]:
        del app.state.temp_users[email]
        return {"success": False, "message": "Код истек, запросите новый"}

    # Проверка кода
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
        db: Session = Depends(get_db)
):
    """Шаг 3: Сохранение личных данных и завершение регистрации"""
    if not hasattr(app.state, "temp_users") or email not in app.state.temp_users:
        return {"success": False, "message": "Сессия истекла, начните регистрацию заново"}

    temp_user = app.state.temp_users[email]

    # Создаем нового пользователя
    contact_info = {}
    if passport:
        contact_info["passport"] = passport
    if inn:
        contact_info["inn"] = inn

    full_name = f"{surname} {name} {patronymic}".strip() if name else email.split('@')[0]

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

    # Очищаем временные данные
    del app.state.temp_users[email]

    return {"success": True, "message": "Регистрация успешно завершена"}


@app.post("/api/register/resend-code")
async def resend_code(email: str = Form(...)):
    """Повторная отправка кода подтверждения"""
    if not hasattr(app.state, "temp_users") or email not in app.state.temp_users:
        return {"success": False, "message": "Сессия истекла"}

    # Генерируем новый код
    new_code = generate_code()
    app.state.temp_users[email]["code"] = new_code
    app.state.temp_users[email]["code_expires"] = datetime.now() + timedelta(minutes=5)

    print(f"📧 Новый код для {email}: {new_code}")

    return {"success": True, "message": "Новый код отправлен"}


# ==================== ВХОД ====================

@app.post("/api/login")
async def login(
        email: str = Form(...),
        password: str = Form(...),
        db: Session = Depends(get_db)
):
    """Вход в систему"""
    user = db.query(User).filter(User.email == email).first()

    if not user:
        return {"success": False, "message": "Пользователь не найден"}

    if not verify_password(password, user.password_hash):
        return {"success": False, "message": "Неверный пароль"}

    if not user.is_active:
        return {"success": False, "message": "Аккаунт деактивирован"}

    # В реальном приложении здесь создается сессия/JWT токен
    return {
        "success": True,
        "message": "Вход выполнен успешно",
        "user": {
            "id": user.user_id,
            "email": user.email,
            "name": user.full_name,
            "type": user.user_type
        }
    }


# ==================== ВОССТАНОВЛЕНИЕ ПАРОЛЯ ====================

@app.get("/recovery", response_class=HTMLResponse)
async def recovery_page(request: Request):
    """Страница восстановления пароля"""
    return templates.TemplateResponse(
        "recovery.html",
        {"request": request}
    )


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
    code = generate_code()

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

    new_code = generate_code()
    app.state.recovery_codes[email]["code"] = new_code
    app.state.recovery_codes[email]["expires"] = datetime.now() + timedelta(minutes=5)

    print(f"🔐 Новый код для {email}: {new_code}")

    return {"success": True, "message": "Новый код отправлен"}


# ==================== ПОИСК И ФИЛЬТРАЦИЯ ====================

@app.post("/search", response_class=HTMLResponse)
async def search_properties(
        request: Request,
        city: str = Form(None),
        min_price: float = Form(None),
        max_price: float = Form(None),
        property_type: str = Form(None),
        db: Session = Depends(get_db)
):
    """Поиск объектов по критериям"""
    query = db.query(Property).filter(Property.status == 'active')

    if city:
        query = query.filter(Property.city.ilike(f"%{city}%"))
    if min_price:
        query = query.filter(Property.price >= min_price)
    if max_price:
        query = query.filter(Property.price <= max_price)
    if property_type and property_type != "all":
        query = query.filter(Property.property_type == property_type)

    properties = query.order_by(Property.created_at.desc()).limit(20).all()

    # Добавляем фото
    for prop in properties:
        main_photo = db.query(PropertyPhoto).filter(
            PropertyPhoto.property_id == prop.property_id,
            PropertyPhoto.is_main == True
        ).first()
        prop.main_photo_url = main_photo.url if main_photo else "/static/placeholder-image.png"

    return templates.TemplateResponse(
        "index.html",
        {
            "request": request,
            "properties": properties,
            "cities": get_default_cities(),
            "search_city": city,
            "search_min_price": min_price,
            "search_max_price": max_price,
            "search_type": property_type
        }
    )


@app.get("/api/cities/search")
async def search_cities_api(query: str = ""):
    """API для поиска городов"""
    all_cities = [
        "Москва", "Санкт-Петербург", "Новосибирск", "Екатеринбург", "Казань",
        "Нижний Новгород", "Челябинск", "Самара", "Омск", "Ростов-на-Дону",
        "Уфа", "Красноярск", "Пермь", "Воронеж", "Волгоград", "Краснодар",
        "Саратов", "Тюмень", "Тольятти", "Ижевск"
    ]

    if query and len(query) >= 2:
        filtered = [city for city in all_cities if query.lower() in city.lower()]
        return filtered[:10]

    return []


# ==================== ДЕТАЛЬНАЯ СТРАНИЦА ОБЪЕКТА ====================

@app.get("/property/{property_id}", response_class=HTMLResponse)
async def property_detail(property_id: int, request: Request, db: Session = Depends(get_db)):
    """Страница детального просмотра объекта"""
    property = db.query(Property).filter(
        Property.property_id == property_id,
        Property.status == 'active'
    ).first()

    if not property:
        return RedirectResponse("/")

    # Загружаем связанные данные
    owner = db.query(User).filter(User.user_id == property.owner_id).first()
    agent = db.query(User).filter(User.user_id == property.agent_id).first() if property.agent_id else None

    # Получаем фото
    photos = db.query(PropertyPhoto).filter(
        PropertyPhoto.property_id == property_id
    ).order_by(PropertyPhoto.sequence_number).all()

    # Добавляем связанные объекты в property
    property.owner = owner
    property.agent = agent

    return templates.TemplateResponse(
        "property_detail.html",
        {
            "request": request,
            "property": property,
            "photos": photos
        }
    )


# ==================== ЗАПУСК СЕРВЕРА ====================

if __name__ == "__main__":
    import uvicorn

    print("=" * 50)
    print("🚀 Запуск RentEase на http://localhost:8000")
    print("=" * 50)

    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=True)