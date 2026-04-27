from sqlalchemy import Column, Integer, String, Text, Date, DateTime, Boolean, DECIMAL, ForeignKey, \
    CheckConstraint
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.ext.mutable import MutableDict
from sqlalchemy.orm import relationship
from datetime import datetime
from database import Base

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
    contact_info = Column(MutableDict.as_mutable(JSONB), default=dict)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Связи
    owned_properties = relationship("Property", back_populates="owner", foreign_keys="Property.owner_id")
    applications = relationship("Application", back_populates="tenant", foreign_keys="Application.tenant_id")
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
    photos = relationship("PropertyPhoto", back_populates="property", cascade="all, delete-orphan")
    applications = relationship("Application", back_populates="property", cascade="all, delete-orphan")

    # Check constraints
    __table_args__ = (
        CheckConstraint(
            "property_type IN ('apartment', 'house', 'commercial')",
            name="property_type_check"
        ),
        CheckConstraint(
            "interval_pay IN ('week', 'month')",
            name="interval_pay_check"
        ),
        CheckConstraint(
            "status IN ('draft', 'active', 'blocked', 'rented', 'archived')",
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

    message = Column(Text)
    desired_date = Column(Date)
    duration_days = Column(Integer)
    answer = Column(Text)
    responded_at = Column(DateTime, nullable=True)  # Когда ответили на заявку

    status = Column(String(20), default='pending')

    created_at = Column(DateTime, default=datetime.utcnow)

    # Связи
    property = relationship("Property", back_populates="applications")
    tenant = relationship("User", foreign_keys=[tenant_id])
    contract = relationship("Contract", back_populates="application", uselist=False)

    # Check constraints
    __table_args__ = (
        CheckConstraint(
            "status IN ('pending', 'approved', 'rejected', 'completed', 'cancelled')",
            name="application_status_check"
        ),
        CheckConstraint("duration_days > 0", name="duration_positive"),
    )


class Contract(Base):
    """Модель договоров"""
    __tablename__ = "contracts"

    contract_id = Column(Integer, primary_key=True, index=True)
    application_id = Column(Integer, ForeignKey("applications.application_id"), unique=True)

    # Ключевые параметры
    start_date = Column(Date, nullable=False)
    end_date = Column(Date)
    total_amount = Column(DECIMAL(12, 2), nullable=False)

    # Статус подписания
    signing_status = Column(String(10), default='draft')

    # Подписи
    tenant_signed = Column(Boolean, default=False)
    owner_signed = Column(Boolean, default=False)

    created_at = Column(DateTime, default=datetime.utcnow)

    # Связи
    application = relationship("Application", back_populates="contract")

    # Check constraints
    __table_args__ = (
        CheckConstraint(
            "signing_status IN ('draft', 'pending', 'signed', 'cancelled')",
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