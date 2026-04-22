# init_db.py
from models import Base, User, Property, PropertyPhoto, Application, Contract
from database import engine, SessionLocal
from datetime import datetime, date
import hashlib


def hash_password(password: str) -> str:
    """Хеширование пароля"""
    return hashlib.sha256(password.encode()).hexdigest()


def create_test_data():
    """Создание тестовых данных"""
    print("🔄 Создание тестовых данных...")
    db = SessionLocal()

    try:
        # ==================== 1. СОЗДАНИЕ ПОЛЬЗОВАТЕЛЕЙ ====================

        # Администратор
        admin = User(
            email="admin@rentease.ru",
            password_hash=hash_password("admin123"),
            full_name="Администратор Системы",
            user_type="admin",
            contact_info={"phone": "+7 (999) 123-45-67"},
            is_active=True,
            created_at=datetime.now()
        )
        db.add(admin)

        # Агенты
        agent1 = User(
            email="agent.anna@rentease.ru",
            password_hash=hash_password("agent123"),
            full_name="Анна Петрова",
            user_type="agent",
            contact_info={"phone": "+7 (999) 234-56-78"},
            is_active=True,
            created_at=datetime.now()
        )
        db.add(agent1)

        agent2 = User(
            email="agent.ivan@rentease.ru",
            password_hash=hash_password("agent123"),
            full_name="Иван Сидоров",
            user_type="agent",
            contact_info={"phone": "+7 (999) 345-67-89"},
            is_active=True,
            created_at=datetime.now()
        )
        db.add(agent2)

        # Собственники
        owner1 = User(
            email="owner.elena@mail.ru",
            password_hash=hash_password("owner123"),
            full_name="Елена Смирнова",
            user_type="owner",
            contact_info={"phone": "+7 (999) 456-78-90"},
            is_active=True,
            created_at=datetime.now()
        )
        db.add(owner1)

        owner2 = User(
            email="owner.dmitry@mail.ru",
            password_hash=hash_password("owner123"),
            full_name="Дмитрий Иванов",
            user_type="owner",
            contact_info={"phone": "+7 (999) 567-89-01"},
            is_active=True,
            created_at=datetime.now()
        )
        db.add(owner2)

        # Арендаторы
        tenant1 = User(
            email="tenant.alex@mail.ru",
            password_hash=hash_password("tenant123"),
            full_name="Алексей Кузнецов",
            user_type="tenant",
            contact_info={"phone": "+7 (999) 678-90-12"},
            is_active=True,
            created_at=datetime.now()
        )
        db.add(tenant1)

        tenant2 = User(
            email="tenant.maria@mail.ru",
            password_hash=hash_password("tenant123"),
            full_name="Мария Васильева",
            user_type="tenant",
            contact_info={"phone": "+7 (999) 789-01-23"},
            is_active=True,
            created_at=datetime.now()
        )
        db.add(tenant2)

        db.commit()
        print("✅ Пользователи созданы")

        # ==================== 2. СОЗДАНИЕ ОБЪЕКТОВ НЕДВИЖИМОСТИ ====================

        properties = [
            Property(
                owner_id=owner1.user_id,
                agent_id=agent1.user_id,
                title="Уютная квартира в центре",
                description="Просторная квартира с видом на набережную, отличный ремонт, вся техника новая",
                address="ул. Тверская, д. 10, кв. 45",
                city="Москва",
                property_type="apartment",
                area=65.5,
                rooms=2,
                price=45000,
                interval_pay="month",
                status="active",
                created_at=datetime.now()
            ),
            Property(
                owner_id=owner1.user_id,
                agent_id=agent1.user_id,
                title="Студия в новостройке",
                description="Современная студия с дизайнерским ремонтом, есть всё для комфортного проживания",
                address="ул. Ленина, д. 15",
                city="Москва",
                property_type="apartment",
                area=32.0,
                rooms=1,
                price=35000,
                interval_pay="month",
                status="active",
                created_at=datetime.now()
            ),
            Property(
                owner_id=owner2.user_id,
                agent_id=agent2.user_id,
                title="Загородный дом у озера",
                description="Двухэтажный дом с участком, камин, сауна, отличное место для отдыха",
                address="пос. Репино, ул. Лесная, д. 5",
                city="Ленинградская область",
                property_type="house",
                area=150.0,
                rooms=4,
                price=120000,
                interval_pay="month",
                status="active",
                created_at=datetime.now()
            ),
            Property(
                owner_id=owner2.user_id,
                agent_id=agent2.user_id,
                title="Квартира на Невском",
                description="Квартира в историческом центре, высокие потолки, лепнина, паркет",
                address="Невский пр., д. 25, кв. 12",
                city="Санкт-Петербург",
                property_type="apartment",
                area=95.0,
                rooms=3,
                price=75000,
                interval_pay="month",
                status="active",
                created_at=datetime.now()
            ),
            Property(
                owner_id=owner1.user_id,
                agent_id=agent1.user_id,
                title="Коммерческое помещение",
                description="Помещение свободного назначения на первом этаже жилого дома",
                address="пр. Мира, д. 30",
                city="Новосибирск",
                property_type="commercial",
                area=85.0,
                rooms=2,
                price=60000,
                interval_pay="month",
                status="active",
                created_at=datetime.now()
            ),
            Property(
                owner_id=owner2.user_id,
                agent_id=agent2.user_id,
                title="Квартира у метро",
                description="Уютная квартира в 5 минутах от метро, хороший ремонт, есть мебель",
                address="ул. Гагарина, д. 7",
                city="Екатеринбург",
                property_type="apartment",
                area=55.0,
                rooms=2,
                price=38000,
                interval_pay="month",
                status="active",
                created_at=datetime.now()
            )
        ]

        for prop in properties:
            db.add(prop)
        db.commit()
        print("✅ Объекты недвижимости созданы")

        # ==================== 3. СОЗДАНИЕ ФОТОГРАФИЙ ====================

        # Получаем созданные объекты
        all_props = db.query(Property).all()

        for i, prop in enumerate(all_props):
            # Главное фото
            main_photo = PropertyPhoto(
                property_id=prop.property_id,
                url=f"/static/photo{i+1}.png",
                is_main=True,
                sequence_number=1
            )
            db.add(main_photo)

            # Дополнительные фото (для некоторых объектов)
            if i % 2 == 0:
                photo2 = PropertyPhoto(
                    property_id=prop.property_id,
                    url=f"/static/photo{(i%3)+2}.png",
                    is_main=False,
                    sequence_number=2
                )
                db.add(photo2)

        db.commit()
        print("✅ Фотографии созданы")

        # ==================== 4. СОЗДАНИЕ ТЕСТОВЫХ ЗАЯВОК ====================

        applications = [
            Application(
                property_id=all_props[0].property_id,
                tenant_id=tenant1.user_id,
                agent_id=agent1.user_id,
                message="Интересует квартира, хотел бы посмотреть в выходные",
                desired_date=date(2024, 6, 15),
                duration_days=365,
                status="pending",
                created_at=datetime.now()
            ),
            Application(
                property_id=all_props[1].property_id,
                tenant_id=tenant2.user_id,
                agent_id=agent1.user_id,
                message="Очень понравилась квартира, готов заключить договор",
                desired_date=date(2024, 6, 10),
                duration_days=180,
                answer="Принято, жду вас в пятницу",
                status="approved",
                created_at=datetime.now()
            ),
            Application(
                property_id=all_props[2].property_id,
                tenant_id=tenant1.user_id,
                agent_id=agent2.user_id,
                message="Дороговато, есть возможность торга?",
                desired_date=date(2024, 6, 20),
                duration_days=30,
                answer="Цена фиксированная",
                status="rejected",
                created_at=datetime.now()
            )
        ]

        for app in applications:
            db.add(app)
        db.commit()
        print("✅ Заявки созданы")

        print("\n🎉 Тестовые данные успешно созданы!")
        print("\n📊 Статистика:")
        print(f"   - Пользователей: {db.query(User).count()}")
        print(f"   - Объектов: {db.query(Property).count()}")
        print(f"   - Фотографий: {db.query(PropertyPhoto).count()}")
        print(f"   - Заявок: {db.query(Application).count()}")
        print(f"   - Договоров: {db.query(Contract).count()}")

        print("\n🔑 Тестовые учетные записи:")
        print("   Админ: admin@rentease.ru / admin123")
        print("   Агент: agent.anna@rentease.ru / agent123")
        print("   Собственник: owner.elena@mail.ru / owner123")
        print("   Арендатор: tenant.alex@mail.ru / tenant123")

    except Exception as e:
        db.rollback()
        print(f"❌ Ошибка при создании тестовых данных: {e}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    print("=" * 50)
    print("🚀 Инициализация базы данных RentEase")
    print("=" * 50)

    try:
        # Создаем таблицы
        Base.metadata.create_all(bind=engine)
        print("✅ Таблицы созданы")

        # Создаем тестовые данные
        create_test_data()

    except Exception as e:
        print(f"❌ Ошибка: {e}")