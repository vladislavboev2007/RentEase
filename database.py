# database.py
from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, relationship, sessionmaker

# Настройка подключения к БД
POSTGRESQL_DATABASE_URL = "postgresql+psycopg2://postgres:1234@localhost:5432/RentEase"

# Создание движка
engine = create_engine(POSTGRESQL_DATABASE_URL, echo=False)  # echo=True для отладки SQL

# Базовый класс для всех моделей
class Base(DeclarativeBase):
    pass

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