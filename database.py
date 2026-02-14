# database.py
from sqlalchemy import create_engine, Column, Integer, String, Text, Date, DateTime, Boolean, DECIMAL, ForeignKey, \
    CheckConstraint
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import DeclarativeBase, relationship, sessionmaker
from sqlalchemy.sql import func
from datetime import datetime

# Настройка подключения к БД
# Локальная разработка
POSTGRESQL_DATABASE_URL = "postgresql+psycopg2://postgres:1234@localhost:5432/RentEase"

# Для продакшена (раскомментировать при необходимости)
# POSTGRESQL_DATABASE_URL = "postgresql+psycopg2://user_01:password1@10.115.0.67:5432/rentease_db"

# Создание движка
engine = create_engine(POSTGRESQL_DATABASE_URL, echo=False)  # echo=True для отладки SQL


# Базовый класс для всех моделей
class Base(DeclarativeBase):
    pass


# ==================== МОДЕЛИ БАЗЫ ДАННЫХ ====================

class User(Base):
    """Модель пользователей системы"""
    __tablename__ = "users"

    user_id = Column(Integer, primary_key=True, index=True)
    email = Column(String(100), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    avatar_url = Column(Text)
    full_name = Column(String(150))
    user_type = Column(String(10), nullable=False)
    contact_info = Column(JSONB, default=dict)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Связи
    owned_properties = relationship("Property", back_populates="owner", foreign_keys="Property.owner_id")
    managed_properties = relationship("Property", back_populates="agent", foreign_keys="Property.agent_id")
    applications = relationship("Application", back_populates="tenant", foreign_keys="Application.tenant_id")
    managed_applications = relationship("Application", back_populates="assigned_agent",
                                        foreign_keys="Application.agent_id")
    sent_messages = relationship("Message", back_populates="sender", foreign_keys="Message.from_user_id")
    received_messages = relationship("Message", back_populates="receiver", foreign_keys="Message.to_user_id")

    # Check constraint через __table_args__
    __table_args__ = (
        CheckConstraint(
            "user_type IN ('tenant', 'owner', 'agent', 'admin')",
            name="user_type_check"
        ),
    )


class Property(Base):
    """Модель объектов недвижимости"""
    __tablename__ = "properties"

    property_id = Column(Integer, primary_key=True, index=True)
    owner_id = Column(Integer, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)
    agent_id = Column(Integer, ForeignKey("users.user_id", ondelete="SET NULL"))

    title = Column(String(200), nullable=False)
    description = Column(Text)
    address = Column(String(300), nullable=False)
    city = Column(String(100), nullable=False, index=True)

    # Основные характеристики
    property_type = Column(String(20))
    area = Column(DECIMAL(8, 2), nullable=False)
    rooms = Column(Integer)
    price = Column(DECIMAL(10, 2), nullable=False)
    interval_pay = Column(String(20))

    # Статусы
    status = Column(String(20), default='draft')

    created_at = Column(DateTime, default=datetime.utcnow)

    # Связи
    owner = relationship("User", back_populates="owned_properties", foreign_keys=[owner_id])
    agent = relationship("User", back_populates="managed_properties", foreign_keys=[agent_id])
    photos = relationship("PropertyPhoto", back_populates="property", cascade="all, delete-orphan")
    applications = relationship("Application", back_populates="property", cascade="all, delete-orphan")
    contracts = relationship("Contract", back_populates="property")

    # Check constraints
    __table_args__ = (
        CheckConstraint(
            "property_type IN ('apartment', 'house', 'commercial')",
            name="property_type_check"
        ),
        CheckConstraint(
            "interval_pay IN ('once', 'week', 'month')",
            name="interval_pay_check"
        ),
        CheckConstraint(
            "status IN ('draft', 'active', 'rented', 'archived')",
            name="property_status_check"
        ),
        CheckConstraint("price >= 0", name="price_positive"),
        CheckConstraint("area > 0", name="area_positive"),
    )


class PropertyPhoto(Base):
    """Модель фотографий объектов"""
    __tablename__ = "property_photos"

    photo_id = Column(Integer, primary_key=True, index=True)
    property_id = Column(Integer, ForeignKey("properties.property_id", ondelete="CASCADE"), nullable=False)
    url = Column(String(500), nullable=False)
    is_main = Column(Boolean, default=False)
    sequence_number = Column(Integer, nullable=False)

    # Связь
    property = relationship("Property", back_populates="photos")


class Application(Base):
    """Модель заявок на аренду"""
    __tablename__ = "applications"

    application_id = Column(Integer, primary_key=True, index=True)
    property_id = Column(Integer, ForeignKey("properties.property_id"), nullable=False)
    tenant_id = Column(Integer, ForeignKey("users.user_id"), nullable=False)
    agent_id = Column(Integer, ForeignKey("users.user_id"))

    message = Column(Text)
    desired_date = Column(Date)
    duration_days = Column(Integer)
    answer = Column(Text)

    status = Column(String(20), default='pending')

    created_at = Column(DateTime, default=datetime.utcnow)

    # Связи
    property = relationship("Property", back_populates="applications")
    tenant = relationship("User", back_populates="applications", foreign_keys=[tenant_id])
    assigned_agent = relationship("User", back_populates="managed_applications", foreign_keys=[agent_id])
    contract = relationship("Contract", back_populates="application", uselist=False)

    # Check constraints
    __table_args__ = (
        CheckConstraint(
            "status IN ('pending', 'approved', 'rejected', 'completed')",
            name="application_status_check"
        ),
        CheckConstraint("duration_days > 0", name="duration_positive"),
    )


class Contract(Base):
    """Модель договоров (аренды и купли-продажи)"""
    __tablename__ = "contracts"

    contract_id = Column(Integer, primary_key=True, index=True)
    application_id = Column(Integer, ForeignKey("applications.application_id"), unique=True)

    # Стороны договора
    property_id = Column(Integer, ForeignKey("properties.property_id"), nullable=False)
    tenant_id = Column(Integer, ForeignKey("users.user_id"), nullable=False)
    owner_id = Column(Integer, ForeignKey("users.user_id"), nullable=False)

    # Ключевые параметры
    contract_type = Column(String(10))
    start_date = Column(Date, nullable=False)
    end_date = Column(Date)
    total_amount = Column(DECIMAL(12, 2), nullable=False)

    # Статус подписания
    signing_status = Column(String(10), default='draft')

    created_at = Column(DateTime, default=datetime.utcnow)

    # Связи
    application = relationship("Application", back_populates="contract")
    property = relationship("Property", back_populates="contracts")
    tenant_user = relationship("User", foreign_keys=[tenant_id])
    owner_user = relationship("User", foreign_keys=[owner_id])

    # Check constraints
    __table_args__ = (
        CheckConstraint(
            "contract_type IN ('lease', 'sale')",
            name="contract_type_check"
        ),
        CheckConstraint(
            "signing_status IN ('draft', 'pending', 'signed')",
            name="signing_status_check"
        ),
        CheckConstraint("total_amount >= 0", name="amount_positive"),
    )


class Message(Base):
    """Модель сообщений и уведомлений"""
    __tablename__ = "messages"

    message_id = Column(Integer, primary_key=True, index=True)
    from_user_id = Column(Integer, ForeignKey("users.user_id"))
    to_user_id = Column(Integer, ForeignKey("users.user_id"))
    content = Column(Text, nullable=False)
    is_read = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Связи
    sender = relationship("User", back_populates="sent_messages", foreign_keys=[from_user_id])
    receiver = relationship("User", back_populates="received_messages", foreign_keys=[to_user_id])


class AuditLog(Base):
    """Модель логов действий для администратора"""
    __tablename__ = "audit_logs"

    log_id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.user_id"))
    action = Column(String(100), nullable=False)
    entity_type = Column(String(30), nullable=False)
    entity_id = Column(Integer)
    details = Column(JSONB)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Связь
    user = relationship("User")


# ==================== УТИЛИТЫ ДЛЯ РАБОТЫ С БАЗОЙ ====================

# Создание фабрики сессий
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def get_db():
    """Dependency для FastAPI, предоставляющая сессию БД"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    """Инициализация базы данных - создание всех таблиц"""
    try:
        # Проверяем подключение
        with engine.connect() as connection:
            print("✅ Подключение к PostgreSQL успешно")

            # Создаем все таблицы
            Base.metadata.create_all(bind=engine)

            print("✅ Таблицы успешно созданы")

    except Exception as e:
        print(f"❌ Ошибка подключения или создания таблиц: {e}")
        raise