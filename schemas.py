from pydantic import BaseModel, EmailStr, Field, field_validator
from typing import Optional
import re
from fastapi import UploadFile


class PropertyCreate(BaseModel):
    title: str
    description: Optional[str] = None
    address: str
    city: str

    @field_validator('title', 'description', 'address', 'city')
    @classmethod
    def sanitize_string(cls, v):
        if not v:
            return v
        # Удаляем потенциально опасные теги
        import re
        # Удаляем HTML-теги
        v = re.sub(r'<[^>]*>', '', v)
        # Ограничиваем длину
        if len(v) > 1000:
            v = v[:1000]
        return v


class ApplicationCreate(BaseModel):
    message: Optional[str] = None

    @field_validator('message')
    @classmethod
    def sanitize_message(cls, v):
        if not v:
            return v
        # Удаляем HTML-теги и опасные символы
        import re
        v = re.sub(r'<[^>]*>', '', v)
        if len(v) > 2000:
            v = v[:2000]
        return v

# ==================== БАЗОВЫЕ ВАЛИДАТОРЫ ====================

def validate_password_strength(password: str) -> str:
    """Проверка сложности пароля"""
    if len(password) < 8:
        raise ValueError('Пароль должен быть не менее 8 символов')
    if not re.search(r'[a-zA-Z]', password):
        raise ValueError('Пароль должен содержать хотя бы одну букву')
    if not re.search(r'\d', password):
        raise ValueError('Пароль должен содержать хотя бы одну цифру')
    return password


def validate_phone(phone: Optional[str]) -> Optional[str]:
    """Проверка номера телефона"""
    if not phone:
        return phone
    # Убираем все нецифровые символы
    digits = re.sub(r'\D', '', phone)
    if len(digits) != 11 or digits[0] not in ['7', '8']:
        raise ValueError('Некорректный номер телефона. Используйте формат +7 (XXX) XXX-XX-XX')
    return phone


def validate_inn(inn: Optional[str]) -> Optional[str]:
    """Проверка ИНН (10 или 12 цифр)"""
    if not inn:
        return inn
    if not inn.isdigit():
        raise ValueError('ИНН должен содержать только цифры')
    if len(inn) not in [10, 12]:
        raise ValueError('ИНН должен быть 10 или 12 цифр')
    return inn


def validate_passport(passport: Optional[str]) -> Optional[str]:
    """Проверка паспорта (серия + номер)"""
    if not passport:
        return passport
    # Убираем пробелы
    cleaned = re.sub(r'\s', '', passport)
    if len(cleaned) != 10 or not cleaned.isdigit():
        raise ValueError('Паспорт должен содержать 10 цифр (4 серия + 6 номер)')
    return passport


def validate_name(name: Optional[str], field_name: str = "Имя") -> Optional[str]:
    """Проверка имени/фамилии"""
    if not name:
        return name
    if not name.replace(' ', '').isalpha():
        raise ValueError(f'{field_name} должно содержать только буквы')
    return name


# ==================== МОДЕЛИ ДЛЯ РЕГИСТРАЦИИ ====================

class UserRegisterStep1(BaseModel):
    email: EmailStr
    password: str
    phone: Optional[str] = None

    @field_validator('password')
    @classmethod
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError('Пароль должен быть не менее 8 символов')
        if not re.search(r'[a-zA-Z]', v):
            raise ValueError('Пароль должен содержать хотя бы одну букву')
        if not re.search(r'\d', v):
            raise ValueError('Пароль должен содержать хотя бы одну цифру')
        return v

    @field_validator('phone')
    @classmethod
    def validate_phone(cls, v):
        if not v:
            return v
        digits = re.sub(r'\D', '', v)
        if len(digits) != 11 or digits[0] not in ['7', '8']:
            raise ValueError('Некорректный номер телефона')
        return v

class UserRegisterStep2(BaseModel):
    email: EmailStr
    code: str

    @field_validator('code')
    @classmethod
    def validate_code(cls, v):
        v = v.replace('-', '')
        if len(v) != 8 or not v.isdigit():
            raise ValueError('Код должен быть 8 цифр')
        return v

class UserRegisterStep3(BaseModel):
    email: EmailStr
    name: Optional[str] = None
    surname: Optional[str] = None
    patronymic: Optional[str] = None
    passport: Optional[str] = None
    inn: Optional[str] = None
    avatar: Optional[UploadFile] = None

    @field_validator('passport')
    @classmethod
    def validate_passport(cls, v):
        if not v:
            return v
        cleaned = re.sub(r'\s', '', v)
        if len(cleaned) != 10 or not cleaned.isdigit():
            raise ValueError('Паспорт должен содержать 10 цифр')
        return v

    @field_validator('inn')
    @classmethod
    def validate_inn(cls, v):
        if not v:
            return v
        if not v.isdigit() or len(v) not in [10, 12]:
            raise ValueError('ИНН должен быть 10 или 12 цифр')
        return v


# ==================== МОДЕЛИ ДЛЯ ПРОФИЛЯ ====================

class UserProfileUpdate(BaseModel):
    full_name: Optional[str] = None
    birth_date: Optional[str] = None
    phone: Optional[str] = None
    city: Optional[str] = None
    passport: Optional[str] = None
    inn: Optional[str] = None

    # Убираем все валидаторы для начала


# ==================== ВОССТАНОВЛЕНИЕ ПАРОЛЯ ====================

class PasswordRecoveryRequest(BaseModel):
    email: EmailStr

class PasswordRecoveryVerify(BaseModel):
    email: EmailStr
    code: str

    @field_validator('code')
    @classmethod
    def validate_code(cls, v):
        v = v.replace('-', '')
        if len(v) != 8 or not v.isdigit():
            raise ValueError('Код должен быть 8 цифр')
        return v

class PasswordRecoveryReset(BaseModel):
    email: EmailStr
    password: str

    @field_validator('password')
    @classmethod
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError('Пароль должен быть не менее 8 символов')
        if not re.search(r'[a-zA-Z]', v):
            raise ValueError('Пароль должен содержать хотя бы одну букву')
        if not re.search(r'\d', v):
            raise ValueError('Пароль должен содержать хотя бы одну цифру')
        return v


# ==================== МОДЕЛИ ДЛЯ ОБЪЕКТОВ ====================

class PropertyCreate(BaseModel):
    title: str = Field(..., min_length=3, max_length=200, description="Название")
    description: Optional[str] = Field(None, max_length=2000, description="Описание")
    address: str = Field(..., min_length=5, max_length=300, description="Адрес")
    city: str = Field(..., min_length=2, max_length=100, description="Город")
    property_type: str = Field(..., pattern='^(apartment|house|commercial)$', description="Тип")
    area: float = Field(..., gt=0, le=10000, description="Площадь")
    rooms: int = Field(0, ge=0, le=100, description="Количество комнат")
    price: float = Field(..., gt=0, le=1_000_000_000, description="Цена")
    interval_pay: str = Field(..., pattern='^(once|week|month)$', description="Интервал оплаты")


# ==================== МОДЕЛИ ДЛЯ ЗАЯВОК ====================

class ApplicationCreate(BaseModel):
    property_id: int = Field(..., gt=0)
    desired_date: str = Field(..., description="Желаемая дата заселения")
    duration_days: int = Field(..., gt=0, le=3650, description="Длительность (дней)")
    message: Optional[str] = Field(None, max_length=1000, description="Сообщение")

    @field_validator('desired_date')
    @classmethod
    def validate_desired_date(cls, v: str) -> str:
        if not re.match(r'^\d{4}-\d{2}-\d{2}$', v):
            raise ValueError('Неверный формат даты. Используйте ГГГГ-ММ-ДД')
        return v


class ApplicationResponse(BaseModel):
    status: str = Field(..., pattern='^(approved|rejected)$')
    answer: Optional[str] = Field(None, max_length=1000)


# ==================== МОДЕЛИ ДЛЯ СООБЩЕНИЙ ====================

class MessageCreate(BaseModel):
    to_user_id: int = Field(..., gt=0)
    content: str = Field(..., min_length=1, max_length=2000)