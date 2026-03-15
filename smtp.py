import smtplib
import logging
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from typing import List, Optional
from datetime import datetime
import asyncio

# Настройки для Yandex Mail
SMTP_SERVER = "smtp.yandex.ru"
SMTP_PORT = 587  # Для TLS
SMTP_PORT_SSL = 465  # Для SSL

# Данные для авторизации (замените на свои)
SMTP_USER = "boeff.vladislav2017@yandex.ru"  # Ваш email на Яндексе
SMTP_PASSWORD = "pqmzqqziaocazoaa"  # Пароль приложения (не от аккаунта!)

# Настройка логирования
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class YandexMailSender:
    """Класс для отправки писем через Yandex Mail"""

    def __init__(self, username: str = None, password: str = None):
        """
        Инициализация отправителя писем

        :param username: Email на Яндексе
        :param password: Пароль приложения
        """
        self.username = username or SMTP_USER
        self.password = password or SMTP_PASSWORD
        self.server = None

    def connect(self) -> bool:
        """Установка соединения с SMTP сервером"""
        try:
            self.server = smtplib.SMTP(SMTP_SERVER, SMTP_PORT)
            self.server.starttls()  # Включаем TLS
            self.server.login(self.username, self.password)
            logger.info(f"✅ Успешное подключение к {SMTP_SERVER}")
            return True
        except Exception as e:
            logger.error(f"❌ Ошибка подключения к SMTP: {e}")
            return False

    def disconnect(self):
        """Закрытие соединения"""
        if self.server:
            try:
                self.server.quit()
                logger.info("✅ Соединение закрыто")
            except:
                pass

    def send_email(self,
                   to_email: str,
                   subject: str,
                   html_content: str = None,
                   text_content: str = None,
                   from_name: str = "RentEase") -> bool:
        """
        Отправка одного письма

        :param to_email: Email получателя
        :param subject: Тема письма
        :param html_content: HTML-содержимое (опционально)
        :param text_content: Текстовое содержимое (опционально)
        :param from_name: Имя отправителя
        :return: True если успешно, иначе False
        """
        try:
            # Создаем сообщение
            msg = MIMEMultipart('alternative')
            msg['From'] = f"{from_name} <{self.username}>"
            msg['To'] = to_email
            msg['Subject'] = subject
            msg['Date'] = datetime.now().strftime('%a, %d %b %Y %H:%M:%S %z')

            # Добавляем текстовую версию (обязательно)
            if text_content:
                msg.attach(MIMEText(text_content, 'plain', 'utf-8'))
            else:
                # Если нет текстовой версии, создаем простую из HTML
                plain_text = html_content.replace('<br>', '\n').replace('</p>', '\n').replace('<strong>', '').replace(
                    '</strong>', '')
                plain_text = re.sub(r'<[^>]+>', '', plain_text) if 're' in globals() else plain_text
                msg.attach(MIMEText(plain_text, 'plain', 'utf-8'))

            # Добавляем HTML-версию
            if html_content:
                msg.attach(MIMEText(html_content, 'html', 'utf-8'))

            # Подключаемся и отправляем
            if not self.server:
                if not self.connect():
                    return False

            self.server.send_message(msg)
            logger.info(f"✅ Письмо отправлено на {to_email}")
            return True

        except Exception as e:
            logger.error(f"❌ Ошибка отправки письма: {e}")
            return False

    def send_bulk(self,
                  recipients: List[str],
                  subject: str,
                  html_content: str = None,
                  text_content: str = None,
                  from_name: str = "RentEase") -> dict:
        """
        Массовая рассылка писем

        :param recipients: Список email-ов получателей
        :param subject: Тема письма
        :param html_content: HTML-содержимое
        :param text_content: Текстовое содержимое
        :param from_name: Имя отправителя
        :return: Словарь с результатами {email: True/False}
        """
        results = {}

        # Подключаемся один раз для всех писем
        if not self.connect():
            return {email: False for email in recipients}

        try:
            for email in recipients:
                success = self.send_email(email, subject, html_content, text_content, from_name)
                results[email] = success
        finally:
            self.disconnect()

        return results

    def send_code(self, to_email: str, code: str, purpose: str = "registration") -> bool:
        """
        Отправка кода подтверждения

        :param to_email: Email получателя
        :param code: Код подтверждения
        :param purpose: Цель (registration/recovery)
        :return: True если успешно
        """
        purposes = {
            "registration": {
                "subject": "Код подтверждения регистрации в RentEase",
                "title": "Регистрация в RentEase"
            },
            "recovery": {
                "subject": "Восстановление пароля в RentEase",
                "title": "Восстановление доступа"
            }
        }

        purpose_data = purposes.get(purpose, purposes["registration"])

        # Создаем HTML-содержимое
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                body {{
                    font-family: 'Segoe UI', Arial, sans-serif;
                    line-height: 1.6;
                    color: #333;
                    max-width: 600px;
                    margin: 0 auto;
                    padding: 20px;
                }}
                .header {{
                    background: linear-gradient(135deg, #007bff 0%, #0056b3 100%);
                    color: white;
                    padding: 20px;
                    text-align: center;
                    border-radius: 10px 10px 0 0;
                }}
                .content {{
                    background: #f8f9fa;
                    padding: 30px;
                    border: 1px solid #e9ecef;
                    border-radius: 0 0 10px 10px;
                }}
                .code {{
                    font-size: 32px;
                    font-weight: 700;
                    color: #007bff;
                    text-align: center;
                    padding: 20px;
                    background: white;
                    border-radius: 10px;
                    margin: 20px 0;
                    letter-spacing: 5px;
                }}
                .footer {{
                    margin-top: 20px;
                    font-size: 12px;
                    color: #6c757d;
                    text-align: center;
                }}
            </style>
        </head>
        <body>
            <div class="header">
                <h1>RentEase</h1>
            </div>
            <div class="content">
                <h2>{purpose_data['title']}</h2>
                <p>Здравствуйте!</p>
                <p>Для завершения {purpose_data['title'].lower()} используйте следующий код подтверждения:</p>

                <div class="code">{code[:4]}-{code[4:]}</div>

                <p>Код действителен в течение 5 минут.</p>
                <p>Если вы не запрашивали этот код, просто проигнорируйте данное письмо.</p>

                <div class="footer">
                    <p>© 2024 RentEase. Все права защищены.</p>
                    <p>Это автоматическое письмо, пожалуйста, не отвечайте на него.</p>
                </div>
            </div>
        </body>
        </html>
        """

        text_content = f"""
        RentEase - {purpose_data['title']}

        Здравствуйте!

        Для завершения {purpose_data['title'].lower()} используйте следующий код подтверждения:

        {code[:4]}-{code[4:]}

        Код действителен в течение 5 минут.

        Если вы не запрашивали этот код, просто проигнорируйте данное письмо.

        © 2024 RentEase
        """

        return self.send_email(to_email, purpose_data['subject'], html_content, text_content)


# Функции для быстрого использования
def send_recovery_code(email: str, code: str) -> bool:
    """Отправка кода восстановления"""
    sender = YandexMailSender()
    return sender.send_code(email, code, "recovery")


def send_registration_code(email: str, code: str) -> bool:
    """Отправка кода регистрации"""
    sender = YandexMailSender()
    return sender.send_code(email, code, "registration")


# Пример использования
if __name__ == "__main__":
    # Тестирование
    import re

    # Замените на свои данные
    test_email = "vladislav.boev02@mail.ru"
    test_code = "12345678"

    # Отправка тестового письма
    sender = YandexMailSender()
    if sender.send_code(test_email, test_code, "registration"):
        print(f"✅ Тестовое письмо отправлено на {test_email}")
    else:
        print("❌ Ошибка отправки")